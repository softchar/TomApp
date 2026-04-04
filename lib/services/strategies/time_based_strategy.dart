import 'package:tomapp/services/strategies/pump_detection_strategy.dart';

class TimeBasedStrategy implements PumpDetectionStrategy {
  @override
  String get name => 'TimeBased';

  @override
  double adjust(double baseThreshold) {
    final now = DateTime.now().toUtc();
    final hour = now.hour;
    final minute = now.minute;

    // 整点前后5分钟
    if (minute <= 5) {
      return -0.3; // 降低阈值，更敏感
    }

    // 分时段调整
    if (hour >= 0 && hour < 8) {
      return 0.3; // 亚洲时段，波动小
    } else if (hour >= 8 && hour < 16) {
      return -0.2; // 欧洲时段，波动增加
    } else {
      return -0.5; // 美洲时段，波动最大
    }
  }
}
