import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const String _databaseName = 'tomapp.db';
  static const int _databaseVersion = 1;
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本升级逻辑
    if (oldVersion < 2) {
      // 添加新字段等
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
