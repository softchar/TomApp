import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tomapp/models/funding_rate.dart';

/// 资金费率历史拉取与本地缓存服务。
///
/// 从 Binance /fapi/v1/fundingRate 分页拉取全量历史 funding rate，
/// 缓存为 Map<symbol, List<FundingRate>>，供回测引擎按 timestamp 查询。
class FundingRateService {
  /// Binance funding rate 历史端点
  static const String _baseUrl = 'https://fapi.binance.com/fapi/v1/fundingRate';

  /// 分页大小（端点最大 1000）
  static const int _pageLimit = 1000;

  /// 请求间隔（遵守 500 req/5min 共享权重限制）
  static const Duration _requestDelay = Duration(milliseconds: 700);

  /// 本地缓存：key 为 symbol，value 为该 symbol 的 funding rate 历史列表
  final Map<String, List<FundingRate>> _cache = {};

  /// HTTP 客户端（可通过构造函数注入，方便测试 mock）
  final http.Client _httpClient;

  FundingRateService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  // ─── 公开 API ────────────────────────────────────────────────

  /// 分页拉取指定 symbol 的 funding rate 历史。
  ///
  /// [startTime] 和 [endTime] 为可选的毫秒时间戳范围。
  /// 每次请求最多 1000 条，自动分页直至无更多数据。
  /// 拉取完成后更新本地缓存。
  Future<List<FundingRate>> fetchHistory({
    required String symbol,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final allRates = <FundingRate>[];
    var currentStart = startTime?.millisecondsSinceEpoch ?? 0;
    final endMs = endTime?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    while (currentStart < endMs) {
      final uri = Uri.parse(
        '$_baseUrl?symbol=$symbol&limit=$_pageLimit&startTime=$currentStart&endTime=$endMs',
      );

      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'fetchHistory 请求失败 ($symbol): HTTP ${response.statusCode}',
        );
      }

      final List<dynamic> data = jsonDecode(response.body);

      if (data.isEmpty) break;

      for (final item in data) {
        allRates.add(
          FundingRate.fromFundingRateEndpoint(item as Map<String, dynamic>),
        );
      }

      // 用最后一条的 fundingTime + 1 作为下页的 startTime（无重复）
      final lastItem = data.last as Map<String, dynamic>;
      currentStart = (lastItem['fundingTime'] as int) + 1;

      // 遵守限流
      await Future.delayed(_requestDelay);
    }

    // 更新缓存：按 fundingTime 升序排列
    allRates.sort((a, b) => a.fundingTime.compareTo(b.fundingTime));
    _cache[symbol] = allRates;

    return allRates;
  }

  /// 查询指定 symbol 在 [timestamp] 时刻生效的 funding rate。
  ///
  /// 查找逻辑：找 fundingTime <= timestamp 且 fundingTime > timestamp - 8h 的最新一条。
  /// 缓存未命中时自动触发 [fetchHistory] 填充。
  Future<double?> getRate(
    String symbol,
    DateTime timestamp,
  ) async {
    // 缓存未命中则自动拉取
    if (!_cache.containsKey(symbol)) {
      await fetchHistory(symbol: symbol, endTime: timestamp);
    }

    final rates = _cache[symbol];
    if (rates == null || rates.isEmpty) return null;

    // 查找生效的 funding rate：
    // funding rate 在结算时刻后的 8 小时内有效
    final eightHoursMs = const Duration(hours: 8).inMilliseconds;
    final timestampMs = timestamp.millisecondsSinceEpoch;
    final cutoffMs = timestampMs - eightHoursMs;

    FundingRate? bestMatch;
    for (final rate in rates) {
      if (rate.fundingTime <= timestampMs && rate.fundingTime > cutoffMs) {
        // 取最新的（fundingTime 最大的）
        if (bestMatch == null || rate.fundingTime > bestMatch.fundingTime) {
          bestMatch = rate;
        }
      }
    }

    return bestMatch?.fundingRate;
  }

  /// 批量预拉取，用于回测引擎启动前一次性加载所有标的的 funding rate 数据。
  ///
  /// 遍历 symbols 列表，每个 symbol 独立拉取（串行，共用限流）。
  Future<void> prefetch(
    List<String> symbols,
    DateTime startTime,
    DateTime endTime,
  ) async {
    for (final symbol in symbols) {
      try {
        await fetchHistory(
          symbol: symbol,
          startTime: startTime,
          endTime: endTime,
        );
      } catch (e) {
        // 单个 symbol 失败不中断整体预拉取
        print('⚠️ [FundingRateService] prefetch 失败 ($symbol): $e');
      }
    }
  }

  /// 清除本地缓存。
  void clearCache() {
    _cache.clear();
  }

  /// 构建回测引擎所需的 fundingRateHistory 映射。
  ///
  /// 返回 {fundingTime(ms): fundingRate}，合并所有缓存 symbol 的费率数据。
  /// 引擎按 fundingTime 精确查找结算时刻的费率。
  ///
  /// 应在 [prefetch] 完成后调用。
  Map<int, double> buildHistoryMap() {
    final map = <int, double>{};
    for (final rates in _cache.values) {
      for (final rate in rates) {
        // 同一 fundingTime 跨 symbol 可能重复，保留最后写入（按 symbol 顺序）
        map[rate.fundingTime] = rate.fundingRate;
      }
    }
    return map;
  }

  /// 缓存中已有的 symbol 数量。
  int get cacheSize => _cache.length;

  /// 指定 symbol 的缓存记录数。
  int cacheSizeFor(String symbol) => _cache[symbol]?.length ?? 0;
}
