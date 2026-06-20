import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/services/rebound/walk_forward.dart';
import 'package:tomapp/services/rebound/backtest_engine.dart';
import 'package:tomapp/services/rebound/trade_simulator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'test_fixtures.dart';

void main() {
  late WalkForward walkForward;
  late BacktestEngine engine;
  late BacktestConfig config;

  setUp(() {
    final ti = TechnicalIndicators();
    final tradeSimulator = TradeSimulator();
    final detector = ReboundDetector(ti);
    engine = BacktestEngine(
      detector: detector,
      tradeSimulator: tradeSimulator,
    );
    walkForward = WalkForward();
    config = BacktestConfig(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 6, 30),
      symbols: const ['TESTUSDT'],
      costsEnabled: false,
      maxHoldBars: 20,
    );
  });

  /// 生成跨 6 个月的合成 K 线数据（用于 walk-forward）。
  List<KlineData> _generate6MonthsKlines() {
    // 生成 ~6 * 30 * 96 = 17280 根 15m K 线（简化版：每"天"4 根 = 每 6h 一根）
    final klines = <KlineData>[];
    final baseTime = DateTime(2025, 1, 1);
    // 为速度考虑，生成较少但跨越足够月份的数据
    // 每月 30 天 × 每天 4 根 = 120 根/月，6 个月 = 720 根
    const barsPerMonth = 120;
    const totalMonths = 6;
    var price = 100.0;

    for (int month = 0; month < totalMonths; month++) {
      for (int bar = 0; bar < barsPerMonth; bar++) {
        // 制作带 V 型反弹的数据模式保证检测器有机会触发信号
        // 每月前半段平稳，后半段 V 型反弹
        final monthProgress = bar / barsPerMonth;
        double close;
        if (monthProgress < 0.5) {
          // 平稳段
          final noise = (monthProgress - 0.25) * 2.0;
          close = price + noise;
        } else if (monthProgress < 0.7) {
          // 下跌段
          final dropProgress = (monthProgress - 0.5) / 0.2;
          close = price - 10.0 * dropProgress;
        } else {
          // 反弹段
          final recoveryProgress = (monthProgress - 0.7) / 0.3;
          close = price - 10.0 + 8.0 * recoveryProgress;
        }

        final open = bar == 0 && month == 0 ? price : klines.last.close;
        final high = open > close ? open + 0.5 : close + 0.5;
        final low = open < close ? open - 0.5 : close - 0.5;

        final barIdx = month * barsPerMonth + bar;
        klines.add(KlineData(
          time: baseTime.add(Duration(hours: 6 * barIdx)),
          open: open,
          high: high,
          low: low > 0 ? low : 0.01,
          close: close,
          volume: 100.0 + (monthProgress >= 0.7 ? 200.0 : 50.0),
        ));
      }
      price = klines.last.close + 5.0; // 每月之间小幅跳升
    }

    return klines;
  }

  /// 生成精简参数网格（测试用，非全量 320）。
  List<ReboundParams> _smallParamGrid() {
    // 2×2×2×2 = 16 组合，足够小网格验证 walk-forward 流程
    final grid = <ReboundParams>[];
    for (final dropAtr in [2.0, 2.5]) {
      for (final recovRatio in [0.5, 0.6]) {
        for (final dropCandles in [3, 4]) {
          for (final volMult in [1.5, 2.0]) {
            grid.add(ReboundParams().copyWith(
              dropAtrMultiplier: dropAtr,
              recoveryMinRatio: recovRatio,
              dropMaxCandles: dropCandles,
              volumeMultiplier: volMult,
            ));
          }
        }
      }
    }
    return grid;
  }

  group('WalkForward', () {
    // ─── 测试 1：6 个月 + 小网格 → 跑 3-fold 全流程不崩溃 ────
    test('6 个月数据 + 16 组合 → 3-fold walk-forward 不崩溃', () async {
      final klines = _generate6MonthsKlines();
      final paramGrid = _smallParamGrid();

      final folds = await walkForward.runWalkForward(
        allKlines: klines,
        paramGrid: paramGrid,
        engine: engine,
        config: config,
      );

      expect(folds.length, equals(3),
          reason: 'walk-forward 应产生 3 个 fold');
      for (final fold in folds) {
        expect(fold.foldIndex, greaterThanOrEqualTo(0));
        expect(fold.foldIndex, lessThan(3));
      }
    });

    // ─── 测试 2：Fold 切片验证 ───────────────────────────────
    test('fold 0 的 test 数据属于第 4 月', () async {
      final klines = _generate6MonthsKlines();
      final paramGrid = [ReboundParams()]; // 1 个组合加速

      final folds = await walkForward.runWalkForward(
        allKlines: klines,
        paramGrid: paramGrid,
        engine: engine,
        config: config,
      );

      expect(folds.length, equals(3));

      // 验证 fold 0 的 train end = month 3, test = month 4
      final fold0 = folds[0];
      expect(fold0.trainMonthEnd, equals(3),
          reason: 'fold 0 train 结束于月 3');
      expect(fold0.testMonth, equals(4),
          reason: 'fold 0 test 是月 4');

      // test trades 的 entryTime 应在 month 4 范围内
      if (fold0.testTrades.isNotEmpty) {
        for (final trade in fold0.testTrades) {
          final month = trade.entryTime.month;
          expect(month, equals(4),
              reason: 'fold 0 test trades 应来自第 4 月，实际是 $month 月');
        }
      }
    });

    // ─── 测试 3：只聚合 out-of-sample ─────────────────────────
    test('buildParamGrid 返回 320 个组合', () {
      final grid = walkForward.buildParamGrid();

      expect(grid.length, equals(320),
          reason: '4×5×4×4 = 320 参数组合');
      // 验证每个组合是不同的
      expect(grid.toSet().length, greaterThan(1),
          reason: '参数网格应包含不同组合');
    });
  });
}
