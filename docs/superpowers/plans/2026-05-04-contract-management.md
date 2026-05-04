# Contract Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a contract information sync feature that automatically fetches and stores Binance futures contract data to SQLite, with a user toggle in the Profile screen.

**Architecture:** Three new services (ContractInfoService, ContractSyncSettings, ContractSyncService) plus database upgrade and UI integration. ContractSyncService orchestrates syncing by fetching from existing ExchangeInfoService and storing via ContractInfoService.

**Tech Stack:** Flutter, Dart, sqflite, shared_preferences, provider

---

## File Structure

### New Files
- `lib/services/contract_info_service.dart` - SQLite CRUD for futures_symbols table
- `lib/services/contract_sync_settings.dart` - SharedPreferences wrapper for sync toggle
- `lib/services/contract_sync_service.dart` - Sync orchestrator with timer

### Modified Files
- `lib/services/database_helper.dart` - Add futures_symbols table, upgrade to v3
- `lib/services/exchange_info_service.dart` - Add pricePrecision/quantityPrecision to FuturesSymbol
- `lib/screens/profile_screen.dart` - Add "合约信息管理" section with switch

---

## Task 1: Extend FuturesSymbol Model

**Files:**
- Modify: `lib/services/exchange_info_service.dart:54-111`

**Why:** Add missing pricePrecision and quantityPrecision fields needed for database storage.

- [ ] **Step 1: Read current FuturesSymbol class**

Run: Read `lib/services/exchange_info_service.dart` lines 54-111

- [ ] **Step 2: Add pricePrecision and quantityPrecision fields**

Modify the FuturesSymbol class to include:

```dart
class FuturesSymbol {
  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final ContractStatus status;
  final String contractType;
  final int onBoardDate;
  final int deliveryDate;
  final int deliveryTime;
  final int pricePrecision;   // NEW
  final int quantityPrecision; // NEW

  FuturesSymbol({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.status,
    required this.contractType,
    required this.onBoardDate,
    this.deliveryDate = 0,
    this.deliveryTime = 0,
    this.pricePrecision = 0,   // NEW
    this.quantityPrecision = 0, // NEW
  });
```

- [ ] **Step 3: Update fromJson factory**

Update the factory constructor to parse new fields:

```dart
  factory FuturesSymbol.fromJson(Map<String, dynamic> json) {
    return FuturesSymbol(
      symbol: json['symbol'] as String? ?? '',
      baseAsset: json['baseAsset'] as String? ?? '',
      quoteAsset: json['quoteAsset'] as String? ?? '',
      status: ContractStatusExtension.fromString(
        json['contractStatus'] as String? ?? json['status'] as String? ?? 'CLOSE'
      ),
      contractType: json['contractType'] as String? ?? '',
      onBoardDate: json['onBoardDate'] as int? ?? 0,
      deliveryDate: json['deliveryDate'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as int? ?? 0,
      pricePrecision: json['pricePrecision'] as int? ?? 0,   // NEW
      quantityPrecision: json['quantityPrecision'] as int? ?? 0, // NEW
    );
  }
```

- [ ] **Step 4: Update toJson method**

Add new fields to serialization:

```dart
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'baseAsset': baseAsset,
      'quoteAsset': quoteAsset,
      'status': status.value,
      'contractType': contractType,
      'onBoardDate': onBoardDate,
      'deliveryDate': deliveryDate,
      'deliveryTime': deliveryTime,
      'pricePrecision': pricePrecision,   // NEW
      'quantityPrecision': quantityPrecision, // NEW
    };
  }
```

- [ ] **Step 5: Analyze code for errors**

Run: `flutter analyze lib/services/exchange_info_service.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/services/exchange_info_service.dart
git commit -m "feat: add pricePrecision and quantityPrecision to FuturesSymbol"
```

---

## Task 2: Upgrade Database to v3

**Files:**
- Modify: `lib/services/database_helper.dart`

**Why:** Create futures_symbols table for storing contract data.

- [ ] **Step 1: Read current database helper**

Run: Read `lib/services/database_helper.dart`

- [ ] **Step 2: Update database version to 3**

Change line 13:

```dart
static const int _databaseVersion = 3;
```

- [ ] **Step 3: Add futures_symbols table creation**

Add to `_onCreate` method (after PumpHistory table, around line 67):

```dart
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
```

