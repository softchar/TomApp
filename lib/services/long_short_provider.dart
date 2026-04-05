import 'package:flutter/foundation.dart';
import '../models/long_short_ratio.dart';
import '../services/binance_api_service.dart';

/// 大户多空比数据提供者
class LongShortProvider extends ChangeNotifier {
  final BinanceApiService _apiService = BinanceApiService();

  List<LongShortRatio> _ratios = [];
  bool _isLoading = false;
  String? _error;
  String _period = '5m';
  int _displayedCount = 20; // 初始显示20条
  LongShortRatio? _currentSymbolRatio; // 当前选中合约的多空比

  List<LongShortRatio> get ratios => _ratios.take(_displayedCount).toList();
  List<LongShortRatio> get allRatios => _ratios;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get period => _period;
  bool get hasMore => _displayedCount < _ratios.length;
  LongShortRatio? get currentSymbolRatio => _currentSymbolRatio;

  /// 设置时间周期
  void setPeriod(String period) {
    if (_period != period) {
      _period = period;
      _displayedCount = 20; // 重置显示数量
      fetchRatios();
    }
  }

  /// 获取最新大户多空比数据（分批加载）
  Future<void> fetchRatios() async {
    // 如果已经在加载中，防止重复请求
    if (_isLoading) {
      if (kDebugMode) print('[LongShortProvider] 已有请求正在进行，忽略重复请求');
      return;
    }

    _isLoading = true;
    _error = null;
    _ratios = [];
    _displayedCount = 20;
    notifyListeners();

    try {
      if (kDebugMode) print('[LongShortProvider] 开始获取多空比数据, period=$_period');

      // 先获取所有数据，但使用进度回调来逐步更新UI
      await _apiService.getLatestTopLongShortRatioWithProgress(
        period: _period,
        onProgress: (batchRatios) {
          if (batchRatios.isNotEmpty) {
            // 去重：基于 symbol 去除重复项
            final existingSymbols = _ratios.map((r) => r.symbol).toSet();
            final newRatios = batchRatios.where((r) => !existingSymbols.contains(r.symbol)).toList();

            _ratios.addAll(newRatios);
            // 排序
            _ratios.sort((a, b) => b.shortAccount.compareTo(a.shortAccount));
            notifyListeners();
          }
        },
      );

      if (kDebugMode) print('[LongShortProvider] 获取到 ${_ratios.length} 条数据');
    } catch (e) {
      if (kDebugMode) print('[LongShortProvider] 获取失败: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多数据
  void loadMore() {
    if (hasMore && !_isLoading) {
      _displayedCount += 20;
      notifyListeners();
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    _displayedCount = 20;
    await fetchRatios();
  }

  /// 获取单个合约的多空比数据
  Future<void> fetchRatioForSymbol(String symbol) async {
    try {
      if (kDebugMode) print('[LongShortProvider] 获取 $symbol 的多空比数据');

      final ratios = await _apiService.getTopLongShortAccountRatio(
        symbol,
        period: _period,
        limit: 1,
      );

      if (ratios.isNotEmpty) {
        _currentSymbolRatio = ratios.first;
        if (kDebugMode) {
          print('[LongShortProvider] 成功获取 $symbol 多空比: '
              '多${(_currentSymbolRatio!.longAccount * 100).toStringAsFixed(1)}% '
              '空${(_currentSymbolRatio!.shortAccount * 100).toStringAsFixed(1)}%');
        }
      } else {
        _currentSymbolRatio = null;
        if (kDebugMode) print('[LongShortProvider] $symbol 没有多空比数据');
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[LongShortProvider] 获取 $symbol 多空比失败: $e');
      _currentSymbolRatio = null;
      notifyListeners();
    }
  }
}
