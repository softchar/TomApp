import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/services/rebound/backtest_engine.dart';
import 'package:tomapp/services/rebound/trade_simulator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'test_fixtures.dart';

/// Lookahead-Analysis 无偏测试（UAT 硬标准 BACKTEST-06）。
///
/// Freqtrade 风格：将每根 bar[t].close 替换为 bar[t+1].open（故意注入未来信息），
/// 若引擎正确杜绝前视偏差，两次回测的信号触发时间和数量应完全不变。
/// 若结果变化——说明引擎存在 lookahead bias。
void main() {
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
    config = BacktestConfig(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 12, 31),
      symbols: const ['TESTUSDT'],
      costsEnabled: false,
      maxHoldBars: 50,
    );
  });

  /// 构造偏差数据：bar[t].close = bar[t+1].open（注入未来信息）。
  /// 最后一根 bar 的 close 保持不变，也不参与信号比较。
  List<KlineData> _makeBiasedData(List<KlineData> original) {
    final biased = List<KlineData>.from(original);
    for (int i = 0; i < biased.length - 1; i++) {
      biased[i] = biased[i].copyWith(close: biased[i + 1].open);
    }
    return biased;
  }

  group('Lookahead-Analysis', () {
    // ─── 测试 1：500 根合成 K 线信号触发一致 ─────────────────
    test('500 根合成 K 线 close→nextOpen 替换后信号触发一致', () async {
      final originalData = syntheticKlines(500, startPrice: 100.0);
      final biasedData = _makeBiasedData(originalData);

      // 使用宽松参数确保至少触发一些信号（测试有意义）
      final params = ReboundParams.looseForTesting;

      final originalReport = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: config,
        klines: originalData,
      );

      final biasedReport = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: config,
        klines: biasedData,
      );

      // 确保测试有意义——原始数据至少触发 1 笔交易
      expect(originalReport.trades.length, greaterThanOrEqualTo(1),
          reason: '合成数据应至少触发 1 笔反弹信号（若为 0 则测试无意义）');

      // 核心断言：信号数量一致
      expect(
        originalReport.trades.length,
        equals(biasedReport.trades.length),
        reason: 'lookahead 偏差数据应产生相同数量的交易。'
            'original=${originalReport.trades.length}, biased=${biasedReport.trades.length}',
      );

      // 逐笔比较进场时间
      for (int i = 0; i < originalReport.trades.length; i++) {
        final orig = originalReport.trades[i];
        final bias = biasedReport.trades[i];

        expect(
          orig.entryTime,
          equals(bias.entryTime),
          reason: '第 $i 笔交易的进场时间应一致。'
              'original=${orig.entryTime}, biased=${bias.entryTime}',
        );

        // R 倍数也应对等
        expect(
          orig.rMultiple,
          closeTo(bias.rMultiple, 0.01),
          reason: '第 $i 笔交易的 R 倍数应一致。'
              'original=${orig.rMultiple}, biased=${bias.rMultiple}',
        );
      }
    });

    // ─── 测试 2：V 型走势 close 替换后评分一致 ───────────────
    test('V 型走势 close 替换后评分一致', () async {
      final originalData = vShapedQuickRecovery();
      final biasedData = _makeBiasedData(originalData);

      final params = ReboundParams();

      final originalReport = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: config,
        klines: originalData,
      );

      final biasedReport = await engine.runBacktestOnKlines(
        symbol: 'TESTUSDT',
        interval: '15m',
        params: params,
        config: config,
        klines: biasedData,
      );

      // V 型走势应至少触发 1 笔交易
      expect(originalReport.trades.isNotEmpty, isTrue,
          reason: 'V 型走势原始数据应触发交易');
      expect(biasedReport.trades.isNotEmpty, isTrue,
          reason: 'V 型走势偏差数据应触发交易');

      // 交易数量一致
      expect(
        originalReport.trades.length,
        equals(biasedReport.trades.length),
        reason: '交易数量应一致',
      );

      // 比较每笔交易的进场时间和 R 倍数
      for (int i = 0; i < originalReport.trades.length; i++) {
        final orig = originalReport.trades[i];
        final bias = biasedReport.trades[i];

        expect(orig.entryTime, equals(bias.entryTime),
            reason: '信号进场时间应一致');
        expect(orig.rMultiple, closeTo(bias.rMultiple, 0.05),
            reason: 'R 倍数应一致');
        expect(orig.exitReason, equals(bias.exitReason),
            reason: '退出原因应一致');
      }
    });
  });
}