- [ ] **Step 4: Add migration logic in _onUpgrade**

Update `_onUpgrade` method:

```dart
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
      // 创建合约信息表
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
```

- [ ] **Step 5: Test database upgrade**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add lib/services/database_helper.dart
git commit -m "feat: add futures_symbols table to database (v3)"
```

---

## Task 3: Create ContractInfoService

**Files:**
- Create: `lib/services/contract_info_service.dart`

**Why:** Handle SQLite CRUD operations for futures_symbols table.

- [ ] **Step 1: Create ContractInfoService file**

Create new file with complete implementation:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'exchange_info_service.dart';

/// 合约信息数据库服务
class ContractInfoService {
  static const String _tableName = 'futures_symbols';
  static const int _batchSize = 100;

  final Database _db;
  final Map<String, FuturesSymbol> _cache = {};

  ContractInfoService._internal(this._db);

  /// 单例
  static ContractInfoService? _instance;
  static Future<ContractInfoService> get instance async {
    if (_instance == null) {
      final db = await DatabaseHelper.instance.database;
      _instance = ContractInfoService._internal(db);
    }
    return _instance!;
  }

  /// 批量插入或更新合约信息
  Future<int> upsertSymbols(List<FuturesSymbol> symbols) async {
    if (symbols.isEmpty) return 0;

    int successCount = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 分批处理
      for (int i = 0; i < symbols.length; i += _batchSize) {
        final batch = symbols.skip(i).take(_batchSize).toList();
        final batchResult = await _processBatch(batch, now);
        successCount += batchResult;
      }

      if (kDebugMode) {
        print('[ContractInfo] Upserted $successCount/${symbols.length} symbols');
      }
      return successCount;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfo] Upsert failed: $e');
      }
      return successCount;
    }
  }

  /// 处理一批数据
  Future<int> _processBatch(List<FuturesSymbol> batch, int timestamp) async {
    int count = 0;

    for (final symbol in batch) {
      try {
        await _db.insert(
          _tableName,
          _symbolToMap(symbol, timestamp),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        _cache[symbol.symbol] = symbol;
        count++;
      } catch (e) {
        if (kDebugMode) {
          print('[ContractInfo] Failed to insert ${symbol.symbol}: $e');
        }
      }
    }

    return count;
  }

  /// 将FuturesSymbol转换为数据库格式
  Map<String, dynamic> _symbolToMap(FuturesSymbol symbol, int timestamp) {
    return {
      'symbol': symbol.symbol,
      'base_asset': symbol.baseAsset,
      'quote_asset': symbol.quoteAsset,
      'status': symbol.status.value,
      'contract_type': symbol.contractType,
      'onboard_date': symbol.onBoardDate,
      'delivery_date': symbol.deliveryDate,
      'price_precision': symbol.pricePrecision,
      'quantity_precision': symbol.quantityPrecision,
      'updated_at': timestamp,
    };
  }

  /// 获取所有合约信息
  Future<List<FuturesSymbol>> getAllSymbols() async {
    try {
      final List<Map<String, dynamic>> maps = await _db.query(
        _tableName,
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => _mapToSymbol(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfo] Failed to get all symbols: $e');
      }
      return [];
    }
  }

  /// 获取可交易的合约
  Future<List<FuturesSymbol>> getTradableSymbols() async {
    try {
      final List<Map<String, dynamic>> maps = await _db.query(
        _tableName,
        where: 'status = ?',
        whereArgs: ['TRADING'],
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => _mapToSymbol(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfo] Failed to get tradable symbols: $e');
      }
      return [];
    }
  }

  /// 获取单个合约信息
  Future<FuturesSymbol?> getSymbol(String symbol) async {
    // 先查缓存
    if (_cache.containsKey(symbol)) {
      return _cache[symbol];
    }

    try {
      final List<Map<String, dynamic>> maps = await _db.query(
        _tableName,
        where: 'symbol = ?',
        whereArgs: [symbol],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final result = _mapToSymbol(maps.first);
        _cache[symbol] = result;
        return result;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfo] Failed to get symbol $symbol: $e');
      }
      return null;
    }
  }

  /// 从数据库映射到FuturesSymbol
  FuturesSymbol _mapToSymbol(Map<String, dynamic> map) {
    return FuturesSymbol(
      symbol: map['symbol'] as String,
      baseAsset: map['base_asset'] as String,
      quoteAsset: map['quote_asset'] as String,
      status: ContractStatusExtension.fromString(map['status'] as String),
      contractType: map['contract_type'] as String,
      onBoardDate: map['onboard_date'] as int,
      deliveryDate: map['delivery_date'] as int,
      deliveryTime: 0,
      pricePrecision: map['price_precision'] as int,
      quantityPrecision: map['quantity_precision'] as int,
    );
  }

  /// 获取统计信息
  Future<Map<String, int>> getStats() async {
    try {
      final totalResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName',
      );
      final tradingResult = await _db.rawQuery(
        "SELECT COUNT(*) as count FROM $_tableName WHERE status = 'TRADING'",
      );

      return {
        'total': totalResult.first['count'] as int,
        'trading': tradingResult.first['count'] as int,
      };
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfo] Failed to get stats: $e');
      }
      return {'total': 0, 'trading': 0};
    }
  }

  /// 清空所有数据
  Future<void> clearAll() async {
    try {
      await _db.delete(_tableName);
      _cache.clear();
      if (kDebugMode) {
        print('[ContractInfo] All data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfo] Failed to clear data: $e');
      }
    }
  }
}
```

