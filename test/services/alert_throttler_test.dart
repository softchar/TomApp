import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/alert_level.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/rebound/alert_throttler.dart';

/// 测试用 ReboundSignal 工厂函数，最小字段填充。
ReboundSignal _makeSignal({
  String? symbol,
  String? timeframe,
  int? score,
  int? deadCatRiskScore,
}) {
  return ReboundSignal(
    symbol: symbol ?? 'BTCUSDT',
    timeframe: timeframe ?? '15m',
    dropMagnitude: 2.0,
    recoveryRatio: 0.6,
    speed: 2,
    confluenceFilters: {},
    score: score ?? 80,
    deadCatRiskScore: deadCatRiskScore ?? 30,
    entryPrice: 100.0,
    swingLowPrice: 90.0,
    swingHighPrice: 110.0,
    dropStartIndex: 0,
    dropEndIndex: 3,
    recoveryEndIndex: 5,
    timestamp: DateTime.now(),
  );
}

/// 默认测试参数。
const int testHighThreshold = 75;
const int testMedThreshold = 50;
const Map<String, bool> testToggles = {
  '15m': true,
  '1h': true,
  '4h': true,
  '1d': true,
};

void main() {
  late AlertThrottler throttler;

  setUp(() {
    throttler = AlertThrottler();
  });

  tearDown(() {
    throttler.reset();
  });

  group('分级判定 (Classify)', () {
    test('test_classify_high: score=80 deadCat=30 → AlertLevel.high', () {
      final signal = _makeSignal(score: 80, deadCatRiskScore: 30);
      final decision = throttler.evaluate(
        signal,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision, isNotNull);
      expect(decision!.level, AlertLevel.high);
      expect(decision.symbol, 'BTCUSDT');
    });

    test('test_classify_medium: score=60 deadCat=30 → AlertLevel.medium', () {
      final signal = _makeSignal(score: 60, deadCatRiskScore: 30);
      final decision = throttler.evaluate(
        signal,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision, isNotNull);
      expect(decision!.level, AlertLevel.medium);
    });

    test('test_low_returns_null: score=40 → evaluate 返回 null', () {
      final signal = _makeSignal(score: 40, deadCatRiskScore: 30);
      final decision = throttler.evaluate(
        signal,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision, isNull);
    });

    test(
        'test_deadcat_downgrade: score=80 deadCat=60 → 应为 medium（非 high）',
        () {
      final signal = _makeSignal(score: 80, deadCatRiskScore: 60);
      final decision = throttler.evaluate(
        signal,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision, isNotNull);
      expect(decision!.level, AlertLevel.medium);
    });
  });

  group('冷却检查 (Cooldown)', () {
    test('test_cooldown: 同 symbol 相隔调用 → 第二次返回 null', () {
      final signal1 = _makeSignal(symbol: 'BTCUSDT');
      final decision1 = throttler.evaluate(
        signal1,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision1, isNotNull);

      final signal2 = _makeSignal(symbol: 'BTCUSDT');
      final decision2 = throttler.evaluate(
        signal2,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision2, isNull);
    });
  });

  group('周期开关 (Timeframe Toggle)', () {
    test("test_timeframe_toggle_off: '1h' 关闭时 1h 信号返回 null", () {
      final toggles = Map<String, bool>.from(testToggles);
      toggles['1h'] = false;
      final signal = _makeSignal(timeframe: '1h', score: 80);
      final decision = throttler.evaluate(
        signal,
        timeframeToggles: toggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision, isNull);
    });
  });

  group('日上限 (Daily Cap)', () {
    test('test_daily_cap: 前 20 次通过，第 21 次返回 null', () {
      for (int i = 0; i < 20; i++) {
        // 每次用不同 symbol 绕过冷却
        final signal = _makeSignal(symbol: 'SYM${i.toString().padLeft(2, '0')}');
        final decision = throttler.evaluate(
          signal,
          timeframeToggles: testToggles,
          highThreshold: testHighThreshold,
          medThreshold: testMedThreshold,
        );
        expect(decision, isNotNull,
            reason: '第 ${i + 1} 次调用应返回非 null');
      }

      // 第 21 次调用应返回 null
      final signal21 = _makeSignal(symbol: 'SYM20');
      final decision21 = throttler.evaluate(
        signal21,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision21, isNull, reason: '第 21 次调用应返回 null');
    });

    test('test_newday_reset: 跨日重置后恢复正常推送', () {
      // 先打满 20 条
      for (int i = 0; i < 20; i++) {
        final signal = _makeSignal(symbol: 'SYM${i.toString().padLeft(2, '0')}');
        throttler.evaluate(
          signal,
          timeframeToggles: testToggles,
          highThreshold: testHighThreshold,
          medThreshold: testMedThreshold,
        );
      }

      // 第 21 次返回 null（上限）
      final signal21 = _makeSignal(symbol: 'SYM20');
      final decision21 = throttler.evaluate(
        signal21,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision21, isNull);

      // 模拟跨日：注入假日期
      throttler.setDateForTesting('2000-01-01');

      // 跨日后应恢复正常
      final signalNew = _makeSignal(symbol: 'SYM20');
      final decisionNew = throttler.evaluate(
        signalNew,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decisionNew, isNotNull,
          reason: '跨日重置后应返回非 null');
    });
  });

  group('连续K线单一推送 (ALERT-06 UAT)', () {
    test(
        'test_consecutive_candles_single_push: 同 symbol 连续 4 次仅首次通过',
        () {
      // 第 1 次：应通过
      final decision1 = throttler.evaluate(
        _makeSignal(symbol: 'ETHUSDT'),
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision1, isNotNull, reason: '第 1 次调用应通过');

      // 第 2-4 次：应全部返回 null（冷却期内）
      for (int i = 2; i <= 4; i++) {
        final decision = throttler.evaluate(
          _makeSignal(symbol: 'ETHUSDT'),
          timeframeToggles: testToggles,
          highThreshold: testHighThreshold,
          medThreshold: testMedThreshold,
        );
        expect(decision, isNull, reason: '第 $i 次调用应返回 null（冷却期内）');
      }
    });
  });

  group('归并架构预留 (Coalesce Architecture)', () {
    test('test_coalesce_single_tf: 单周期下归并恒跳过，evaluate 正常返回', () {
      // 当前 monitoredTimeframes=['15m'] 单周期，归并逻辑恒不触发
      final signal = _makeSignal(symbol: 'BTCUSDT', timeframe: '15m');
      final decision = throttler.evaluate(
        signal,
        timeframeToggles: testToggles,
        highThreshold: testHighThreshold,
        medThreshold: testMedThreshold,
      );
      expect(decision, isNotNull);
      expect(decision!.level, AlertLevel.high);
      // 单周期下 coalescedTimeframes 恒为 [signal.timeframe]
      expect(decision.coalescedTimeframes, ['15m']);
    });
  });
}
