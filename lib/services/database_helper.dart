import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// 测试专用：注入数据库路径（如 [inMemoryDatabasePath]）以验证 onCreate / onUpgrade 迁移。
  @visibleForTesting
  DatabaseHelper.forTesting(this._dbPath);

  /// 可注入的数据库路径（null 时用默认 getDatabasesPath()/_databaseName）。
  String? _dbPath;

  static const String _databaseName = 'tomapp.db';
  // v4：drift 管理的 klines/backtest_runs/backtest_trades；
  // v5：rebound_notifications（通知历史）；
  // v6：rebound_signals（看板列表信号持久化）。
  static const int _databaseVersion = 6;
  static int get currentVersion => _databaseVersion;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = _dbPath ?? join(await getDatabasesPath(), _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE PumpHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol TEXT NOT NULL,
        basePrice REAL NOT NULL,
        peakPrice REAL NOT NULL,
        priceChange REAL NOT NULL,
        triggerTime INTEGER NOT NULL,
        detectedAt TEXT NOT NULL,
        cooldownMinutes INTEGER NOT NULL,
        strategyType TEXT NOT NULL,
        subsequentLow REAL,
        subsequentLowTime INTEGER,
        pullbackPercent REAL,
        isConfirmed INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_symbol_time ON PumpHistory(symbol, triggerTime DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_trigger_time ON PumpHistory(triggerTime DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_is_confirmed ON PumpHistory(isConfirmed)
    ''');

    await db.execute('''
      CREATE TABLE futures_symbols (
        symbol TEXT PRIMARY KEY,
        base_asset TEXT NOT NULL,
        quote_asset TEXT NOT NULL,
        status TEXT NOT NULL,
        contract_type TEXT NOT NULL,
        onboard_date INTEGER NOT NULL,
        delivery_date INTEGER NOT NULL,
        price_precision INTEGER NOT NULL,
        quantity_precision INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_status ON futures_symbols(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_updated_at ON futures_symbols(updated_at)
    ''');

    // Phase 1 新增：drift 管理的三表（onCreate 全新安装路径，per BLOCKER 2 / D-07）。
    await _createDriftTables(db);

    // v5：反弹通知历史表（onCreate 全新安装路径）。
    await _createReboundNotificationsTable(db);

    // v6：看板列表信号表（onCreate 全新安装路径）。
    await _createReboundSignalsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 创建K线缓存表
      await db.execute('''
        CREATE TABLE kline_cache (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          symbol TEXT NOT NULL,
          interval TEXT NOT NULL,
          data TEXT NOT NULL,
          cached_at INTEGER NOT NULL,
          UNIQUE(symbol, interval)
        )
      ''');
      await db.execute('CREATE INDEX idx_kline_symbol_interval ON kline_cache(symbol, interval)');
    }

    if (oldVersion < 3) {
      // 创建期货合约表
      await db.execute('''
        CREATE TABLE futures_symbols (
          symbol TEXT PRIMARY KEY,
          base_asset TEXT NOT NULL,
          quote_asset TEXT NOT NULL,
          status TEXT NOT NULL,
          contract_type TEXT NOT NULL,
          onboard_date INTEGER NOT NULL,
          delivery_date INTEGER NOT NULL,
          price_precision INTEGER NOT NULL,
          quantity_precision INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_status ON futures_symbols(status)');
      await db.execute('CREATE INDEX idx_updated_at ON futures_symbols(updated_at)');
    }

    if (oldVersion < 4) {
      // Phase 1：drift 管理的三表（onUpgrade 升级路径，per BLOCKER 2）。
      await _createDriftTables(db);
    }

    if (oldVersion < 5) {
      // v5：反弹通知历史表（onUpgrade 升级路径）。
      await _createReboundNotificationsTable(db);
    }

    if (oldVersion < 6) {
      // v6：看板列表信号表（onUpgrade 升级路径）。
      await _createReboundSignalsTable(db);
    }
  }

  /// 创建 drift 管理的三张表（klines / backtest_runs / backtest_trades）。
  ///
  /// onCreate（全新安装）与 onUpgrade(oldVersion<4)（升级）两条路径都调用本方法，
  /// 确保 drift 三表在两条路径都被创建（per BLOCKER 2）。这与既有 kline_cache 仅出现在
  /// onUpgrade 的 pre-existing 不一致不同——drift 三表刻意双路径都建，避免全新安装缺表。
  ///
  /// 表名/列名与 drift 生成的 schema（snake_case 表名）保持一致，使 drift DAO 与
  /// sqflite 原生访问在 Phase 3/6 指向同一物理表（per ARCHITECTURE.md 共存策略）。
  Future<void> _createDriftTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS klines (
        symbol TEXT NOT NULL,
        interval TEXT NOT NULL,
        openTime INTEGER NOT NULL,
        open REAL NOT NULL,
        high REAL NOT NULL,
        low REAL NOT NULL,
        close REAL NOT NULL,
        volume REAL NOT NULL,
        closeTime INTEGER NOT NULL,
        PRIMARY KEY (symbol, interval, openTime)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS backtest_runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        params TEXT NOT NULL,
        startedAt INTEGER NOT NULL,
        stats TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS backtest_trades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runId INTEGER NOT NULL,
        symbol TEXT NOT NULL,
        entryTime INTEGER NOT NULL,
        entryPrice REAL NOT NULL,
        exitTime INTEGER,
        exitPrice REAL,
        side TEXT NOT NULL,
        pnl REAL NOT NULL,
        rMultiple REAL NOT NULL,
        FOREIGN KEY (runId) REFERENCES backtest_runs(id) ON DELETE CASCADE
      )
    ''');
  }

  /// v5：创建反弹通知历史表（onCreate 与 onUpgrade 双路径，与 drift 三表一致）。
  Future<void> _createReboundNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rebound_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        score INTEGER NOT NULL,
        deadCatRiskScore INTEGER NOT NULL,
        dropMagnitude REAL NOT NULL,
        recoveryRatio REAL NOT NULL,
        notifiedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rebound_notified_at
      ON rebound_notifications(notifiedAt DESC)
    ''');
  }

  /// v6：创建看板列表信号表（onCreate 与 onUpgrade 双路径）。
  ///
  /// 持久化 score≥70 的列表信号，app 重启后由 ReboundSignalRepository.queryListed 恢复。
  /// PK 为 (symbol, timeframe)：upsert 覆盖同位置；confluenceFilters 不存（展示不用）。
  Future<void> _createReboundSignalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rebound_signals (
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        score INTEGER NOT NULL,
        deadCatRiskScore INTEGER NOT NULL,
        dropMagnitude REAL NOT NULL,
        recoveryRatio REAL NOT NULL,
        entryPrice REAL NOT NULL,
        swingLowPrice REAL NOT NULL,
        swingHighPrice REAL NOT NULL,
        dropStartIndex INTEGER NOT NULL,
        dropEndIndex INTEGER NOT NULL,
        recoveryEndIndex INTEGER NOT NULL,
        isLatestBar INTEGER NOT NULL,
        klineCloseTime INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        PRIMARY KEY (symbol, timeframe)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_rebound_signals_score
      ON rebound_signals(score DESC)
    ''');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
