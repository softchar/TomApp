import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/models/position.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_report.dart';
import 'package:tomapp/models/backtest_trade.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/trade_simulator.dart';

/// Event-driven 逐 bar 回测引擎（纯计算核心，零 I/O）。
///
/// 禁用向量化操作（对齐 CONTEXT.md D-15 + PITFALLS.md Pitfall 1）。
/// live 路径与回测路径调用同一 ReboundDetector.evaluate 纯函数。
///
/// 关键约束：
/// - bar[t].close 触发信号 → bar[t+1].open 进场（D-01）
/// - 每 symbol 最多 1 个并发仓位（v1）
/// - 窗口只用 bar[0..i]，不含未来数据
class BacktestEngine {
  final ReboundDetector _detector;
  final TradeSimulator _tradeSimulator;

  BacktestEngine({
    required ReboundDetector detector,
    required TradeSimulator tradeSimulator,
  })  : _detector = detector,
        _tradeSimulator = tradeSimulator;

  /// 在给定的 K 线序列上运行 event-driven 回测。
  ///
  /// [symbol]/[interval] 传给 ReboundDetector.evaluate。
  /// [klines] 必须按时间升序排列。
  /// [params] 检测器参数。
  /// [config] 回测配置（costsEnabled、maxHoldBars）。
  /// [fundingRateHistory] 资金费率历史 {fundingTime(ms): rate}，可选。
  ///
  /// 返回完整的 [BacktestReport]，包含交易列表和统计指标。
  Future<BacktestReport> runBacktestOnKlines({
    required String symbol,
    required String interval,
    required ReboundParams params,
    required BacktestConfig config,
    required List<KlineData> klines,
    Map<int, double>? fundingRateHistory,
  }) async {
    final startedAt = DateTime.now();

    if (klines.isEmpty) {
      final completedAt = DateTime.now();
      return BacktestReport.empty(config).copyWith(
        startedAt: startedAt,
        completedAt: completedAt,
      );
    }

    final trades = <BacktestTrade>[];
    Position? position;
    ReboundSignal? pendingSignal;
    int entryBarIndex = -1;
    // 累计资金费扣除（在持仓期间逐 bar 累计）
    double cumulativeFundingCost = 0.0;

    for (int i = 0; i < klines.length; i++) {
      final bar = klines[i];

      // ─── 开盘阶段：若上根有 pending signal 且无持仓，在 bar[i].open 进场 ───
      if (pendingSignal != null && position == null) {
        position = _tradeSimulator.enterPosition(pendingSignal, bar);
        entryBarIndex = i;
        pendingSignal = null;
      }

      // ─── 持仓中：检查出场 + 扣费 ─────────────────────────────
      if (position != null) {
        bool exited = false;

        // 止损检查（D-02）：bar.low <= stopLoss
        final afterSL = _tradeSimulator.checkStopLoss(position, bar);
        if (afterSL == null) {
          final exitPrice = position.stopLoss;
          final rMultiple = _calcRMultiple(
              position.entryPrice, exitPrice, position.stopLoss,
              isPartialExit: false);
          double pnl = rMultiple;
          if (config.costsEnabled) {
            pnl = _tradeSimulator.applyTransactionCost(
                rMultiple, position.entryPrice, exitPrice, position.stopLoss);
            pnl -= cumulativeFundingCost;
          }
          trades.add(BacktestTrade(
            symbol: position.symbol,
            entryTime: position.entryTime,
            entryPrice: position.entryPrice,
            exitTime: bar.time,
            exitPrice: exitPrice,
            exitReason: 'stopLoss',
            pnl: pnl,
            rMultiple: rMultiple,
          ));
          position = null;
          cumulativeFundingCost = 0.0;
          exited = true;
        }

        // 双止盈检查（D-03）：bar.high >= takeProfit1 / takeProfit2
        if (!exited && position != null) {
          final tpResult = _tradeSimulator.checkTakeProfit(position, bar);
          if (tpResult != null) {
            final tpExitType = tpResult.exitType!;
            if (tpResult.position == null) {
              // 完全退出（TP2 或 TP1+TP2 同一 bar）
              // 先处理 TP1 partial（50% 仓位）
              if (position.exitedHalf == false &&
                  bar.high >= position.takeProfit2) {
                // 同一根 bar: TP1 先触发 → 再 TP2
                final tp1R = _calcRMultiple(position.entryPrice,
                    position.takeProfit1, position.stopLoss,
                    isPartialExit: true);
                double tp1Pnl = tp1R;
                if (config.costsEnabled) {
                  tp1Pnl = _tradeSimulator.applyTransactionCost(
                      tp1R, position.entryPrice, position.takeProfit1,
                      position.stopLoss);
                  tp1Pnl -= cumulativeFundingCost * 0.5;
                }
                trades.add(BacktestTrade(
                  symbol: position.symbol,
                  entryTime: position.entryTime,
                  entryPrice: position.entryPrice,
                  exitTime: bar.time,
                  exitPrice: position.takeProfit1,
                  exitReason: 'takeProfit1',
                  pnl: tp1Pnl,
                  rMultiple: tp1R,
                ));

                // TP2: 剩余 50% 仓位
                final tp2R = _calcRMultiple(position.entryPrice,
                    position.takeProfit2, position.stopLoss,
                    isPartialExit: true);
                double tp2Pnl = tp2R;
                if (config.costsEnabled) {
                  tp2Pnl = _tradeSimulator.applyTransactionCost(
                      tp2R, position.entryPrice, position.takeProfit2,
                      position.stopLoss);
                  tp2Pnl -= cumulativeFundingCost * 0.5;
                }
                trades.add(BacktestTrade(
                  symbol: position.symbol,
                  entryTime: position.entryTime,
                  entryPrice: position.entryPrice,
                  exitTime: bar.time,
                  exitPrice: position.takeProfit2,
                  exitReason: 'takeProfit2',
                  pnl: tp2Pnl,
                  rMultiple: tp2R,
                ));
              } else if (position.exitedHalf) {
                // TP2 single exit (TP1 already happened on a previous bar)
                final tp2R = _calcRMultiple(position.entryPrice,
                    position.takeProfit2, position.stopLoss,
                    isPartialExit: true);
                double tp2Pnl = tp2R;
                if (config.costsEnabled) {
                  tp2Pnl = _tradeSimulator.applyTransactionCost(
                      tp2R, position.entryPrice, position.takeProfit2,
                      position.stopLoss);
                  tp2Pnl -= cumulativeFundingCost * 0.5;
                }
                trades.add(BacktestTrade(
                  symbol: position.symbol,
                  entryTime: position.entryTime,
                  entryPrice: position.entryPrice,
                  exitTime: bar.time,
                  exitPrice: position.takeProfit2,
                  exitReason: 'takeProfit2',
                  pnl: tp2Pnl,
                  rMultiple: tp2R,
                ));
              } else {
                // TP1 only (partial exit, 50% 仓位)
                final tp1R = _calcRMultiple(position.entryPrice,
                    position.takeProfit1, position.stopLoss,
                    isPartialExit: true);
                double tp1Pnl = tp1R;
                if (config.costsEnabled) {
                  tp1Pnl = _tradeSimulator.applyTransactionCost(
                      tp1R, position.entryPrice, position.takeProfit1,
                      position.stopLoss);
                  tp1Pnl -= cumulativeFundingCost * 0.5;
                }
                trades.add(BacktestTrade(
                  symbol: position.symbol,
                  entryTime: position.entryTime,
                  entryPrice: position.entryPrice,
                  exitTime: bar.time,
                  exitPrice: position.takeProfit1,
                  exitReason: 'takeProfit1',
                  pnl: tp1Pnl,
                  rMultiple: tp1R,
                ));
              }

              position = null;
              cumulativeFundingCost = 0.0;
              exited = true;
            } else {
              // TP1 触发但未完全退出（exitedHalf=true）
              final tp1R = _calcRMultiple(position.entryPrice,
                  position.takeProfit1, position.stopLoss,
                  isPartialExit: true);
              double tp1Pnl = tp1R;
              if (config.costsEnabled) {
                tp1Pnl = _tradeSimulator.applyTransactionCost(
                    tp1R, position.entryPrice, position.takeProfit1,
                    position.stopLoss);
                tp1Pnl -= cumulativeFundingCost * 0.5;
              }
              trades.add(BacktestTrade(
                symbol: position.symbol,
                entryTime: position.entryTime,
                entryPrice: position.entryPrice,
                exitTime: bar.time,
                exitPrice: position.takeProfit1,
                exitReason: 'takeProfit1',
                pnl: tp1Pnl,
                rMultiple: tp1R,
              ));
              // 继续持有剩余 50%，不移除 position
              cumulativeFundingCost *= 0.5;
              position = tpResult.position;
            }
          }
        }

        // 时间退出检查（D-04）：holdBars >= maxHoldBars
        if (!exited && position != null) {
          final holdBars = i - entryBarIndex;
          final afterTime = _tradeSimulator.checkTimeExit(
              position, holdBars, config.maxHoldBars);
          if (afterTime == null) {
            final exitPrice = bar.close; // 在 bar.close 市价退出
            final rMultiple = _calcRMultiple(
                position.entryPrice, exitPrice, position.stopLoss,
                isPartialExit: position.exitedHalf);
            double pnl = rMultiple;
            if (config.costsEnabled) {
              pnl = _tradeSimulator.applyTransactionCost(
                  rMultiple, position.entryPrice, exitPrice,
                  position.stopLoss);
              pnl -= cumulativeFundingCost;
            }
            trades.add(BacktestTrade(
              symbol: position.symbol,
              entryTime: position.entryTime,
              entryPrice: position.entryPrice,
              exitTime: bar.time,
              exitPrice: exitPrice,
              exitReason: 'timeExit',
              pnl: pnl,
              rMultiple: rMultiple,
            ));
            position = null;
            cumulativeFundingCost = 0.0;
            exited = true;
          }
        }

        // 资金费扣费（D-05）：持仓跨 8h 整点扣 funding
        if (!exited && position != null && config.costsEnabled) {
          final fundingCost = _tradeSimulator.applyFundingFee(
            position,
            bar.time,
            fundingRateHistory ?? {},
            barDuration: _barDurationFromInterval(interval),
          );
          cumulativeFundingCost += fundingCost;
        }
      }

      // ─── 收盘阶段：调用 detector.evaluate ───────────────────
      // 只用 bar[0..i]，不含未来数据（Pitfall 1 硬约束）
      final window = klines.sublist(0, i + 1);
      pendingSignal = _detector.evaluate(
        window,
        params,
        symbol: symbol,
        timeframe: interval,
      );
    }

    // ─── 遍历结束：若有未平仓位，在最后一根 bar 的 close 强制平仓 ───
    if (position != null) {
      final lastBar = klines.last;
      final exitPrice = lastBar.close;
      final rMultiple = _calcRMultiple(
          position.entryPrice, exitPrice, position.stopLoss,
          isPartialExit: position.exitedHalf);
      double pnl = rMultiple;
      if (config.costsEnabled) {
        pnl = _tradeSimulator.applyTransactionCost(
            rMultiple, position.entryPrice, exitPrice,
            position.stopLoss);
        pnl -= cumulativeFundingCost;
      }
      trades.add(BacktestTrade(
        symbol: position.symbol,
        entryTime: position.entryTime,
        entryPrice: position.entryPrice,
        exitTime: lastBar.time,
        exitPrice: exitPrice,
        exitReason: 'manual',
        pnl: pnl,
        rMultiple: rMultiple,
      ));
    }

    // ─── 组装报告 ───────────────────────────────────────────
    return _buildReport(config, trades, startedAt);
  }

