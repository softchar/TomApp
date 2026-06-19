import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/drift_database.dart';

/// Phase 1：验证 drift AppDatabase 的三表 DAO 可用（类型安全 CRUD + 外键级联）。
/// 注意：drift 生成的表名为 snake_case（klines / backtest_runs / backtest_trades），
/// 与 DatabaseHelper 的 raw SQL 一致（Phase 3/6 共存指向同一物理表）。

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // SQLite 默认外键关闭，显式开启以验证 ON DELETE CASCADE
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async => await db.close());

  test('klines 复合主键去重（insertOrReplace）', () async {
    await db.into(db.klines).insert(KlinesCompanion.insert(
          symbol: 'BTCUSDT',
          interval: '1h',
          openTime: 5000,
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 10.0,
          closeTime: 6000,
        ));
    // 同主键 insertOrReplace → 覆盖 close
    await db.into(db.klines).insert(
          KlinesCompanion.insert(
            symbol: 'BTCUSDT',
            interval: '1h',
            openTime: 5000,
            open: 100.0,
            high: 101.0,
            low: 99.0,
            close: 105.0,
            volume: 10.0,
            closeTime: 6000,
          ),
          mode: InsertMode.insertOrReplace,
        );
    final rows = await db.select(db.klines).get();
    expect(rows.length, 1, reason: '复合主键 (symbol,interval,openTime) 去重');
    expect(rows.first.close, 105.0);
  });

  test('backtest_runs 自增 id + backtest_trades 外键级联删除', () async {
    final runId = await db.into(db.backtestRuns).insert(
          BacktestRunsCompanion.insert(
            params: '{}',
            startedAt: 1000,
          ),
        );
    expect(runId, greaterThan(0));

    await db.into(db.backtestTrades).insert(
          BacktestTradesCompanion.insert(
            runId: runId,
            symbol: 'BTCUSDT',
            entryTime: 1000,
            entryPrice: 100.0,
            side: 'long',
            pnl: 10.0,
            rMultiple: 1.5,
          ),
        );
    expect((await db.select(db.backtestTrades).get()).length, 1);

    // 级联：删除 run → 关联 trades 自动删除
    await (db.delete(db.backtestRuns)
          ..where((r) => r.id.equals(runId)))
        .go();
    expect((await db.select(db.backtestTrades).get()).length, 0,
        reason: 'ON DELETE CASCADE 应删除关联 trades');
  });
}