- [ ] **Step 2: Verify no syntax errors**

Run: `flutter analyze lib/services/contract_info_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/contract_info_service.dart
git commit -m "feat: add ContractInfoService for SQLite operations"
```

---

## Task 4: Create ContractSyncSettings

**Files:**
- Create: `lib/services/contract_sync_settings.dart`

**Why:** Manage sync toggle state using SharedPreferences.

- [ ] **Step 1: Create ContractSyncSettings file**

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// 合约同步设置
class ContractSyncSettings {
  static const String _keyAutoSyncEnabled = 'contract_auto_sync_enabled';

  bool _autoSyncEnabled = false;

  bool get autoSyncEnabled => _autoSyncEnabled;

  /// 单例
  static final ContractSyncSettings _instance = ContractSyncSettings._internal();
  static ContractSyncSettings get instance => _instance;
  factory ContractSyncSettings() => _instance;

  ContractSyncSettings._internal() {
    _loadSettings();
  }

  /// 从SharedPreferences加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSyncEnabled = prefs.getBool(_keyAutoSyncEnabled) ?? false;
    } catch (e) {
      _autoSyncEnabled = false;
    }
  }

  /// 设置自动同步开关
  Future<void> setAutoSyncEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoSyncEnabled, enabled);
      _autoSyncEnabled = enabled;
    } catch (e) {
      // 保存失败，更新内存状态
      _autoSyncEnabled = enabled;
    }
  }

  /// 初始化设置（在app启动时调用）
  Future<void> init() async {
    await _loadSettings();
  }
}
```

- [ ] **Step 2: Verify no syntax errors**

Run: `flutter analyze lib/services/contract_sync_settings.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/contract_sync_settings.dart
git commit -m "feat: add ContractSyncSettings for sync toggle management"
```

---

## Task 5: Create ContractSyncService

**Files:**
- Create: `lib/services/contract_sync_service.dart`

**Why:** Orchestrate sync operations with hourly timer.

- [ ] **Step 1: Create ContractSyncService file**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'exchange_info_service.dart';
import 'contract_info_service.dart';
import 'contract_sync_settings.dart';

/// 同步状态
enum SyncStatus {
  idle,
  syncing,
  error,
}

/// 合约同步服务
class ContractSyncService {
  Timer? _syncTimer;
  SyncStatus _status = SyncStatus.idle;
  final Duration _syncInterval = const Duration(hours: 1);

  /// 单例
  static final ContractSyncService _instance = ContractSyncService._internal();
  static ContractSyncService get instance => _instance;
  factory ContractSyncService() => _instance;

  ContractSyncService._internal();

  SyncStatus get status => _status;

  /// 启动同步
  Future<void> startSync() async {
    if (_syncTimer != null && _syncTimer!.isActive) {
      if (kDebugMode) {
        print('[ContractSync] Already running, skipping');
      }
      return;
    }

    if (kDebugMode) {
      print('[ContractSync] Starting sync service');
    }

    // 立即执行一次同步
    await performSync();

    // 启动定时器
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      performSync();
    });
  }

  /// 停止同步
  void stopSync() {
    if (kDebugMode) {
      print('[ContractSync] Stopping sync service');
    }
    _syncTimer?.cancel();
    _syncTimer = null;
    _status = SyncStatus.idle;
  }

  /// 执行一次同步
  Future<void> performSync() async {
    if (_status == SyncStatus.syncing) {
      if (kDebugMode) {
        print('[ContractSync] Already syncing, skipping');
      }
      return;
    }

    _status = SyncStatus.syncing;

    try {
      if (kDebugMode) {
        print('[ContractSync] Starting sync...');
      }

      // 确保ExchangeInfoService已初始化
      if (!ExchangeInfoService.instance.isInitialized) {
        // 等待ExchangeInfoService初始化完成（最多5秒）
        int attempts = 0;
        while (!ExchangeInfoService.instance.isInitialized && attempts < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
        if (!ExchangeInfoService.instance.isInitialized) {
          if (kDebugMode) {
            print('[ContractSync] ExchangeInfoService not initialized, aborting');
          }
          _status = SyncStatus.error;
          return;
        }
      }

      // 获取合约信息
      final symbols = ExchangeInfoService.instance.symbols.values.toList();

      if (symbols.isEmpty) {
        if (kDebugMode) {
          print('[ContractSync] No symbols found from ExchangeInfoService');
        }
        _status = SyncStatus.error;
        return;
      }

      // 存储到数据库
      final contractService = await ContractInfoService.instance;
      final count = await contractService.upsertSymbols(symbols);

      // 获取统计信息
      final stats = await contractService.getStats();

      if (kDebugMode) {
        print('[ContractSync] Sync completed: $count records, '
              'total=${stats['total']}, trading=${stats['trading']}');
      }

      _status = SyncStatus.idle;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractSync] Sync failed: $e');
      }
      _status = SyncStatus.error;
    }
  }

  /// 检查是否正在运行
  bool get isRunning => _syncTimer != null && _syncTimer!.isActive;

  /// 释放资源
  void dispose() {
    stopSync();
  }
}
```