  /// 从 Binance interval 字符串解析 bar 时长（WR-04）。
  ///
  /// 支持 "15m"/"1h"/"4h"/"1d" 等。无法解析时默认 15 分钟（向后兼容）。
  Duration _barDurationFromInterval(String interval) {
    if (interval.isEmpty) return const Duration(minutes: 15);
    final unit = interval[interval.length - 1];
    final value = int.tryParse(interval.substring(0, interval.length - 1));
    if (value == null) return const Duration(minutes: 15);
    switch (unit) {
      case 'm':
        return Duration(minutes: value);
      case 'h':
        return Duration(hours: value);
      case 'd':
        return Duration(days: value);
      case 'w':
        return Duration(days: value * 7);
      default:
        return const Duration(minutes: 15);
    }
  }

  /// 计算 R 倍数（以止损风险为 1R 单位）。
  ///
  /// 多头：rMultiple = (exitPrice - entryPrice) / (entryPrice - stopLoss)
  /// 部分退出时 rMultiple 已在上层折半处理。
  double _calcRMultiple(
    double entryPrice,
    double exitPrice,
    double stopLoss, {
    required bool isPartialExit,
  }) {
    final risk = entryPrice - stopLoss;
    if (risk <= 0) return 0.0;
    final r = (exitPrice - entryPrice) / risk;
    return isPartialExit ? r * 0.5 : r;
  }

