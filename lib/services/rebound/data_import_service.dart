import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/drift_database.dart';

/// 历史 K 线数据导入管线。
///
/// 从 data.binance.vision 月度 ZIP 下载 USDT 永续 K 线，
/// CSV 解析后写入 drift Klines 表，缺口通过 REST /fapi/v1/klines 补足。
class DataImportService {
  /// data.binance.vision 月度 K 线 ZIP 基础 URL
  static const String _baseUrl =
      'https://data.binance.vision/data/futures/um/monthly/klines';

  /// 最大下载并发数
  static const int _maxConcurrency = 5;

  /// ZIP 响应体大小上限（200MB 防 ZIP bomb）
  static const int _maxZipBytes = 200 * 1024 * 1024;

  /// symbol 格式校验正则：大写字母 + USDT 结尾
  static final RegExp _symbolPattern = RegExp(r'^[A-Z]+USDT$');

  // ─── 公开 API ────────────────────────────────────────────────

  /// 下载单个月份的 K 线 ZIP 文件并解析为 KlineData 列表。
  ///
  /// [symbol] 必须为大写字母 + USDT 结尾的有效合约 symbol。
  /// 无效 symbol 返回明确的 ArgumentError。
  Future<List<KlineData>> downloadMonth({
    required String symbol,
    required String interval,
    required int year,
    required int month,
  }) async {
    validateSymbol(symbol);

    final monthStr = month.toString().padLeft(2, '0');
    final url =
        '$_baseUrl/$symbol/$interval/$symbol-$interval-$year-$monthStr.zip';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('下载失败 ($symbol $year-$monthStr): HTTP ${response.statusCode}');
    }

    // 检查响应体大小，防 ZIP bomb（T-06-02 缓解）
    if (response.bodyBytes.length > _maxZipBytes) {
      throw Exception(
        'ZIP 文件过大 (${response.bodyBytes.length} bytes)，超过上限 $_maxZipBytes bytes',
      );
    }

    // 解压 ZIP（每月仅含 1 个 CSV 文件）
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    if (archive.files.isEmpty) {
      throw Exception('ZIP 文件为空 ($symbol $year-$monthStr)');
    }

    // 只取第一个文件（entry.name 防路径遍历 T-06-02 缓解）
    final csvFile = archive.files.first;
    final csvContent = utf8.decode(csvFile.content);

