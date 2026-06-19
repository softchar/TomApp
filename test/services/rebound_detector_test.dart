import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/rebound_confluence_scorer.dart';

/// Phase 2 单测：ReboundDetector 三阶段纯函数 + ReboundConfluenceScorer。
/// 全部使用合成 fixture（无网络、无真实数据、无 DateTime.now）。

/// 快速构造 KlineData helper。
KlineData _bar(
  int minute,
  double close, {
  double? high,
  double? low,
  double? open,
  double volume = 10,
}) {
  return KlineData(
    time: DateTime(2024, 1, 1, 0, minute),
    open: open ?? close,
    high: high ?? close + 1,
    low: low ?? close - 1,
    close: close,
    volume: volume,
  );
}

/// 构造一段平稳行情（close=100，high=101，low=99，volume=10）。
List<KlineData> _stableBars(int count, {int startMinute = 0}) {
  return List.generate(count, (i) => _bar(startMinute + i, 100));
}

/// 构造标准 V 型反弹 fixture：
/// stable(20) + drop 3 bars(100→90) + recovery 2 bars(→98, volume=20)
/// 回补 (98-99)/(100-89) ≈ 81%，speed=2，volume 2× → 强信号。
List<KlineData> _vReboundFixture() {
  return [
    ..._stableBars(20),
    // 下跌段：3 根急跌
    _bar(20, 97, high: 100, low: 96, volume: 10),
    _bar(21, 93, high: 97, low: 92, volume: 10),
    _bar(22, 90, high: 93, low: 89, volume: 10),
    // 拉回段：2 根快速回升（volume 放大）
    _bar(23, 99, high: 100, low: 90, volume: 20),
    _bar(24, 98, high: 99, low: 95, volume: 15),
  ];
}

