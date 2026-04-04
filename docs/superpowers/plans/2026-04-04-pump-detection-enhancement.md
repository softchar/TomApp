# 快速上涨检测功能增强 - 实施计划 v1.1

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增强快速上涨检测功能，添加本地数据库存储、智能监控策略、数据分析和优化的 UI/UX

**Architecture:** 渐进式增强架构 - 在现有代码基础上添加新组件，保留稳定功能，使用 SQLite 持久化 + Provider 状态管理

**Tech Stack:** Flutter, Dart, sqflite, provider, shared_preferences, fl_chart

**变更日志:**
- v1.1: 添加 RepositoryFactory，调整任务顺序（TDD），修复导入问题，拆分大任务

---

## 阶段 0：依赖更新

### Task 1: 更新 pubspec.yaml 添加新依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 sqflite 和 fl_chart 依赖**

在 `dependencies:` 部分添加：

```yaml
  sqflite: ^2.3.0
  path: ^1.8.0
  fl_chart: ^0.65.0
```

完整文件应包含：

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  intl: ^0.18.1
  provider: ^6.1.0
  shared_preferences: ^2.2.2
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.4
  web_socket_channel: ^2.4.0
  flutter_background_service: ^5.0.10
  sqflite: ^2.3.0
  path: ^1.8.0
  fl_chart: ^0.65.0
```

- [ ] **Step 2: 运行 flutter pub get**

```bash
flutter pub get
```

Expected: `Got dependencies!` 或类似输出

- [ ] **Step 3: 验证并提交**

```bash
flutter analyze
git add pubspec.yaml pubspec.lock
git commit -m "chore: add sqflite, path, and fl_chart dependencies"
git log -1 --stat
```

Expected: Commit shows 2 files changed

---

## 阶段 1：基础设施

### Task 2: 创建 PumpHistoryModel 数据模型

**Prerequisites:** Task 1 must be completed

**Files:**
- Create: `lib/models/pump_history_model.dart`
- Create: `test/models/pump_history_model_test.dart`

- [ ] **Step 1: 先写测试 (TDD)**

创建 `test/models/pump_history_model_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/models/pump_model.dart';

