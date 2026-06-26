import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/models/kline_data.dart';

void main() {
  group('TestDataGenerator', () {
    group('vRebound 模式', () {
      test('第 20-22 根 close 递减（下跌段）', () {
        final gen = TestDataGenerator(
          mode: SimulationMode.vRebound,
          seed: 42,
        );
        // 跳过前 20 根
        for (int i = 0; i < 20; i++) {
          gen.nextCandle(DateTime(2024, 1, 1, 0, i));
        }
        // 第 20-22 根应递减
        final candles = <KlineData>[];
        for (int i = 20; i < 23; i++) {
          candles.add(gen.nextCandle(DateTime(2024, 1, 1, 0, i)));
        }
        expect(candles[0].close, greaterThan(candles[1].close));
        expect(candles[1].close, greaterThan(candles[2].close));
      });

      test('第 23-24 根 close 递增（回升段）', () {
        final gen = TestDataGenerator(
          mode: SimulationMode.vRebound,
          seed: 42,
        );
        // 跳过前 23 根
        for (int i = 0; i < 23; i++) {
          gen.nextCandle(DateTime(2024, 1, 1, 0, i));
        }
        // 第 23-24 根应递增
        final candles = <KlineData>[];
        for (int i = 23; i < 25; i++) {
          candles.add(gen.nextCandle(DateTime(2024, 1, 1, 0, i)));
        }
        expect(candles[0].close, lessThan(candles[1].close));
      });

      test('回升段 volume 放大', () {
        final gen = TestDataGenerator(
          mode: SimulationMode.vRebound,
          seed: 42,
        );
        // 收集平稳段 volume
        final stableVolumes = <double>[];
        for (int i = 0; i < 20; i++) {
          final k = gen.nextCandle(DateTime(2024, 1, 1, 0, i));
          stableVolumes.add(k.volume);
        }
        final avgStableVol =
            stableVolumes.reduce((a, b) => a + b) / stableVolumes.length;

        // 跳过下跌段 3 根
        for (int i = 20; i < 23; i++) {
          gen.nextCandle(DateTime(2024, 1, 1, 0, i));
        }
        // 回升段 volume 应大于平稳段均值
        for (int i = 23; i < 25; i++) {
          final k = gen.nextCandle(DateTime(2024, 1, 1, 0, i));
          expect(k.volume, greaterThan(avgStableVol));
        }
      });
    });

    group('deadCatBounce 模式', () {
      test('第 23-24 根回补幅度小于 vRebound', () {
        // vRebound 回补幅度
        final vGen = TestDataGenerator(
          mode: SimulationMode.vRebound,
          seed: 42,
        );
        // 生成 23 根，获取第 22 根（下跌段结束）和第 24 根（回补结束）
        final vCandles = <KlineData>[];
        for (int i = 0; i < 25; i++) {
          vCandles.add(vGen.nextCandle(DateTime(2024, 1, 1, 0, i)));
        }
        final vLow = vCandles[22].close; // 下跌段最低
        final vRecoveryEnd = vCandles[24].close; // 回补结束
        final vRecoveryPct = (vRecoveryEnd - vLow) / vLow;

        // deadCatBounce 回补幅度
        final dGen = TestDataGenerator(
          mode: SimulationMode.deadCatBounce,
          seed: 42,
        );
        final dCandles = <KlineData>[];
        for (int i = 0; i < 25; i++) {
          dCandles.add(dGen.nextCandle(DateTime(2024, 1, 1, 0, i)));
        }
        final dLow = dCandles[22].close;
        final dRecoveryEnd = dCandles[24].close;
        final dRecoveryPct = (dRecoveryEnd - dLow) / dLow;

        expect(dRecoveryPct, lessThan(vRecoveryPct));
      });
    });

    group('randomWalk 模式', () {
      test('无明显单向趋势（最大连续同方向不超过 15 根）', () {
        final gen = TestDataGenerator(
          mode: SimulationMode.randomWalk,
          seed: 42,
        );
        final closes = <double>[];
        for (int i = 0; i < 30; i++) {
          final k = gen.nextCandle(DateTime(2024, 1, 1, 0, i));
          closes.add(k.close);
        }
        // 检查最长连续同方向不超过 15 根
        int maxConsecutive = 1;
        int currentConsecutive = 1;
        for (int i = 2; i < closes.length; i++) {
          final prevDir = closes[i - 1] > closes[i - 2];
          final currDir = closes[i] > closes[i - 1];
          if (currDir == prevDir) {
            currentConsecutive++;
            if (currentConsecutive > maxConsecutive) {
              maxConsecutive = currentConsecutive;
            }
          } else {
            currentConsecutive = 1;
          }
        }
        expect(maxConsecutive, lessThanOrEqualTo(15));
      });
    });

    group('steadyDecline 模式', () {
      test('所有 close 严格递减', () {
        final gen = TestDataGenerator(
          mode: SimulationMode.steadyDecline,
          seed: 42,
        );
        final closes = <double>[];
        for (int i = 0; i < 30; i++) {
          final k = gen.nextCandle(DateTime(2024, 1, 1, 0, i));
          closes.add(k.close);
        }
        for (int i = 1; i < closes.length; i++) {
          expect(closes[i], lessThan(closes[i - 1]),
              reason: '第 $i 根 close 应小于第 ${i - 1} 根');
        }
      });
    });

    group('seed 可重现性', () {
      test('相同 seed + 相同调用序列 = 相同结果', () {
        final gen1 = TestDataGenerator(
          mode: SimulationMode.vRebound,
          seed: 42,
        );
        final gen2 = TestDataGenerator(
          mode: SimulationMode.vRebound,
          seed: 42,
        );

        for (int i = 0; i < 30; i++) {
          final time = DateTime(2024, 1, 1, 0, i);
          final k1 = gen1.nextCandle(time);
          final k2 = gen2.nextCandle(time);
          expect(k1.close, equals(k2.close), reason: '第 $i 根 close 应相同');
          expect(k1.volume, equals(k2.volume), reason: '第 $i 根 volume 应相同');
        }
      });
    });

    test('nextCandle 每次调用 step 递增', () {
      final gen = TestDataGenerator(
        mode: SimulationMode.vRebound,
        seed: 42,
      );
      expect(gen.step, 0);
      gen.nextCandle(DateTime(2024, 1, 1, 0, 0));
      expect(gen.step, 1);
      gen.nextCandle(DateTime(2024, 1, 1, 0, 1));
      expect(gen.step, 2);
    });

    test('reset 重置状态', () {
      final gen = TestDataGenerator(
        mode: SimulationMode.vRebound,
        seed: 42,
      );
      gen.nextCandle(DateTime(2024, 1, 1, 0, 0));
      gen.nextCandle(DateTime(2024, 1, 1, 0, 1));
      expect(gen.step, 2);
      gen.reset();
      expect(gen.step, 0);
    });
  });
}
