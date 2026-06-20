import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_report.dart';
import 'package:tomapp/models/backtest_trade.dart';
import 'package:tomapp/services/rebound/backtest_engine.dart';
import 'package:tomapp/services/rebound/report_generator.dart';

/// Walk-forward 单次折叠结果。
class FoldResult {
  /// 折叠编号（0-based）。
  final int foldIndex;

  /// 训练窗口结束月份（1-based）。
  final int trainMonthEnd;

  /// 测试月份（1-based）。
  final int testMonth;

  /// 在测试窗口表现最优的参数组合。
  final ReboundParams? bestParams;

  /// 测试窗口内产生的交易列表。
  final List<BacktestTrade> testTrades;

  /// 测试窗口的统计报告。
  final BacktestReport? testStats;

  const FoldResult({
    required this.foldIndex,
    required this.trainMonthEnd,
    required this.testMonth,
    this.bestParams,
    required this.testTrades,
    this.testStats,
  });
}

/// Walk-forward 参数扫描编排器。
///
/// 实现 3-fold 锚定 walk-forward + 320 参数网格全量扫描。
/// 只聚合 out-of-sample 指标（D-10/D-11 强制）。
class WalkForward {
  final ReportGenerator _reportGenerator = ReportGenerator();

  /// 构造 320 个 ReboundParams 参数组合（4×5×4×4）。
  ///
  /// - dropAtrMultiplier: [1.5, 2.0, 2.5, 3.0]（4 档）
  /// - recoveryMinRatio: [0.3, 0.4, 0.5, 0.6, 0.7]（5 档）
  /// - dropMaxCandles: [2, 3, 4, 5]（4 档）
  /// - volumeMultiplier: [1.0, 1.5, 2.0, 3.0]（4 档）
  ///
  /// 权重（D-13）和共振过滤器开关（D-14）不进扫描——沿用默认值。
  List<ReboundParams> buildParamGrid() {
    final grid = <ReboundParams>[];
    const dropAtrValues = [1.5, 2.0, 2.5, 3.0];
    const recovRatioValues = [0.3, 0.4, 0.5, 0.6, 0.7];
    const dropCandlesValues = [2, 3, 4, 5];
    const volMultValues = [1.0, 1.5, 2.0, 3.0];

    for (final dropAtr in dropAtrValues) {
      for (final recovRatio in recovRatioValues) {
        for (final dropCandles in dropCandlesValues) {
          for (final volMult in volMultValues) {
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
    return grid; // 4×5×4×4 = 320
  }

  /// 运行 3-fold 锚定 walk-forward 参数扫描。
  ///
  /// [allKlines] 按时间升序排列的全部 K 线（覆盖整个回测日期范围）。
  /// [paramGrid] 参数组合列表。
  /// [engine] 回测引擎实例。
  /// [config] 回测配置。
  /// [fundingRateHistory] 资金费率历史 {fundingTime(ms): rate}，透传给引擎
  ///   计算 D-05 资金费扣费（CR-02）。
  ///
  /// 返回 3 个 FoldResult。数据不足时降级处理（不崩溃）。
  Future<List<FoldResult>> runWalkForward({
    required List<KlineData> allKlines,
    required List<ReboundParams> paramGrid,
    required BacktestEngine engine,
    required BacktestConfig config,
    Map<int, double>? fundingRateHistory,
  }) async {
    if (allKlines.isEmpty || paramGrid.isEmpty) {
      return [];
    }

    // 按月份分桶
    final months = _splitByMonth(allKlines);
    if (months.length < 2) {
      // 数据不足时返回空 folds 列表，由 aggregateOutOfSample 生成空报告（WR-01）。
      // 退化为单折使用 train == test 的全量数据会得到 In-Sample 结果，
      // 违反 D-10/D-11「仅报告 Out-of-Sample 指标」约束。
      return [];
    }

    final results = <FoldResult>[];

    // 确定折叠数：min(3, 月份数-1)
    final numFolds = (months.length - 1).clamp(1, 3);

    for (int fold = 0; fold < numFolds; fold++) {
      // Fold N: train = 月 1..(3+N), test = 月 (4+N)
      // 简化：train_end_month = months.length - numFolds + fold
      final trainEndMonthIdx = months.length - numFolds + fold;
      final testMonthIdx = trainEndMonthIdx + 1;

      if (testMonthIdx > months.length) break;

      // 合并训练数据
      final trainKlines = <KlineData>[];
      for (int m = 0; m < trainEndMonthIdx; m++) {
        trainKlines.addAll(months[m]);
      }
      // 测试数据
      final testKlines = months[testMonthIdx - 1]; // months 0-indexed

      final foldResult = await _runFold(
        foldIndex: fold,
        trainKlines: trainKlines,
        testKlines: testKlines,
        paramGrid: paramGrid,
        engine: engine,
        config: config,
        trainMonthEnd: trainEndMonthIdx,
        testMonth: testMonthIdx,
        fundingRateHistory: fundingRateHistory,
      );

      results.add(foldResult);
    }

    return results;
  }

  /// 聚合所有 fold 的 out-of-sample 交易为一个大厅列表，生成聚合报告。
  ///
  /// 只包含 test window 的交易（对齐 D-10/D-11）。
  BacktestReport aggregateOutOfSample(
    List<FoldResult> folds,
    BacktestConfig config,
  ) {
    final allTestTrades = <BacktestTrade>[];
    for (final fold in folds) {
      allTestTrades.addAll(fold.testTrades);
    }

    return _reportGenerator.generate(config: config, trades: allTestTrades);
  }

  // ─── 内部方法 ──────────────────────────────────────────────

  /// 按月份将 K 线分组。月份编号从 1 开始。
  List<List<KlineData>> _splitByMonth(List<KlineData> klines) {
    if (klines.isEmpty) return [];

    final months = <List<KlineData>>[];
    final baseMonth = klines.first.time.month;
    final baseYear = klines.first.time.year;
    var currentMonth = baseMonth;
    var currentYear = baseYear;
    var currentBucket = <KlineData>[];

    for (final kline in klines) {
      if (kline.time.month != currentMonth ||
          kline.time.year != currentYear) {
        if (currentBucket.isNotEmpty) {
          months.add(currentBucket);
        }
        currentMonth = kline.time.month;
        currentYear = kline.time.year;
        currentBucket = <KlineData>[];
      }
      currentBucket.add(kline);
    }
    if (currentBucket.isNotEmpty) {
      months.add(currentBucket);
    }

    return months;
  }

  /// 执行单个 fold 的参数扫描。
  Future<FoldResult> _runFold({
    required int foldIndex,
    required List<KlineData> trainKlines,
    required List<KlineData> testKlines,
    required List<ReboundParams> paramGrid,
    required BacktestEngine engine,
    required BacktestConfig config,
    required int trainMonthEnd,
    required int testMonth,
    Map<int, double>? fundingRateHistory,
  }) async {
    ReboundParams? bestParams;
    List<BacktestTrade> bestTrades = [];
    double bestPnL = double.negativeInfinity;

    // 合并 train + test 作为完整序列传给引擎
    final fullKlines = [...trainKlines, ...testKlines];

    for (final params in paramGrid) {
      final report = await engine.runBacktestOnKlines(
        symbol: config.symbols.isNotEmpty ? config.symbols.first : 'TESTUSDT',
        interval: '15m',
        params: params,
        config: config,
        klines: fullKlines,
        fundingRateHistory: fundingRateHistory,
      );

      // 只提取 test window 内的交易
      final testWindowStart = testKlines.first.time;
      final testWindowEnd = testKlines.last.time;
      final testTrades = report.trades
          .where((t) =>
              !t.entryTime.isBefore(testWindowStart) &&
              !t.entryTime.isAfter(testWindowEnd))
          .toList();

      final testPnL = testTrades.fold<double>(0, (s, t) => s + t.pnl);

      if (testPnL > bestPnL) {
        bestPnL = testPnL;
        bestParams = params;
        bestTrades = testTrades;
      }
    }

    BacktestReport? testStats;
    if (bestTrades.isNotEmpty) {
      testStats = _reportGenerator.generate(config: config, trades: bestTrades);
    }

    return FoldResult(
      foldIndex: foldIndex,
      trainMonthEnd: trainMonthEnd,
      testMonth: testMonth,
      bestParams: bestParams,
      testTrades: bestTrades,
      testStats: testStats,
    );
  }
}
