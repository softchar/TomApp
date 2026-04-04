import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/strategies/time_based_strategy.dart';

void main() {
  group('TimeBasedStrategy', () {
    late TimeBasedStrategy strategy;

    setUp(() {
      strategy = TimeBasedStrategy();
    });

    test('name returns "TimeBased"', () {
      expect(strategy.name, 'TimeBased');
    });

    test('adjust returns numeric value', () {
      final result = strategy.adjust(2.0);
      expect(result, isA<double>());
      expect(result, greaterThan(-1.0));
      expect(result, lessThan(1.0));
    });
  });
}
