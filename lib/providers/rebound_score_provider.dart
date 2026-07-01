import 'package:flutter/foundation.dart';
import 'package:tomapp/models/rebound_notification_record.dart';
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

  /// warm-up 中的标的集合（由 ReboundAlertService 更新，UI 显示加载状态）
  final Set<String> _warmingUpSymbols = {};

  // ─── 04-03 扫描状态 ──────────────────────────────────────
  int _scanRound = 0;
  int _trackedCount = 0;
  DateTime? _lastScanTime;

  /// 不可变视图（UI 读取）
  Map<String, Map<String, ReboundSignal?>> get signalsBySymbol =>
      Map.unmodifiable(_signalsBySymbol);

  /// 查询单个信号。
  ReboundSignal? getSignal(String symbol, String tf) =>
      _signalsBySymbol[symbol]?[tf];

  /// 按周期过滤信号，按 score 降序返回。
  ///
  /// [minScore]：仅返回评分 ≥ 此值的信号（默认 0 不过滤，向后兼容）。
  List<ReboundSignal> getSignalsForTimeframe(String tf, {int minScore = 0}) {
    final result = <ReboundSignal>[];
    for (final tfMap in _signalsBySymbol.values) {
      final signal = tfMap[tf];
      if (signal != null && signal.score >= minScore) result.add(signal);
    }
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  /// 所有有信号的 symbol 集合。
  Set<String> get activeSymbols => _signalsBySymbol.keys.toSet();

  /// 获取最近收盘价（用于 sparkline 渲染）。无数据返回 null。
  List<double>? getRecentCloses(String symbol, String tf) =>
      _recentClosesBySymbol[symbol]?[tf];

  /// warm-up 中的标的集合（不可变视图）。
  Set<String> get warmingUpSymbols => Set.unmodifiable(_warmingUpSymbols);

  /// 04-03 扫描轮次（每完成一轮自增）。
  int get scanRound => _scanRound;

  /// 04-03 当前精跟中的标的数量。
  int get trackedCount => _trackedCount;

  /// 04-03 最近一次完整扫描完成时间。
  DateTime? get lastScanTime => _lastScanTime;

  /// 更新扫描状态（由 ReboundMarketScanner.onProgress 回调驱动，per B3）。
  ///
  /// [lastScanTime] 为 null 时保留旧值（进行中的进度回调无完成时间）。
  void updateScanState({
    required int round,
    required int trackedCount,
    DateTime? lastScanTime,
  }) {
    _scanRound = round;
    _trackedCount = trackedCount;
    if (lastScanTime != null) {
      _lastScanTime = lastScanTime;
    }
    notifyListeners();
  }

  // ─── 调试日志（测试期，看板底部面板显示）─────────────────────
  final List<String> _logs = [];

  /// 最近日志（只读视图，UI 底部面板渲染）。
  List<String> get logs => List.unmodifiable(_logs);

  /// 追加一条日志（带时间戳，超过 200 条裁剪旧条目）。
  void addLog(String msg) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    _logs.add('$ts  $msg');
    if (_logs.length > 200) {
      _logs.removeRange(0, _logs.length - 200);
    }
    notifyListeners();
  }

  /// 清空日志。
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

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
    _warmingUpSymbols.clear();
    notifyListeners();
  }

  /// 更新 warm-up 状态集合（由 ReboundAlertService 调用）。
  void updateWarmingUpSymbols(Set<String> symbols) {
    if (_warmingUpSymbols.length == symbols.length &&
        _warmingUpSymbols.containsAll(symbols)) {
      return; // 无变更，不触发通知
    }
    _warmingUpSymbols
      ..clear()
      ..addAll(symbols);
    notifyListeners();
  }

  // ─── 通知历史（监控页历史区域展示）──────────────────────
  final List<ReboundNotificationRecord> _notificationHistory = [];

  /// 历史最多保留条数。
  static const int maxNotificationHistory = 50;

  /// 通知历史（最新在前，只读视图）。
  List<ReboundNotificationRecord> get notificationHistory =>
      List.unmodifiable(_notificationHistory);

  /// 追加一条通知到历史头部（alertService 推送后调），超上限裁剪旧条目。
  void addNotificationHistory(ReboundNotificationRecord record) {
    _notificationHistory.insert(0, record);
    if (_notificationHistory.length > maxNotificationHistory) {
      _notificationHistory.removeLast();
    }
    notifyListeners();
  }

  /// 从持久化加载历史（监控页启动调）。[loader] 通常传 `repo.queryRecent`。
  Future<void> loadNotificationHistory(
      Future<List<ReboundNotificationRecord>> Function(int limit) loader) async {
    final loaded = await loader(maxNotificationHistory);
    _notificationHistory
      ..clear()
      ..addAll(loaded);
    notifyListeners();
  }
}
