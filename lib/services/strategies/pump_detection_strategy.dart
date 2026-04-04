/// Pump 检测策略接口
abstract class PumpDetectionStrategy {
  /// 计算调整后的阈值
  /// 返回调整量（可以为负）
  double adjust(double baseThreshold);

  /// 策略名称（用于日志和数据库记录）
  String get name;
}
