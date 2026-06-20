import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_report.dart';
import 'package:tomapp/models/backtest_trade.dart';

/// 回测报告生成器（纯计算，零 I/O）。
///
/// 负责从交易列表计算全部统计指标和权益曲线数据。
class ReportGenerator {
  /// 从交易列表和配置生成回测报告。
  ///
  /// [trades] 为空时返回空报告（stats 全为 0）。
  BacktestReport generate({
    required BacktestConfig config,
    required List<BacktestTrade> trades,
  }) {
    final startedAt = DateTime.now();
    final completedAt = DateTime.now();

    if (trades.isEmpty) {
      return BacktestReport.empty(config).copyWith(
        startedAt: startedAt,
        completedAt: completedAt,
      );
    }

    final totalTrades = trades.length;

    // 胜率：pnl > 0 视为赢
    final winningTrades =
        trades.where((t) => t.pnl > 0).length;
    final winRate = totalTrades > 0 ? winningTrades / totalTrades : 0.0;

    // 平均 R 倍数（纯 R）
    final avgR =
        trades.fold<double>(0, (s, t) => s + t.rMultiple) / totalTrades;

    // 总 PnL
    final totalPnL =
        trades.fold<double>(0, (s, t) => s + t.pnl);

    // 每笔平均 PnL
    final avgRPerTrade =
        totalTrades > 0 ? totalPnL / totalTrades : 0.0;

    // 盈亏比：总盈利 / |总亏损|
    final positivePnl = trades
        .where((t) => t.pnl > 0)
        .fold<double>(0, (s, t) => s + t.pnl);
    final negativePnl = trades
        .where((t) => t.pnl < 0)
        .fold<double>(0, (s, t) => s + t.pnl);
    final profitFactor = negativePnl.abs() > 0
        ? positivePnl / negativePnl.abs()
        : (positivePnl > 0 ? double.infinity : 0.0);

    // 权益曲线
    final equityCurveZeroCost =
        <({int tradeIndex, double cumulativeR})>[];
    final equityCurveWithCost =
        <({int tradeIndex, double cumulativeR})>[];
    double cumRZero = 0.0;
    double cumRCost = 0.0;
    for (int i = 0; i < trades.length; i++) {
      cumRZero += trades[i].rMultiple;
      cumRCost += trades[i].pnl;
      equityCurveZeroCost.add((tradeIndex: i, cumulativeR: cumRZero));
      equityCurveWithCost.add((tradeIndex: i, cumulativeR: cumRCost));
    }

    // 最大回撤：从含成本权益曲线峰值到谷底计算
    double maxDrawdown = 0.0;
    if (equityCurveWithCost.isNotEmpty) {
      double peak = equityCurveWithCost.first.cumulativeR;
      for (final point in equityCurveWithCost) {
        if (point.cumulativeR > peak) {
          peak = point.cumulativeR;
        }
        final denominator = peak.abs().clamp(0.01, double.infinity);
        final drawdown = (peak - point.cumulativeR) / denominator;
        if (drawdown > maxDrawdown) {
          maxDrawdown = drawdown;
        }
      }
    }

    return BacktestReport(
      config: config,
      startedAt: startedAt,
      completedAt: completedAt,
      totalTrades: totalTrades,
      winRate: winRate,
      avgR: avgR,
      profitFactor: profitFactor,
      maxDrawdown: maxDrawdown,
      sampleCount: totalTrades,
      totalPnL: totalPnL,
      avgRPerTrade: avgRPerTrade,
      trades: trades,
      equityCurveZeroCost: equityCurveZeroCost,
      equityCurveWithCost: equityCurveWithCost,
    );
  }
}
