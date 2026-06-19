import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/providers/rebound_score_provider.dart';

/// Phase 3 / D-05/D-11：ReboundScoreProvider ChangeNotifier 测试。

ReboundSignal _signal(String symbol, String tf, {int score = 80}) {
  return ReboundSignal(
    symbol: symbol,
    timeframe: tf,
    dropMagnitude: 2.5,
    recoveryRatio: 0.7,
    speed: 2,
    confluenceFilters: {},
    score: score,
    deadCatRiskScore: 20,
    entryPrice: 98,
    swingLowPrice: 89,
    swingHighPrice: 100,
    dropStartIndex: 10,
    dropEndIndex: 12,
    recoveryEndIndex: 14,
    timestamp: DateTime(2024),
  );
}

void main() {
  late ReboundScoreProvider provider;
  late int notifyCount;

  setUp(() {
    provider = ReboundScoreProvider();
    notifyCount = 0;
    provider.addListener(() => notifyCount++);
  });

  tearDown(() {
    provider.dispose();
  });

  group('ReboundScoreProvider', () {
    test('upsert 存储信号并触发 notifyListeners', () {
      final signal = _signal('BTCUSDT', '1h');
      provider.upsert('BTCUSDT', '1h', signal);
      expect(provider.getSignal('BTCUSDT', '1h'), equals(signal));
      expect(notifyCount, 1);
    });

    test('upsert null 信号清除指定位置', () {
      provider.upsert('BTCUSDT', '1h', _signal('BTCUSDT', '1h'));
      provider.upsert('BTCUSDT', '1h', null);
      expect(provider.getSignal('BTCUSDT', '1h'), isNull);
      expect(notifyCount, 2);
    });

    test('upsertBatch 单次 notifyListeners', () {
      final batch = {
        'BTCUSDT': {'1h': _signal('BTCUSDT', '1h', score: 85)},
        'ETHUSDT': {'1h': _signal('ETHUSDT', '1h', score: 70)},
      };
      provider.upsertBatch(batch);
      expect(provider.getSignal('BTCUSDT', '1h')!.score, 85);
      expect(provider.getSignal('ETHUSDT', '1h')!.score, 70);
      expect(notifyCount, 1, reason: '批量更新仅触发一次通知');
    });

    test('getSignalsForTimeframe 按 score 降序', () {
      provider.upsert('A', '1h', _signal('A', '1h', score: 60));
      provider.upsert('B', '1h', _signal('B', '1h', score: 90));
      provider.upsert('C', '1h', _signal('C', '1h', score: 75));
      provider.upsert('D', '4h', _signal('D', '4h', score: 99));
      final result = provider.getSignalsForTimeframe('1h');
      expect(result.length, 3);
      expect(result[0].score, 90);
      expect(result[1].score, 75);
      expect(result[2].score, 60);
    });

    test('removeSymbol 清除指定 symbol 所有信号', () {
      provider.upsert('BTCUSDT', '1h', _signal('BTCUSDT', '1h'));
      provider.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m'));
      provider.upsert('ETHUSDT', '1h', _signal('ETHUSDT', '1h'));
      provider.removeSymbol('BTCUSDT');
      expect(provider.getSignal('BTCUSDT', '1h'), isNull);
      expect(provider.getSignal('BTCUSDT', '15m'), isNull);
      expect(provider.getSignal('ETHUSDT', '1h'), isNotNull);
      expect(notifyCount, 4); // 3 upsert + 1 remove
    });

    test('clear 清空所有信号', () {
      provider.upsert('A', '1h', _signal('A', '1h'));
      provider.upsert('B', '1h', _signal('B', '1h'));
      provider.clear();
      expect(provider.signalsBySymbol, isEmpty);
      expect(provider.activeSymbols, isEmpty);
    });
  });

  group('recentCloses（sparkline 数据流）', () {
    test('upsert 传 recentCloses 后 getRecentCloses 可获取', () {
      provider.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m'),
          recentCloses: [99.0, 100.0, 101.0]);
      final closes = provider.getRecentCloses('BTCUSDT', '15m');
      expect(closes, isNotNull);
      expect(closes, [99.0, 100.0, 101.0]);
    });

    test('不传 recentCloses 时 getRecentCloses 返回 null（向后兼容）', () {
      provider.upsert('ETHUSDT', '1h', _signal('ETHUSDT', '1h'));
      final closes = provider.getRecentCloses('ETHUSDT', '1h');
      expect(closes, isNull);
    });

    test('多次 upsert 同一 symbol+tf，最近收盘价被最新值覆盖', () {
      provider.upsert('BTCUSDT', '1h', _signal('BTCUSDT', '1h'),
          recentCloses: [100.0, 101.0]);
      provider.upsert('BTCUSDT', '1h', _signal('BTCUSDT', '1h', score: 90),
          recentCloses: [200.0, 201.0, 202.0]);
      final closes = provider.getRecentCloses('BTCUSDT', '1h');
      expect(closes, [200.0, 201.0, 202.0]);
      // 信号本身也被更新
      expect(provider.getSignal('BTCUSDT', '1h')!.score, 90);
    });

    test('removeSymbol 也清除对应 recentCloses', () {
      provider.upsert('BTCUSDT', '1h', _signal('BTCUSDT', '1h'),
          recentCloses: [100.0, 101.0]);
      provider.removeSymbol('BTCUSDT');
      expect(provider.getRecentCloses('BTCUSDT', '1h'), isNull);
    });

    test('clear 也清除所有 recentCloses', () {
      provider.upsert('A', '1h', _signal('A', '1h'),
          recentCloses: [100.0]);
      provider.upsert('B', '4h', _signal('B', '4h'),
          recentCloses: [200.0]);
      provider.clear();
      expect(provider.getRecentCloses('A', '1h'), isNull);
      expect(provider.getRecentCloses('B', '4h'), isNull);
    });
  });
}
