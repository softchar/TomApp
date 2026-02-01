import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/funding_rate.dart';

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
  static const String _baseUrl = 'https://fapi.binance.com';
  static const String _premiumIndexEndpoint = '/fapi/v1/premiumIndex';
  static const String _fundingInfoEndpoint = '/fapi/v1/fundingInfo';

  final http.Client _client;
  Map<String, int> _fundingIntervals = {};

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

  /// 获取资金费率间隔信息
  Future<void> _fetchFundingIntervals() async {
    try {
      final uri = Uri.parse('$_baseUrl$_fundingInfoEndpoint');
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final intervalMap = <String, int>{};

        // 默认所有合约为8小时
        intervalMap['default'] = 8;

        for (var item in data) {
          final info = _FundingIntervalInfo.fromJson(item as Map<String, dynamic>);
          intervalMap[info.symbol] = info.fundingIntervalHours;
        }

        _fundingIntervals = intervalMap;
      }
    } catch (e) {
      // 如果获取失败，使用默认8小时
      _fundingIntervals = {'default': 8};
    }
  }

  /// 获取USDT合约的费率（筛选USDT永续合约）
  Future<List<FundingRate>> getUSDTFuturesRates() async {
    // 先获取费率间隔信息
    await _fetchFundingIntervals();

    final allRates = await getFundingRates();

    // 设置每个合约的实际费率间隔
    for (var rate in allRates) {
      final interval = _fundingIntervals[rate.symbol] ?? _fundingIntervals['default'] ?? 8;
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

  void dispose() {
    _client.close();
  }
}
