import 'package:drift/drift.dart';

part 'drift_database.g.dart';

/// Phase 1：drift 管理的类型安全持久化表（K 线 + 回测）。
///
/// 这三张表由 drift 定义、由 build_runner 生成类型安全 DAO，供 Phase 3（监控信号写入）
/// 与 Phase 6（回测历史读取）使用。与既有 sqflite 表（PumpHistory / futures_symbols）
/// 共存于同一 SQLite 文件（per ARCHITECTURE.md）。
///
/// 表名（Klines / BacktestRuns / BacktestTrades）与 [DatabaseHelper] 的 raw SQL 建表
/// 名称保持一致，确保 drift 与 sqflite 两条路径指向同一物理表。

/// K 线持久化。复合主键 (symbol, interval, openTime) 保证同币同周期同开盘时间唯一。
class Klines extends Table {
  TextColumn get symbol => text()();
  TextColumn get interval => text()();
  IntColumn get openTime => integer()();
  RealColumn get open => real()();
  RealColumn get high => real()();
  RealColumn get low => real()();
  RealColumn get close => real()();
  RealColumn get volume => real()();
  IntColumn get closeTime => integer()();

  @override
  Set<Column> get primaryKey => {symbol, interval, openTime};
}

/// 回测运行记录。params/stats 以 JSON 文本存储（Phase 6 填充）。
class BacktestRuns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get params => text()();
  IntColumn get startedAt => integer()();
  TextColumn get stats => text().nullable()();
}

/// 回测成交明细。runId 外键引用 [BacktestRuns]，删除 run 时级联删除其 trades。
class BacktestTrades extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get runId =>
      integer().references(BacktestRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get symbol => text()();
  IntColumn get entryTime => integer()();
  RealColumn get entryPrice => real()();
  IntColumn get exitTime => integer().nullable()();
  RealColumn get exitPrice => real().nullable()();
  TextColumn get side => text()();
  RealColumn get pnl => real()();
  RealColumn get rMultiple => real()();
}

/// App 级 drift 数据库，包含三张表。
/// 继承生成的 _$AppDatabase（提供 klines / backtestRuns / backtestTrades 表 getter）。
@DriftDatabase(tables: [Klines, BacktestRuns, BacktestTrades])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
