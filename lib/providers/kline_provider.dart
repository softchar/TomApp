import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/kline_data.dart';
import '../models/macd_data.dart';
import '../services/binance_api_service.dart';
import '../services/kline_cache_service.dart';
import '../services/kline_websocket_service.dart';
import '../services/technical_indicators.dart';

/// K线数据状态管理Provider
///
/// 负责K线数据的加载、缓存、实时更新和技术指标计算
class KlineProvider extends ChangeNotifier {
  late final KlineWebSocketService _wsService;
  final KlineCacheService _cacheService = KlineCacheService();
  final BinanceApiService _apiService = BinanceApiService();
  final TechnicalIndicators _indicators = TechnicalIndicators();

  String _symbol = '';
  String _currentInterval = '15m';
  List<KlineData> _klineData = [];
  List<KlineDataWithIndicators> _klineWithIndicators = [];
  bool _isLoading = false;
  bool _isRealtime = false;
  String? _errorMessage;
  MACDData? _macdData;
  bool _showMacd = false;
  double? _currentPrice;
  double? _priceChange;
  StreamSubscription? _wsSubscription;

  KlineProvider() {
    _wsService = KlineWebSocketService();
  }

  // Getters
  String get symbol => _symbol;
  String get currentInterval => _currentInterval;
  List<KlineData> get klineData => _klineData;
  List<KlineDataWithIndicators> get klineWithIndicators => _klineWithIndicators;
  bool get isLoading => _isLoading;
  bool get isRealtime => _isRealtime;
  String? get errorMessage => _errorMessage;
  MACDData? get macdData => _macdData;
  bool get showMacd => _showMacd;
  double? get currentPrice => _currentPrice;
  double? get priceChange => _priceChange;

  /// 加载K线数据
  ///
  /// [symbol] 交易对符号，如 'BTCUSDT'
  /// [interval] K线间隔，如 '1m', '15m', '1h', '1d'
  Future<void> loadKlines(String symbol, String interval) async {
    _symbol = symbol;
    _currentInterval = interval;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 尝试从缓存加载
      final cachedData = await _cacheService.getCached(symbol, interval);

      if (cachedData != null && cachedData.isNotEmpty) {
        // 缓存命中
        _klineData = cachedData;
        _calculateIndicators();
        _updateCurrentPrice();
        _isLoading = false;
        notifyListeners();

        // 启动实时更新
        _startRealtime();
      } else {
        // 缓存未命中，调用API
        final apiData = await _apiService.getRecentKlines(
          symbol: symbol,
          interval: interval,
          limit: 500,
        );

        // 转换为KlineData
        _klineData = apiData
            .map((item) => KlineData.fromBinanceResponse(item as List<dynamic>))
            .toList();

        // 保存到缓存
        await _cacheService.saveCache(symbol, interval, _klineData);

        // 计算技术指标
        _calculateIndicators();
        _updateCurrentPrice();

        _isLoading = false;
        notifyListeners();

        // 启动实时更新
        _startRealtime();
      }

      // 保存用户偏好
      await _cacheService.savePreferences(symbol, interval);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 计算技术指标
  void _calculateIndicators() {
    if (_klineData.isEmpty) {
      _klineWithIndicators = [];
      _macdData = null;
      return;
    }

    // 计算MA指标
    final ma5 = _indicators.calculateMA(_klineData, 5);
    final ma10 = _indicators.calculateMA(_klineData, 10);
    final ma20 = _indicators.calculateMA(_klineData, 20);

    // 计算BOLL指标
    final boll = _indicators.calculateBOLL(_klineData);

    // 计算MACD指标
    _macdData = _indicators.calculateMACD(_klineData);

    // 组合数据与指标
    _klineWithIndicators = List.generate(
      _klineData.length,
      (index) => KlineDataWithIndicators(
        data: _klineData[index],
        ma5: ma5[index],
        ma10: ma10[index],
        ma20: ma20[index],
        upperBoll: boll.upper[index],
        lowerBoll: boll.lower[index],
      ),
    );
  }

  /// 切换K线间隔
  Future<void> switchInterval(String interval) async {
    if (_currentInterval == interval) return;

    await _stopRealtime();
    await loadKlines(_symbol, interval);
  }

  /// 切换交易对
  Future<void> switchSymbol(String symbol) async {
    if (_symbol == symbol) return;

    await _stopRealtime();
    await loadKlines(symbol, _currentInterval);
  }

  /// 启动实时更新
  void _startRealtime() {
    _wsService.connect(_symbol, _currentInterval);
    _wsSubscription = _wsService.klineStream.listen(
      _onKlineUpdate,
      onError: (error) {
        if (kDebugMode) {
          print('KlineProvider: WebSocket error - $error');
        }
      },
    );
    _isRealtime = true;
    notifyListeners();
  }

  /// 停止实时更新
  Future<void> _stopRealtime() async {
    await _wsSubscription?.cancel();
    await _wsService.disconnect();
    _isRealtime = false;
    notifyListeners();
  }

  /// 更新当前价格和涨跌幅
  void _updateCurrentPrice() {
    if (_klineData.isEmpty) return;

    _currentPrice = _klineData.last.close;
    if (_klineData.length >= 2) {
      final prevClose = _klineData[_klineData.length - 2].close;
      _priceChange = ((_currentPrice! - prevClose) / prevClose) * 100;
    }
  }

  /// 处理K线实时更新
  void _onKlineUpdate(KlineData data) {
    if (_klineData.isEmpty) return;

    final lastIndex = _klineData.length - 1;
    final lastKline = _klineData[lastIndex];

    if (_isSameKline(lastKline.time, data.time, _currentInterval)) {
      // 同一根K线，更新最后一个数据点
      _klineData[lastIndex] = data;
    } else {
      // 新K线，添加到列表
      _klineData.add(data);

      // 限制列表长度，避免内存无限增长
      if (_klineData.length > 2000) {
        _klineData.removeAt(0);
      }

      // 重新计算指标
      _calculateIndicators();
    }

    // 更新当前价格和涨跌幅
    _currentPrice = data.close;
    if (_klineData.length >= 2) {
      final prevClose = _klineData[lastIndex].close;
      _priceChange = ((data.close - prevClose) / prevClose) * 100;
    }

    notifyListeners();
  }

  /// 判断两个时间是否属于同一根K线
  bool _isSameKline(DateTime time1, DateTime time2, String interval) {
    switch (interval) {
      case '1m':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour &&
            time1.minute == time2.minute;

      case '15m':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour &&
            (time1.minute ~/ 15) == (time2.minute ~/ 15);

      case '1h':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour;

      case '4h':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            (time1.hour ~/ 4) == (time2.hour ~/ 4);

      case '1d':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day;

      case '1w':
        return time1.year == time2.year &&
            _getWeekNumber(time1) == _getWeekNumber(time2);

      default:
        // 默认按分钟比较
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour &&
            time1.minute == time2.minute;
    }
  }

  /// 获取一年中的周数
  int _getWeekNumber(DateTime date) {
    // 使用DateFormat获取一年中的第几天
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return (dayOfYear - 1) ~/ 7 + 1;
  }

  /// 切换MACD显示状态
  void toggleMacd() {
    _showMacd = !_showMacd;
    notifyListeners();
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadKlines(_symbol, _currentInterval);
  }

  @override
  void dispose() {
    _stopRealtime();
    _wsService.dispose();
    super.dispose();
  }
}
