import 'package:flutter/foundation.dart';
import 'package:tomapp/models/rebound_signal.dart';

/// 反弹信号评分 Provider（ChangeNotifier）。
///
/// 由 [ReboundAlertService] 更新，UI（Phase 4 ReboundDashboardScreen）消费。
/// 暴露 per-(symbol, timeframe) 的只读信号状态，按评分降序。
class ReboundScoreProvider extends ChangeNotifier {
  /// symbol → timeframe → signal（只读暴露）
  final Map<String, Map<String, ReboundSignal?>> _signalsBySymbol = {};

  /// symbol → timeframe → 最近 N 根收盘价（用于 sparkline 渲染）
  final Map<String, Map<String, List<double>>> _recentClosesBySymbol = {};

  /// 不可变视图（UI 读取）
  Map<String, Map<String, ReboundSignal?>> get signalsBySymbol =>
      Map.unmodifiable(_signalsBySymbol);

  /// 查询单个信号。
  ReboundSignal? getSignal(String symbol, String tf) =>
      _signalsBySymbol[symbol]?[tf];

  /// 按周期过滤信号，按 score 降序返回。
  List<ReboundSignal> getSignalsForTimeframe(String tf) {
    final result = <ReboundSignal>[];
    for (final tfMap in _signalsBySymbol.values) {
      final signal = tfMap[tf];
      if (signal != null) result.add(signal);
    }
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  /// 所有有信号的 symbol 集合。
  Set<String> get activeSymbols => _signalsBySymbol.keys.toSet();

  /// 获取最近收盘价（用于 sparkline 渲染）。无数据返回 null。
  List<double>? getRecentCloses(String symbol, String tf) =>
      _recentClosesBySymbol[symbol]?[tf];

  /// 更新单个信号 + 通知监听者（Phase 4 UI rebuild）。
  ///
  /// [recentCloses] 为可选最近收盘价列表，用于 sparkline 渲染。不传则保持现有数据。
  void upsert(String symbol, String tf, ReboundSignal? signal,
      {List<double>? recentCloses}) {
    _signalsBySymbol.putIfAbsent(symbol, () => {});
    _signalsBySymbol[symbol]![tf] = signal;
    if (recentCloses != null) {
      _recentClosesBySymbol.putIfAbsent(symbol, () => {});
      _recentClosesBySymbol[symbol]![tf] = recentCloses;
    }
    notifyListeners();
  }

  /// 批量更新 + 单次 notifyListeners（性能优化，避免 N 次通知）。
  void upsertBatch(Map<String, Map<String, ReboundSignal?>> batch) {
    for (final entry in batch.entries) {
      _signalsBySymbol.putIfAbsent(entry.key, () => {});
      for (final tfEntry in entry.value.entries) {
        _signalsBySymbol[entry.key]![tfEntry.key] = tfEntry.value;
      }
    }
    notifyListeners();
  }

  /// watchlist churn：移除下架合约的所有信号。
  void removeSymbol(String symbol) {
    _signalsBySymbol.remove(symbol);
    _recentClosesBySymbol.remove(symbol);
    notifyListeners();
  }

  /// 断连时清空所有信号。
  void clear() {
    _signalsBySymbol.clear();
    _recentClosesBySymbol.clear();
    notifyListeners();
  }
}
