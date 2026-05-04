import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const String _databaseName = 'tomapp.db';
  static const int _databaseVersion = 3;
  static int get currentVersion => _databaseVersion;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

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
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
