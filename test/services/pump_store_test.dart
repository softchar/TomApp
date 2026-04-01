import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_store.dart';

void main() {
  group('PumpStore', () {
    late PumpStore store;

    setUp(() {
      store = PumpStore();
    });

    test('should start with empty list', () {
      expect(store.pumps, isEmpty);
    });

    test('should add pump and notify listeners', () async {
      PumpModel? receivedPump;

      store.addListener(() {
        receivedPump = store.pumps.lastOrNull;
      });

      final pump = PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
        currentPrice: 67234.50,
      );

      store.addPump(pump);

      expect(store.pumps.length, 1);
      expect(store.pumps.first, pump);
      expect(receivedPump, pump);
    });

    test('should maintain max 50 pumps (FIFO)', () {
      // 添加 55 个 pump
      for (int i = 0; i < 55; i++) {
        store.addPump(PumpModel(
          symbol: 'TEST$i',
          priceChange: 2.0,
          triggerTime: DateTime(2026, 4, 1, 10, 0, 0).add(Duration(seconds: i)),
          currentPrice: 100.0,
        ));
      }

      expect(store.pumps.length, 50);
      expect(store.pumps.first.symbol, 'TEST5'); // 前 5 个被移除
      expect(store.pumps.last.symbol, 'TEST54');
    });

    test('should clear all pumps', () {
      store.addPump(PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
        currentPrice: 67234.50,
      ));

      store.clear();

      expect(store.pumps, isEmpty);
    });

    test('should get today pump count', () {
      final today = DateTime(2026, 4, 1, 12, 0, 0);
      final yesterday = DateTime(2026, 3, 31, 12, 0, 0);

      store.addPump(PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: today,
        currentPrice: 67234.50,
      ));

      store.addPump(PumpModel(
        symbol: 'ETHUSDT',
        priceChange: 2.5,
        triggerTime: yesterday,
        currentPrice: 3456.78,
      ));

      expect(store.todayPumpCount(today), 1);
    });
  });
}
