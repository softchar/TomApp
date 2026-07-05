import 'package:flutter/foundation.dart';
import 'package:tomapp/models/alert_level.dart';
import 'package:tomapp/models/rebound_signal.dart';

/// 通知节流器——五道闸门评估管线。
///
/// 在信号送往推送前依次执行：分级 → 周期开关 → 冷却 → 日重置 → 上限。
/// 任意一道闸门可独立拒绝信号（返回 null）。
///
/// 设计原则（per RESEARCH.md Common Pitfalls）：
/// - Pitfall 1: 冷却键仅用 symbol（不含 TF），避免同币不同 TF 独立冷却。
/// - Pitfall 2: 跨日重置逻辑在 evaluate() 入口执行，避免计数器跨日不归零。
/// - Pitfall 5: 归并逻辑在当前单周期（monitoredTimeframes=['15m']）下恒跳过，
///   但架构预留 coalesceWindowMinutes=60 窗口参数。
///
/// AlertThrottler 是纯 Dart 同步逻辑——不导入 dart:async、flutter、
/// shared_preferences、flutter_local_notifications。
class AlertThrottler {
  /// Per-symbol 最后推送时间（内存，非持久化）。
  /// 键仅用 symbol（不含 TF），实现 per-symbol 全局冷却。
  final Map<String, DateTime> _lastAlertTime = {};

  /// 当日已推送计数。
  int _todayCount = 0;

  /// 缓存的日期字符串（yyyy-MM-dd 格式），用于跨日重置判断。
  String _todayDate = '';

  /// 冷却时长（小时）。
  static const int cooldownHours = 4;

  /// 每日推送上限。
  static const int dailyLimit = 20;

  /// 主评估入口：对信号执行五道闸门过滤。
  ///
  /// 参数：
  /// - [signal]: 反弹检测器输出的信号。
  /// - [timeframeToggles]: 每个 TF 的推送开关（true=启用）。
  /// - [highThreshold]: high 级别的评分阈值。
  /// - [medThreshold]: medium 级别的评分阈值。
  ///
  /// 返回 [AlertDecision] 表示通过全部闸门，null 表示被某道闸门拒绝。
  AlertDecision? evaluate(
    ReboundSignal signal, {
    required Map<String, bool> timeframeToggles,
    required int highThreshold,
    required int medThreshold,
  }) {
    // Step 0: 跨日重置——必须在所有闸门前执行，确保计数器在日期变更时立即归零
    // （Pitfall 2: 在 evaluate 入口执行，per RESEARCH.md）
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (today != _todayDate) {
      _todayDate = today;
      _todayCount = 0;
    }

    // Step 1: 分级判定
    final level = _classify(
      signal.score,
      signal.deadCatRiskScore,
      highThreshold,
      medThreshold,
    );
    if (level == AlertLevel.low) return null; // low = 仅看板，不推送

    // Step 2: 周期开关
    if (timeframeToggles[signal.timeframe] == false) return null;

    // Step 3: 冷却检查（Pitfall 1: 键仅用 symbol，不含 TF）
    final lastTime = _lastAlertTime[signal.symbol];
    if (lastTime != null) {
      final hoursSince = DateTime.now().difference(lastTime).inHours;
      if (hoursSince < cooldownHours) return null;
    }

    // Step 4: 日上限（跨日重置已在 Step 0 入口执行）
    if (_todayCount >= dailyLimit) return null;

    // 归并逻辑架构预留 (Pitfall 5):
    // 当前 monitoredTimeframes=['15m'] 单周期下恒跳过。
    // 多周期恢复时在此插入归并窗口检查：
    //   if (monitoredTimeframes.length > 1) {
    //     // 收集 _pendingCoalesce Map<String, List<AlertCandidate>> 中的候选
    //     // 判断是否在 coalesceWindowMinutes=60 窗口内
    //     // 合并同 symbol 的多 TF 信号为单条
    //   }
    // 归并相关预留成员：
    //   static const int coalesceWindowMinutes = 60;
    //   final Map<String, List<_AlertCandidate>> _pendingCoalesce = {};

    // Step 6: 通过全部闸门！更新状态并返回决策
    _lastAlertTime[signal.symbol] = DateTime.now();
    _todayCount++;

    return AlertDecision(
      symbol: signal.symbol,
      level: level,
      signal: signal,
      coalescedTimeframes: [signal.timeframe],
      createdAt: DateTime.now(),
    );
  }

  /// 分级辅助方法——纯函数。
  ///
  /// 规则：
  /// - [AlertLevel.high]: score >= highTh 且 deadCatRiskScore < 50（死猫过滤）
  /// - [AlertLevel.medium]: score >= medTh（不满足 high 条件时）
  /// - [AlertLevel.low]: 其余情况
  AlertLevel _classify(
    int score,
    int deadCatRiskScore,
    int highTh,
    int medTh,
  ) {
    if (score >= highTh && deadCatRiskScore < 50) {
      return AlertLevel.high;
    }
    if (score >= medTh) {
      return AlertLevel.medium;
    }
    return AlertLevel.low;
  }

  /// 重置所有内部状态。
  ///
  /// 清空冷却 Map、日计数器、日期缓存。
  /// 供 [ReboundAlertService.stop] 调用，避免 stop/start 循环后
  /// 旧冷却状态误判（Pitfall 4）。
  void reset() {
    _lastAlertTime.clear();
    _todayCount = 0;
    _todayDate = '';
  }

  /// 仅供测试使用：注入假日期以模拟跨日场景。
  ///
  /// 设置后，下一次 evaluate() 调用会检测到日期变更并重置计数器。
  @visibleForTesting
  void setDateForTesting(String date) {
    _todayDate = date;
  }
}
