// integration_test/pump_alert_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tomapp/main.dart' as app;
import 'package:tomapp/screens/pump_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pump Alert Integration Tests', () {
    testWidgets('should navigate to pump screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 点击快速上涨卡片
      await tester.tap(find.text('快速上涨'));
      await tester.pumpAndSettle();

      // 验证导航成功
      expect(find.byType(PumpScreen), findsOneWidget);
      expect(find.text('快速上涨'), findsWidgets);
    });
  });
}
