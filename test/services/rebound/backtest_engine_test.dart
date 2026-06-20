import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/services/rebound/backtest_engine.dart';
import 'package:tomapp/services/rebound/trade_simulator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';

import 'test_fixtures.dart';

void main() {
  late BacktestEngine engine;
  late TradeSimulator tradeSimulator;
  late ReboundDetector detector;
  late TechnicalIndicators ti;
  late BacktestConfig defaultConfig;

  setUp(() {
    ti = TechnicalIndicators();
    tradeSimulator = TradeSimulator();
    detector = ReboundDetector(ti);
    engine = BacktestEngine(
      detector: detector,
      tradeSimulator: tradeSimulator,
    );
    defaultConfig = BacktestConfig(
      startDate: DateTime(2025, 3, 14),
      endDate: DateTime(2025, 3, 16),
      symbols: const ['TESTUSDT'],
      costsEnabled: true,
      maxHoldBars: 20,
    );
  });

  group('BacktestEngine', () {
    // ─── 测试 1：V 型反弹全流程 ───────────────────────────────
    test('V 型反弹全流程：检测信号 → 进场 → 出场', () async {
      final klines = vShapedQuickRecovery();
      final params = ReboundParams();

      final report = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: defaultConfig,
        klines: klines,
      );

      expect(report.totalTrades, greaterThanOrEqualTo(1),
          reason: 'V 型走势应触发至少一笔交易');
      expect(report.trades.length, equals(report.totalTrades));

      // 第一笔交易的验证
      final trade = report.trades.first;
      expect(trade.symbol, equals('TESTUSDT'));
      expect(trade.entryTime, isNotNull);
      expect(
        ['takeProfit1', 'takeProfit2', 'stopLoss', 'timeExit', 'manual']
            .contains(trade.exitReason),
        isTrue,
        reason: 'exitReason 应为有效枚举值',
      );
    });

    // ─── 测试 2：止损触发 ─────────────────────────────────────
    test('止损触发：反弹后跌破止损则 exitReason=stopLoss', () async {
      // 设计：V 型反弹（部分回补，close 低于 TP1）触发信号，
      // 信号触发后行情再次下跌击穿止损。
      final klines = <KlineData>[];
      final baseTime = DateTime(2025, 3, 15, 0, 0);

      // 平稳段（warm-up，窄幅波动确保 ATR 小）
      for (int i = 0; i < 20; i++) {
        final open = i == 0 ? 100.0 : klines[i - 1].close;
        final close = open;
        klines.add(KlineData(
          time: baseTime.add(Duration(minutes: 15 * i)),
          open: open,
          high: open + 0.4,
          low: open - 0.3,
          close: close,
          volume: 100.0,
        ));
      }

      // 急跌 3 根（swingHigh → swingLow）
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 20)),
        open: 100.0, high: 101.0, low: 94.0, close: 95.0, volume: 200.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 21)),
        open: 95.0, high: 96.0, low: 83.0, close: 85.0, volume: 220.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 22)),
        open: 85.0, high: 86.0, low: 74.0, close: 75.0, volume: 250.0,
      ));

      // 部分反弹（2 根，close 低于 TP1）
      // TP1 ≈ 74 + (101-74)*0.618 ≈ 90.7
      // close=88 → recoveryRatio=(88-75)/(101-74)=13/27=0.48 → < 0.5，不够！
      // 需要 recoveryRatio >= 0.5：
      // close_min = 75 + 0.5*27 = 88.5，取 close=89
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 23)),
        open: 75.0, high: 84.0, low: 77.0, close: 83.0, volume: 280.0,
      ));
      // 第二根反弹 bar：close=89，满足 recoveryRatio >= 0.5
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 24)),
        open: 83.0, high: 90.0, low: 81.0, close: 89.0, volume: 300.0,
      ));

      // 信号在 bar 24 close 触发，引擎在 bar 25 open 进场。
      // Entry ~89，TP1≈90.7，TP2=101，stopLoss≈74-0.3*atr≈74-0.3*1≈73.7
      // 现在加入下跌段击穿 stopLoss：
      for (final p in [85.0, 80.0, 72.0, 65.0, 58.0]) {
        final prev = klines.last;
        final idx = klines.length;
        klines.add(KlineData(
          time: baseTime.add(Duration(minutes: 15 * idx)),
          open: prev.close,
          high: prev.close + 1.0,
          low: p - 1.5, // low 低于 stopLoss
          close: p,
          volume: 200.0,
        ));
      }

      final params = ReboundParams();
      final report = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: defaultConfig.copyWith(maxHoldBars: 50),
        klines: klines,
      );

      final stopLossTrades =
          report.trades.where((t) => t.exitReason == 'stopLoss').toList();
      expect(stopLossTrades.isNotEmpty, isTrue,
          reason: '反弹后再次下跌应触发止损退出。trades=${report.trades.map((t) => '${t.exitReason}').toList()}');
    });

    // ─── 测试 3：下一根开盘进场 ───────────────────────────────
    test('下一根开盘进场：entryTime 是 signal 后下一根 bar 的时间', () async {
      final klines = vShapedQuickRecovery();
      final params = ReboundParams();

      final report = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: defaultConfig,
        klines: klines,
      );

      expect(report.trades.isNotEmpty, isTrue,
          reason: 'V 型走势应触发交易');

      for (final trade in report.trades) {
        final entryIndex =
            klines.indexWhere((k) => k.time == trade.entryTime);
        expect(entryIndex, greaterThanOrEqualTo(0),
            reason: '进场时间必须在 K 线序列中存在');

        if (entryIndex >= 0 && entryIndex < klines.length) {
          expect(trade.entryPrice, closeTo(klines[entryIndex].open, 0.01),
              reason: '进场价格应为该 bar 的 open');
        }
      }
    });

    // ─── 测试 4：不叠加仓位 ───────────────────────────────────
    test('不叠加仓位：连续信号不叠加第二个仓位', () async {
      // 构造两段 V 型模式，验证仓位不重叠。
      final klines = <KlineData>[];
      final baseTime = DateTime(2025, 3, 15, 0, 0);

      // 平稳段（warm-up）
      for (int i = 0; i < 20; i++) {
        final price = 100.0 + i * 0.01;
        klines.add(KlineData(
          time: baseTime.add(Duration(minutes: 15 * i)),
          open: price, high: price + 0.4, low: price - 0.3,
          close: price, volume: 100.0,
        ));
      }

      // 第一段 V 型：急跌 + 急弹
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 20)),
        open: 100.2, high: 101.0, low: 94.0, close: 95.0, volume: 200.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 21)),
        open: 95.0, high: 96.0, low: 83.0, close: 85.0, volume: 220.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 22)),
        open: 85.0, high: 86.0, low: 74.0, close: 75.0, volume: 250.0,
      ));
      // 反弹
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 23)),
        open: 75.0, high: 84.0, low: 77.0, close: 83.0, volume: 280.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 24)),
        open: 83.0, high: 90.0, low: 81.0, close: 89.0, volume: 300.0,
      ));

      // 第一段 V 型结束后稳定上涨（巩固反弹）
      var price = 89.0;
      for (int i = 25; i < 45; i++) {
        price += 0.3;
        klines.add(KlineData(
          time: baseTime.add(Duration(minutes: 15 * i)),
          open: klines.last.close, high: price + 0.4,
          low: price - 0.3, close: price, volume: 100.0,
        ));
      }

      // 第二段 V 型：急跌 + 急弹（紧接着）
      final secondDropStart = klines.last.close; // ~95
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 45)),
        open: secondDropStart, high: secondDropStart + 1.0,
        low: 90.0, close: 91.0, volume: 200.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 46)),
        open: 91.0, high: 91.5, low: 82.0, close: 84.0, volume: 220.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 47)),
        open: 84.0, high: 85.0, low: 73.0, close: 74.0, volume: 250.0,
      ));
      // 反弹
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 48)),
        open: 74.0, high: 82.0, low: 76.0, close: 80.0, volume: 280.0,
      ));
      klines.add(KlineData(
        time: baseTime.add(Duration(minutes: 15 * 49)),
        open: 80.0, high: 88.0, low: 78.0, close: 87.0, volume: 300.0,
      ));
      // 延续
      price = 87.0;
      for (int i = 50; i < 70; i++) {
        price += 0.2;
        klines.add(KlineData(
          time: baseTime.add(Duration(minutes: 15 * i)),
          open: klines.last.close, high: price + 0.3,
          low: price - 0.2, close: price, volume: 100.0,
        ));
      }

      final params = ReboundParams();
      final report = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: defaultConfig.copyWith(maxHoldBars: 50),
        klines: klines,
      );

      expect(report.trades.isNotEmpty, isTrue,
          reason: '应至少产生一笔交易。trades=${report.trades.length}');

      // 验证无重叠仓位：同一 time 进场的交易来自同一仓位（分批退出），
      // 不同进场的交易不应重叠（prev.exitTime <= next.entryTime）。
      for (int i = 0; i < report.trades.length - 1; i++) {
        for (int j = i + 1; j < report.trades.length; j++) {
          final a = report.trades[i];
          final b = report.trades[j];
          // 同进场时间 = 同仓位，跳过
          if (a.entryTime == b.entryTime) continue;
          if (a.exitTime != null && b.entryTime != null &&
              b.entryTime.isBefore(a.exitTime!)) {
            fail('仓位重叠：交易 $i（进场 ${a.entryTime} 退出 ${a.exitTime}）'
                '与交易 $j（进场 ${b.entryTime}）重叠');
          }
        }
      }
    });
  });
}
