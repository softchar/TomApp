import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tomapp/services/database_helper.dart';

/// Phase 1 / BLOCKER 2：验证 DatabaseHelper 的 onCreate（全新安装）与
/// onUpgrade(oldVersion<4)（升级）两条路径都创建 drift 三表，并对既有表零回归。

Future<Set<String>> _tableNames(Database db) async {
  final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'android_%' AND name NOT LIKE 'sqlite_%'");
  return rows.map((r) => r['name'] as String).toSet();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('fresh-install (onCreate) 创建 drift 三表 + 既有表零回归', () async {
    final helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final db = await helper.database; // 触发 onCreate (version 4)
    final names = await _tableNames(db);

    // BLOCKER 2 核心验收：drift 三表在全新安装路径上都被创建
    expect(names, containsAll(['klines', 'backtest_runs', 'backtest_trades']));
    // 既有表仍存在（零回归）
    expect(names, containsAll(['PumpHistory', 'futures_symbols']));
    await db.close();
  });

  test('upgrade 路径 (v3 → v4) 也创建 drift 三表', () async {
    final tmpDir = await Directory.systemTemp.createTemp('tomapp_upgrade_');
    final path = p.join(tmpDir.path, 'upgrade.db');

    // 1) 初始 v3 库（只建 PumpHistory，模拟旧版本）
    final v3 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, v) async {
          await db.execute(
              'CREATE TABLE PumpHistory (id INTEGER PRIMARY KEY AUTOINCREMENT)');
        },
      ),
    );
    await v3.close();

    // 2) 以 v4 helper 打开同一路径 → onUpgrade(3→4) 触发 drift 三表建表
    final helper = DatabaseHelper.forTesting(path);
    final db = await helper.database;
    final names = await _tableNames(db);

    expect(names, containsAll(['klines', 'backtest_runs', 'backtest_trades']),
        reason: '升级路径 oldVersion<4 必须建 drift 三表');
    expect(names, contains('PumpHistory'), reason: '既有表保留');
    await db.close();
    await tmpDir.delete(recursive: true);
  });

  test('CRUD + 外键级联：drift 三表可用且级联生效（FK 开启）', () async {
    final helper = DatabaseHelper.forTesting(inMemoryDatabasePath);
    final db = await helper.database;
    await db.execute('PRAGMA foreign_keys = ON');

    // backtest_runs 插入
    final runId = await db.insert('backtest_runs',
        {'params': '{"period":14}', 'startedAt': 1000, 'stats': null});
    expect(runId, greaterThan(0));

    // backtest_trades 插入（FK→runId）
    await db.insert('backtest_trades', {
      'runId': runId,
      'symbol': 'BTCUSDT',
      'entryTime': 1000,
      'entryPrice': 100.0,
      'side': 'long',
      'pnl': 12.5,
      'rMultiple': 1.5,
    });
    expect((await db.query('backtest_trades')).length, 1);

    // 级联：删除 run → trades 自动删
    await db.delete('backtest_runs', where: 'id = ?', whereArgs: [runId]);
    expect((await db.query('backtest_trades')).length, 0,
        reason: 'ON DELETE CASCADE 应删除关联 trades');

    // klines 复合主键去重（INSERT OR REPLACE）
    await db.insert('klines', {
      'symbol': 'BTCUSDT',
      'interval': '1h',
      'openTime': 5000,
      'open': 100.0,
      'high': 101.0,
      'low': 99.0,
      'close': 100.0,
      'volume': 10.0,
      'closeTime': 6000,
    });
    await db.insert(
      'klines',
      {
        'symbol': 'BTCUSDT',
        'interval': '1h',
        'openTime': 5000,
        'open': 100.0,
        'high': 101.0,
        'low': 99.0,
        'close': 105.0,
        'volume': 10.0,
        'closeTime': 6000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final klinesRows = await db.query('klines');
    expect(klinesRows.length, 1, reason: '主键 (symbol,interval,openTime) 去重');
    expect(klinesRows.first['close'], 105.0);

    await db.close();
  });
}
