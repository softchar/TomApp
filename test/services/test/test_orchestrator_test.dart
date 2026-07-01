import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/services/test/test_orchestrator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';

void main() {
  group('TestOrchestrator', () {
    late TestDataGenerator generator;
    late ReboundDetector detector;

    setUp(() {
      generator = TestDataGenerator(
        mode: SimulationMode.vRebound,
        seed: 42,
      );
      detector = ReboundDetector(TechnicalIndicators());
    });

    TestOrchestrator createOrchestrator() {
      return TestOrchestrator(
        generator: generator,
        detector: detector,
      );
    }

    test('初始状态 isRunning = false', () {
      final orch = createOrchestrator();
      expect(orch.isRunning, false);
      expect(orch.window, isEmpty);
      expect(orch.signals, isEmpty);
      orch.dispose();
    });

    test('start() 后 isRunning = true', () {
      final orch = createOrchestrator();
      orch.start();
      expect(orch.isRunning, true);
      orch.dispose();
    });

    test('pause() 后 isRunning = false', () {
      final orch = createOrchestrator();
      orch.start();
      orch.pause();
      expect(orch.isRunning, false);
      orch.dispose();
    });

    test('reset() 清空 window 和 signals', () {
      final orch = createOrchestrator();
      orch.start();
      orch.pause();
      orch.reset();
      expect(orch.window, isEmpty);
      expect(orch.signals, isEmpty);
      orch.dispose();
    });

    test('changeMode() 切换模式后 window 清空且暂停', () {
      final orch = createOrchestrator();
      orch.start();
      orch.pause();
      orch.changeMode(SimulationMode.steadyDecline);
      expect(orch.window, isEmpty);
      expect(orch.isRunning, false);
      orch.dispose();
    });

    test('changeMode() 切换到 steadyDecline 后 isRunning = false', () {
      final orch = createOrchestrator();
      orch.start();
      orch.changeMode(SimulationMode.steadyDecline);
      expect(orch.isRunning, false);
      orch.dispose();
    });

    test('dispose() 取消 Timer 不抛异常', () {
      final orch = createOrchestrator();
      orch.start();
      // dispose 应该正常取消 timer，不抛异常
      expect(() => orch.dispose(), returnsNormally);
    });
  });

  group('TestDataGenerator mode 特征验证', () {
    test('steadyDecline 模式 close 严格递减', () {
      final gen = TestDataGenerator(
        mode: SimulationMode.steadyDecline,
        seed: 42,
      );
      final baseTime = DateTime(2024, 1, 1);
      double? prevClose;

      for (int i = 0; i < 30; i++) {
        final candle = gen.nextCandle(baseTime.add(Duration(minutes: i * 5)));
        if (prevClose != null) {
          expect(
            candle.close,
            lessThan(prevClose),
            reason: '第 $i 根 close (${candle.close}) 应 < 前一根 ($prevClose)',
          );
        }
        prevClose = candle.close;
      }
    });

    test('vRebound 模式第 20-22 根 close 递减（急跌段）', () {
      final gen = TestDataGenerator(
        mode: SimulationMode.vRebound,
        seed: 42,
      );
      final baseTime = DateTime(2024, 1, 1);
      final candles = <double>[];

      for (int i = 0; i < 25; i++) {
        final candle = gen.nextCandle(baseTime.add(Duration(minutes: i * 5)));
        candles.add(candle.close);
      }

      // 急跌段：第 20、21、22 根 close 递减
      for (int i = 20; i < 23; i++) {
        expect(
          candles[i],
          lessThan(candles[i - 1]),
          reason: '第 $i 根 close (${candles[i]}) 应 < 第 ${i - 1} 根 (${candles[i - 1]})',
        );
      }
    });

    test('seed getter 返回构造时传入的 seed', () {
      final gen = TestDataGenerator(
        mode: SimulationMode.vRebound,
        seed: 99,
      );
      expect(gen.seed, 99);
    });

    test('seed getter 无 seed 时返回 null', () {
      final gen = TestDataGenerator(
        mode: SimulationMode.vRebound,
      );
      expect(gen.seed, isNull);
    });

    test('相同 seed + 相同模式 = 相同数据序列', () {
      final baseTime = DateTime(2024, 1, 1);
      final gen1 = TestDataGenerator(mode: SimulationMode.steadyDecline, seed: 42);
      final gen2 = TestDataGenerator(mode: SimulationMode.steadyDecline, seed: 42);

      for (int i = 0; i < 10; i++) {
        final t = baseTime.add(Duration(minutes: i * 5));
        final c1 = gen1.nextCandle(t);
        final c2 = gen2.nextCandle(t);
        expect(c1.close, equals(c2.close), reason: '第 $i 根 close 应相同');
      }
    });

    test('相同 seed + 不同模式 = 不同数据序列', () {
      final baseTime = DateTime(2024, 1, 1);
      final gen1 = TestDataGenerator(mode: SimulationMode.vRebound, seed: 42);
      final gen2 = TestDataGenerator(mode: SimulationMode.steadyDecline, seed: 42);

      // 跳过前 20 根平稳段（vRebound 前 20 根与 steadyDecline 可能相似）
      final candles1 = <double>[];
      final candles2 = <double>[];
      for (int i = 0; i < 30; i++) {
        final t = baseTime.add(Duration(minutes: i * 5));
        candles1.add(gen1.nextCandle(t).close);
        candles2.add(gen2.nextCandle(t).close);
      }

      // 至少在某个阶段数据应该不同
      final hasDifference = List.generate(30, (i) => candles1[i] != candles2[i]).any((b) => b);
      expect(hasDifference, isTrue, reason: '不同模式即使 seed 相同，数据序列也应不同');
    });
  });

  group('TestOrchestrator changeMode 数据特征验证', () {
    late ReboundDetector detector;

    setUp(() {
      detector = ReboundDetector(TechnicalIndicators());
    });

    test('changeMode 切换到 steadyDecline 后生成的 window 数据持续下跌', () {
      // 通过直接使用 TestDataGenerator 模拟 changeMode 后的行为
      final gen = TestDataGenerator(mode: SimulationMode.steadyDecline, seed: 42);
      final baseTime = DateTime(2024, 1, 1);
      double? prevClose;

      for (int i = 0; i < 30; i++) {
        final candle = gen.nextCandle(baseTime.add(Duration(minutes: i * 5)));
        if (prevClose != null) {
          expect(
            candle.close,
            lessThan(prevClose),
            reason: '第 $i 根 close (${candle.close}) 应 < 前一根 ($prevClose)',
          );
        }
        prevClose = candle.close;
      }
    });

    test('changeMode 切换回 vRebound 后数据符合 V 型特征', () {
      final gen = TestDataGenerator(mode: SimulationMode.vRebound, seed: 42);
      final baseTime = DateTime(2024, 1, 1);
      final candles = <double>[];

      for (int i = 0; i < 25; i++) {
        final candle = gen.nextCandle(baseTime.add(Duration(minutes: i * 5)));
        candles.add(candle.close);
      }

      // 第 20-22 根 close 递减（急跌段）
      for (int i = 20; i < 23; i++) {
        expect(
          candles[i],
          lessThan(candles[i - 1]),
          reason: '第 $i 根 close (${candles[i]}) 应 < 第 ${i - 1} 根 (${candles[i - 1]})',
        );
      }
    });

    test('changeMode 保留 seed 可重现性', () {
      final baseTime = DateTime(2024, 1, 1);

      // 模拟 orchestrator changeMode 后的行为：创建新 generator，保留 seed
      final gen1 = TestDataGenerator(mode: SimulationMode.steadyDecline, seed: 42);
      final gen2 = TestDataGenerator(mode: SimulationMode.steadyDecline, seed: 42);

      final data1 = <double>[];
      final data2 = <double>[];

      for (int i = 0; i < 10; i++) {
        final t = baseTime.add(Duration(minutes: i * 5));
        data1.add(gen1.nextCandle(t).close);
        data2.add(gen2.nextCandle(t).close);
      }

      expect(data1, equals(data2), reason: '相同 seed + 相同模式应产生完全一致的数据');
    });
  });

  // ── 向生产监控页对齐：信号收集口径 ──────────────────────────────
  // 决策1：移除 score>=60 门槛（命中由 detector 三阶段门槛决定）
  // 决策2：recentBars 过滤（只保留最近 N 根内结束的反弹，与 ReboundMarketScanner 一致）
  group('TestOrchestrator 信号收集口径（向监控页对齐）', () {
    // 极小阈值让 warm-up minLen 最小（3+1+1+1+2=8）以尽快进入检测；
    // 取 8 > recentBars(6)，避开 window.length==recentBars 的 threshold=0 边界
    // （生产 scanner 窗口远大于 recentBars，不会触发该边界）。
    const tinyParams = ReboundParams(
      atrPeriod: 3,
      dropMaxCandles: 1,
      recoveryMaxCandles: 1,
      swingLookback: 1,
    );

    test('弱信号（score<60）也入库 —— 移除 score>=60 门槛（决策1）', () {
      final orch = TestOrchestrator(
        generator: TestDataGenerator(mode: SimulationMode.vRebound, seed: 1),
        detector: _FakeDetector(_signal(score: 50, recoveryEndIndex: 100)),
        params: tinyParams,
      );
      orch.start();
      orch.pause(); // 停真实 Timer，手动驱动 tick
      for (var i = 0; i < 10; i++) orch.tick(); // window.length=10
      expect(orch.signals, isNotEmpty,
          reason: 'score=50 应入库：命中由 detector 三阶段门槛决定，不再卡 score>=60');
      orch.dispose();
    });

    test('窗口内历史反弹（recoveryEndIndex 在最近6根外）被过滤（决策2）', () {
      final orch = TestOrchestrator(
        generator: TestDataGenerator(mode: SimulationMode.vRebound, seed: 1),
        detector: _FakeDetector(_signal(score: 80, recoveryEndIndex: 0)),
        params: tinyParams,
      );
      orch.start();
      orch.pause();
      for (var i = 0; i < 10; i++) orch.tick();
      expect(orch.signals, isEmpty,
          reason: 'recoveryEndIndex=0 在最近6根外，应被 recentBars 过滤（与 scanner 一致）');
      orch.dispose();
    });

    test('最近发生的强反弹仍入库（防回归）', () {
      final orch = TestOrchestrator(
        generator: TestDataGenerator(mode: SimulationMode.vRebound, seed: 1),
        detector: _FakeDetector(_signal(score: 80, recoveryEndIndex: 1000)),
        params: tinyParams,
      );
      orch.start();
      orch.pause();
      for (var i = 0; i < 10; i++) orch.tick();
      expect(orch.signals, isNotEmpty,
          reason: 'recoveryEndIndex 在最近6根内 + 高分，应正常入库');
      orch.dispose();
    });
  });
}

/// 构造可控的测试信号（仅 score / recoveryEndIndex 可变，其余固定）。
ReboundSignal _signal({required int score, required int recoveryEndIndex}) {
  return ReboundSignal(
    symbol: 'TESTUSDT',
    timeframe: '15m',
    dropMagnitude: 2.5,
    recoveryRatio: 0.6,
    speed: 1,
    confluenceFilters: const <ConfluenceType>{},
    score: score,
    deadCatRiskScore: 10,
    entryPrice: 100,
    swingLowPrice: 90,
    swingHighPrice: 100,
    dropStartIndex: 0,
    dropEndIndex: 1,
    recoveryEndIndex: recoveryEndIndex,
    timestamp: DateTime(2024, 1, 1),
  );
}

/// 假检测器：忽略真实窗口，恒返回预设信号，便于精确控制 score / recoveryEndIndex。
class _FakeDetector extends ReboundDetector {
  final ReboundSignal signal;
  _FakeDetector(this.signal) : super(TechnicalIndicators());

  @override
  ReboundSignal? evaluate(
    List<KlineData> window,
    ReboundParams params, {
    required String symbol,
    required String timeframe,
  }) =>
      signal;
}
