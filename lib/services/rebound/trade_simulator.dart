import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/models/position.dart';

/// 模拟交易引擎（纯计算，零 I/O）。
///
/// 负责进场、止损、双止盈、时间退出、成本扣费五项功能。
/// live 与回测共用同一份代码（同源不变量）。
///
/// 对齐 CONTEXT.md D-01 至 D-06 全部交易与成本规则。
class TradeSimulator {
  /// 从信号数据恢复 ATR 值（引擎计算时已确定）。
  ///
  /// dropMagnitude = drop / atr，所以 atr = drop / dropMagnitude。
  double _recoverAtr(ReboundSignal signal) {
    final drop = signal.swingHighPrice - signal.swingLowPrice;
    if (drop <= 0 || signal.dropMagnitude <= 0) return 0.0;
    return drop / signal.dropMagnitude;
  }

  /// 构建持仓（D-01/D-02/D-03）。
  ///
  /// - entryPrice = [entryBar.open]（bar[t+1].open，非 signal.entryPrice）。
  /// - stopLoss = swingLow − 0.3×ATR（ATR 从信号数据恢复）。
  /// - takeProfit1 = swingHigh − (swingHigh − swingLow) × 0.618（61.8% Fib 回撤位）。
  /// - takeProfit2 = swingHigh（100% Fib 回撤位）。
  Position enterPosition(ReboundSignal signal, KlineData entryBar) {
    final entryPrice = entryBar.open;
    final atr = _recoverAtr(signal);
    final stopLoss = signal.swingLowPrice - 0.3 * atr;
    final dropRange = signal.swingHighPrice - signal.swingLowPrice;
    // 多头仓位止盈位：从底部向上计算 Fibonacci 回撤位
    // 61.8% 回撤 = swingLow + dropRange * 0.618
    // 100% 回撤 = swingHighPrice
    final takeProfit1 = signal.swingLowPrice + dropRange * 0.618;
    final takeProfit2 = signal.swingHighPrice;

    return Position(
      symbol: signal.symbol,
      entryTime: entryBar.time,
      entryPrice: entryPrice,
      quantity: 1.0, // v1 固定名义仓位=1（R 倍数归一化）
      stopLoss: stopLoss.clamp(0.0, entryPrice),
      takeProfit1: takeProfit1,
      takeProfit2: takeProfit2,
      exitedHalf: false,
    );
  }

  /// 止损检查（D-02）。
  ///
  /// 若 [bar.low] <= [position.stopLoss]，以 stopLoss 价格退出。
  /// 返回 null 表示仓位已平。
  Position? checkStopLoss(Position position, KlineData bar) {
    if (bar.low <= position.stopLoss) {
      return null; // 止损退出
    }
    return position;
  }

  /// 双止盈检查（D-03）。
  ///
  /// - !exitedHalf 且 bar.high >= takeProfit1：出售 50% 仓位，标记 exitedHalf=true，返回新的 Position。
  /// - exitedHalf 且 bar.high >= takeProfit2：出售剩余 50%，完全退出，返回 null。
  /// - 同一根 bar 同时触发 TP1 和 TP2：先 TP1 再 TP2（两个独立事件）。
  ///
  /// 返回 record：position=null 表示完全退出，exitType 为触发的止盈类型。
  /// 无触发时返回 null（外层 null）。
  ({Position? position, String? exitType})? checkTakeProfit(
    Position position,
    KlineData bar,
  ) {
    // 同一根 bar 同时触发 TP1 和 TP2
    if (!position.exitedHalf && bar.high >= position.takeProfit1) {
      if (bar.high >= position.takeProfit2) {
        // 直接到 TP2（TP1 先触发再 TP2）
        return (position: null, exitType: 'takeProfit2');
      }
      // 只触发 TP1
      return (
        position: position.copyWith(exitedHalf: true),
        exitType: 'takeProfit1',
      );
    }

    // TP1 已触发，现触发 TP2
    if (position.exitedHalf && bar.high >= position.takeProfit2) {
      return (position: null, exitType: 'takeProfit2');
    }

    return null; // 无触发
  }

