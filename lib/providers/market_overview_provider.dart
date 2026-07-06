import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tomapp/services/binance_api_service.dart';
import 'package:tomapp/services/exchange_info_service.dart';

/// 24小时行情数据
class Ticker24h {
  final String symbol;
  final double priceChange;
  final double priceChangePercent;
  final double weightedAvgPrice;
  final double prevClosePrice;
  final double lastPrice;
  final double lastQty;
  final double bidPrice;
  final double bidQty;
  final double askPrice;
  final double askQty;
  final double openPrice;
  final double highPrice;
  final double lowPrice;
  final double volume;
  final double quoteVolume;
  final int openTime;
  final int closeTime;
  final int firstId;
  final int lastId;
  final int count;

  Ticker24h({
    required this.symbol,
    required this.priceChange,
    required this.priceChangePercent,
    required this.weightedAvgPrice,
    required this.prevClosePrice,
    required this.lastPrice,
    required this.lastQty,
    required this.bidPrice,
    required this.bidQty,
    required this.askPrice,
    required this.askQty,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.quoteVolume,
    required this.openTime,
    required this.closeTime,
    required this.firstId,
    required this.lastId,
    required this.count,
  });

  factory Ticker24h.fromJson(Map<String, dynamic> json) {
    return Ticker24h(
      symbol: json['symbol'] as String? ?? '',
      priceChange: double.parse(json['priceChange'] as String? ?? '0'),
      priceChangePercent: double.parse(json['priceChangePercent'] as String? ?? '0'),
      weightedAvgPrice: double.parse(json['weightedAvgPrice'] as String? ?? '0'),
      prevClosePrice: double.parse(json['prevClosePrice'] as String? ?? '0'),
      lastPrice: double.parse(json['lastPrice'] as String? ?? '0'),
      lastQty: double.parse(json['lastQty'] as String? ?? '0'),
      bidPrice: double.parse(json['bidPrice'] as String? ?? '0'),
      bidQty: double.parse(json['bidQty'] as String? ?? '0'),
      askPrice: double.parse(json['askPrice'] as String? ?? '0'),
      askQty: double.parse(json['askQty'] as String? ?? '0'),
      openPrice: double.parse(json['openPrice'] as String? ?? '0'),
      highPrice: double.parse(json['highPrice'] as String? ?? '0'),
      lowPrice: double.parse(json['lowPrice'] as String? ?? '0'),
      volume: double.parse(json['volume'] as String? ?? '0'),
      quoteVolume: double.parse(json['quoteVolume'] as String? ?? '0'),
      openTime: json['openTime'] as int? ?? 0,
      closeTime: json['closeTime'] as int? ?? 0,
      firstId: json['firstId'] as int? ?? 0,
      lastId: json['lastId'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
    );
  }
}

/// 涨幅分布
class PriceChangeDistribution {
  final int negative5Plus;    // -5%以上
  final int negative5to3;     // -5% ~ -3%
  final int negative3to1;     // -3% ~ -1%
  final int negative1to0;     // -1% ~ 0%
  final int positive0to1;     // 0% ~ 1%
  final int positive1to3;     // 1% ~ 3%
  final int positive3to5;     // 3% ~ 5%
  final int positive5Plus;    // 5%以上

  PriceChangeDistribution({
    required this.negative5Plus,
    required this.negative5to3,
    required this.negative3to1,
    required this.negative1to0,
    required this.positive0to1,
    required this.positive1to3,
    required this.positive3to5,
    required this.positive5Plus,
  });

  int get total => negative5Plus + negative5to3 + negative3to1 +
      negative1to0 + positive0to1 + positive1to3 + positive3to5 + positive5Plus;
}

/// 市场概览数据
class MarketOverview {
  final int totalSymbols;
  final int upCount;
  final int downCount;
  final int unchangedCount;
  final List<Ticker24h> topGainers;
  final List<Ticker24h> topLosers;
  final PriceChangeDistribution distribution;

  MarketOverview({
    required this.totalSymbols,
    required this.upCount,
    required this.downCount,
    required this.unchangedCount,
    required this.topGainers,
    required this.topLosers,
    required this.distribution,
  });

  double get upPercent => totalSymbols > 0 ? (upCount / totalSymbols * 100) : 0;
  double get downPercent => totalSymbols > 0 ? (downCount / totalSymbols * 100) : 0;
}

/// 市场概览Provider
class MarketOverviewProvider extends ChangeNotifier {
  MarketOverview? _overview;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  MarketOverview? get overview => _overview;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  MarketOverviewProvider() {
    _startAutoRefresh();
  }

  /// 获取24小时行情数据
  Future<void> fetchMarketOverview() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 等待 ExchangeInfoService 初始化完成
      final exchangeInfo = ExchangeInfoService.instance;
      if (!exchangeInfo.isInitialized) {
        await _waitForInitialization(exchangeInfo);
      }

