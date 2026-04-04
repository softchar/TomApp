import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/macd_data.dart';

void main() {
  group('MACDData', () {
    test('should create model with all required fields', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0, 2.0, 3.0],
        dea: [0.5, 1.5, 2.5],
        macd: [0.5, 0.5, 0.5],
        time: [
          now,
          now.add(const Duration(minutes: 1)),
          now.add(const Duration(minutes: 2)),
        ],
      );

      expect(model.dif, [1.0, 2.0, 3.0]);
      expect(model.dea, [0.5, 1.5, 2.5]);
      expect(model.macd, [0.5, 0.5, 0.5]);
      expect(model.time.length, 3);
    });

    test('should handle nullable values in lists', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0, null, 3.0],
        dea: [0.5, null, 2.5],
        macd: [0.5, null, 0.5],
        time: [
          now,
          now.add(const Duration(minutes: 1)),
          now.add(const Duration(minutes: 2)),
        ],
      );

      expect(model.dif[1], isNull);
      expect(model.dea[1], isNull);
      expect(model.macd[1], isNull);
    });

    test('length should return time list length', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0, 2.0],
        dea: [0.5, 1.5],
        macd: [0.5, 0.5],
        time: [
          now,
          now.add(const Duration(minutes: 1)),
        ],
      );

      expect(model.length, 2);
    });

    test('getValue should return null for out of bounds index', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0],
        dea: [0.5],
        macd: [0.5],
        time: [now],
      );

      expect(model.getValue(-1), isNull);
      expect(model.getValue(10), isNull);
    });

    test('getValue should return null when any value is null', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0, null, 3.0],
        dea: [0.5, 1.5, 2.5],
        macd: [0.5, 0.5, 0.5],
        time: [
          now,
          now.add(const Duration(minutes: 1)),
          now.add(const Duration(minutes: 2)),
        ],
      );

      expect(model.getValue(1), isNull);
    });

    test('getValue should return MACDValue when all values are present', () {
      final now = DateTime.now();
      final time1 = now.add(const Duration(minutes: 1));
      final model = MACDData(
        dif: [1.0, 2.0, 3.0],
        dea: [0.5, 1.5, 2.5],
        macd: [0.5, 0.5, 0.5],
        time: [
          now,
          time1,
          now.add(const Duration(minutes: 2)),
        ],
      );

      final value = model.getValue(1);

      expect(value, isNotNull);
      expect(value!.dif, 2.0);
      expect(value.dea, 1.5);
      expect(value.macd, 0.5);
      expect(value.time, time1);
    });

    test('getValue should return valid MACDValue at first index', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0],
        dea: [0.5],
        macd: [0.5],
        time: [now],
      );

      final value = model.getValue(0);

      expect(value, isNotNull);
      expect(value!.dif, 1.0);
      expect(value.dea, 0.5);
      expect(value.macd, 0.5);
      expect(value.time, now);
    });
  });

  group('MACDValue', () {
    test('should create model with all required fields', () {
      final now = DateTime.now();
      final value = MACDValue(
        dif: 2.5,
        dea: 1.5,
        macd: 1.0,
        time: now,
      );

      expect(value.dif, 2.5);
      expect(value.dea, 1.5);
      expect(value.macd, 1.0);
      expect(value.time, now);
    });

    test('isPositive should return true when macd is positive', () {
      final value = MACDValue(
        dif: 2.5,
        dea: 1.5,
        macd: 1.0,
        time: DateTime.now(),
      );

      expect(value.isPositive, isTrue);
    });

    test('isPositive should return true when macd is zero', () {
      final value = MACDValue(
        dif: 2.5,
        dea: 2.5,
        macd: 0.0,
        time: DateTime.now(),
      );

      expect(value.isPositive, isTrue);
    });

    test('isPositive should return false when macd is negative', () {
      final value = MACDValue(
        dif: 1.5,
        dea: 2.5,
        macd: -1.0,
        time: DateTime.now(),
      );

      expect(value.isPositive, isFalse);
    });

    test('isPositive should handle very small positive values', () {
      final value = MACDValue(
        dif: 2.5,
        dea: 2.4999,
        macd: 0.0001,
        time: DateTime.now(),
      );

      expect(value.isPositive, isTrue);
    });

    test('isPositive should handle very small negative values', () {
      final value = MACDValue(
        dif: 2.5,
        dea: 2.5001,
        macd: -0.0001,
        time: DateTime.now(),
      );

      expect(value.isPositive, isFalse);
    });

    test('should handle large values', () {
      final value = MACDValue(
        dif: 1000000.0,
        dea: 500000.0,
        macd: 500000.0,
        time: DateTime.now(),
      );

      expect(value.dif, 1000000.0);
      expect(value.dea, 500000.0);
      expect(value.macd, 500000.0);
      expect(value.isPositive, isTrue);
    });

    test('should handle negative values for all fields', () {
      final value = MACDValue(
        dif: -100.0,
        dea: -50.0,
        macd: -50.0,
        time: DateTime.now(),
      );

      expect(value.dif, -100.0);
      expect(value.dea, -50.0);
      expect(value.macd, -50.0);
      expect(value.isPositive, isFalse);
    });
  });

  group('MACDData edge cases', () {
    test('should handle empty lists', () {
      final model = MACDData(
        dif: [],
        dea: [],
        macd: [],
        time: [],
      );

      expect(model.length, 0);
      expect(model.getValue(0), isNull);
    });

    test('should handle single element lists', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [1.0],
        dea: [0.5],
        macd: [0.5],
        time: [now],
      );

      expect(model.length, 1);
      final value = model.getValue(0);
      expect(value, isNotNull);
      expect(value!.dif, 1.0);
    });

    test('should handle all null values', () {
      final now = DateTime.now();
      final model = MACDData(
        dif: [null, null],
        dea: [null, null],
        macd: [null, null],
        time: [
          now,
          now.add(const Duration(minutes: 1)),
        ],
      );

      expect(model.length, 2);
      expect(model.getValue(0), isNull);
      expect(model.getValue(1), isNull);
    });
  });
}
