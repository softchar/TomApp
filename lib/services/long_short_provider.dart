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

  List<LongShortRatio> get ratios => _ratios.take(_displayedCount).toList();
  List<LongShortRatio> get allRatios => _ratios;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get period => _period;
  bool get hasMore => _displayedCount < _ratios.length;

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
            _ratios.addAll(batchRatios);
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
}
