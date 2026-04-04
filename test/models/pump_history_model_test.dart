import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/models/pump_model.dart';

void main() {
  group('PumpHistoryModel', () {
    test('fromPumpModel creates correct model', () {
      final pump = PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 2.3,
        triggerTime: DateTime(2026, 4, 4, 12, 0),
        currentPrice: 66500.0,
      );

      final history = PumpHistoryModel.fromPumpModel(
        pump,
        strategyType: 'Test',
      );

      expect(history.symbol, 'BTCUSDT');
      expect(history.priceChange, 2.3);
      expect(history.strategyType, 'Test');
      expect(history.isConfirmed, 0);
    });

    test('toMap and fromMap are symmetric', () {
      final original = PumpHistoryModel(
        id: 1,
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: 1712224000000,
        detectedAt: '2026-04-04T12:00:00.000Z',
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      final map = original.toMap();
      final restored = PumpHistoryModel.fromMap(map);

      expect(restored.symbol, original.symbol);
      expect(restored.priceChange, original.priceChange);
    });

    test('isConfirmed returns correct bool', () {
      final confirmed = PumpHistoryModel(
        id: 1,
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: 1712224000000,
        detectedAt: '2026-04-04T12:00:00.000Z',
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 1,
      );

      expect(confirmed.confirmed, true);
    });
  });
}