  /// 从交易列表构建回测报告。
  BacktestReport _buildReport(
    BacktestConfig config,
    List<BacktestTrade> trades,
    DateTime startedAt,
  ) {
    final completedAt = DateTime.now();

    if (trades.isEmpty) {
      return BacktestReport.empty(config).copyWith(
        startedAt: startedAt,
        completedAt: completedAt,
      );
    }

    // 统计计算（含成本 pnl）
    final totalTrades = trades.length;
    final winningTrades =
        trades.where((t) => t.pnl > 0).length;
    final winRate = totalTrades > 0 ? winningTrades / totalTrades : 0.0;
    final avgR = trades.fold<double>(0, (s, t) => s + t.rMultiple) / totalTrades;
    final totalPnL =
        trades.fold<double>(0, (s, t) => s + t.pnl);
    final avgRPerTrade =
        totalTrades > 0 ? totalPnL / totalTrades : 0.0;

    // profitFactor: sum of positive / |sum of negative|
    final positivePnl = trades
        .where((t) => t.pnl > 0)
        .fold<double>(0, (s, t) => s + t.pnl);
    final negativePnl = trades
        .where((t) => t.pnl < 0)
        .fold<double>(0, (s, t) => s + t.pnl);
    // profitFactor（WR-02）：与 ReportGenerator.generate 保持一致的边界处理。
    // 无亏损且有盈利 → infinity；无亏损也无盈利（全 0 PnL）→ 0.0。
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

    // maxDrawdown（从含成本权益曲线峰值到谷底）
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
