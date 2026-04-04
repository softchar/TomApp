import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/pump_detector.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';

void main() {
  group('PumpDetector', () {
    late PumpDetector detector;

    setUp(() {
      // 使用内存 repository 创建 detector
      detector = PumpDetector(
        config: PumpConfig(),
        repository: MemoryPumpRepository(),
      );
    });

    test('should return null when price change is below threshold', () async {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      // 添加基准价格
      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 1 分钟后，上涨 1% (低于阈值)
      final result = await detector.check(
        'BTCUSDT',
        65650.0, // 1% 涨幅
        baseTime.add(const Duration(minutes: 1)),
      );

      expect(result, isNull);
    });

    test('should detect pump when price change exceeds threshold', () async {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 1 分钟后，上涨 3% (超过阈值)
      final result = await detector.check(
        'BTCUSDT',
        66950.0, // 3% 涨幅
        baseTime.add(const Duration(minutes: 1)),
      );

      expect(result, isNotNull);
      expect(result!.symbol, 'BTCUSDT');
      expect(result.priceChange, closeTo(3.0, 0.1));
      expect(result.currentPrice, 66950.0);
    });

    test('should enforce cooldown period', () async {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 第一次触发
      await detector.check(
        'BTCUSDT',
        66950.0,
        baseTime.add(const Duration(minutes: 1)),
      );

      // 30 秒后再次触发 (在冷却期内)
      final result2 = await detector.check(
        'BTCUSDT',
        67500.0,
        baseTime.add(const Duration(minutes: 1, seconds: 30)),
      );

      expect(result2, isNull); // 冷却中，返回 null
    });

    test('should allow detection after cooldown expires', () async {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 第一次触发
      await detector.check(
        'BTCUSDT',
        66950.0,
        baseTime.add(const Duration(minutes: 1)),
      );

      // 添加新的基准价格 (模拟 2 分钟时的价格)
      detector.addPricePoint('BTCUSDT', 66000.0, baseTime.add(const Duration(minutes: 2)));

      // 3 分钟后再次触发 (冷却期已过，涨幅超过阈值)
      final result2 = await detector.check(
        'BTCUSDT',
        68000.0, // 从 66000 到 68000 是 ~3% 涨幅
        baseTime.add(const Duration(minutes: 3)),
      );

      expect(result2, isNotNull);
    });

    test('should clean up old price points', () {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      // 添加 3 分钟前的旧数据点
      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);
      // 添加当前价格点
      detector.addPricePoint('BTCUSDT', 66000.0, baseTime.add(const Duration(minutes: 3)));

      // 旧数据点应该被清理
      expect(detector.getPricePointCount('BTCUSDT'), lessThanOrEqualTo(2));
    });
  });
}
