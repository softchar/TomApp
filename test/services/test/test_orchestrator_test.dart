import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/services/test/test_orchestrator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';

void main() {
  group('TestOrchestrator', () {
    late TestDataGenerator generator;
    late ReboundDetector detector;

    setUp(() {
      generator = TestDataGenerator(
        mode: SimulationMode.vRebound,
        seed: 42,
      );
      detector = ReboundDetector(TechnicalIndicators());
    });

    TestOrchestrator createOrchestrator() {
      return TestOrchestrator(
        generator: generator,
        detector: detector,
      );
    }

    test('初始状态 isRunning = false', () {
      final orch = createOrchestrator();
      expect(orch.isRunning, false);
      expect(orch.window, isEmpty);
      expect(orch.signals, isEmpty);
      orch.dispose();
    });

    test('start() 后 isRunning = true', () {
      final orch = createOrchestrator();
      orch.start();
      expect(orch.isRunning, true);
      orch.dispose();
    });

    test('pause() 后 isRunning = false', () {
      final orch = createOrchestrator();
      orch.start();
      orch.pause();
      expect(orch.isRunning, false);
      orch.dispose();
    });

    test('reset() 清空 window 和 signals', () {
      final orch = createOrchestrator();
      orch.start();
      orch.pause();
      orch.reset();
      expect(orch.window, isEmpty);
      expect(orch.signals, isEmpty);
      orch.dispose();
    });

    test('changeMode() 切换模式后 window 清空', () {
      final orch = createOrchestrator();
      orch.start();
      orch.pause();
      orch.changeMode(SimulationMode.steadyDecline);
      expect(orch.window, isEmpty);
      orch.dispose();
    });

    test('dispose() 取消 Timer 不抛异常', () {
      final orch = createOrchestrator();
      orch.start();
      // dispose 应该正常取消 timer，不抛异常
      expect(() => orch.dispose(), returnsNormally);
    });
  });
}
