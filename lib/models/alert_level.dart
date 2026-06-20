import 'package:tomapp/models/rebound_signal.dart';

/// 通知级别枚举。
///
/// - [high]: 响铃 + 震动，适用于高分 + 低死猫风险信号。
/// - [medium]: 横幅提醒，适用于中等分数信号或高死猫风险降级信号。
/// - [low]: 仅看板展示，不触发推送通知。
enum AlertLevel {
  /// 响铃 + 震动（Android Importance.max）
  high,

  /// 横幅提醒（Android Importance.defaultImportance）
  medium,

  /// 仅看板展示，不推送
  low,
}

/// 通知决策数据类（不可变）。
///
/// 由 [AlertThrottler.evaluate] 在信号通过全部闸门后返回。
/// 包含分级结果、原始信号引用、归并涉及的时间周期等完整上下文。
class AlertDecision {
  /// 交易对（如 "BTCUSDT"）
  final String symbol;

  /// 通知级别
  final AlertLevel level;

  /// 原始反弹信号引用
  final ReboundSignal signal;

  /// 归并涉及的所有时间周期。
  /// 单周期下恒为 `[signal.timeframe]`；
  /// 多周期归并时包含所有共振的时间周期。
  final List<String> coalescedTimeframes;

  /// 决策时间戳（单测用，通常为 evaluate 调用时刻）
  final DateTime createdAt;

  const AlertDecision({
    required this.symbol,
    required this.level,
    required this.signal,
    required this.coalescedTimeframes,
    required this.createdAt,
  });

  @override
  String toString() =>
      'AlertDecision($symbol/${level.name} score=${signal.score} '
      'deadCat=${signal.deadCatRiskScore} tf=${coalescedTimeframes.join(",")} '
      'at=$createdAt)';
}
