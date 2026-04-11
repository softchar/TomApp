import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/favorite_service.dart';

enum PumpListStatus { initial, loading, loaded, error, empty }

class PumpListState {
  final PumpListStatus status;
  final List<PumpHistoryModel> pumps;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  PumpListState({
    this.status = PumpListStatus.initial,
    this.pumps = const [],
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 0,
  });

  PumpListState copyWith({
    PumpListStatus? status,
    List<PumpHistoryModel>? pumps,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
  }) {
    return PumpListState(
      status: status ?? this.status,
      pumps: pumps ?? this.pumps,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PumpListProvider extends ChangeNotifier {
  final PumpRepository _repository;
  final PumpConfig _config;

  PumpListState _state = PumpListState();
  PumpListState get state => _state;

  /// 获取收藏筛选状态
  bool get isFilteringFavorites => _filterFavoritesOnly;

  // 筛选条件
  String _searchQuery = '';
  String? _filterSymbol;
  bool? _filterConfirmed;
  bool _filterFavoritesOnly = false;
  PumpListSort _sortType = PumpListSort.timeDesc;

  PumpListProvider({
    required PumpRepository repository,
    required PumpConfig config,
  })  : _repository = repository,
        _config = config;

  /// 加载数据
  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _state = _state.copyWith(
        currentPage: 0,
        pumps: [],
      );
    }

    _state = _state.copyWith(status: PumpListStatus.loading);
    notifyListeners();

    try {
      final pumps = await _repository.findAll(
        limit: _config.listPageSize,
        offset: _state.currentPage * _config.listPageSize,
        symbol: _filterSymbol,
        isConfirmed: _filterConfirmed,
      );

      // 应用搜索和排序
      final filteredPumps = _applyFilterAndSort(pumps);

      if (filteredPumps.isEmpty) {
        _state = _state.copyWith(
          status: PumpListStatus.empty,
          pumps: filteredPumps,
          hasMore: false,
        );
      } else {
        _state = _state.copyWith(
          status: PumpListStatus.loaded,
          pumps: filteredPumps,
          hasMore: filteredPumps.length >= _config.listPageSize,
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        status: PumpListStatus.error,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (!_state.hasMore || _state.status == PumpListStatus.loading) {
      return;
    }

    final nextPage = _state.currentPage + 1;

    try {
      final pumps = await _repository.findAll(
        limit: _config.listPageSize,
        offset: nextPage * _config.listPageSize,
        symbol: _filterSymbol,
        isConfirmed: _filterConfirmed,
      );

      final filteredPumps = _applyFilterAndSort(pumps);

      _state = _state.copyWith(
        status: PumpListStatus.loaded,
        pumps: [..._state.pumps, ...filteredPumps],
        hasMore: filteredPumps.length >= _config.listPageSize,
        currentPage: nextPage,
      );
    } catch (e) {
      debugPrint('加载更多失败: $e');
    }

    notifyListeners();
  }

  /// 设置搜索
  void setSearchQuery(String query) {
    _searchQuery = query.toUpperCase();
    load(refresh: true);
  }

  /// 设置币种筛选
  void setSymbolFilter(String? symbol) {
    _filterSymbol = symbol;
    load(refresh: true);
  }

  /// 设置确认状态筛选
  void setConfirmedFilter(bool? confirmed) {
    _filterConfirmed = confirmed;
    load(refresh: true);
  }

  /// 设置排序
  void setSortType(PumpListSort sortType) {
    _sortType = sortType;
    load(refresh: true);
  }

  /// 设置收藏筛选
  void setFavoriteFilter(bool favoritesOnly) {
    _filterFavoritesOnly = favoritesOnly;
    load(refresh: true);
  }

  List<PumpHistoryModel> _applyFilterAndSort(List<PumpHistoryModel> pumps) {
    var result = pumps.toList();

    // 应用搜索
    if (_searchQuery.isNotEmpty) {
      result = result.where((p) => p.symbol.contains(_searchQuery)).toList();
    }

    // 应用收藏筛选
    if (_filterFavoritesOnly) {
      final favorites = FavoriteService().favorites;
      result = result.where((p) => favorites.contains(p.symbol)).toList();
    }

    // 应用排序
    switch (_sortType) {
      case PumpListSort.timeDesc:
        result.sort((a, b) => b.triggerTime.compareTo(a.triggerTime));
        break;
      case PumpListSort.timeAsc:
        result.sort((a, b) => a.triggerTime.compareTo(b.triggerTime));
        break;
      case PumpListSort.changeDesc:
        result.sort((a, b) => b.priceChange.compareTo(a.priceChange));
        break;
      case PumpListSort.changeAsc:
        result.sort((a, b) => a.priceChange.compareTo(b.priceChange));
        break;
    }

    return result;
  }
}

enum PumpListSort { timeDesc, timeAsc, changeDesc, changeAsc }
