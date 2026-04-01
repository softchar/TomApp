import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_model.dart';

void main() {
  group('PumpModel', () {
    test('should create model with all required fields', () {
      final model = PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
        currentPrice: 67234.50,
      );

      expect(model.symbol, 'BTCUSDT');
      expect(model.priceChange, 3.5);
      expect(model.triggerTime, DateTime(2026, 4, 1, 10, 23, 45));
      expect(model.currentPrice, 67234.50);
    });

    test('should serialize to map correctly', () {
      final model = PumpModel(
        symbol: 'ETHUSDT',
        priceChange: 2.3,
        triggerTime: DateTime(2026, 4, 1, 10, 22, 10),
        currentPrice: 3456.78,
      );

      final map = model.toMap();

      expect(map['symbol'], 'ETHUSDT');
      expect(map['priceChange'], 2.3);
      expect(map['triggerTime'], DateTime(2026, 4, 1, 10, 22, 10).toIso8601String());
      expect(map['currentPrice'], 3456.78);
    });

    test('should deserialize from map correctly', () {
      final map = {
        'symbol': 'BTCUSDT',
        'priceChange': 3.5,
        'triggerTime': DateTime(2026, 4, 1, 10, 23, 45).toIso8601String(),
        'currentPrice': 67234.50,
      };

      final model = PumpModel.fromMap(map);

      expect(model.symbol, 'BTCUSDT');
      expect(model.priceChange, 3.5);
      expect(model.triggerTime, DateTime(2026, 4, 1, 10, 23, 45));
      expect(model.currentPrice, 67234.50);
    });
  });
}
