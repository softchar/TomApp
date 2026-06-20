import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_report.dart';
import 'package:tomapp/models/backtest_trade.dart';
import 'package:tomapp/services/rebound/report_generator.dart';

void main() {
  late ReportGenerator generator;
  late BacktestConfig config;

  setUp(() {
    generator = ReportGenerator();
    config = BacktestConfig(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 6, 30),
      symbols: const ['TESTUSDT'],
      costsEnabled: true,
    );
  });

  /// 辅助：便捷创建交易记录。
  BacktestTrade _makeTrade({
    double pnl = 0.5,
    double rMultiple = 0.6,
    String exitReason = 'takeProfit1',
  }) {
    return BacktestTrade(
      symbol: 'TESTUSDT',
      entryTime: DateTime(2025, 3, 15, 8, 0),
      entryPrice: 100.0,
      exitTime: DateTime(2025, 3, 15, 12, 0),
      exitPrice: 101.0,
      exitReason: exitReason,
      pnl: pnl,
      rMultiple: rMultiple,
    );
  }

  group('ReportGenerator', () {
    // ─── 测试 1：混合盈亏 → winRate 和 profitFactor 正确 ─────
    test('3 赢 2 亏 -> winRate=0.6 profitFactor 正确', () {
      final trades = [
        _makeTrade(pnl: 1.0, rMultiple: 1.2), // 赢
        _makeTrade(pnl: 0.5, rMultiple: 0.7), // 赢
        _makeTrade(pnl: -0.3, rMultiple: -0.2), // 亏
        _makeTrade(pnl: 2.0, rMultiple: 2.1), // 赢
        _makeTrade(pnl: -1.0, rMultiple: -0.8), // 亏
      ];

      final report = generator.generate(config: config, trades: trades);

      expect(report.totalTrades, equals(5));
      expect(report.winRate, closeTo(0.6, 0.01),
          reason: '3/5 = 0.6');
      expect(report.avgR, closeTo((1.2 + 0.7 - 0.2 + 2.1 - 0.8) / 5, 0.01));

      // profitFactor = (1.0+0.5+2.0) / |(-0.3)+(-1.0)| = 3.5/1.3 ≈ 2.692
      expect(report.profitFactor, closeTo(3.5 / 1.3, 0.01));
    });

    // ─── 测试 2：全部盈利 → profitFactor = infinity ──────────
    test('全部盈利时 profitFactor=double.infinity', () {
      final trades = [
        _makeTrade(pnl: 1.0, rMultiple: 1.0),
        _makeTrade(pnl: 2.0, rMultiple: 2.0),
        _makeTrade(pnl: 0.5, rMultiple: 0.5),
      ];

      final report = generator.generate(config: config, trades: trades);

      expect(report.winRate, equals(1.0));
      expect(report.profitFactor, equals(double.infinity),
          reason: '无亏损交易时 profitFactor 为 infinity');
    });

    // ─── 测试 3：零笔交易 → stats 全为 0 ────────────────────
    test('零笔交易时 stats 全为 0、equityCurve 为空', () {
      final report = generator.generate(config: config, trades: []);

      expect(report.totalTrades, equals(0));
      expect(report.winRate, equals(0.0));
      expect(report.avgR, equals(0.0));
      expect(report.profitFactor, equals(0.0));
      expect(report.maxDrawdown, equals(0.0));
      expect(report.sampleCount, equals(0));
      expect(report.totalPnL, equals(0.0));
      expect(report.avgRPerTrade, equals(0.0));
      expect(report.trades, isEmpty);
      expect(report.equityCurveZeroCost, isEmpty);
      expect(report.equityCurveWithCost, isEmpty);
    });

    // ─── 测试 4：maxDrawdown 从峰值计算 ──────────────────────
    test('maxDrawdown 从权益曲线峰值到谷底计算', () {
      // 构造：先涨到 5R，再跌到 2R，最大回撤 = (5-2)/5 = 0.6
      final trades = [
        _makeTrade(pnl: 1.0, rMultiple: 1.0), // cumR=1
        _makeTrade(pnl: 2.0, rMultiple: 2.0), // cumR=3 (接近峰值)
        _makeTrade(pnl: 2.0, rMultiple: 2.0), // cumR=5 ★峰值
        _makeTrade(pnl: -1.0, rMultiple: -1.0), // cumR=4
        _makeTrade(pnl: -2.0, rMultiple: -2.0), // cumR=2 ★谷底，回撤 60%
      ];

      final report = generator.generate(config: config, trades: trades);

      expect(report.maxDrawdown, closeTo(0.6, 0.01),
          reason: '峰值 5R 跌到 2R，回撤 = (5-2)/5 = 0.6');
      // 验证不是从起始值计算（若从起始值，第一个点 cumR=1，
      // 谷底=2 在峰值=5 之后，所以不可能 > 峰值）
    });
  });
}
