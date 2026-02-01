import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/funding_rate.dart';
import '../models/long_short_ratio.dart';

/// 资金费率间隔信息
class _FundingIntervalInfo {
  final String symbol;
  final int fundingIntervalHours;

  _FundingIntervalInfo({
    required this.symbol,
    required this.fundingIntervalHours,
  });

  factory _FundingIntervalInfo.fromJson(Map<String, dynamic> json) {
    return _FundingIntervalInfo(
      symbol: json['symbol'] ?? '',
      fundingIntervalHours: json['fundingIntervalHours'] ?? 8,
    );
  }
}

/// 币安合约API服务
class BinanceApiService {
  // 可配置的API基础URL
  // 如果在中国大陆无法访问，可以设置为代理服务器地址
  // 例如：'https://your-proxy.com' 或使用 Cloudflare Workers
  static String _baseUrl = 'https://fapi.binance.com';

  // 可用的备用域名（按优先级排序）
  static const List<String> _fallbackUrls = [
    'https://fapi.binance.com',    // 原始API
    'https://api.binance.com',      // 备用域名
    'https://data-api.binance.vision', // 公共数据API
  ];

  static const String _premiumIndexEndpoint = '/fapi/v1/premiumIndex';
  static const String _fundingInfoEndpoint = '/fapi/v1/fundingInfo';
  static const String _topLongShortAccountRatioEndpoint = '/futures/data/topLongShortAccountRatio';

  final http.Client _client;

  /// 设置自定义API基础URL（用于代理）
  static void setCustomBaseUrl(String url) {
    _baseUrl = url;
  }

  /// 重置为默认API
  static void resetBaseUrl() {
    _baseUrl = _fallbackUrls[0];
  }

  /// 获取当前基础URL
  static String get currentBaseUrl => _baseUrl;

  BinanceApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 获取所有合约的资金费率
  Future<List<FundingRate>> getFundingRates() async {
    try {
      final uri = Uri.parse('$_baseUrl$_premiumIndexEndpoint');

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => FundingRate.fromPremiumIndex(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } catch (e) {
      throw Exception('获取资金费率失败: $e');
    }
  }

  /// 获取资金费率间隔信息（返回所有合约的间隔）
  Future<Map<String, int>> fetchFundingIntervals() async {
    try {
      final uri = Uri.parse('$_baseUrl$_fundingInfoEndpoint');
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final intervalMap = <String, int>{};

        if (kDebugMode) print('[BinanceApiService] fundingInfo 返回 ${data.length} 条数据');

        for (var item in data) {
          final info = _FundingIntervalInfo.fromJson(item as Map<String, dynamic>);
          intervalMap[info.symbol] = info.fundingIntervalHours;
        }

        if (kDebugMode) print('[BinanceApiService] 找到1小时/4小时合约: ${intervalMap.entries.where((e) => e.value == 1 || e.value == 4).length} 个');

        return intervalMap;
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('[BinanceApiService] fetchFundingIntervals 失败: $e');
      return {};
    }
  }

  /// 获取USDT合约的费率（筛选USDT永续合约）
  Future<List<FundingRate>> getUSDTFuturesRates() async {
    // 先获取费率间隔信息
    final intervalMap = await fetchFundingIntervals();

    final allRates = await getFundingRates();

    // 设置每个合约的实际费率间隔
    for (var rate in allRates) {
      final interval = intervalMap[rate.symbol] ?? 8;
      rate.setFundingIntervalHours(interval);
    }

    // 筛选USDT/BUSD永续合约
    return allRates.where((rate) {
      return rate.symbol.endsWith('USDT') || rate.symbol.endsWith('BUSD');
    }).toList();
  }

  /// 根据交易对获取单个资金费率
  Future<FundingRate?> getFundingRateBySymbol(String symbol) async {
    try {
      final uri = Uri.parse('$_baseUrl$_premiumIndexEndpoint?symbol=$symbol');

      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FundingRate.fromPremiumIndex(data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取大户多空账号人数比（单个交易对）
  Future<List<LongShortRatio>> getTopLongShortAccountRatio(
    String symbol, {
    String period = '5m', // 5m, 15m, 30m, 1h, 2h, 4h, 6h, 12h, 1d
    int limit = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        'symbol': symbol,
        'period': period,
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl$_topLongShortAccountRatioEndpoint')
          .replace(queryParameters: queryParams);

      // 添加完整的浏览器头部避免 403 错误
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'Connection': 'keep-alive',
          'Referer': 'https://www.binance.com/',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((json) => LongShortRatio.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('请求超时，请检查网络连接');
    } catch (e) {
      throw Exception('获取大户多空比失败: $e');
    }
  }

  /// 获取所有合约的大户多空比（最新数据）
  /// 只获取1小时和4小时资费间隔的合约
  /// 按空头比例从高到低排序
  Future<List<LongShortRatio>> getLatestTopLongShortRatio({
    String period = '5m',
  }) async {
    try {
      // 步骤1: 从 /fapi/v1/fundingInfo 获取所有合约的资费间隔
      final intervalMap = await fetchFundingIntervals();

      if (intervalMap.isEmpty) {
        if (kDebugMode) print('[BinanceApiService] 没有获取到资费间隔数据');
        return [];
      }

      // 步骤2: 筛选出1小时和4小时资费间隔的USDT合约
      final targetSymbols = intervalMap.entries
          .where((entry) =>
              entry.key.endsWith('USDT') &&
              (entry.value == 1 || entry.value == 4))
          .map((entry) => entry.key)
          .toList();

      if (kDebugMode) {
        print('[BinanceApiService] 筛选出的1h/4h合约数量: ${targetSymbols.length}');
        print('[BinanceApiService] 筛选出的合约前20个: ${targetSymbols.take(20).join(", ")}');

        // 检查 BULLA 是否在筛选列表中
        final hasBulla = targetSymbols.any((s) => s.contains('BULLA') || s.contains('bulla'));
        print('[BinanceApiService] BULLA 是否在1h/4h列表中: $hasBulla');

        // 如果有，显示 BULLA 的资费间隔
        if (hasBulla) {
          final bullaEntry = intervalMap.entries.firstWhere(
            (e) => e.key.contains('BULLA') || e.key.contains('bulla'),
            orElse: () => const MapEntry('NOT_FOUND', 0),
          );
          print('[BinanceApiService] BULLA 资费间隔: ${bullaEntry.value} 小时');
        }
      }

      if (targetSymbols.isEmpty) {
        if (kDebugMode) print('[BinanceApiService] 没有1h/4h合约');
        return [];
      }

      final List<LongShortRatio> allRatios = [];

      // 步骤3: 获取这些合约的多空账号人数比
      // 获取所有合约（不再限制15个），但并发处理以提高速度

      if (kDebugMode) print('[BinanceApiService] 开始获取 ${targetSymbols.length} 个合约的多空比数据...');

      // 分批处理，每批5个并发请求（避免触发速率限制）
      const batchSize = 5;
      for (int i = 0; i < targetSymbols.length; i += batchSize) {
        final batch = targetSymbols.skip(i).take(batchSize).toList();

        // 并发获取当前批次
        final futures = batch.map((symbol) async {
          try {
            final ratios = await getTopLongShortAccountRatio(symbol, period: period, limit: 1);
            if (ratios.isNotEmpty) {
              if (kDebugMode) print('[BinanceApiService] 成功获取 $symbol 多空比');
              final ratio = ratios.first;
              // 设置资费间隔
              ratio.setFundingIntervalHours(intervalMap[symbol] ?? 8);
              return ratio;
            }
          } catch (e) {
            if (kDebugMode) print('[BinanceApiService] 获取 $symbol 多空比失败: $e');
          }
          return null;
        }).toList();

        final results = await Future.wait(futures);
        for (final result in results) {
          if (result != null) {
            allRatios.add(result);
          }
        }

        if (kDebugMode) print('[BinanceApiService] 进度: ${allRatios.length}/${targetSymbols.length}');
      }

      if (kDebugMode) {
        print('[BinanceApiService] 共获取 ${allRatios.length} 条多空比数据');
        // 打印每个合约的多空比详情
        for (final ratio in allRatios) {
          final shortPct = (ratio.shortAccount * 100).toStringAsFixed(1);
          final longPct = (ratio.longAccount * 100).toStringAsFixed(1);
          print('[BinanceApiService] ${ratio.symbol}: 空${shortPct}% / 多${longPct}%');
        }
      }

      // 按空头比例从高到低排序
      allRatios.sort((a, b) => b.shortAccount.compareTo(a.shortAccount));

      return allRatios;
    } catch (e) {
      if (kDebugMode) print('[BinanceApiService] getLatestTopLongShortRatio 失败: $e');
      throw Exception('获取最新大户多空比失败: $e');
    }
  }

  /// 获取所有合约的大户多空比（带进度回调，用于分批显示）
  /// 只获取1小时和4小时资费间隔的合约
  /// 按空头比例从高到低排序
  Future<void> getLatestTopLongShortRatioWithProgress({
    String period = '5m',
    void Function(List<LongShortRatio> batch)? onProgress,
  }) async {
    try {
      // 步骤1: 从 /fapi/v1/fundingInfo 获取所有合约的资费间隔
      final intervalMap = await fetchFundingIntervals();

      if (intervalMap.isEmpty) {
        if (kDebugMode) print('[BinanceApiService] 没有获取到资费间隔数据');
        return;
      }

      // 步骤2: 筛选出1小时和4小时资费间隔的USDT合约
      final targetSymbols = intervalMap.entries
          .where((entry) =>
              entry.key.endsWith('USDT') &&
              (entry.value == 1 || entry.value == 4))
          .map((entry) => entry.key)
          .toList();

      if (kDebugMode) {
        print('[BinanceApiService] 筛选出的1h/4h合约数量: ${targetSymbols.length}');
      }

      if (targetSymbols.isEmpty) {
        if (kDebugMode) print('[BinanceApiService] 没有1h/4h合约');
        return;
      }

      final List<LongShortRatio> allRatios = [];

      if (kDebugMode) print('[BinanceApiService] 开始获取 ${targetSymbols.length} 个合约的多空比数据...');

      // 分批处理，每批5个并发请求（避免触发速率限制）
      const batchSize = 5;
      for (int i = 0; i < targetSymbols.length; i += batchSize) {
        final batch = targetSymbols.skip(i).take(batchSize).toList();

        // 并发获取当前批次
        final futures = batch.map((symbol) async {
          try {
            final ratios = await getTopLongShortAccountRatio(symbol, period: period, limit: 1);
            if (ratios.isNotEmpty) {
              final ratio = ratios.first;
              // 设置资费间隔
              ratio.setFundingIntervalHours(intervalMap[symbol] ?? 8);
              return ratio;
            }
          } catch (e) {
            // 打印错误信息以便调试
            if (kDebugMode) print('[BinanceApiService] 获取 $symbol 多空比失败: $e');
          }
          return null;
        }).toList();

        final results = await Future.wait(futures);
        final batchRatios = <LongShortRatio>[];
        for (final result in results) {
          if (result != null) {
            allRatios.add(result);
            batchRatios.add(result);
          }
        }

        // 每批次完成后通知回调
        if (onProgress != null && batchRatios.isNotEmpty) {
          onProgress(batchRatios);
        }

        if (kDebugMode) print('[BinanceApiService] 进度: ${allRatios.length}/${targetSymbols.length}');
      }
    } catch (e) {
      if (kDebugMode) print('[BinanceApiService] getLatestTopLongShortRatioWithProgress 失败: $e');
      throw Exception('获取最新大户多空比失败: $e');
    }
  }

  /// 测试 API 连接是否可用
  Future<Map<String, dynamic>> testConnection() async {
    final result = <String, dynamic>{
      'baseUrl': _baseUrl,
      'isConnected': false,
      'message': '',
      'details': <String, bool>{},
    };

    try {
      // 测试基础 API (premiumIndex)
      try {
        final uri = Uri.parse('$_baseUrl$_premiumIndexEndpoint?symbol=BTCUSDT');
        final response = await _client.get(uri).timeout(const Duration(seconds: 10));
        result['details']['premiumIndex'] = response.statusCode == 200;
        if (response.statusCode == 200) {
          result['message'] = '基础 API 可访问';
        }
      } catch (e) {
        result['details']['premiumIndex'] = false;
      }

      // 测试多空比 API (topLongShortAccountRatio)
      try {
        final uri = Uri.parse('$_baseUrl$_topLongShortAccountRatioEndpoint?symbol=BTCUSDT&period=5m');
        final response = await _client.get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 10));
        result['details']['longShortRatio'] = response.statusCode == 200;
        if (response.statusCode == 200) {
          result['isConnected'] = true;
          result['message'] = '所有 API 连接正常';
        }
      } catch (e) {
        result['details']['longShortRatio'] = false;
        if (result['message'] == '基础 API 可访问') {
          result['message'] = '基础 API 可用，但多空比 API 需要配置代理';
        } else {
          result['message'] = 'API 连接失败，请配置代理服务器';
        }
      }

      return result;
    } catch (e) {
      result['message'] = '连接测试失败: $e';
      return result;
    }
  }

  void dispose() {
    _client.close();
  }
}
