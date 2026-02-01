import 'dart:async';
import 'package:flutter/material.dart';
import '../models/funding_rate.dart';
import '../services/binance_api_service.dart';
import '../services/notification_service.dart';

/// 资金费率数据管理Provider
class FundingRateProvider with ChangeNotifier {
  final BinanceApiService _apiService;
  final NotificationService _notificationService;

  List<FundingRate> _fundingRates = [];
  List<FundingRate> _filteredRates = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _updateTimer;
  String _searchQuery = '';
  SortType _sortType = SortType.intervalAsc;

  FundingRateProvider({
    BinanceApiService? apiService,
    NotificationService? notificationService,
  })  : _apiService = apiService ?? BinanceApiService(),
        _notificationService = notificationService ?? NotificationService();

  List<FundingRate> get fundingRates => _filteredRates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get rateCount => _filteredRates.length;
  SortType get sortType => _sortType;

  /// 获取资金费率数据
  Future<void> fetchFundingRates() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newRates = await _apiService.getUSDTFuturesRates();

      // 检查间隔变化并发送通知
      await _notificationService.checkIntervalChanges(newRates);

      _fundingRates = newRates;
      _applyFilterAndSort();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 启动定时更新（每1小时更新一次）
  void startPeriodicUpdate() {
    // 立即获取一次数据
    fetchFundingRates();

    // 设置定时器，每1小时更新一次
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => fetchFundingRates(),
    );
  }

  /// 停止定时更新
  void stopPeriodicUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// 搜索过滤
  void setSearchQuery(String query) {
    _searchQuery = query.toUpperCase();
    _applyFilterAndSort();
    notifyListeners();
  }

  /// 排序方式
  void setSortType(SortType sortType) {
    _sortType = sortType;
    _applyFilterAndSort();
    notifyListeners();
  }

  /// 应用过滤和排序
  void _applyFilterAndSort() {
    var rates = _fundingRates;

    // 应用搜索过滤
    if (_searchQuery.isNotEmpty) {
      rates = rates.where((rate) =>
          rate.symbol.contains(_searchQuery)).toList();
    }

    // 根据选择的排序方式排序
    switch (_sortType) {
      case SortType.intervalAsc:
        // 按间隔升序（间隔小的在前）
        rates.sort((a, b) => a.fundingIntervalHours.compareTo(b.fundingIntervalHours));
        break;
      case SortType.intervalDesc:
        // 按间隔降序（间隔大的在前）
        rates.sort((a, b) => b.fundingIntervalHours.compareTo(a.fundingIntervalHours));
        break;
      case SortType.rateDesc:
        // 按费率降序（费率高的在前）
        rates.sort((a, b) => b.fundingRate.compareTo(a.fundingRate));
        break;
      case SortType.rateAsc:
        // 按费率升序（费率低的在前）
        rates.sort((a, b) => a.fundingRate.compareTo(b.fundingRate));
        break;
      case SortType.symbolAsc:
        // 按交易对名称升序
        rates.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
      case SortType.symbolDesc:
        // 按交易对名称降序
        rates.sort((a, b) => b.symbol.compareTo(a.symbol));
        break;
    }

    // 限制最多显示20条
    if (rates.length > 20) {
      rates = rates.take(20).toList();
    }

    _filteredRates = rates;
  }

  /// 刷新数据
  Future<void> refresh() async {
    await fetchFundingRates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }
}

/// 排序类型枚举
enum SortType {
  intervalAsc,
  intervalDesc,
  rateDesc,
  rateAsc,
  symbolAsc,
  symbolDesc,
}