- [ ] **Step 2: Verify no syntax errors**

Run: `flutter analyze lib/services/contract_sync_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/contract_sync_service.dart
git commit -m "feat: add ContractSyncService with hourly timer"
```

---

## Task 6: Update ProfileScreen UI

**Files:**
- Modify: `lib/screens/profile_screen.dart`
- Insert position: After "快速上涨设置" Card section, before "测试功能" section (find `// 测试部分` comment)

**Why:** Add the contract sync toggle UI.

- [ ] **Step 1: Add import statements**

Add to imports section (around line 9):

```dart
import '../services/contract_sync_settings.dart';
import '../services/contract_sync_service.dart';
```

- [ ] **Step 2: Add contract sync section UI**

Insert after "快速上涨设置" Card (after line 181):

```dart
          const SizedBox(height: 32),
          // 合约信息管理部分
          _buildSectionHeader('合约信息管理'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: StreamBuilder<bool>(
              stream: Stream.periodic(
                const Duration(seconds: 1),
                (_) => ContractSyncSettings.instance.autoSyncEnabled,
              ),
              initialData: ContractSyncSettings.instance.autoSyncEnabled,
              builder: (context, snapshot) {
                final enabled = snapshot.data ?? false;
                return SwitchListTile(
                  title: const Text('自动同步合约信息'),
                  subtitle: Text(enabled ? '每小时自动同步' : '已关闭'),
                  value: enabled,
                  onChanged: (value) async {
                    await ContractSyncSettings.instance.setAutoSyncEnabled(value);
                    if (value) {
                      ContractSyncService.instance.startSync();
                    } else {
                      ContractSyncService.instance.stopSync();
                    }
                    setState(() {});
                  },
                );
              },
            ),
          ),
```

- [ ] **Step 3: Simplify UI (without StreamBuilder)**

Better approach - use direct state:

```dart
          const SizedBox(height: 32),
          // 合约信息管理部分
          _buildSectionHeader('合约信息管理'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              title: const Text('自动同步合约信息'),
              subtitle: Text(
                ContractSyncSettings.instance.autoSyncEnabled
                    ? '每小时自动同步'
                    : '已关闭',
              ),
              value: ContractSyncSettings.instance.autoSyncEnabled,
              onChanged: (value) async {
                await ContractSyncSettings.instance.setAutoSyncEnabled(value);
                if (value) {
                  ContractSyncService.instance.startSync();
                } else {
                  ContractSyncService.instance.stopSync();
                }
                setState(() {});
              },
            ),
          ),
```