    return _parseCsv(
      csvContent,
      symbol: symbol,
      interval: interval,
    );
  }

  /// 批量导入历史 K 线数据到 drift Klines 表。
  ///
  /// 遍历 config.symbols × ['15m'] 周期，按月下载并批量写入。
  /// 使用 drift batch insert 每批 1000 条，复合主键自动去重。
  /// 返回实际新增的 K 线条数（不含被 insertOrIgnore 跳过的重复行，WR-05）。
  Future<int> importHistoricalData({
    required AppDatabase db,
    required BacktestConfig config,
  }) async {
    int totalInserted = 0;

    // 目前只导入 15m 周期（后续 Phase 可扩展为多周期）
    const intervals = ['15m'];

    for (final symbol in config.symbols) {
      validateSymbol(symbol);

      for (final interval in intervals) {
        // 计算需要下载的月份列表
        final months = _monthsInRange(config.startDate, config.endDate);

        // 分批并发下载（控制并发数）
        for (int i = 0; i < months.length; i += _maxConcurrency) {
          final batch = months.skip(i).take(_maxConcurrency).toList();
          final futures = batch.map((ym) => downloadMonth(
                symbol: symbol,
                interval: interval,
                year: ym.$1,
                month: ym.$2,
              ));

          final results = await Future.wait(futures);

          for (final klineDataList in results) {
            // 将 KlineData 转换为 drift Kline 并批量写入
            final klines = klineDataList
                .map((kd) => KlinesCompanion.insert(
                      symbol: symbol,
                      interval: interval,
                      openTime: kd.time.millisecondsSinceEpoch,
                      open: kd.open,
                      high: kd.high,
                      low: kd.low,
                      close: kd.close,
                      volume: kd.volume,
                      // CSV 不包含 closeTime，设为 0
                      closeTime: kd.time.millisecondsSinceEpoch + 900000,
                    ))
                .toList();

            // 按每批 1000 条写入
            for (int j = 0; j < klines.length; j += 1000) {
              final chunk = klines.sublist(
                j,
                min(j + 1000, klines.length),
              );
              // 用 batch 前后的总行数差值计算实际新增行数（WR-05）。
              // 原实现 totalInserted += chunk.length 会把被 insertOrIgnore
              // 跳过的重复行也算入，导致返回值虚高，调用方 insertedCount == 0
              // 判断可能误判「有数据」。
              final countBefore = await _countKlines(db);
              await db.batch((batch) {
                batch.insertAll(
                  db.klines,
                  chunk,
                  mode: InsertMode.insertOrIgnore,
                );
              });
              final countAfter = await _countKlines(db);
              totalInserted += (countAfter - countBefore).clamp(0, chunk.length);
            }
          }
        }
      }
    }

    return totalInserted;
  }

  /// REST 补足当月缺口数据。
  ///
  /// 从 Binance /fapi/v1/klines 拉取指定区间内的 K 线，
  /// 写入 drift Klines 表。遵守 Binance REST 权重限制。
  Future<void> gapFill({
    required String symbol,
    required String interval,
    DateTime? startTime,
    DateTime? endTime,
    required AppDatabase db,
  }) async {
    validateSymbol(symbol);

    const baseUrl = 'https://fapi.binance.com/fapi/v1/klines';
    const maxLimit = 1000;
    var currentStart = startTime?.millisecondsSinceEpoch ?? 0;
    final endMs = endTime?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    while (currentStart < endMs) {
      final uri = Uri.parse(
        '$baseUrl?symbol=$symbol&interval=$interval&limit=$maxLimit&startTime=$currentStart&endTime=$endMs',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'gapFill 请求失败 ($symbol): HTTP ${response.statusCode}',
        );
      }

      final List<dynamic> data = jsonDecode(response.body);

      if (data.isEmpty) break;

      final klines = <KlinesCompanion>[];
      for (final item in data) {
        final list = item as List<dynamic>;
        klines.add(KlinesCompanion.insert(
          symbol: symbol,
          interval: interval,
          openTime: list[0] as int,
          open: double.parse(list[1].toString()),
          high: double.parse(list[2].toString()),
          low: double.parse(list[3].toString()),
          close: double.parse(list[4].toString()),
          volume: double.parse(list[5].toString()),
          closeTime: list[6] as int,
        ));
      }

      // 批量写入，去重
      await db.batch((batch) {
        batch.insertAll(db.klines, klines, mode: InsertMode.insertOrIgnore);
      });

      // 用最后一条的 openTime+1 作为下页起点
      final lastItem = data.last as List<dynamic>;
      currentStart = (lastItem[0] as int) + 1;

      // 遵守权重限制：200ms 间隔
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// 从 Binance /fapi/v1/ticker/24hr 获取按 24h 交易量排序的前 [count] 个 USDT 永续 symbol。
  ///
  /// 请求失败抛出异常（不静默回退默认列表）。
  Future<List<String>> fetchTopSymbols({int count = 100}) async {
    const url = 'https://fapi.binance.com/fapi/v1/ticker/24hr';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'fetchTopSymbols 请求失败: HTTP ${response.statusCode}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body);

    // 过滤 USDT 永续，按 quoteVolume 降序排列
    final usdtSymbols = data
        .where((item) {
          final symbol = item['symbol'] as String? ?? '';
          return _symbolPattern.hasMatch(symbol);
        })
        .map((item) => (
              symbol: item['symbol'] as String,
              quoteVolume: double.tryParse(
                    item['quoteVolume']?.toString() ?? '0',
                  ) ??
                  0.0,
            ))
        .toList();

    // 按 quoteVolume 降序排列
    usdtSymbols.sort((a, b) => b.quoteVolume.compareTo(a.quoteVolume));

    return usdtSymbols.take(count).map((e) => e.symbol).toList();
  }

  // ─── 校验方法 ────────────────────────────────────────────────

  /// 验证 symbol 格式是否有效。
  bool isValidSymbol(String symbol) {
    return _symbolPattern.hasMatch(symbol);
  }

  /// 统计 drift Klines 表的总行数（用于计算 insertOrIgnore 实际新增行数，WR-05）。
  Future<int> _countKlines(AppDatabase db) async {
    final countExp = db.klines.openTime.count();
    final query = db.selectOnly(db.klines)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// 验证 symbol 格式，无效时抛出 ArgumentError。
  void validateSymbol(String symbol) {
    if (!isValidSymbol(symbol)) {
      throw ArgumentError(
        '无效的 symbol 格式: "$symbol"，'
        '必须为大写字母 + USDT 结尾（如 BTCUSDT）',
      );
    }
  }

  // ─── 内部方法 ────────────────────────────────────────────────

  /// 解析 CSV 内容为 KlineData 列表。
  ///
  /// CSV 格式：openTime, open, high, low, close, volume, closeTime,
  ///            quoteVolume, trades, takerBuyBaseVol, takerBuyQuoteVol, ignore
  /// 共 12 列。
  ///
  /// 时间戳标准化：<= 13 位按毫秒处理，> 13 位按微秒除以 1000。
  /// 空行跳过不报错，列数 ≠ 12 的行跳过并打印 warning。
  List<KlineData> _parseCsv(
    String csv, {
    required String symbol,
    required String interval,
  }) {
    final klines = <KlineData>[];
    final lines = csv.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final cols = line.split(',');
      if (cols.length != 12) {
        // 列数 ≠ 12 的行跳过，打印 warning（不崩溃）
        print(
          '⚠️ [DataImportService] 跳过畸形行 ($symbol/$interval): '
          '期望 12 列，实际 ${cols.length} 列',
        );
        continue;
      }

      try {
        final rawTime = int.parse(cols[0]);
        // 时间戳标准化：> 13 位 = 微秒 → 除以 1000 转为毫秒
        final timeMs = rawTime > 10000000000000 ? rawTime ~/ 1000 : rawTime;

        klines.add(KlineData(
          time: DateTime.fromMillisecondsSinceEpoch(timeMs),
          open: double.parse(cols[1]),
          high: double.parse(cols[2]),
          low: double.parse(cols[3]),
          close: double.parse(cols[4]),
          volume: double.parse(cols[5]),
        ));
      } catch (e) {
        // 解析失败时跳过该行并打印 warning
        print(
          '⚠️ [DataImportService] 解析行失败 ($symbol/$interval): $e',
        );
      }
    }

    return klines;
  }

  /// 计算起止日期之间需要覆盖的月份列表。
  List<(int, int)> _monthsInRange(DateTime start, DateTime end) {
    final months = <(int, int)>[];
    var current = DateTime(start.year, start.month, 1);
    final endDate = DateTime(end.year, end.month, 1);

    while (!current.isAfter(endDate)) {
      months.add((current.year, current.month));
      current = DateTime(current.year, current.month + 1, 1);
    }

    return months;
  }

  // ─── 测试辅助 ────────────────────────────────────────────────

  /// 测试用公开入口，将 [_parseCsv] 暴露给单元测试。
  @visibleForTesting
  List<KlineData> parseCsvForTest(
    String csv, {
    required String symbol,
    required String interval,
  }) {
    return _parseCsv(csv, symbol: symbol, interval: interval);
  }
}
