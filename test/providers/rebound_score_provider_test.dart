import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/rebound_notification_record.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/providers/rebound_score_provider.dart';
import 'package:tomapp/services/rebound/rebound_signal_repository.dart';

/// Phase 3 / D-05/D-11：ReboundScoreProvider ChangeNotifier 测试。

ReboundSignal _signal(String symbol, String tf,
    {int score = 80, DateTime? timestamp}) {
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
    timestamp: timestamp ?? DateTime(2024),
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

    test('getSignalsForTimeframe 按时间降序（最新在上），时间戳优先于 score', () {
      provider.upsert('OLD', '1h',
          _signal('OLD', '1h', score: 90, timestamp: DateTime(2024, 1, 1, 9)));
      provider.upsert('MID', '1h',
          _signal('MID', '1h', score: 60, timestamp: DateTime(2024, 1, 1, 10)));
      provider.upsert('NEW', '1h',
          _signal('NEW', '1h', score: 75, timestamp: DateTime(2024, 1, 1, 11)));
      provider.upsert('D', '4h',
          _signal('D', '4h', score: 99, timestamp: DateTime(2024, 1, 1, 12)));
      final result = provider.getSignalsForTimeframe('1h');
      expect(result.length, 3);
      expect(result[0].symbol, 'NEW', reason: '最新时间戳在最前，即使 score 不是最高');
      expect(result[1].symbol, 'MID');
      expect(result[2].symbol, 'OLD', reason: '最早时间戳在最后，即使 score 最高');
    });

    test('getSignalsForTimeframe 同收盘时间按 score 降序兜底', () {
      // 同时间戳（默认 DateTime(2024)）→ 走 score 兜底排序。
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

    test('getSignalsForTimeframe minScore 过滤：仅返回 ≥ minScore', () {
      provider.upsert('A', '1h', _signal('A', '1h', score: 60));
      provider.upsert('B', '1h', _signal('B', '1h', score: 90));
      provider.upsert('C', '1h', _signal('C', '1h', score: 70));
      provider.upsert('D', '1h', _signal('D', '1h', score: 69));
      final result = provider.getSignalsForTimeframe('1h', minScore: 70);
      expect(result.length, 2, reason: '60 和 69 应被过滤');
      expect(result[0].score, 90);
      expect(result[1].score, 70);
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

  group('扫描状态字段 (04-03)', () {
    test('默认值：scanRound=0, trackedCount=0, lastScanTime=null', () {
      final p = ReboundScoreProvider();
      expect(p.scanRound, 0);
      expect(p.trackedCount, 0);
      expect(p.lastScanTime, isNull);
      p.dispose();
    });

    test('updateScanState 更新字段并触发 notifyListeners', () {
      final p = ReboundScoreProvider();
      int n = 0;
      p.addListener(() => n++);
      final now = DateTime(2024, 6, 20, 12, 30);
      p.updateScanState(round: 5, trackedCount: 12, lastScanTime: now);
      expect(p.scanRound, 5);
      expect(p.trackedCount, 12);
      expect(p.lastScanTime, now);
      expect(n, 1, reason: '应触发一次 notifyListeners');
      p.dispose();
    });

    test('updateScanState lastScanTime 为 null 时保留旧值', () {
      final p = ReboundScoreProvider();
      final t1 = DateTime(2024, 6, 20, 12);
      p.updateScanState(round: 1, trackedCount: 3, lastScanTime: t1);
      // 再次更新不传 lastScanTime → 保留旧值
      p.updateScanState(round: 2, trackedCount: 5, lastScanTime: null);
      expect(p.scanRound, 2);
      expect(p.trackedCount, 5);
      expect(p.lastScanTime, t1, reason: 'null 应保留旧值');
      p.dispose();
    });
  });

  group('通知历史', () {
    test('addNotificationHistory 插入头部并裁剪到上限', () {
      for (var i = 0; i < 55; i++) {
        provider.addNotificationHistory(_notifRecord('SYM$i'));
      }
      expect(provider.notificationHistory.length, 50);
      expect(provider.notificationHistory.first.symbol, 'SYM54',
          reason: '最新在前');
    });

    test('loadNotificationHistory 从 loader 加载并清空旧值', () async {
      provider.addNotificationHistory(_notifRecord('OLD'));
      await provider.loadNotificationHistory(
          (limit) async => [_notifRecord('BTC'), _notifRecord('ETH')]);
      expect(provider.notificationHistory.length, 2);
      expect(provider.notificationHistory.first.symbol, 'BTC');
    });
  });

  group('列表信号持久化', () {
    test('upsert(persist:true) 写库', () {
      final repo = _FakeSignalRepo();
      final p = ReboundScoreProvider(signalRepository: repo);
      p.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m', score: 85),
          persist: true);
      expect(repo.inserted, hasLength(1));
      p.dispose();
    });

    test('upsert(persist:false) 不写库', () {
      final repo = _FakeSignalRepo();
      final p = ReboundScoreProvider(signalRepository: repo);
      p.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m'), persist: false);
      expect(repo.inserted, isEmpty);
      p.dispose();
    });

    test('upsert null 信号（persist:true）触发 delete', () async {
      final repo = _FakeSignalRepo();
      final p = ReboundScoreProvider(signalRepository: repo);
      p.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m'), persist: true);
      p.upsert('BTCUSDT', '15m', null, persist: true);
      await Future<void>.delayed(Duration.zero);
      expect(repo.deleted, hasLength(1));
      p.dispose();
    });

    test('upsert null 信号（persist:false）不删库（5秒重评估路径）', () async {
      final repo = _FakeSignalRepo();
      final p = ReboundScoreProvider(signalRepository: repo);
      p.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m'), persist: true);
      p.upsert('BTCUSDT', '15m', null, persist: false);
      await Future<void>.delayed(Duration.zero);
      expect(repo.deleted, isEmpty,
          reason: 'partial 评估的 null 不应删库，避免信号凭空消失');
      p.dispose();
    });

    test('loadSignals 从 loader 恢复信号', () async {
      final p = ReboundScoreProvider();
      await p.loadSignals((_, __) async => [
            _signal('BTC', '15m', score: 80),
            _signal('ETH', '15m', score: 75),
          ]);
      expect(p.getSignal('BTC', '15m'), isNotNull);
      expect(p.getSignal('ETH', '15m'), isNotNull);
      p.dispose();
    });
  });

  group('onSignalListed 跃迁回调', () {
    ReboundSignal s(int score) => _signal('X', '15m', score: score);

    test('null → ≥70 触发', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', s(72));
      expect(listed, hasLength(1));
      expect(listed.first.score, 72);
      p.dispose();
    });

    test('<70 → ≥70 触发（仅跨越那次）', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', s(60));
      p.upsert('X', '15m', s(75));
      expect(listed, hasLength(1));
      p.dispose();
    });

    test('≥70 → ≥70 不触发（已在列表）', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', s(72));
      p.upsert('X', '15m', s(80));
      expect(listed, hasLength(1));
      p.dispose();
    });

    test('<70 不触发', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', s(60));
      expect(listed, isEmpty);
      p.dispose();
    });
  });
}

ReboundNotificationRecord _notifRecord(String sym, {int score = 80}) =>
    ReboundNotificationRecord(
      symbol: sym,
      timeframe: '15m',
      score: score,
      deadCatRiskScore: 10,
      dropMagnitude: 3.0,
      recoveryRatio: 0.7,
      notifiedAt: DateTime(2024),
    );

class _FakeSignalRepo implements ReboundSignalRepositoryInterface {
  final List<ReboundSignal> inserted = [];
  final List<String> deleted = [];
  @override
  Future<void> upsert(ReboundSignal s) async => inserted.add(s);
  @override
  Future<void> delete(String symbol, String timeframe) async =>
      deleted.add('$symbol:$timeframe');
  @override
  Future<List<ReboundSignal>> queryListed(int minScore, int limit) async => [];
}
