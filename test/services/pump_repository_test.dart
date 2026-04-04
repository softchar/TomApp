import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/pump_repository.dart';

void main() {
  group('MemoryPumpRepository', () {
    late MemoryPumpRepository repository;

    setUp(() {
      repository = MemoryPumpRepository();
    });

    test('save and retrieve pump', () async {
      final pump = PumpHistoryModel(
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      await repository.save(pump);

      final results = await repository.findAll();
      expect(results.length, 1);
      expect(results.first.symbol, 'BTCUSDT');
    });

    test('findAll with symbol filter', () async {
      final pump1 = PumpHistoryModel(
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      final pump2 = PumpHistoryModel(
        symbol: 'ETHUSDT',
        basePrice: 3500.0,
        peakPrice: 3570.0,
        priceChange: 2.0,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      await repository.saveAll([pump1, pump2]);

      final results = await repository.findAll(symbol: 'BTCUSDT');
      expect(results.length, 1);
      expect(results.first.symbol, 'BTCUSDT');
    });

    test('updatePullback updates pullback percent', () async {
      final pump = PumpHistoryModel(
        id: 1,
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      await repository.save(pump);
      await repository.updatePullback(1, 66000.0, DateTime.now().millisecondsSinceEpoch);

      final results = await repository.findAll();
      expect(results.first.pullbackPercent, closeTo(-0.75, 0.01));
    });
  });

  group('RepositoryFactory', () {
    test('create returns repository', () {
      final repo = RepositoryFactory.create();
      expect(repo, isA<PumpRepository>());
    });
  });
}
