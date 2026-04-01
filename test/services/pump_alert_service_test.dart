import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/pump_alert_service.dart';

void main() {
  group('PumpAlertService', () {
    late PumpAlertService service;

    setUp(() {
      service = PumpAlertService();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('should be singleton', () {
      final instance1 = PumpAlertService.instance;
      final instance2 = PumpAlertService.instance;

      expect(identical(instance1, instance2), true);
    });

    test('should start in stopped state', () {
      expect(service.isRunning, false);
    });

    test('should start service', () async {
      await service.start();

      expect(service.isRunning, true);
    });

    test('should stop service', () async {
      await service.start();
      await service.stop();

      expect(service.isRunning, false);
    });
  });
}