void main() {
  group('PumpHistoryModel', () {
    test('fromPumpModel creates correct model', () {
      final pump = PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 2.3,
        triggerTime: DateTime(2026, 4, 4, 12, 0),
        currentPrice: 66500.0,
      );

      final history = PumpHistoryModel.fromPumpModel(
        pump,
        strategyType: 'Test',
      );

      expect(history.symbol, 'BTCUSDT');
      expect(history.priceChange, 2.3);
      expect(history.strategyType, 'Test');
      expect(history.isConfirmed, 0);
    });

    test('toMap and fromMap are symmetric', () {
      final original = PumpHistoryModel(
        id: 1,
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: 1712224000000,
        detectedAt: '2026-04-04T12:00:00.000Z',
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      final map = original.toMap();
      final restored = PumpHistoryModel.fromMap(map);

      expect(restored.symbol, original.symbol);
      expect(restored.priceChange, original.priceChange);
    });

    test('isConfirmed returns correct bool', () {
      final confirmed = PumpHistoryModel(
        id: 1,
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: 1712224000000,
        detectedAt: '2026-04-04T12:00:00.000Z',
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 1,
      );

      expect(confirmed.confirmed, true);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/models/pump_history_model_test.dart
```

Expected: FAIL - "file not found"

- [ ] **Step 3: 创建模型文件**

创建 `lib/models/pump_history_model.dart`：

```dart
import 'package:tomapp/models/pump_model.dart';

/// PumpHistory 数据库实体模型
class PumpHistoryModel {
  final int? id;
  final String symbol;
  final double basePrice;
  final double peakPrice;
  final double priceChange;
  final int triggerTime; // Unix timestamp in milliseconds
  final String detectedAt; // ISO 8601 format
  final int cooldownMinutes;
  final String strategyType;
  final double? subsequentLow;
  final int? subsequentLowTime;
  final double? pullbackPercent;
  final int isConfirmed; // 0 = false, 1 = true

  PumpHistoryModel({
    this.id,
    required this.symbol,
    required this.basePrice,
    required this.peakPrice,
    required this.priceChange,
    required this.triggerTime,
    required this.detectedAt,
    required this.cooldownMinutes,
    required this.strategyType,
    this.subsequentLow,
    this.subsequentLowTime,
    this.pullbackPercent,
    required this.isConfirmed,
  });

  /// 从 PumpModel 转换
  factory PumpHistoryModel.fromPumpModel(PumpModel pump, {
    required String strategyType,
    int cooldownMinutes = 1,
  }) {
    final now = DateTime.now();
    return PumpHistoryModel(
      symbol: pump.symbol,
      basePrice: pump.currentPrice / (1 + pump.priceChange / 100),
      peakPrice: pump.currentPrice,
      priceChange: pump.priceChange,
      triggerTime: pump.triggerTime.millisecondsSinceEpoch,
      detectedAt: now.toIso8601String(),
      cooldownMinutes: cooldownMinutes,
      strategyType: strategyType,
      isConfirmed: 0,
    );
  }

  /// 从数据库 Map 创建
  factory PumpHistoryModel.fromMap(Map<String, dynamic> map) {
    return PumpHistoryModel(
      id: map['id'] as int?,
      symbol: map['symbol'] as String,
      basePrice: (map['basePrice'] as num).toDouble(),
      peakPrice: (map['peakPrice'] as num).toDouble(),
      priceChange: (map['priceChange'] as num).toDouble(),
      triggerTime: map['triggerTime'] as int,
      detectedAt: map['detectedAt'] as String,
      cooldownMinutes: map['cooldownMinutes'] as int,
      strategyType: map['strategyType'] as String,
      subsequentLow: map['subsequentLow'] != null 
          ? (map['subsequentLow'] as num).toDouble() 
          : null,
      subsequentLowTime: map['subsequentLowTime'] as int?,
      pullbackPercent: map['pullbackPercent'] != null 
          ? (map['pullbackPercent'] as num).toDouble() 
          : null,
      isConfirmed: map['isConfirmed'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'symbol': symbol,
      'basePrice': basePrice,
      'peakPrice': peakPrice,
      'priceChange': priceChange,
      'triggerTime': triggerTime,
      'detectedAt': detectedAt,
      'cooldownMinutes': cooldownMinutes,
      'strategyType': strategyType,
      'subsequentLow': subsequentLow,
      'subsequentLowTime': subsequentLowTime,
      'pullbackPercent': pullbackPercent,
      'isConfirmed': isConfirmed,
    };
  }

  /// 转换为 PumpModel (用于兼容)
  PumpModel toPumpModel() {
    return PumpModel(
      symbol: symbol,
      priceChange: priceChange,
      triggerTime: DateTime.fromMillisecondsSinceEpoch(triggerTime),
      currentPrice: peakPrice,
    );
  }

  /// 复制并修改部分字段
  PumpHistoryModel copyWith({
    int? id,
    String? symbol,
    double? basePrice,
    double? peakPrice,
    double? priceChange,
    int? triggerTime,
    String? detectedAt,
    int? cooldownMinutes,
    String? strategyType,
    double? subsequentLow,
    int? subsequentLowTime,
    double? pullbackPercent,
    int? isConfirmed,
  }) {
    return PumpHistoryModel(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      basePrice: basePrice ?? this.basePrice,
      peakPrice: peakPrice ?? this.peakPrice,
      priceChange: priceChange ?? this.priceChange,
      triggerTime: triggerTime ?? this.triggerTime,
      detectedAt: detectedAt ?? this.detectedAt,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      strategyType: strategyType ?? this.strategyType,
      subsequentLow: subsequentLow ?? this.subsequentLow,
      subsequentLowTime: subsequentLowTime ?? this.subsequentLowTime,
      pullbackPercent: pullbackPercent ?? this.pullbackPercent,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  /// 获取触发时间作为 DateTime
  DateTime get triggerDateTime => 
      DateTime.fromMillisecondsSinceEpoch(triggerTime);

  /// 是否已确认
  bool get confirmed => isConfirmed == 1;

  /// 是否还在监控期内
  bool isWithinMonitoringPeriod({int minutes = 15}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = Duration(minutes: minutes).inMilliseconds;
    return (now - triggerTime) < maxAge;
  }

  /// 计算从检测到现在的时间差
  Duration get age => 
      DateTime.now().difference(triggerDateTime);
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/models/pump_history_model_test.dart
```

Expected: 3 tests pass

- [ ] **Step 5: 运行 flutter analyze**

```bash
flutter analyze lib/models/pump_history_model.dart
```

Expected: No issues found

- [ ] **Step 6: 提交**

```bash
git add lib/models/pump_history_model.dart test/models/pump_history_model_test.dart
git commit -m "feat: add PumpHistoryModel with tests"
git log -1 --stat
```

---

### Task 3: 创建数据库帮助类

**Prerequisites:** Task 2 must be completed

**Files:**
- Create: `lib/services/database_helper.dart`
- Create: `test/services/database_helper_test.dart`

- [ ] **Step 1: 先写测试**

创建 `test/services/database_helper_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/database_helper.dart';

void main() {
  group('DatabaseHelper', () {
    test('instance returns singleton', () {
      final helper1 = DatabaseHelper.instance;
      final helper2 = DatabaseHelper.instance;
      expect(identical(helper1, helper2), true);
    });

    test('databaseVersion is defined', () {
      expect(DatabaseHelper.currentVersion, 1);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/database_helper_test.dart
```

Expected: FAIL - "file not found"

- [ ] **Step 3: 创建数据库帮助类**

创建 `lib/services/database_helper.dart`：

```dart
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
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/services/database_helper_test.dart
```

Expected: 2 tests pass

- [ ] **Step 5: 提交**

```bash
git add lib/services/database_helper.dart test/services/database_helper_test.dart
git commit -m "feat: add DatabaseHelper for SQLite initialization"
git log -1 --stat
```

---

### Task 4: 创建 PumpRepository 和 RepositoryFactory

**Prerequisites:** Task 2, Task 3 must be completed

**Files:**
- Create: `lib/services/pump_repository.dart`
- Create: `test/services/pump_repository_test.dart`

- [ ] **Step 1: 先写测试**

创建 `test/services/pump_repository_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/pump_repository.dart';

void main() {
  group('MemoryPumpRepository', () {
    late MemoryPumpRepository repository;

    setUp(() {
      repository = MemoryPumpRepository();
    });

    test('save and retrieve pump', () async {
      final pump = PumpHistoryModel(
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      await repository.save(pump);

      final results = await repository.findAll();
      expect(results.length, 1);
      expect(results.first.symbol, 'BTCUSDT');
    });

    test('findAll with symbol filter', () async {
      final pump1 = PumpHistoryModel(
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      final pump2 = PumpHistoryModel(
        symbol: 'ETHUSDT',
        basePrice: 3500.0,
        peakPrice: 3570.0,
        priceChange: 2.0,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      await repository.saveAll([pump1, pump2]);

      final results = await repository.findAll(symbol: 'BTCUSDT');
      expect(results.length, 1);
      expect(results.first.symbol, 'BTCUSDT');
    });

    test('updatePullback updates pullback percent', () async {
      final pump = PumpHistoryModel(
        id: 1,
        symbol: 'BTCUSDT',
        basePrice: 65000.0,
        peakPrice: 66500.0,
        priceChange: 2.3,
        triggerTime: DateTime.now().millisecondsSinceEpoch,
        detectedAt: DateTime.now().toIso8601String(),
        cooldownMinutes: 1,
        strategyType: 'Test',
        isConfirmed: 0,
      );

      await repository.save(pump);
      await repository.updatePullback(1, 66000.0, DateTime.now().millisecondsSinceEpoch);

      final results = await repository.findAll();
      expect(results.first.pullbackPercent, closeTo(-0.75, 0.01));
    });
  });

  group('RepositoryFactory', () {
    test('create returns repository', () {
      final repo = RepositoryFactory.create();
      expect(repo, isA<PumpRepository>());
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/pump_repository_test.dart
```

Expected: FAIL - "file not found"

- [ ] **Step 3: 创建 Repository**

创建 `lib/services/pump_repository.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/database_helper.dart';

/// PumpRepository 抽象接口
abstract class PumpRepository {
  Future<void> save(PumpHistoryModel pump);
  Future<void> saveAll(List<PumpHistoryModel> pumps);
  
  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  });
  
  Future<List<PumpHistoryModel>> getRecentData(String symbol, {int hours = 24});
  Future<PumpStatistics> getStatistics();
  Future<List<SymbolStats>> getTopSymbols(int limit);
  
  Future<void> updatePullback(int id, double lowPrice, int lowTime);
  Future<void> markConfirmed(int id);
  
  Future<void> cleanOldData({int daysToKeep = 90});
  Future<int> getDatabaseSize();
}

/// 统计数据模型
class PumpStatistics {
  final int totalDetections;
  final int uniqueSymbols;
  final double avgPriceChange;
  final double successRate;
  final List<SymbolStats> topSymbols;
  final List<HourlyCount> detectionsByHour;

  PumpStatistics({
    required this.totalDetections,
    required this.uniqueSymbols,
    required this.avgPriceChange,
    required this.successRate,
    required this.topSymbols,
    required this.detectionsByHour,
  });
}

/// 币种统计
class SymbolStats {
  final String symbol;
  final int count;
  final double avgChange;
  final double maxChange;
  final double successRate;

  SymbolStats({
    required this.symbol,
    required this.count,
    required this.avgChange,
    required this.maxChange,
    required this.successRate,
  });
}

/// 小时统计
class HourlyCount {
  final int hour;
  final int count;

  HourlyCount({required this.hour, required this.count});
}

/// RepositoryFactory - 根据规范 Section 3.6
class RepositoryFactory {
  static PumpRepository create() {
    try {
      return SqlitePumpRepository();
    } catch (e) {
      debugPrint('数据库初始化失败，降级到内存模式: $e');
      return MemoryPumpRepository();
    }
  }
}

/// SQLite 实现
class SqlitePumpRepository implements PumpRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<void> save(PumpHistoryModel pump) async {
    final db = await _dbHelper.database;
    await db.insert('PumpHistory', pump.toMap());
  }

  @override
  Future<void> saveAll(List<PumpHistoryModel> pumps) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    
    for (final pump in pumps) {
      batch.insert('PumpHistory', pump.toMap());
    }
    
    await batch.commit(noResult: true);
  }

  @override
  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  }) async {
    final db = await _dbHelper.database;
    
    String query = 'SELECT * FROM PumpHistory WHERE 1=1';
    final args = <dynamic>[];
    
    if (symbol != null) {
      query += ' AND symbol = ?';
      args.add(symbol);
    }
    
    if (startTime != null) {
      query += ' AND triggerTime >= ?';
      args.add(startTime.millisecondsSinceEpoch);
    }
    
    if (endTime != null) {
      query += ' AND triggerTime <= ?';
      args.add(endTime.millisecondsSinceEpoch);
    }
    
    if (isConfirmed != null) {
      query += ' AND isConfirmed = ?';
      args.add(isConfirmed ? 1 : 0);
    }
    
    query += ' ORDER BY triggerTime DESC';
    
    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }
    
    if (offset != null) {
      query += ' OFFSET ?';
      args.add(offset);
    }
    
    final maps = await db.rawQuery(query, args);
    return maps.map((map) => PumpHistoryModel.fromMap(map)).toList();
  }

  @override
  Future<List<PumpHistoryModel>> getRecentData(String symbol, {int hours = 24}) async {
    final startTime = DateTime.now().subtract(Duration(hours: hours));
    return findAll(
      symbol: symbol,
      startTime: startTime,
    );
  }

  @override
  Future<PumpStatistics> getStatistics() async {
    final db = await _dbHelper.database;
    
    // 总检测次数
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM PumpHistory'
    );
    final totalDetections = Sqflite.firstIntValue(totalResult) ?? 0;
    
    // 唯一币种数
    final symbolsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT symbol) as count FROM PumpHistory'
    );
    final uniqueSymbols = Sqflite.firstIntValue(symbolsResult) ?? 0;
    
    // 平均涨幅
    final avgResult = await db.rawQuery(
      'SELECT AVG(priceChange) as avg FROM PumpHistory'
    );
    final avgPriceChange = 
        (avgResult.first['avg'] as num?)?.toDouble() ?? 0.0;
    
    // 确认率
    final confirmedResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN isConfirmed = 1 AND (pullbackPercent IS NULL OR pullbackPercent > -0.5) THEN 1 ELSE 0 END) as confirmed
      FROM PumpHistory
    ''');
    final total = confirmedResult.first['total'] as int? ?? 1;
    final confirmed = confirmedResult.first['confirmed'] as int? ?? 0;
    final successRate = total > 0 ? (confirmed / total) : 0.0;
    
    // 热门币种 TOP 10
    final topSymbolsResult = await db.rawQuery('''
      SELECT 
        symbol,
        COUNT(*) as count,
        AVG(priceChange) as avgChange,
        MAX(priceChange) as maxChange,
        SUM(CASE WHEN isConfirmed = 1 AND (pullbackPercent IS NULL OR pullbackPercent > -0.5) THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as successRate
      FROM PumpHistory
      GROUP BY symbol
      ORDER BY count DESC
      LIMIT 10
    ''');
    
    final topSymbols = topSymbolsResult.map((row) => SymbolStats(
      symbol: row['symbol'] as String,
      count: row['count'] as int,
      avgChange: (row['avgChange'] as num).toDouble(),
      maxChange: (row['maxChange'] as num).toDouble(),
      successRate: (row['successRate'] as num).toDouble(),
    )).toList();
    
    // 按小时统计
    final hourlyResult = await db.rawQuery('''
      SELECT 
        CAST(strftime('%H', datetime(triggerTime/1000, 'unixepoch')) AS INTEGER) as hour,
        COUNT(*) as count
      FROM PumpHistory
      GROUP BY hour
      ORDER BY hour
    ''');
    
    final detectionsByHour = hourlyResult.map((row) => HourlyCount(
      hour: row['hour'] as int,
      count: row['count'] as int,
    )).toList();
    
    return PumpStatistics(
      totalDetections: totalDetections,
      uniqueSymbols: uniqueSymbols,
      avgPriceChange: avgPriceChange,
      successRate: successRate,
      topSymbols: topSymbols,
      detectionsByHour: detectionsByHour,
    );
  }

  @override
  Future<List<SymbolStats>> getTopSymbols(int limit) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        symbol,
        COUNT(*) as count,
        AVG(priceChange) as avgChange,
        MAX(priceChange) as maxChange,
        SUM(CASE WHEN isConfirmed = 1 AND (pullbackPercent IS NULL OR pullbackPercent > -0.5) THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as successRate
      FROM PumpHistory
      GROUP BY symbol
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);
    
    return result.map((row) => SymbolStats(
      symbol: row['symbol'] as String,
      count: row['count'] as int,
      avgChange: (row['avgChange'] as num).toDouble(),
      maxChange: (row['maxChange'] as num).toDouble(),
      successRate: (row['successRate'] as num).toDouble(),
    )).toList();
  }

  @override
  Future<void> updatePullback(int id, double lowPrice, int lowTime) async {
    final db = await _dbHelper.database;
    
    final pumpResult = await db.query(
      'PumpHistory',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (pumpResult.isEmpty) return;
    
    final pump = PumpHistoryModel.fromMap(pumpResult.first);
    final pullbackPercent = ((lowPrice - pump.peakPrice) / pump.peakPrice) * 100;
    
    await db.update(
      'PumpHistory',
      {
        'subsequentLow': lowPrice,
        'subsequentLowTime': lowTime,
        'pullbackPercent': pullbackPercent,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markConfirmed(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'PumpHistory',
      {'isConfirmed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final db = await _dbHelper.database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .millisecondsSinceEpoch;
    
    await db.delete(
      'PumpHistory',
      where: 'triggerTime < ?',
      whereArgs: [cutoffTime],
    );
  }

  @override
  Future<int> getDatabaseSize() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM PumpHistory
    ''');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

/// 内存实现 (降级方案)
class MemoryPumpRepository implements PumpRepository {
  final List<PumpHistoryModel> _pumps = [];

  @override
  Future<void> save(PumpHistoryModel pump) async {
    _pumps.add(pump);
  }

  @override
  Future<void> saveAll(List<PumpHistoryModel> pumps) async {
    _pumps.addAll(pumps);
  }

  @override
  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  }) async {
    var result = _pumps.toList();
    
    if (symbol != null) {
      result = result.where((p) => p.symbol == symbol).toList();
    }
    
    if (startTime != null) {
      result = result.where((p) => p.triggerTime >= startTime.millisecondsSinceEpoch).toList();
    }
    
    if (endTime != null) {
      result = result.where((p) => p.triggerTime <= endTime.millisecondsSinceEpoch).toList();
    }
    
    if (isConfirmed != null) {
      result = result.where((p) => p.confirmed == isConfirmed).toList();
    }
    
    result.sort((a, b) => b.triggerTime.compareTo(a.triggerTime));
    
    if (offset != null && offset > 0) {
      result = result.skip(offset).toList();
    }
    
    if (limit != null && limit > 0) {
      result = result.take(limit).toList();
    }
    
    return result;
  }

  @override
  Future<List<PumpHistoryModel>> getRecentData(String symbol, {int hours = 24}) async {
    final startTime = DateTime.now().subtract(Duration(hours: hours));
    return findAll(
      symbol: symbol,
      startTime: startTime,
    );
  }

  @override
  Future<PumpStatistics> getStatistics() async {
    return PumpStatistics(
      totalDetections: _pumps.length,
      uniqueSymbols: _pumps.map((p) => p.symbol).toSet().length,
      avgPriceChange: _pumps.isEmpty ? 0 : 
          _pumps.map((p) => p.priceChange).reduce((a,b) => a+b) / _pumps.length,
      successRate: 0.0,
      topSymbols: [],
      detectionsByHour: [],
    );
  }

  @override
  Future<List<SymbolStats>> getTopSymbols(int limit) async {
    return [];
  }

  @override
  Future<void> updatePullback(int id, double lowPrice, int lowTime) async {
    final index = _pumps.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final pump = _pumps[index];
      final pullbackPercent = ((lowPrice - pump.peakPrice) / pump.peakPrice) * 100;
      _pumps[index] = pump.copyWith(
        subsequentLow: lowPrice,
        subsequentLowTime: lowTime,
        pullbackPercent: pullbackPercent,
      );
    }
  }

  @override
  Future<void> markConfirmed(int id) async {
    final index = _pumps.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _pumps[index] = _pumps[index].copyWith(isConfirmed: 1);
    }
  }

  @override
  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .millisecondsSinceEpoch;
    _pumps.removeWhere((p) => p.triggerTime < cutoffTime);
  }

  @override
  Future<int> getDatabaseSize() async {
    return _pumps.length;
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/services/pump_repository_test.dart
```

Expected: 4 tests pass

- [ ] **Step 5: 提交**

```bash
git add lib/services/pump_repository.dart test/services/pump_repository_test.dart
git commit -m "feat: add PumpRepository with RepositoryFactory pattern"
git log -1 --stat
```

---

### Task 5: 创建 PumpConfigService

**Prerequisites:** Task 1 must be completed

**Files:**
- Create: `lib/services/pump_config_service.dart`

- [ ] **Step 1: 创建配置服务**

创建 `lib/services/pump_config_service.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PumpConfig with ChangeNotifier {
  // 配置键
  static const String _keyBaseThreshold = 'pump_base_threshold';
  static const String _keyMinThreshold = 'pump_min_threshold';
  static const String _keyMaxThreshold = 'pump_max_threshold';
  static const String _keyActiveDataDays = 'pump_active_data_days';
  static const String _keyArchiveDataDays = 'pump_archive_data_days';
  static const String _keyMemoryCacheSize = 'pump_memory_cache_size';
  static const String _keyListPageSize = 'pump_list_page_size';
  static const String _keyPullbackMonitorMinutes = 'pump_pullback_monitor_minutes';

  // 默认值
  double _baseThreshold = 2.0;
  double _minThreshold = 1.0;
  double _maxThreshold = 4.0;
  int _activeDataDays = 30;
  int _archiveDataDays = 90;
  int _memoryCacheSize = 50;
  int _listPageSize = 50;
  int _pullbackMonitorMinutes = 15;

  // Getters
  double get baseThreshold => _baseThreshold;
  double get minThreshold => _minThreshold;
  double get maxThreshold => _maxThreshold;
  int get activeDataDays => _activeDataDays;
  int get archiveDataDays => _archiveDataDays;
  int get memoryCacheSize => _memoryCacheSize;
  int get listPageSize => _listPageSize;
  int get pullbackMonitorMinutes => _pullbackMonitorMinutes;

  // Singleton
  static final PumpConfig _instance = PumpConfig._internal();
  static PumpConfig get instance => _instance;
  factory PumpConfig() => _instance;

  PumpConfig._internal();

  /// 从 SharedPreferences 加载配置
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _baseThreshold = prefs.getDouble(_keyBaseThreshold) ?? _baseThreshold;
      _minThreshold = prefs.getDouble(_keyMinThreshold) ?? _minThreshold;
      _maxThreshold = prefs.getDouble(_keyMaxThreshold) ?? _maxThreshold;
      _activeDataDays = prefs.getInt(_keyActiveDataDays) ?? _activeDataDays;
      _archiveDataDays = prefs.getInt(_keyArchiveDataDays) ?? _archiveDataDays;
      _memoryCacheSize = prefs.getInt(_keyMemoryCacheSize) ?? _memoryCacheSize;
      _listPageSize = prefs.getInt(_keyListPageSize) ?? _listPageSize;
      _pullbackMonitorMinutes = prefs.getInt(_keyPullbackMonitorMinutes) ?? _pullbackMonitorMinutes;
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load pump config: $e');
    }
  }

  /// 保存配置到 SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setDouble(_keyBaseThreshold, _baseThreshold);
      await prefs.setDouble(_keyMinThreshold, _minThreshold);
      await prefs.setDouble(_keyMaxThreshold, _maxThreshold);
      await prefs.setInt(_keyActiveDataDays, _activeDataDays);
      await prefs.setInt(_keyArchiveDataDays, _archiveDataDays);
      await prefs.setInt(_keyMemoryCacheSize, _memoryCacheSize);
      await prefs.setInt(_keyListPageSize, _listPageSize);
      await prefs.setInt(_keyPullbackMonitorMinutes, _pullbackMonitorMinutes);
    } catch (e) {
      debugPrint('Failed to save pump config: $e');
    }
  }

  /// Setters with auto-save
  set baseThreshold(double value) {
    _baseThreshold = value.clamp(0.5, 10.0);
    notifyListeners();
    save();
  }

  set minThreshold(double value) {
    _minThreshold = value.clamp(0.1, _baseThreshold);
    notifyListeners();
    save();
  }

  set maxThreshold(double value) {
    _maxThreshold = value.clamp(_baseThreshold, 20.0);
    notifyListeners();
    save();
  }

  set activeDataDays(int value) {
    _activeDataDays = value.clamp(7, 365);
    notifyListeners();
    save();
  }

  set archiveDataDays(int value) {
    _archiveDataDays = value.clamp(30, 365);
    notifyListeners();
    save();
  }

  set memoryCacheSize(int value) {
    _memoryCacheSize = value.clamp(10, 500);
    notifyListeners();
    save();
  }

  set listPageSize(int value) {
    _listPageSize = value.clamp(10, 200);
    notifyListeners();
    save();
  }

  set pullbackMonitorMinutes(int value) {
    _pullbackMonitorMinutes = value.clamp(5, 60);
    notifyListeners();
    save();
  }

  /// 重置为默认值
  Future<void> reset() async {
    _baseThreshold = 2.0;
    _minThreshold = 1.0;
    _maxThreshold = 4.0;
    _activeDataDays = 30;
    _archiveDataDays = 90;
    _memoryCacheSize = 50;
    _listPageSize = 50;
    _pullbackMonitorMinutes = 15;
    
    notifyListeners();
    await save();
  }
}
```

- [ ] **Step 2: 运行 flutter analyze**

```bash
flutter analyze lib/services/pump_config_service.dart
```

Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add lib/services/pump_config_service.dart
git commit -m "feat: add PumpConfigService for configuration management"
git log -1 --stat
```

---

## 阶段 2：监控策略

### Task 6: 创建策略接口和实现

**Prerequisites:** Task 4 must be completed

**Files:**
- Create: `lib/services/strategies/pump_detection_strategy.dart`
- Create: `lib/services/strategies/time_based_strategy.dart`
- Create: `lib/services/strategies/adaptive_strategy.dart`
- Create: `test/services/strategies/time_based_strategy_test.dart`

- [ ] **Step 1: 先写测试**

创建 `test/services/strategies/time_based_strategy_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/strategies/time_based_strategy.dart';

void main() {
  group('TimeBasedStrategy', () {
    late TimeBasedStrategy strategy;

    setUp(() {
      strategy = TimeBasedStrategy();
    });

    test('name returns "TimeBased"', () {
      expect(strategy.name, 'TimeBased');
    });

    test('adjust returns numeric value', () {
      final result = strategy.adjust(2.0);
      expect(result, isA<double>());
      expect(result, greaterThan(-1.0));
      expect(result, lessThan(1.0));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/strategies/time_based_strategy_test.dart
```

Expected: FAIL - "file not found"

- [ ] **Step 3: 创建策略接口**

创建 `lib/services/strategies/pump_detection_strategy.dart`：

```dart
/// Pump 检测策略接口
abstract class PumpDetectionStrategy {
  /// 计算调整后的阈值
  /// 返回调整量（可以为负）
  double adjust(double baseThreshold);
  
  /// 策略名称（用于日志和数据库记录）
  String get name;
}
```

- [ ] **Step 4: 创建 TimeBasedStrategy**

创建 `lib/services/strategies/time_based_strategy.dart`：

```dart
import 'package:tomapp/services/strategies/pump_detection_strategy.dart';

class TimeBasedStrategy implements PumpDetectionStrategy {
  @override
  String get name => 'TimeBased';

  @override
  double adjust(double baseThreshold) {
    final now = DateTime.now().toUtc();
    final hour = now.hour;
    final minute = now.minute;

    // 整点前后5分钟
    if (minute <= 5) {
      return -0.3; // 降低阈值，更敏感
    }

    // 分时段调整
    if (hour >= 0 && hour < 8) {
      return 0.3; // 亚洲时段，波动小
    } else if (hour >= 8 && hour < 16) {
      return -0.2; // 欧洲时段，波动增加
    } else {
      return -0.5; // 美洲时段，波动最大
    }
  }
}
```

- [ ] **Step 5: 创建 AdaptiveStrategy**

创建 `lib/services/strategies/adaptive_strategy.dart`：

```dart
import 'dart:math';
import 'package:tomapp/services/strategies/pump_detection_strategy.dart';
import 'package:tomapp/services/pump_repository.dart';

class AdaptiveStrategy implements PumpDetectionStrategy {
  final PumpRepository _repository;

  AdaptiveStrategy(this._repository);

  @override
  String get name => 'Adaptive';

  @override
  double adjust(double baseThreshold) {
    // 自适应策略需要基于具体币种，这里返回默认值
    // 实际使用时通过 calculateEffectiveThreshold 调用
    return 0.0;
  }

  /// 计算币种活跃度评分 (0.0 - 1.0)
  Future<double> calculateActivityScore(String symbol) async {
    final recent = await _repository.getRecentData(symbol, hours: 24);
    
    if (recent.isEmpty) return 0.5; // 新币种默认值
    
    final detectionCount = recent.length;
    final avgChange = recent.map((e) => e.priceChange).reduce((a, b) => a + b) / detectionCount;
    
    // 计算波动率
    final changes = recent.map((e) => e.priceChange).toList();
    final mean = changes.reduce((a, b) => a + b) / changes.length;
    final variance = changes.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / changes.length;
    final volatility = (variance > 0) ? sqrt(variance) : 0.0;
    
    // 标准化波动率到 0-0.3 范围
    final normalizedVolatility = (volatility / 5).clamp(0.0, 0.3);
    
    // 检测次数标准化到 0-0.4 范围
    final normalizedCount = (detectionCount / 10).clamp(0.0, 0.4);
    
    // 涨幅标准化到 0-0.3 范围
    final normalizedChange = (avgChange / 5).clamp(0.0, 0.3);
    
    return (normalizedCount + normalizedChange + normalizedVolatility).clamp(0.0, 1.0);
  }

  /// 根据活跃度调整阈值
  double adjustWithActivity(double baseThreshold, double activityScore) {
    // 活跃度越高，阈值越低 (更敏感)
    // 调整范围: ±0.3%
    final adjustment = (activityScore - 0.5) * 0.6;
    return baseThreshold - adjustment;
  }
}
```

- [ ] **Step 6: 运行测试验证通过**

```bash
flutter test test/services/strategies/time_based_strategy_test.dart
```

Expected: 2 tests pass

- [ ] **Step 7: 提交**

```bash
git add lib/services/strategies/ test/services/strategies/
git commit -m "feat: add pump detection strategy interfaces"
git log -1 --stat
```

---

### Task 7: 更新 PumpDetector 使用策略 (拆分)

**Prerequisites:** Task 5, Task 6 must be completed
**注意**: 此任务完全重写 PumpDetector，分成多个小步骤

**Files:**
- Modify: `lib/services/pump_detector.dart`

- [ ] **Step 1: 备份原文件**

```bash
cp lib/services/pump_detector.dart lib/services/pump_detector.dart.backup
```

- [ ] **Step 2: 添加新的导入**

将文件开头替换为：

```dart
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/strategies/pump_detection_strategy.dart';
import 'package:tomapp/services/strategies/time_based_strategy.dart';
import 'package:tomapp/services/strategies/adaptive_strategy.dart';
```

- [ ] **Step 3: 添加策略支持字段到类**

在 `PumpDetector` 类中，将现有的字段：

```dart
  final double threshold;
  final int cooldownMinutes;
```

替换为：

```dart
  final PumpConfig _config;
  final PumpRepository _repository;
  final List<PumpDetectionStrategy> _strategies;
```

- [ ] **Step 4: 更新构造函数**

将构造函数：

```dart
  PumpDetector({required this.threshold, required this.cooldownMinutes});
```

替换为：

```dart
  PumpDetector({
    PumpConfig? config,
    required PumpRepository repository,
  })  : _config = config ?? PumpConfig(),
        _repository = repository,
        _strategies = [
          TimeBasedStrategy(),
          AdaptiveStrategy(repository),
        ];
```

- [ ] **Step 5: 添加 calculateEffectiveThreshold 方法**

在 `getPricePointCount` 方法之前添加：

```dart
  /// 计算有效阈值（应用所有策略）
  Future<double> calculateEffectiveThreshold(String symbol) async {
    double threshold = _config.baseThreshold;
    
    for (final strategy in _strategies) {
      if (strategy is AdaptiveStrategy) {
        final activityScore = await strategy.calculateActivityScore(symbol);
        threshold = strategy.adjustWithActivity(threshold, activityScore);
      } else {
        threshold += strategy.adjust(threshold);
      }
    }
    
    // 确保在合理范围内
    return threshold.clamp(_config.minThreshold, _config.maxThreshold);
  }

  /// 获取使用的策略类型名称（用于记录）
  String getStrategyTypeName() {
    return _strategies.map((s) => s.name).join('+');
  }
```

- [ ] **Step 6: 更新 check 方法使用新阈值**

将 `check` 方法中的这一行：

```dart
    if (change == null || change <= threshold) {
```

替换为：

```dart
    // 计算有效阈值
    final effectiveThreshold = await calculateEffectiveThreshold(symbol);
    
    // 计算涨幅
    final change = _calculate1MinChange(symbol, timestamp);
    if (change == null || change <= effectiveThreshold) {
```

- [ ] **Step 7: 更新 _isInCooldown 使用默认值**

将 `_isInCooldown` 方法中的这一行：

```dart
    return elapsed.inMinutes < cooldownMinutes;
```

替换为：

```dart
    return elapsed.inMinutes < 1; // 默认 1 分钟冷却
```

- [ ] **Step 8: 添加内存管理方法**

在 `_cleanupInactiveSymbols` 方法之后添加：

```dart
  void _cleanupInactiveSymbols() {
    // 清理超过 5 分钟没有更新的币种数据
    final cutoff = DateTime.now().subtract(Duration(minutes: 5));
    _priceHistory.removeWhere((symbol, points) {
      if (points.isEmpty) return true;
      return points.last.timestamp.isBefore(cutoff);
    });
  }
```

- [ ] **Step 9: 在 addPricePoint 方法中调用清理**

在 `_cleanupOldPoints` 调用之后添加：

```dart
    // 内存管理：超过 200 个币种时清理不活跃数据
    if (_priceHistory.length > 200) {
      _cleanupInactiveSymbols();
    }
```

- [ ] **Step 10: 运行 flutter analyze**

```bash
flutter analyze lib/services/pump_detector.dart
```

Expected: No issues found

- [ ] **Step 11: 删除备份文件**

```bash
rm lib/services/pump_detector.dart.backup
```

- [ ] **Step 12: 提交**

```bash
git add lib/services/pump_detector.dart
git commit -m "refactor: update PumpDetector to use strategy pattern"
git log -1 --stat
```

---

### Task 8: 更新 PumpAlertService 集成数据库

**Prerequisites:** Task 4, Task 5, Task 7 must be completed

**Files:**
- Modify: `lib/services/pump_alert_service.dart`

- [ ] **Step 1: 添加新的导入**

在 `lib/services/pump_alert_service.dart` 顶部添加：

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/services/pump_detector.dart';
import 'package:tomapp/services/pump_store.dart';
import 'package:tomapp/services/notification_service.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/pump_repository.dart' show RepositoryFactory, PumpRepository;
```

- [ ] **Step 2: 添加私有字段**

在类中添加：

```dart
  final BinanceWebSocketManager _wsManager = BinanceWebSocketManager();
  late PumpDetector _detector;
  final PumpStore _store = PumpStore();
  final NotificationService _notificationService = NotificationService();
  
  late PumpRepository _repository;
  final PumpConfig _config = PumpConfig();

  StreamSubscription? _tickerSubscription;
  bool _isRunning = false;
```

- [ ] **Step 3: 添加 initialize 方法**

在 `start` 方法之前添加：

```dart
  /// 初始化服务
  Future<void> initialize() async {
    await _config.load();
    _repository = RepositoryFactory.create();
    
    _detector = PumpDetector(
      config: _config,
      repository: _repository,
    );
  }
```

- [ ] **Step 4: 更新 start 方法调用 initialize**

将 `start` 方法修改为：

```dart
  Future<void> start() async {
    if (_isRunning) return;
    
    await initialize();

    try {
      // 连接 WebSocket
      await _wsManager.connect();

      // 订阅 ticker 数据
      _tickerSubscription = _wsManager.tickerStream.listen(_onTicker);

      // 初始化通知服务
      await _notificationService.initialize();

      _isRunning = true;
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }
```

- [ ] **Step 5: 将 check 方法改为异步**

将 `_onTicker` 方法改为异步并调用新的检测：

```dart
  void _onTicker(Ticker ticker) {
    // 只处理 USDT 合约
    if (!ticker.symbol.endsWith('USDT')) {
      return;
    }

    // 异步检测快速上涨
    _checkPump(ticker.symbol, ticker.price, ticker.timestamp);
  }
  
  Future<void> _checkPump(
    String symbol,
    double price,
    DateTime timestamp,
  ) async {
    final pump = await _detector.check(symbol, price, timestamp);

    if (pump != null) {
      _handlePump(pump);
    }
  }
```

- [ ] **Step 6: 更新 _handlePump 保存到数据库**

将 `_handlePump` 方法更新为：

```dart
  void _handlePump(PumpModel pump) {
    // 存入 store (内存缓存)
    _store.addPump(pump);
    
    // 存入数据库
    final historyModel = PumpHistoryModel.fromPumpModel(
      pump,
      strategyType: _detector.getStrategyTypeName(),
    );
    _repository.save(historyModel);

    // 发送通知
    _notificationService.showPumpNotification(
      symbol: pump.symbol,
      priceChange: pump.priceChange,
      currentPrice: pump.currentPrice,
    );
  }
```

- [ ] **Step 7: 运行 flutter analyze**

```bash
flutter analyze lib/services/pump_alert_service.dart
```

Expected: No issues found

- [ ] **Step 8: 提交**

```bash
git add lib/services/pump_alert_service.dart
git commit -m "feat: integrate PumpRepository into PumpAlertService"
git log -1 --stat
```

---

## 阶段 3：数据分析

### Task 9: 创建 PumpAnalyticsService

**Prerequisites:** Task 4, Task 5 must be completed

**Files:**
- Create: `lib/services/pump_analytics_service.dart`

- [ ] **Step 1: 创建分析服务**

创建 `lib/services/pump_analytics_service.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/binance_api_service.dart';

class PumpAnalyticsService {
  final PumpRepository _repository;
  final PumpConfig _config;
  final BinanceApiService _apiService = BinanceApiService();

  PumpAnalyticsService({
    required PumpRepository repository,
    required PumpConfig config,
  })  : _repository = repository,
        _config = config;

  /// 获取统计数据
  Future<PumpStatistics> getStatistics() async {
    return await _repository.getStatistics();
  }

  /// 获取热门币种
  Future<List<SymbolStats>> getTopSymbols(int limit) async {
    return await _repository.getTopSymbols(limit);
  }

  /// 执行回撤分析
  Future<void> analyzePullbacks() async {
    try {
      final unconfirmed = await _repository.findAll(isConfirmed: false);
      
      for (final pump in unconfirmed) {
        final age = DateTime.now().millisecondsSinceEpoch - pump.triggerTime;
        final maxAge = Duration(minutes: _config.pullbackMonitorMinutes).inMilliseconds;
        
        if (age < maxAge) {
          // 还在监控期内，获取当前价格
          try {
            final currentPrice = await _getCurrentPrice(pump.symbol);
            
            if (currentPrice != null) {
              final pullback = (currentPrice - pump.peakPrice) / pump.peakPrice * 100;
              
              if (pump.pullbackPercent == null || pullback < pump.pullbackPercent!) {
                await _repository.updatePullback(
                  pump.id!,
                  currentPrice,
                  DateTime.now().millisecondsSinceEpoch,
                );
              }
            }
          } catch (e) {
            debugPrint('获取 ${pump.symbol} 价格失败: $e');
          }
        } else {
          // 监控期结束，标记确认
          await _repository.markConfirmed(pump.id!);
        }
      }
    } catch (e) {
      debugPrint('回撤分析失败: $e');
    }
  }

  /// 获取币种详情统计
  Future<SymbolDetailStats> getSymbolStats(String symbol) async {
    final recent = await _repository.findAll(
      symbol: symbol,
      limit: 100,
    );
    
    if (recent.isEmpty) {
      return SymbolDetailStats(
        symbol: symbol,
        totalDetections: 0,
        avgChange: 0,
        maxChange: 0,
        minChange: 0,
        successRate: 0,
        recentDetections: [],
      );
    }
    
    final changes = recent.map((e) => e.priceChange).toList();
    final avgChange = changes.reduce((a, b) => a + b) / changes.length;
    final maxChange = changes.reduce((a, b) => a > b ? a : b);
    final minChange = changes.reduce((a, b) => a < b ? a : b);
    
    final confirmedCount = recent.where((p) => 
      p.confirmed && (p.pullbackPercent == null || p.pullbackPercent! > -0.5)
    ).length;
    final successRate = confirmedCount / recent.length;
    
    return SymbolDetailStats(
      symbol: symbol,
      totalDetections: recent.length,
      avgChange: avgChange,
      maxChange: maxChange,
      minChange: minChange,
      successRate: successRate,
      recentDetections: recent.take(10).toList(),
    );
  }

  /// 清理旧数据
  Future<void> cleanOldData() async {
    await _repository.cleanOldData(daysToKeep: _config.archiveDataDays);
  }

  Future<double?> _getCurrentPrice(String symbol) async {
    try {
      final rates = await _apiService.getUSDTFuturesRates();
      final symbolRate = rates.firstWhere(
        (r) => r.symbol == symbol,
        orElse: () => throw Exception('Symbol not found'),
      );
      return symbolRate.markPrice;
    } catch (e) {
      debugPrint('获取 $symbol 价格失败: $e');
      return null;
    }
  }
}

/// 币种详情统计
class SymbolDetailStats {
  final String symbol;
  final int totalDetections;
  final double avgChange;
  final double maxChange;
  final double minChange;
  final double successRate;
  final List<PumpHistoryModel> recentDetections;

  SymbolDetailStats({
    required this.symbol,
    required this.totalDetections,
    required this.avgChange,
    required this.maxChange,
    required this.minChange,
    required this.successRate,
    required this.recentDetections,
  });
}
```

- [ ] **Step 2: 运行 flutter analyze**

```bash
flutter analyze lib/services/pump_analytics_service.dart
```

Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add lib/services/pump_analytics_service.dart
git commit -m "feat: add PumpAnalyticsService for data analysis"
git log -1 --stat
```

---

### Task 10: 更新后台服务执行定期分析

**Prerequisites:** Task 9 must be completed

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 找到 callbackDispatcher 中的 Timer.periodic**

在 `lib/main.dart` 中找到 `callbackDispatcher` 函数内的：

```dart
  Timer.periodic(const Duration(seconds: 30), (timer) async {
```

- [ ] **Step 2: 在 Timer 回调开始添加分析调用**

在 `if (service is AndroidServiceInstance)` 块之后、HTTP 轮询代码之前添加：

```dart
    // 每 5 个周期（约 2.5 分钟）执行一次回撤分析
    if (timer.tick % 5 == 0) {
      try {
        final analytics = PumpAnalyticsService(
          repository: RepositoryFactory.create(),
          config: PumpConfig(),
        );
        await analytics.analyzePullbacks();
      } catch (e) {
        debugPrint('回撤分析失败: $e');
      }
    }
```

- [ ] **Step 3: 添加必要的导入**

确保 `lib/main.dart` 顶部有：

```dart
import 'package:tomapp/services/pump_analytics_service.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/pump_repository.dart' show RepositoryFactory;
```

- [ ] **Step 4: 运行 flutter analyze**

```bash
flutter analyze lib/main.dart
```

Expected: No issues found

- [ ] **Step 5: 提交**

```bash
git add lib/main.dart
git commit -m "feat: add periodic pullback analysis to background service"
git log -1 --stat
```

---

## 阶段 4：UI/UX

### Task 11: 创建 PumpListProvider 状态管理

**Prerequisites:** Task 2, Task 4, Task 5 must be completed

**Files:**
- Create: `lib/providers/pump_list_provider.dart`

- [ ] **Step 1: 创建状态管理**

创建 `lib/providers/pump_list_provider.dart`：

```dart
import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';

enum PumpListStatus { initial, loading, loaded, error, empty }

class PumpListState {
  final PumpListStatus status;
  final List<PumpHistoryModel> pumps;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  PumpListState({
    this.status = PumpListStatus.initial,
    this.pumps = const [],
    this.errorMessage,
    this.hasMore = true,
    this.currentPage = 0,
  });

  PumpListState copyWith({
    PumpListStatus? status,
    List<PumpHistoryModel>? pumps,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
  }) {
    return PumpListState(
      status: status ?? this.status,
      pumps: pumps ?? this.pumps,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PumpListProvider extends ChangeNotifier {
  final PumpRepository _repository;
  final PumpConfig _config;

  PumpListState _state = PumpListState();
  PumpListState get state => _state;

  // 筛选条件
  String _searchQuery = '';
  String? _filterSymbol;
  bool? _filterConfirmed;
  PumpListSort _sortType = PumpListSort.timeDesc;

  PumpListProvider({
    required PumpRepository repository,
    required PumpConfig config,
  })  : _repository = repository,
        _config = config;

  /// 加载数据
  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _state = _state.copyWith(
        currentPage: 0,
        pumps: [],
      );
    }

    _state = _state.copyWith(status: PumpListStatus.loading);
    notifyListeners();

    try {
      final pumps = await _repository.findAll(
        limit: _config.listPageSize,
        offset: _state.currentPage * _config.listPageSize,
        symbol: _filterSymbol,
        isConfirmed: _filterConfirmed,
      );

      // 应用搜索和排序
      final filteredPumps = _applyFilterAndSort(pumps);

      if (filteredPumps.isEmpty) {
        _state = _state.copyWith(
          status: PumpListStatus.empty,
          pumps: filteredPumps,
          hasMore: false,
        );
      } else {
        _state = _state.copyWith(
          status: PumpListStatus.loaded,
          pumps: filteredPumps,
          hasMore: filteredPumps.length >= _config.listPageSize,
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        status: PumpListStatus.error,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (!_state.hasMore || _state.status == PumpListStatus.loading) {
      return;
    }

    final nextPage = _state.currentPage + 1;

    try {
      final pumps = await _repository.findAll(
        limit: _config.listPageSize,
        offset: nextPage * _config.listPageSize,
        symbol: _filterSymbol,
        isConfirmed: _filterConfirmed,
      );

      final filteredPumps = _applyFilterAndSort(pumps);

      _state = _state.copyWith(
        status: PumpListStatus.loaded,
        pumps: [..._state.pumps, ...filteredPumps],
        hasMore: filteredPumps.length >= _config.listPageSize,
        currentPage: nextPage,
      );
    } catch (e) {
      debugPrint('加载更多失败: $e');
    }

    notifyListeners();
  }

  /// 设置搜索
  void setSearchQuery(String query) {
    _searchQuery = query.toUpperCase();
    load(refresh: true);
  }

  /// 设置币种筛选
  void setSymbolFilter(String? symbol) {
    _filterSymbol = symbol;
    load(refresh: true);
  }

  /// 设置确认状态筛选
  void setConfirmedFilter(bool? confirmed) {
    _filterConfirmed = confirmed;
    load(refresh: true);
  }

  /// 设置排序
  void setSortType(PumpListSort sortType) {
    _sortType = sortType;
    load(refresh: true);
  }

  List<PumpHistoryModel> _applyFilterAndSort(List<PumpHistoryModel> pumps) {
    var result = pumps.toList();

    // 应用搜索
    if (_searchQuery.isNotEmpty) {
      result = result.where((p) => p.symbol.contains(_searchQuery)).toList();
    }

    // 应用排序
    switch (_sortType) {
      case PumpListSort.timeDesc:
        result.sort((a, b) => b.triggerTime.compareTo(a.triggerTime));
        break;
      case PumpListSort.timeAsc:
        result.sort((a, b) => a.triggerTime.compareTo(b.triggerTime));
        break;
      case PumpListSort.changeDesc:
        result.sort((a, b) => b.priceChange.compareTo(a.priceChange));
        break;
      case PumpListSort.changeAsc:
        result.sort((a, b) => a.priceChange.compareTo(b.priceChange));
        break;
    }

    return result;
  }
}

enum PumpListSort { timeDesc, timeAsc, changeDesc, changeAsc }
```

- [ ] **Step 2: 运行 flutter analyze**

```bash
flutter analyze lib/providers/pump_list_provider.dart
```

Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add lib/providers/pump_list_provider.dart
git commit -m "feat: add PumpListProvider for state management"
git log -1 --stat
```

---

### Task 12: 创建 PumpHistoryItem 组件

**Prerequisites:** Task 2 must be completed

**Files:**
- Create: `lib/widgets/pump_history_item.dart`

- [ ] **Step 1: 创建组件**

创建 `lib/widgets/pump_history_item.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:intl/intl.dart';

class PumpHistoryItem extends StatelessWidget {
  final PumpHistoryModel pump;
  final VoidCallback onTap;

  const PumpHistoryItem({
    super.key,
    required this.pump,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = pump.priceChange >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              
              // 主要信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pump.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(pump.triggerDateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 涨幅和回撤
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${pump.priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (pump.pullbackPercent != null) ...[
                        Icon(
                          pump.pullbackPercent! < 0 
                              ? Icons.arrow_downward 
                              : pump.pullbackPercent! > 0 
                                  ? Icons.arrow_upward 
                                  : Icons.remove,
                          size: 14,
                          color: pump.pullbackPercent! < 0 
                              ? Colors.red 
                              : pump.pullbackPercent! > 0 
                                  ? Colors.green 
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pump.pullbackPercent!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        pump.confirmed ? Icons.check_circle : Icons.hourglass_empty,
                        size: 16,
                        color: pump.confirmed ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }
}
```

- [ ] **Step 2: 运行 flutter analyze**

```bash
flutter analyze lib/widgets/pump_history_item.dart
```

Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add lib/widgets/pump_history_item.dart
git commit -m "feat: add PumpHistoryItem widget"
git log -1 --stat
```

---

### Task 13: 更新 PumpScreen

**Prerequisites:** Task 11, Task 12 must be completed

**Files:**
- Modify: `lib/screens/pump_screen.dart`

- [ ] **Step 1: 备份原文件**

```bash
cp lib/screens/pump_screen.dart lib/screens/pump_screen.dart.backup
```

- [ ] **Step 2: 替换文件内容**

完全替换 `lib/screens/pump_screen.dart` 为：

```dart
// lib/screens/pump_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/widgets/pump_history_item.dart';
import 'package:tomapp/screens/pump_detail_screen.dart';

class PumpScreen extends StatefulWidget {
  const PumpScreen({super.key});

  @override
  State<PumpScreen> createState() => _PumpScreenState();
}

class _PumpScreenState extends State<PumpScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // 初始加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PumpListProvider>().load();
    });
    
    // 监听滚动，加载更多
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PumpListProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('快速上涨'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          Consumer<BinanceWebSocketManager>(
            builder: (context, wsManager, child) {
              final state = wsManager.connectionState;
              Color dotColor;
              String statusText;

              switch (state) {
                case WebSocketConnectionState.connected:
                  dotColor = Colors.green;
                  statusText = '已连接';
                  break;
                case WebSocketConnectionState.connecting:
                case WebSocketConnectionState.reconnecting:
                  dotColor = Colors.orange;
                  statusText = '连接中';
                  break;
                default:
                  dotColor = Colors.red;
                  statusText = '已断开';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          PopupMenuButton<PumpListSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) {
              context.read<PumpListProvider>().setSortType(sort);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PumpListSort.timeDesc,
                child: Text('最新优先'),
              ),
              const PopupMenuItem(
                value: PumpListSort.timeAsc,
                child: Text('最早优先'),
              ),
              const PopupMenuItem(
                value: PumpListSort.changeDesc,
                child: Text('涨幅最高'),
              ),
              const PopupMenuItem(
                value: PumpListSort.changeAsc,
                child: Text('涨幅最低'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索币种...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<PumpListProvider>().setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: isDark 
                    ? const Color(0xFF2C2C2C) 
                    : Colors.grey[200],
                isDense: true,
              ),
              onChanged: (value) {
                context.read<PumpListProvider>().setSearchQuery(value);
              },
            ),
          ),
        ),
      ),
      body: Consumer<PumpListProvider>(
        builder: (context, provider, child) {
          final state = provider.state;

          switch (state.status) {
            case PumpListStatus.initial:
            case PumpListStatus.loading:
              return const Center(
                child: CircularProgressIndicator(),
              );

            case PumpListStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: isDark ? Colors.red[400] : Colors.red[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? '加载失败',
                      style: TextStyle(
                        color: isDark ? Colors.red[400] : Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => provider.load(refresh: true),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );

            case PumpListStatus.empty:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 64,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无快速上涨记录',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );

            case PumpListStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => provider.load(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.pumps.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.pumps.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final pump = state.pumps[index];
                    return PumpHistoryItem(
                      pump: pump,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PumpDetailScreen(pump: pump),
                        ),
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 3: 运行 flutter analyze**

```bash
flutter analyze lib/screens/pump_screen.dart
```

Expected: No issues found

- [ ] **Step 4: 删除备份文件**

```bash
rm lib/screens/pump_screen.dart.backup
```

- [ ] **Step 5: 提交**

```bash
git add lib/screens/pump_screen.dart
git commit -m "feat: update PumpScreen with database-backed list"
git log -1 --stat
```

---

### Task 14: 创建 PumpDetailScreen

**Prerequisites:** Task 9, Task 11 must be completed

**Files:**
- Create: `lib/screens/pump_detail_screen.dart`

- [ ] **Step 1: 创建详情页**

创建 `lib/screens/pump_detail_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/pump_analytics_service.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:intl/intl.dart';

class PumpDetailScreen extends StatefulWidget {
  final PumpHistoryModel pump;

  const PumpDetailScreen({super.key, required this.pump});

  @override
  State<PumpDetailScreen> createState() => _PumpDetailScreenState();
}

class _PumpDetailScreenState extends State<PumpDetailScreen> {
  late final PumpRepository _repository;
  late final PumpAnalyticsService _analytics;
  SymbolDetailStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = RepositoryFactory.create();
    _analytics = PumpAnalyticsService(
      repository: _repository,
      config: PumpConfig(),
    );
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _analytics.getSymbolStats(widget.pump.symbol);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final isPositive = widget.pump.priceChange >= 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.pump.symbol),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 检测信息卡片
            _buildInfoCard(isDark),
            const SizedBox(height: 16),

            // 价格走势图占位
            _buildChartPlaceholder(isDark),
            const SizedBox(height: 16),

            // 后续走势
            _buildPullbackSection(isDark),
            const SizedBox(height: 16),

            // 历史统计
            if (!_isLoading) _buildStatsSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '检测信息',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('检测时间', DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.pump.triggerDateTime)),
            const SizedBox(height: 8),
            _buildInfoRow('基准价格', '\$${widget.pump.basePrice.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('峰值价格', '\$${widget.pump.peakPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow(
              '涨幅',
              '${widget.pump.priceChange >= 0 ? '+' : ''}${widget.pump.priceChange.toStringAsFixed(2)}%',
              valueColor: widget.pump.priceChange >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('策略', widget.pump.strategyType),
            const SizedBox(height: 8),
            _buildInfoRow('冷却时间', '${widget.pump.cooldownMinutes} 分钟'),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '价格走势',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '图表功能即将推出',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPullbackSection(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '后续走势',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.pump.subsequentLow != null) ...[
              _buildInfoRow('最低价', '\$${widget.pump.subsequentLow!.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInfoRow(
                '回撤',
                '${widget.pump.pullbackPercent!.toStringAsFixed(2)}%',
                valueColor: widget.pump.pullbackPercent! < 0 ? Colors.red : Colors.green,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  widget.pump.confirmed ? Icons.check_circle : Icons.hourglass_empty,
                  size: 20,
                  color: widget.pump.confirmed ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.pump.confirmed ? '已确认' : '分析中',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    if (_stats == null) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '历史统计 (${widget.pump.symbol})',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('检测次数', '${_stats!.totalDetections} 次'),
            const SizedBox(height: 8),
            _buildInfoRow('平均涨幅', '+${_stats!.avgChange.toStringAsFixed(2)}%'),
            const SizedBox(height: 8),
            _buildInfoRow('最大涨幅', '+${_stats!.maxChange.toStringAsFixed(2)}%'),
            const SizedBox(height: 8),
            _buildInfoRow('确认率', '${(_stats!.successRate * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor ?? (isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 运行 flutter analyze**

```bash
flutter analyze lib/screens/pump_detail_screen.dart
```

Expected: No issues found

- [ ] **Step 3: 提交**

```bash
git add lib/screens/pump_detail_screen.dart
git commit -m "feat: add PumpDetailScreen"
git log -1 --stat
```

---

### Task 15: 更新 main.dart 集成 Provider

**Prerequisites:** Task 11 must be completed

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 找到 MultiProxyProvider 位置**

在 `lib/main.dart` 中搜索 `MultiProxyProvider` 或 `ProxyProvider`

- [ ] **Step 2: 添加 PumpListProvider 注册**

在现有 Provider 列表中添加（确保在其他 Provider 之后）：

```dart
          ChangeNotifierProvider(
            create: (_) => PumpListProvider(
              repository: RepositoryFactory.create(),
              config: PumpConfig(),
            ),
          ),
```

- [ ] **Step 3: 添加导入**

在文件顶部添加：

```dart
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/pump_config_service.dart';
```

- [ ] **Step 4: 运行 flutter analyze**

```bash
flutter analyze lib/main.dart
```

Expected: No issues found

- [ ] **Step 5: 提交**

```bash
git add lib/main.dart
git commit -m "feat: register PumpListProvider in main.dart"
git log -1 --stat
```

---

## 阶段 5：最终验证

### Task 16: 运行应用测试

**Prerequisites:** 所有之前任务必须完成

- [ ] **Step 1: 运行完整应用测试**

```bash
flutter run
```

Expected: 应用成功启动，可以导航到快速上涨页面

- [ ] **Step 2: 验证数据库功能**

在应用中：
1. 触发一次快速上涨检测（或等待自动检测）
2. 检查数据是否保存到数据库
3. 退出应用并重新启动
4. 检查历史记录是否显示

- [ ] **Step 3: 验证 UI 功能**

1. 搜索功能
2. 排序功能
3. 下拉刷新
4. 点击进入详情页
5. 返回查看历史统计

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "chore: final verification complete"
git log -1 --stat
```

---

## 验收检查点

### 检查点 1：数据库功能
- [ ] 应用启动后数据库自动创建
- [ ] 检测到 Pump 后数据自动保存
- [ ] 可以查询历史记录
- [ ] RepositoryFactory 降级机制正常工作

### 检查点 2：策略功能
- [ ] TimeBasedStrategy 正常工作
- [ ] AdaptiveStrategy 正常工作
- [ ] 阈值计算正确
- [ ] 策略组合生效

### 检查点 3：分析功能
- [ ] 回撤分析定期执行
- [ ] 统计数据正确
- [ ] 旧数据清理正常

### 检查点 4：UI 功能
- [ ] 列表正常显示
- [ ] 搜索筛选正常
- [ ] 详情页正常显示
- [ ] 下拉刷新正常
- [ ] 上拉加载更多正常

### 检查点 5：测试覆盖
- [ ] 单元测试全部通过
- [ ] 代码无警告
- [ ] 提交历史完整

---

## 文件变更摘要

### 新增文件
```
lib/models/pump_history_model.dart
lib/services/database_helper.dart
lib/services/pump_repository.dart
lib/services/pump_config_service.dart
lib/services/pump_analytics_service.dart
lib/services/strategies/pump_detection_strategy.dart
lib/services/strategies/time_based_strategy.dart
lib/services/strategies/adaptive_strategy.dart
lib/providers/pump_list_provider.dart
lib/screens/pump_detail_screen.dart
lib/widgets/pump_history_item.dart
test/models/pump_history_model_test.dart
test/services/database_helper_test.dart
test/services/pump_repository_test.dart
test/services/strategies/time_based_strategy_test.dart
```

### 修改文件
```
pubspec.yaml
lib/services/pump_detector.dart
lib/services/pump_alert_service.dart
lib/screens/pump_screen.dart
lib/main.dart
```

---

## 提交规范

每个功能完成后提交一次，提交信息格式：
- `feat:` - 新功能
- `refactor:` - 重构
- `test:` - 测试
- `fix:` - 修复
- `chore:` - 配置/工具

提交信息应该清晰描述做了什么。

---

## 注意事项

1. **渐进式开发**：每个 Task 完成后都可以运行和测试
2. **向后兼容**：保留现有功能，只添加新功能
3. **错误处理**：数据库失败时降级到内存模式
4. **性能优化**：列表分页加载，避免一次性加载过多数据
5. **测试驱动**：先写测试，再实现功能
6. **RepositoryFactory**: 所有数据库访问通过工厂创建，支持降级
