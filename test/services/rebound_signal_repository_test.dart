import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/database_helper.dart';
import 'package:tomapp/services/rebound/rebound_signal_repository.dart';

ReboundSignal _sig(String sym, {int score = 80, String tf = '15m'}) =>
    ReboundSignal(
      symbol: sym,
      timeframe: tf,
      dropMagnitude: 2.5,
      recoveryRatio: 0.7,
      speed: 2,
      confluenceFilters: const {},
      score: score,
      deadCatRiskScore: 20,
      entryPrice: 98,
      swingLowPrice: 89,
      swingHighPrice: 100,
      dropStartIndex: 10,
      dropEndIndex: 12,
      recoveryEndIndex: 14,
      isLatestBar: true,
      timestamp: DateTime(2024, 1, 1, 9, 30),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper helper;
  late ReboundSignalRepository repo;

  setUp(() async {
    helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    await helper.database; // 触发 onCreate（v6 含 rebound_signals 表）
    repo = ReboundSignalRepository(helper);
  });

  tearDown(() async => helper.close());

  group('ReboundSignalRepository', () {
    test('upsert 写入 + queryListed 读回', () async {
      await repo.upsert(_sig('BTCUSDT', score: 85));
      final listed = await repo.queryListed(70, 50);
      expect(listed, hasLength(1));
      expect(listed.first.symbol, 'BTCUSDT');
      expect(listed.first.score, 85);
      expect(listed.first.timeframe, '15m');
    });

    test('queryListed minScore 过滤：仅返回 ≥ minScore', () async {
      await repo.upsert(_sig('A', score: 90));
      await repo.upsert(_sig('B', score: 70));
      await repo.upsert(_sig('C', score: 69));
      final listed = await repo.queryListed(70, 50);
      expect(listed.length, 2);
      expect(listed.map((s) => s.score).toList()..sort(), [70, 90]);
    });

    test('upsert 同 (symbol,tf) 覆盖', () async {
      await repo.upsert(_sig('BTCUSDT', score: 80));
      await repo.upsert(_sig('BTCUSDT', score: 90));
      final listed = await repo.queryListed(0, 50);
      expect(listed, hasLength(1));
      expect(listed.first.score, 90);
    });

    test('delete 移除指定 (symbol,tf)', () async {
      await repo.upsert(_sig('BTCUSDT'));
      await repo.delete('BTCUSDT', '15m');
      expect(await repo.queryListed(0, 50), isEmpty);
    });

    test('isLatestBar=false 写入读回仍 false', () async {
      final sig = _sig('BTCUSDT').copyWith(isLatestBar: false);
      await repo.upsert(sig);
      final listed = await repo.queryListed(0, 50);
      expect(listed.firstWhere((s) => s.symbol == 'BTCUSDT').isLatestBar, false);
    });
  });
}
