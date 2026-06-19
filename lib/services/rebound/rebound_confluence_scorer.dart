import 'package:tomapp/models/rebound_signal.dart';

/// 跨周期共振评分器（纯函数，零 I/O）。
///
/// Phase 2 仅定义，Phase 3 编排器消费——输入同币多周期信号 map，
/// 输出多周期共振加分（0-15）。Phase 2 单 TF 调用时返回 0。
class ReboundConfluenceScorer {
  /// 跨周期共振评分。
  ///
  /// [signalsByTf]：同币各周期信号（如 {"15m": signal1, "1h": signal2, ...}）。
  /// null 表示该周期无信号。
  ///
  /// 每个额外 TF（>1）+5 分，上限 15。单 TF 时返回 0（per D-07）。
  static int scoreMultiTimeframe(Map<String, ReboundSignal?> signalsByTf) {
    final activeCount = signalsByTf.values.where((s) => s != null).length;
    if (activeCount <= 1) return 0;
    return ((activeCount - 1) * 5).clamp(0, 15);
  }
}
