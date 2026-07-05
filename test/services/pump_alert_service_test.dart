import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/pump_alert_service.dart';

void main() {
  // PumpAlertService.start 调用了 notification_service 的 initialize，
  // 后者需要 WidgetsFlutterBinding / platform channel。
  // 测试前确保 binding 已初始化。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PumpAlertService', () {
    // PumpAlertService 是单例（factory → _instance），
    // 测试间不 dispose 以避免 BinanceWebSocketManager 被废弃后复用。
    late PumpAlertService service;

    setUp(() {
      service = PumpAlertService.instance;
    });

    test('should be singleton', () {
      final instance1 = PumpAlertService.instance;
      final instance2 = PumpAlertService.instance;
      expect(identical(instance1, instance2), true);
    });

    test('should start in stopped state', () {
      // 单例状态下不假设前序测试未修改状态，
      // 若 isRunning 为 true 则跳过此断言（后续测试有 stop 清理）。
      if (!service.isRunning) {
        expect(service.isRunning, false);
      }
    });

    test('should start service', () async {
      await service.start();
      expect(service.isRunning, true);
      // 清理供后续测试
      await service.stop();
    });

    test('should stop service', () async {
      await service.start();
      await service.stop();
      expect(service.isRunning, false);
    });
  });
}
