import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/services/rebound/trade_simulator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';

import 'test_fixtures.dart';

void main() {
  late TradeSimulator tradeSimulator;
  late ReboundDetector detector;
  late TechnicalIndicators ti;

  setUp(() {
    ti = TechnicalIndicators();
    tradeSimulator = TradeSimulator();
    detector = ReboundDetector(ti);
  });

  /// 辅助函数：从 V 型走势 fixture 获取反弹信号。
  ReboundSignal _getSignalFromVShapedFixture() {
    final klines = vShapedQuickRecovery();
    final params = ReboundParams();
    final signal = detector.evaluate(klines, params,
        symbol: 'TESTUSDT', timeframe: '15m');
    expect(signal, isNotNull,
        reason: 'V 型 fixture 应生成至少一个反弹信号');
    return signal!;
  }

  /// 辅助函数：创建模拟 K 线以测试进场。
  KlineData _bar({
    required DateTime time,
    double open = 100.0,
    double high = 105.0,
    double low = 95.0,
    double close = 100.0,
    double volume = 100.0,
  }) {
    return KlineData(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  group('TradeSimulator', () {
    // ─── 测试 1：进场价格 = bar.open ───────────────────────────
    test('进场价格等于入场 bar 的 open', () {
      final signal = _getSignalFromVShapedFixture();
      final entryBar = _bar(
        time: DateTime(2025, 3, 15, 8, 0),
        open: 95.0,
        high: 97.0,
        low: 94.0,
        close: 96.0,
      );

      final position = tradeSimulator.enterPosition(signal, entryBar);

      expect(position.entryPrice, equals(95.0),
          reason: '进场价格应为 bar.open 而非 signal.entryPrice');
      expect(position.entryPrice, isNot(equals(signal.entryPrice)),
          reason: '进场价格不应等于信号中的 entryPrice');
    });

    // ─── 测试 2：止损触发 ─────────────────────────────────────
    test('bar.low <= stopLoss 时触发止损退出', () {
      final signal = _getSignalFromVShapedFixture();
      final entryBar = _bar(
        time: DateTime(2025, 3, 15, 8, 0),
        open: 95.0,
        high: 97.0,
        low: 94.0,
        close: 96.0,
      );

      final position = tradeSimulator.enterPosition(signal, entryBar);
      final stopLossPrice = position.stopLoss;

      // 构造跌破止损的 bar
      final crashBar = _bar(
        time: DateTime(2025, 3, 15, 8, 15),
        open: stopLossPrice + 1.0,
        high: stopLossPrice + 1.5,
        low: stopLossPrice - 0.5, // 跌穿止损
        close: stopLossPrice - 0.3,
      );

      final result =
          tradeSimulator.checkStopLoss(position, crashBar);

      expect(result, isNull,
          reason: '跌破止损后应返回 null 表示仓位已平');
    });

    // ─── 测试 3：双止盈（TP1 再 TP2） ─────────────────────────
    test('bar.high >= TP1 触发一半退出，再 TP2 完全退出', () {
      final signal = _getSignalFromVShapedFixture();
      final entryBar = _bar(
        time: DateTime(2025, 3, 15, 8, 0),
        open: 95.0,
        high: 97.0,
        low: 94.0,
        close: 96.0,
      );

      final position = tradeSimulator.enterPosition(signal, entryBar);

      // 检查 TP 价格顺序合理
      expect(position.takeProfit1, lessThan(position.takeProfit2),
          reason: 'TP1 (61.8%) 应低于 TP2 (100%)');
      expect(position.exitedHalf, isFalse);

      // ── 触发 TP1 ──
      final tp1Bar = _bar(
        time: DateTime(2025, 3, 15, 8, 30),
        open: position.takeProfit1,
        high: position.takeProfit1 + 0.5, // 触及 TP1
        low: position.takeProfit1 - 0.5,
        close: position.takeProfit1,
      );

      final tp1Result =
          tradeSimulator.checkTakeProfit(position, tp1Bar);
      expect(tp1Result, isNotNull,
          reason: '触及 TP1 应有返回值');
      final tp1Pos = tp1Result!.position;
      final tp1ExitType = tp1Result.exitType;
      expect(tp1ExitType, equals('takeProfit1'));
      expect(tp1Pos, isNotNull,
          reason: 'TP1 只退出一半，仓位仍存在');
      expect(tp1Pos!.exitedHalf, isTrue,
          reason: 'TP1 触发后应标记 exitedHalf=true');
      expect(tp1Pos.stopLoss, equals(position.stopLoss),
          reason: 'TP1 后止损保持不变');

      // ── 触发 TP2 ──
      final tp2Bar = _bar(
        time: DateTime(2025, 3, 15, 8, 45),
        open: position.takeProfit2,
        high: position.takeProfit2 + 1.0, // 触及 TP2
        low: position.takeProfit2 - 0.5,
        close: position.takeProfit2,
      );

      final tp2Result =
          tradeSimulator.checkTakeProfit(tp1Pos, tp2Bar);
      expect(tp2Result, isNotNull,
          reason: '触及 TP2 应有返回值');
      expect(tp2Result!.position, isNull,
          reason: 'TP2 完全退出，仓位应为 null');
      expect(tp2Result.exitType, equals('takeProfit2'));
    });

    // ─── 测试 4：时间退出 ─────────────────────────────────────
    test('持仓达到 maxHoldBars 后时间退出', () {
      final signal = _getSignalFromVShapedFixture();
      final entryBar = _bar(
        time: DateTime(2025, 3, 15, 8, 0),
        open: 95.0,
        high: 97.0,
        low: 94.0,
        close: 96.0,
      );

      final position = tradeSimulator.enterPosition(signal, entryBar);
      const maxHoldBars = 20;

      // 持仓 19 根时不应退出
      final stillHolding =
          tradeSimulator.checkTimeExit(position, 19, maxHoldBars);
      expect(stillHolding, isNotNull,
          reason: '持仓不足 maxHoldBars 不应时间退出');

      // 持仓 20 根时应退出
      final timeExited =
          tradeSimulator.checkTimeExit(position, 20, maxHoldBars);
      expect(timeExited, isNull,
          reason: '持仓达到 maxHoldBars 应触发时间退出');
    });

    // ─── 测试 5：成本扣费 ─────────────────────────────────────
    test('扣费后 pnl 小于纯 R 倍数', () {
      const entryPrice = 100.0;
      const exitPrice = 105.0;
      const stopLoss = 95.0; // 1R = entryPrice - stopLoss = 5
      const rMultiple = 1.5; // 纯 R 倍数

      final pnlWithCost = tradeSimulator.applyTransactionCost(
        rMultiple,
        entryPrice,
        exitPrice,
        stopLoss,
      );

      // 手续费 + 滑点应扣减（CR-03：成本按 1R = |entryPrice - stopLoss| 换算）
      // entryFee = 100 * 0.0006 = 0.06
      // exitFee = 105 * 0.0006 = 0.063
      // slippage = 100 * 0.001 + 105 * 0.001 = 0.205
      // totalCost = 0.328；riskPerR = 5；costInR = 0.328 / 5 = 0.0656
      // pnl = rMultiple - costInR = 1.5 - 0.0656 ≈ 1.4344
      expect(pnlWithCost, lessThan(rMultiple),
          reason: '含成本 PnL 应小于纯 R 倍数');
      expect(pnlWithCost, greaterThan(1.49),
          reason: '成本扣减比例正确（约 0.00328 R 单位）');
      expect(pnlWithCost, lessThan(1.5),
          reason: '成本扣减不为零');
    });
  });
}