      final response = await http.get(
        Uri.parse('${BinanceApiService.currentBaseUrl}/fapi/v1/ticker/24hr'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 只处理USDT永续合约（排除交割合约，交割合约合约名包含日期如230325, 230630等）
        final exchangeInfo = ExchangeInfoService.instance;
        final usdtTickers = data
            .map((e) => Ticker24h.fromJson(e as Map<String, dynamic>))
            .where((t) => t.symbol.endsWith('USDT'))
            .where((t) => !_isDeliverySymbol(t.symbol))
            .where((t) => exchangeInfo.isSymbolTradable(t.symbol))
            .toList();

        // 计算涨跌统计
        int upCount = 0;
        int downCount = 0;
        int unchangedCount = 0;

        // 涨幅分布
        int neg5Plus = 0, neg5to3 = 0, neg3to1 = 0, neg1to0 = 0;
        int pos0to1 = 0, pos1to3 = 0, pos3to5 = 0, pos5Plus = 0;

        for (final ticker in usdtTickers) {
          final change = ticker.priceChangePercent;

          if (change > 0.01) {
            upCount++;
            if (change < 1) pos0to1++;
            else if (change < 3) pos1to3++;
            else if (change < 5) pos3to5++;
            else pos5Plus++;
          } else if (change < -0.01) {
            downCount++;
            if (change > -1) neg1to0++;
            else if (change > -3) neg3to1++;
            else if (change > -5) neg5to3++;
            else neg5Plus++;
          } else {
            unchangedCount++;
          }
        }

        // 按涨幅排序，取前20（过滤交易量小于100万USDT的合约）
        final sortedByGain = List<Ticker24h>.from(usdtTickers)
            .where((t) => t.quoteVolume >= 1000000) // 24小时交易量>=100万USDT
            .toList();
        sortedByGain.sort((a, b) => b.priceChangePercent.compareTo(a.priceChangePercent));
        final topGainers = sortedByGain.take(20).toList();

        // 按跌幅排序，取前20
        final sortedByLoss = List<Ticker24h>.from(usdtTickers);
        sortedByLoss.sort((a, b) => a.priceChangePercent.compareTo(b.priceChangePercent));
        final topLosers = sortedByLoss.take(20).toList();

        _overview = MarketOverview(
          totalSymbols: usdtTickers.length,
          upCount: upCount,
          downCount: downCount,
          unchangedCount: unchangedCount,
          topGainers: topGainers,
          topLosers: topLosers,
          distribution: PriceChangeDistribution(
            negative5Plus: neg5Plus,
            negative5to3: neg5to3,
            negative3to1: neg3to1,
            negative1to0: neg1to0,
            positive0to1: pos0to1,
            positive1to3: pos1to3,
            positive3to5: pos3to5,
            positive5Plus: pos5Plus,
          ),
        );

        if (kDebugMode) {
          print('[MarketOverview] 获取成功: 总数=${usdtTickers.length}, '
                '涨=$upCount, 跌=$downCount, 平盘=$unchangedCount');
          print('[MarketOverview] Top5涨幅 (交易量>=100万USDT):');
          for (var i = 0; i < (topGainers.length < 5 ? topGainers.length : 5); i++) {
            print('  ${i + 1}. ${topGainers[i].symbol} +${topGainers[i].priceChangePercent.toStringAsFixed(2)}% '
                  '交易量: ${(topGainers[i].quoteVolume / 1000000).toStringAsFixed(1)}M USDT');
          }
        }
      } else {
        _errorMessage = '获取市场数据失败: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = '网络错误: $e';
      if (kDebugMode) {
        print('[MarketOverview] 获取失败: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 开始自动刷新 (每30秒)
  void _startAutoRefresh() {
    fetchMarketOverview();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchMarketOverview();
    });
  }

  /// 刷新数据
  Future<void> refresh() async {
    await fetchMarketOverview();
  }

  /// 等待 ExchangeInfoService 初始化完成（最多2秒）
  Future<void> _waitForInitialization(ExchangeInfoService exchangeInfo) async {
    final timeout = Duration(seconds: 2);
    final startTime = DateTime.now();

    while (!exchangeInfo.isInitialized) {
      if (DateTime.now().difference(startTime) > timeout) {
        if (kDebugMode) {
          print('[MarketOverview] 等待 ExchangeInfoService 初始化超时');
        }
        return;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (kDebugMode) {
      print('[MarketOverview] ExchangeInfoService 初始化完成，耗时: '
            '${DateTime.now().difference(startTime).inMilliseconds}ms');
    }
  }

  /// 判断是否为交割合约（合约名包含日期如 230325, 230630, 250328 等）
  bool _isDeliverySymbol(String symbol) {
    // 移除USDT后缀
    final baseSymbol = symbol.replaceAll('USDT', '');
    // 如果包含6位数字（YYMMDD格式），则为交割合约
    final RegExp datePattern = RegExp(r'\d{6}$');
    return datePattern.hasMatch(baseSymbol);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