void main() {
  final ti = TechnicalIndicators();
  final detector = ReboundDetector(ti);
  final defaultParams = ReboundParams();

  ReboundSignal? eval(List<KlineData> window,
      {ReboundParams? params, String tf = '1h'}) {
    return detector.evaluate(window, params ?? defaultParams,
        symbol: 'TESTUSDT', timeframe: tf);
  }

  group('ReboundDetector', () {
    // Test 1: V 型反弹完整三阶段通过
    test('V 型反弹：score > 70, recoveryRatio > 0.5, speed ≤ 2, deadCatRisk < 50',
        () {
      final signal = eval(_vReboundFixture());
      expect(signal, isNotNull, reason: 'V 型反弹应产生信号');
      expect(signal!.score, greaterThan(70), reason: '强信号');
      expect(signal.recoveryRatio, greaterThan(0.5));
      expect(signal.speed, lessThanOrEqualTo(2));
      expect(signal.deadCatRiskScore, lessThan(50), reason: '非死猫');
    });

    // Test 2: warm-up 数据不足 → null
    test('warm-up：窗口 < 最小长度 → null，不抛异常', () {
      final short = _stableBars(10);
      final signal = eval(short);
      expect(signal, isNull, reason: '数据不足应返回 null');
    });

    // Test 3: 死猫反弹 — 弱回补刚过阈值但量能弱
    test('死猫反弹：弱回补 + 低量 → score < 50, deadCatRisk > 60', () {
      // 急跌后回补刚好 52%（刚过 50% 阈值），但 volume 低（5）
      final fixture = [
        ..._stableBars(20),
        _bar(20, 97, high: 100, low: 96, volume: 10),
        _bar(21, 93, high: 97, low: 92, volume: 10),
        _bar(22, 90, high: 93, low: 89, volume: 10),
        // 回补刚好过阈值：midpoint=(100+89)/2=94.5, 需 close > 94.5
        // recoveryRatio = (95-89)/(100-89) = 6/11 ≈ 54.5% > 50% ✓
        _bar(23, 95, high: 96, low: 90, volume: 5),
        _bar(24, 95.5, high: 96, low: 95, volume: 5),
      ];
      final signal = eval(fixture);
      expect(signal, isNotNull, reason: '回补过阈值应有信号');
      expect(signal!.score, lessThan(50), reason: '弱信号');
      expect(signal.deadCatRiskScore, greaterThan(60), reason: '高死猫风险');
      expect(signal.confluenceFilters.contains(ConfluenceType.volumeConfirmation),
          isFalse);
    });

    // Test 4: 下跌中继 — 回补不足 → null
    test('下跌中继：回补 < 50% → null（不误触发）', () {
      final fixture = [
        ..._stableBars(20),
        _bar(20, 97, high: 100, low: 96, volume: 10),
        _bar(21, 93, high: 97, low: 92, volume: 10),
        _bar(22, 90, high: 93, low: 89, volume: 10),
        // 回补仅 ~30%：close 92 < midpoint 94.5
        _bar(23, 92, high: 93, low: 90, volume: 10),
        _bar(24, 92.5, high: 93, low: 91, volume: 10),
      ];
      expect(eval(fixture), isNull, reason: '回补不足不应产生信号');
    });

    // Test 5: lookahead 抵御 — 信号仅在收盘后触发
    test('lookahead 抵御：回补 K 线未达阈值时不触发', () {
      // 构造窗口：最后一根 close 未站上 midpoint
      final fixture = [
        ..._stableBars(20),
        _bar(20, 97, high: 100, low: 96, volume: 10),
        _bar(21, 93, high: 97, low: 92, volume: 10),
        _bar(22, 90, high: 93, low: 89, volume: 10),
        // 回补第一根：close=93 < midpoint=94.5（不满足）
        _bar(23, 93, high: 94, low: 90, volume: 15),
        // 到此窗口结束，没有下一根 → null
      ];
      expect(eval(fixture), isNull, reason: '回补未完成不应触发');
    });

    // Test 6: 纯函数幂等 — 同一输入两次调用结果一致
    test('纯函数幂等：同一输入两次 evaluate 结果完全一致', () {
      final window = _vReboundFixture();
      final r1 = eval(window);
      final r2 = eval(window);
      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r1!.score, equals(r2!.score));
      expect(r1.deadCatRiskScore, equals(r2.deadCatRiskScore));
      expect(r1.recoveryRatio, equals(r2.recoveryRatio));
      expect(r1.dropMagnitude, equals(r2.dropMagnitude));
      expect(r1.confluenceFilters, equals(r2.confluenceFilters));
      expect(r1.entryPrice, equals(r2.entryPrice));
    });

    // Test 7: RSI 超卖拐头触发共振过滤
    test('RSI 超卖拐头：confluenceFilters 含 rsiOversoldTurning', () {
      // 先建 15 根急跌（RSI 降至极低），再接 V 型反弹
      final decline = List.generate(15,
          (i) => _bar(i, 100 - i * 1.5, high: 101 - i * 1.5, low: 99 - i * 1.5));
      // decline 结束时 close ≈ 100 - 14*1.5 = 79，RSI 应 < 30
      final fixture = [
        ...decline,
        // 保持低位几根
        _bar(15, 78, high: 79, low: 77, volume: 10),
        _bar(16, 77, high: 78, low: 76, volume: 10),
        _bar(17, 76, high: 77, low: 75, volume: 10),
        // 急跌段（触发 Stage 1 检测）
        _bar(18, 73, high: 76, low: 72, volume: 10),
        _bar(19, 70, high: 73, low: 69, volume: 10),
        // 拉回段（触发 Stage 2 + RSI 拐头）
        _bar(20, 76, high: 77, low: 70, volume: 20),
        _bar(21, 78, high: 79, low: 75, volume: 20),
        _bar(22, 79, high: 80, low: 76, volume: 15),
      ];
      final signal = eval(fixture);
      expect(signal, isNotNull, reason: '应产生反弹信号');
      expect(
          signal!.confluenceFilters
              .contains(ConfluenceType.rsiOversoldTurning),
          isTrue,
          reason: 'RSI 应从超卖拐头向上');
    });

    // Test 8: 放量确认触发 volume 共振
    test('放量确认：confluenceFilters 含 volumeConfirmation', () {
      final fixture = _vReboundFixture(); // recovery volume=20, drop volume=10
      final signal = eval(fixture);
      expect(signal, isNotNull);
      expect(
          signal!.confluenceFilters
              .contains(ConfluenceType.volumeConfirmation),
          isTrue,
          reason: '拉回段 volume 2× → 放量确认');
    });

    // Test 9: 评分范围验证 — 输出在 [0, 100]
    test('评分范围：所有 score 和 deadCatRiskScore 在 [0, 100]', () {
      final scenarios = [
        _vReboundFixture(), // 强反弹
        [
          ..._stableBars(20),
          _bar(20, 97, high: 100, low: 96, volume: 10),
          _bar(21, 93, high: 97, low: 92, volume: 10),
          _bar(22, 90, high: 93, low: 89, volume: 10),
          _bar(23, 95, high: 96, low: 90, volume: 5), // 弱回补
          _bar(24, 95.5, high: 96, low: 94, volume: 5),
        ],
      ];
      for (final fixture in scenarios) {
        final signal = eval(fixture);
        if (signal != null) {
          expect(signal.score, greaterThanOrEqualTo(0),
              reason: 'score >= 0');
          expect(signal.score, lessThanOrEqualTo(100),
              reason: 'score <= 100');
          expect(signal.deadCatRiskScore, greaterThanOrEqualTo(0),
              reason: 'deadCatRisk >= 0');
          expect(signal.deadCatRiskScore, lessThanOrEqualTo(100),
              reason: 'deadCatRisk <= 100');
        }
      }
    });

    // Test 10: ReboundConfluenceScorer 单 TF 返回 0
    test('ConfluenceScorer 单 TF → 0', () {
      final map = {'1h': ReboundSignal(
        symbol: 'TEST', timeframe: '1h', dropMagnitude: 2.5,
        recoveryRatio: 0.7, speed: 2, confluenceFilters: {},
        score: 80, deadCatRiskScore: 20, entryPrice: 98,
        swingLowPrice: 89, swingHighPrice: 100,
        dropStartIndex: 20, dropEndIndex: 22, recoveryEndIndex: 24,
        timestamp: DateTime(2024),
      )};
      expect(ReboundConfluenceScorer.scoreMultiTimeframe(map), 0);
    });

    // Test 11: ReboundConfluenceScorer 多 TF 加分
    test('ConfluenceScorer 3 TF → 10', () {
      ReboundSignal makeSignal(String tf) => ReboundSignal(
        symbol: 'TEST', timeframe: tf, dropMagnitude: 2.5,
        recoveryRatio: 0.7, speed: 2, confluenceFilters: {},
        score: 80, deadCatRiskScore: 20, entryPrice: 98,
        swingLowPrice: 89, swingHighPrice: 100,
        dropStartIndex: 20, dropEndIndex: 22, recoveryEndIndex: 24,
        timestamp: DateTime(2024),
      );
      final map = {
        '15m': makeSignal('15m'),
        '1h': makeSignal('1h'),
        '4h': makeSignal('4h'),
      };
      // (3-1) × 5 = 10
      expect(ReboundConfluenceScorer.scoreMultiTimeframe(map), 10);
    });
  });
}