  /// 时间退出检查（D-04）。
  ///
  /// 若 [holdBars] >= [maxHoldBars]，触发时间退出。
  /// 返回 null 表示仓位已平；返回原 Position 表示继续持仓。
  Position? checkTimeExit(Position position, int holdBars, int maxHoldBars) {
    if (holdBars >= maxHoldBars) {
      return null; // 时间退出
    }
    return position;
  }

  /// 交易成本扣除（D-06）。
  ///
  /// - 进场 taker fee = entryPrice × 0.06%。
  /// - 出场 taker fee = exitPrice × 0.06%。
  /// - 滑点 = entryPrice × 0.1% + exitPrice × 0.1%（单边 0.1%）。
  /// - 总成本从 [rMultiple]（R 倍数）中扣除。
  ///
  /// 注意：[rMultiple] 是 R 倍数而非绝对金额，成本需要转换为 R 单位的等值调整量。
  /// 简单实现：成本按价格比例直接扣除（使用 entry/exit price 的百分比）。
  double applyTransactionCost(double rMultiple, double entryPrice,
      double exitPrice) {
    const takerFeeRate = 0.0006; // 0.06%
    const slippageRate = 0.001; // 0.1% per side

    final entryFee = entryPrice * takerFeeRate;
    final exitFee = exitPrice * takerFeeRate;
    final slippage = entryPrice * slippageRate + exitPrice * slippageRate;

    // 成本转换：成本占 entryPrice 的比例（近似 R 单位扣减）
    // 保守假设入场时 1R = entryPrice（因为 R 倍数已 normalization）
    final costRatio = (entryFee + exitFee + slippage) / entryPrice;
    return rMultiple - costRatio;
  }

  /// 资金费率扣费（D-05）。
  ///
  /// 检查 [barTime] 是否跨越 00:00/08:00/16:00 UTC 结算时刻。
  /// 若跨越，查找对应的 funding rate 并计算扣费。
  ///
  /// [fundingRateHistory]：{fundingTime(ms): rate}，由 engine 外部维护。
  ///
  /// 返回应扣除的成本（以 entryPrice 比例计，近似 R 单位）。
  double applyFundingFee(
    Position position,
    DateTime barTime,
    Map<int, double> fundingRateHistory,
  ) {
    // UTC 结算时刻（小时）
    const settlementHours = [0, 8, 16];

    double totalCost = 0.0;

    for (final hour in settlementHours) {
      final settlementTime =
          DateTime.utc(barTime.year, barTime.month, barTime.day, hour);

      // 检查 bar 是否跨越该结算时刻
      // bar 从 barTime 开始持续到下一个 bar 时间
      // 简化：如果 barTime 的小时数 和下一个结算时刻在同一 bar 跨度内
      // 实际上：bar 的时间代表 openTime，跨 15m。
      // 若 settlementTime 在 (barTime, barTime + 15min] 范围内，则跨越。
      final barEnd = barTime.add(const Duration(minutes: 15));
      if (settlementTime.isAfter(barTime) &&
          !settlementTime.isAfter(barEnd)) {
        // 查找该结算时刻的 funding rate
        final settlementMs = settlementTime.millisecondsSinceEpoch;
        final rate = fundingRateHistory[settlementMs];
        if (rate != null) {
          // fundingCost = quantity * fundingRate（名义仓位价值 × rate）
          // quantity = 1（R 归一化时）——扣费按 signal.entryPrice * rate 近似
          final fundingCost = position.quantity * rate.abs();
          totalCost += fundingCost;
        }
      }
    }

    // 转换回 entryPrice 比例
    if (position.entryPrice > 0) {
      return totalCost / position.entryPrice;
    }
    return 0.0;
  }
}
