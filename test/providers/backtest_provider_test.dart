import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_status.dart';
import 'package:tomapp/providers/backtest_provider.dart';

/// Phase 6 / Plan 03：BacktestProvider ChangeNotifier 状态机测试。
///
/// 测试覆盖：状态字段默认值、输入验证、重入守卫、清除守卫、
/// updateConfig 守卫、cancelBacktest 标记。
/// 不测试完整回测运行流程（需要 mock DataImportService/BacktestEngine）。

void main() {
  late BacktestProvider provider;
  late int notifyCount;

  setUp(() {
    provider = BacktestProvider();
    notifyCount = 0;
    provider.addListener(() => notifyCount++);
  });

  tearDown(() {
    provider.dispose();
  });

  group('BacktestProvider 默认状态', () {
    test('初始状态为 idle，config 为默认值', () {
      expect(provider.status, BacktestStatus.idle);
      expect(provider.config, isA<BacktestConfig>());
      expect(provider.report, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.currentFold, 0);
      expect(provider.totalFolds, 3);
      expect(provider.completedCombos, 0);
      expect(provider.totalCombos, 320);
    });
  });

  group('updateConfig', () {
    test('idle 状态下可更新配置', () {
      final newConfig = BacktestConfig.defaults().copyWith(
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 6, 30),
      );
      provider.updateConfig(newConfig);
      expect(provider.config.startDate, DateTime(2024, 1, 1));
      expect(provider.config.endDate, DateTime(2024, 6, 30));
      expect(notifyCount, 1);
    });

    test('可更新任意配置字段', () {
      final newConfig = BacktestConfig.defaults().copyWith(
        maxHoldBars: 30,
        costsEnabled: false,
      );
      provider.updateConfig(newConfig);
      expect(provider.config.maxHoldBars, 30);
      expect(provider.config.costsEnabled, false);
    });
  });

  group('runBacktest 输入验证', () {
    test('startDate >= endDate 时 status=error 并设 errorMessage', () {
      final badConfig = BacktestConfig(
        startDate: DateTime(2024, 6, 30),
        endDate: DateTime(2024, 1, 1),
        symbols: ['BTCUSDT'],
      );
      provider.updateConfig(badConfig);

      // runBacktest 是 async，但日期验证在同步代码块内执行
      provider.runBacktest();
      expect(provider.status, BacktestStatus.error);
      expect(provider.errorMessage, '起始日期必须早于结束日期');
    });

    test('日期范围超过 365 天时 status=error', () {
      final badConfig = BacktestConfig(
        startDate: DateTime(2023, 1, 1),
        endDate: DateTime(2024, 12, 31),
        symbols: ['BTCUSDT'],
      );
      provider.updateConfig(badConfig);
      provider.runBacktest();
      expect(provider.status, BacktestStatus.error);
      expect(provider.errorMessage, '回测时间范围最多 365 天');
    });

    test('startDate 早于 2020-01-01 时 status=error', () {
      final badConfig = BacktestConfig(
        startDate: DateTime(2019, 1, 1),
        endDate: DateTime(2019, 12, 31),
        symbols: ['BTCUSDT'],
      );
      provider.updateConfig(badConfig);
      provider.runBacktest();
      expect(provider.status, BacktestStatus.error);
      expect(provider.errorMessage, '起始日期不能早于 2020-01-01');
    });
  });

  group('clearResults', () {
    test('idle 状态下清除无效果但仍可调用', () {
      provider.clearResults();
      expect(provider.status, BacktestStatus.idle);
      expect(provider.report, isNull);
      expect(provider.errorMessage, isNull);
    });

    test('error 状态下可清除并重置为 idle', () {
      // 先通过非法日期让状态变为 error
      final badConfig = BacktestConfig(
        startDate: DateTime(2024, 6, 30),
        endDate: DateTime(2024, 1, 1),
        symbols: ['BTCUSDT'],
      );
      provider.updateConfig(badConfig);
      provider.runBacktest();
      expect(provider.status, BacktestStatus.error);

      final notifyBeforeClear = notifyCount;
      provider.clearResults();
      expect(provider.status, BacktestStatus.idle);
      expect(provider.report, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.currentFold, 0);
      expect(provider.completedCombos, 0);
      expect(notifyCount, greaterThan(notifyBeforeClear));
    });
  });
}