- [ ] **Step 4: Verify no syntax errors**

Run: `flutter analyze lib/screens/profile_screen.dart`
Expected: No issues found

- [ ] **Step 5: Test UI renders**

Run: `flutter run`
Expected: Profile screen shows new section with toggle

- [ ] **Step 6: Commit**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add contract sync toggle to ProfileScreen"
```

---

## Task 7: Initialize Sync on App Start

**Files:**
- Modify: `lib/main.dart`

**Why:** Auto-start sync if setting is enabled when app launches.

- [ ] **Step 1: Read current main.dart**

Run: Read `lib/main.dart`

- [ ] **Step 2: Add initialization in main()**

Find the services initialization section (after `FavoriteService().initialize()` around line 271, before `PumpBackgroundService.initialize()` around line 274). Add:

```dart
  // Initialize contract sync settings
  await ContractSyncSettings.instance.init();

  // Auto-start sync if enabled
  if (ContractSyncSettings.instance.autoSyncEnabled) {
    ContractSyncService.instance.startSync();
  }
```

Also add imports at top:

```dart
import 'services/contract_sync_settings.dart';
import 'services/contract_sync_service.dart';
```

- [ ] **Step 3: Verify app builds**

Run: `flutter build apk --debug`
Expected: Build succeeds

- [ ] **Step 4: Test auto-start**

Run: `flutter run`
1. Enable sync toggle in Profile
2. Close app
3. Reopen app
Expected: Sync auto-starts

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: auto-start contract sync on app launch"
```

---

## Task 8: Integration Testing

**Files:**
- All modified/new files

**Why:** Verify the complete feature works end-to-end.

- [ ] **Step 1: Test toggle functionality**

1. Launch app
2. Navigate to Profile screen
3. Find "合约信息管理" section
4. Toggle switch ON

Expected: Switch turns on, subtitle shows "每小时自动同步"

- [ ] **Step 2: Test immediate sync**

After toggling ON:

Run: Check logs for `[ContractSync] Starting sync...` and `[ContractSync] Sync completed`

Expected: Sync executes immediately

- [ ] **Step 3: Test database storage**

Run: Add temporary debug code or use SQLite viewer

```dart
// Add to ContractInfoService temporarily for testing:
final stats = await ContractInfoService.instance.getStats();
print('DB stats: total=${stats['total']}, trading=${stats['trading']}');
```

Expected: futures_symbols table contains records, stats show non-zero values

- [ ] **Step 4: Test toggle OFF**

Toggle switch OFF

Expected: Timer stops, no further syncs occur

- [ ] **Step 5: Test persistence**

1. Enable sync
2. Close app completely
3. Reopen app

Expected: Sync resumes automatically

- [ ] **Step 6: Test error handling**

Turn off network, then enable sync

Expected: Error logged, app doesn't crash

- [ ] **Step 7: Commit final fixes**

```bash
git add -A
git commit -m "fix: integration test adjustments"
```

---

## Task 9: Documentation Update

**Files:**
- Create: `docs/contract-management.md` (optional)

- [ ] **Step 1: Create usage documentation**

```markdown
# Contract Management Feature

## Overview
Automatically syncs Binance futures contract information to local SQLite database.

## Usage
1. Go to "我" (Profile) screen
2. Find "合约信息管理" section
3. Toggle "自动同步合约信息" to enable

## Data Storage
- Table: `futures_symbols`
- Sync frequency: Every hour
- Conflict resolution: INSERT OR REPLACE on symbol
```

- [ ] **Step 2: Commit documentation**

```bash
git add docs/contract-management.md
git commit -m "docs: add contract management feature documentation"
```

---

## Completion Checklist

- [ ] All tests pass
- [ ] No linter warnings
- [ ] Feature tested on device/emulator
- [ ] Code follows project patterns
- [ ] All commits pushed

---

## Notes

- The sync runs every hour via Timer.periodic
- ExchangeInfoService must be initialized before sync
- Batch size of 100 prevents memory issues
- Internal sync status (idle/syncing/error) is for debugging only
- UI doesn't show sync status per requirements
