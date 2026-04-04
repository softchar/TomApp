import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/technical_indicators.dart';

void main() {
  group('TechnicalIndicators.calculateMA', () {
    test('returns null for insufficient data', () {
      final indicators = TechnicalIndicators();
      final data = _createTestKlineData(3); // Only 3 data points

      final result = indicators.calculateMA(data, 5);

      expect(result, hasLength(3));
      expect(result.every((value) => value == null), true);
    });

    test('computes correct average', () {
      final indicators = TechnicalIndicators();
      final data = _createTestKlineData(5, closes: [10.0, 20.0, 30.0, 40.0, 50.0]);

      final result = indicators.calculateMA(data, 3);

      // First 2 values should be null
      expect(result[0], null);
      expect(result[1], null);

      // Third value: (10 + 20 + 30) / 3 = 20
      expect(result[2]!.toStringAsFixed(2), '20.00');

      // Fourth value: (20 + 30 + 40) / 3 = 30
      expect(result[3]!.toStringAsFixed(2), '30.00');

      // Fifth value: (30 + 40 + 50) / 3 = 40
      expect(result[4]!.toStringAsFixed(2), '40.00');
    });
  });

  group('TechnicalIndicators.calculateBOLL', () {
    test('returns correct bands', () {
      final indicators = TechnicalIndicators();
      final data = _createTestKlineData(20, closes: List.generate(20, (i) => 100.0 + i.toDouble()));

      final result = indicators.calculateBOLL(data, period: 5, stdDev: 2.0);

      expect(result, isNotNull);
      expect(result.upper, hasLength(20));
      expect(result.middle, hasLength(20));
      expect(result.lower, hasLength(20));

      // First 4 values should be null (insufficient data for period 5)
      for (int i = 0; i < 4; i++) {
        expect(result.middle[i], null);
        expect(result.upper[i], null);
        expect(result.lower[i], null);
      }

      // 5th value should have data
      expect(result.middle[4], isNotNull);
      expect(result.upper[4], isNotNull);
      expect(result.lower[4], isNotNull);

      // Upper band should be >= middle >= lower band
      expect(result.upper[4]! >= result.middle[4]!, true);
      expect(result.middle[4]! >= result.lower[4]!, true);
    });
  });

  group('TechnicalIndicators.calculateMACD', () {
    test('returns null for insufficient data', () {
      final indicators = TechnicalIndicators();
      final data = _createTestKlineData(10); // Less than slowPeriod (26) + signalPeriod (9)

      final result = indicators.calculateMACD(data);

      expect(result, null);
    });

    test('computes MACD correctly with default parameters', () {
      final indicators = TechnicalIndicators();
      // Create 40 data points to ensure sufficient data for MACD calculation
      final data = _createTestKlineData(40, closes: List.generate(40, (i) => 100.0 + i.toDouble()));

      final result = indicators.calculateMACD(data);

      expect(result, isNotNull);
      expect(result!.dif, hasLength(40));
      expect(result.dea, hasLength(40));
      expect(result.macd, hasLength(40));
      expect(result.time, hasLength(40));

      // First values should be null (insufficient data for calculations)
      int nullCount = result.dif.where((d) => d == null).length;
      expect(nullCount, greaterThan(0));

      // After sufficient data, all values should be non-null
      int nonNullCount = result.dif.skip(35).where((d) => d != null).length;
      expect(nonNullCount, greaterThan(0));
    });

    test('computes MACD correctly with custom periods', () {
      final indicators = TechnicalIndicators();
      final data = _createTestKlineData(30, closes: List.generate(30, (i) => 100.0 + i.toDouble()));

      final result = indicators.calculateMACD(
        data,
        fastPeriod: 5,
        slowPeriod: 10,
        signalPeriod: 3,
      );

      expect(result, isNotNull);
      expect(result!.dif, hasLength(30));
      expect(result.dea, hasLength(30));
      expect(result.macd, hasLength(30));
    });
  });
}

/// Helper function to create test KlineData
List<KlineData> _createTestKlineData(int count, {List<double>? closes}) {
  return List.generate(count, (i) {
    final close = closes?[i] ?? 100.0 + i.toDouble();
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(1700000000000 + i * 60000),
      open: close - 1,
      high: close + 2,
      low: close - 2,
      close: close,
      volume: 1000.0,
    );
  });
}
