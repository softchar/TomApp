import 'dart:math';
import 'package:tomapp/services/strategies/pump_detection_strategy.dart';
import 'package:tomapp/services/pump_repository.dart';

class AdaptiveStrategy implements PumpDetectionStrategy {
  final PumpRepository _repository;

  AdaptiveStrategy(this._repository);

  @override
  String get name => 'Adaptive';

  @override
  double adjust(double baseThreshold) {
    // 自适应策略需要基于具体币种，这里返回默认值
    // 实际使用时通过 calculateEffectiveThreshold 调用
    return 0.0;
  }

  /// 计算币种活跃度评分 (0.0 - 1.0)
  Future<double> calculateActivityScore(String symbol) async {
    final recent = await _repository.getRecentData(symbol, hours: 24);

    if (recent.isEmpty) return 0.5; // 新币种默认值

    final detectionCount = recent.length;
    final avgChange = recent.map((e) => e.priceChange).reduce((a, b) => a + b) / detectionCount;

    // 计算波动率
    final changes = recent.map((e) => e.priceChange).toList();
    final mean = changes.reduce((a, b) => a + b) / changes.length;
    final variance = changes.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / changes.length;
    final volatility = (variance > 0) ? sqrt(variance) : 0.0;

    // 标准化波动率到 0-0.3 范围
    final normalizedVolatility = (volatility / 5).clamp(0.0, 0.3);

    // 检测次数标准化到 0-0.4 范围
    final normalizedCount = (detectionCount / 10).clamp(0.0, 0.4);

    // 涨幅标准化到 0-0.3 范围
    final normalizedChange = (avgChange / 5).clamp(0.0, 0.3);

    return (normalizedCount + normalizedChange + normalizedVolatility).clamp(0.0, 1.0);
  }

  /// 根据活跃度调整阈值
  double adjustWithActivity(double baseThreshold, double activityScore) {
    // 活跃度越高，阈值越低 (更敏感)
    // 调整范围: ±0.3%
    final adjustment = (activityScore - 0.5) * 0.6;
    return baseThreshold - adjustment;
  }
}
