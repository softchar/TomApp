# 反弹监控 5 秒重检测 + 持久化 + 进列表通知 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让合约反弹监控页的精跟标的每 5 秒重新检测、列表信号持久化不丢失、每行显示触发时间、新信号进列表(score≥70)即推送手机通知。

**Architecture:** 抽公共 `_evaluateWindow` 供收盘事件与 5 秒定时器共用；新增 `rebound_signals` 表 + `ReboundSignalRepository` 持久化列表信号（仅低频路径写库）；通知触发点从 alertService 显式调用改为 `ReboundScoreProvider` 的"首次进列表"跃迁回调，scan/收盘/5秒重评估三路径统一。

**Tech Stack:** Flutter 3.24 / Dart 3.6、provider、sqflite（v5→v6）、sqflite_common_ffi（测试）、flutter_local_notifications（已接入）。

**Spec:** `docs/superpowers/specs/2026-07-01-rebound-5s-persist-notify-design.md`

---

## File Structure

| 文件 | 责任 | 动作 |
|---|---|---|
| `lib/services/database_helper.dart` | v6 建 `rebound_signals` 表 | Modify |
| `lib/services/rebound/rebound_signal_repository.dart` | 列表信号 upsert/delete/queryListed | **Create** |
| `lib/models/rebound_signal.dart` | 无需改（已有 `timestamp`/`isLatestBar`） | — |
| `lib/providers/rebound_score_provider.dart` | repo 注入 + `loadSignals` + `upsert(persist:)` + `onSignalListed` 跃迁 | Modify |
| `lib/services/rebound/rebound_alert_service.dart` | `_evaluateWindow` 公共方法 + 5 秒定时器 + `untrackSymbol` 不删信号 + `_dispatchListed` | Modify |
| `lib/screens/rebound_dashboard_screen.dart` | 注入 repo + `loadSignals` + `_SignalRow` 时间列 + 移除 `notifyOnSignal` 调用 | Modify |
| `test/services/rebound_signal_repository_test.dart` | 仓库 CRUD | **Create** |
| `test/providers/rebound_score_provider_test.dart` | 新增持久化 + 跃迁测试 | Modify |
| `test/services/rebound_alert_service_test.dart` | 重写通知组为跃迁触发 + 5 秒重评估 | Modify |

**关于 `ReboundSignal.confluenceFilters`**：DB 不存该 Set（展示不用）；`queryListed` 重建时传 `const {}`，不影响 UI。

---

## Task 1: DatabaseHelper v6 — rebound_signals 表

**Files:**
- Modify: `lib/services/database_helper.dart`
- Test: `test/services/database_helper_test.dart`

- [ ] **Step 1: 改 version 常量 + 注释**

`lib/services/database_helper.dart` 第 21-22 行：

```dart
  // v4：drift 管理的 klines/backtest_runs/backtest_trades；
  // v5：rebound_notifications（通知历史）；
  // v6：rebound_signals（看板列表信号持久化）。
  static const int _databaseVersion = 6;
```

- [ ] **Step 2: 加建表方法**

在 `_createReboundNotificationsTable` 方法之后追加：

```dart
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
```

- [ ] **Step 3: onCreate 调用**

`_onCreate` 末尾（`_createReboundNotificationsTable(db);` 之后）加：

```dart
    // v6：看板列表信号表（onCreate 全新安装路径）。
    await _createReboundSignalsTable(db);
```

- [ ] **Step 4: onUpgrade 调用**

`_onUpgrade` 末尾（`if (oldVersion < 5)` 块之后）加：

```dart
    if (oldVersion < 6) {
      // v6：看板列表信号表（onUpgrade 升级路径）。
      await _createReboundSignalsTable(db);
    }
```

- [ ] **Step 5: 更新测试断言 version**

`test/services/database_helper_test.dart` 第 13-15 行：

```dart
    test('databaseVersion is v6（含反弹通知历史表 + 列表信号表）', () {
      expect(DatabaseHelper.currentVersion, 6);
    });
```

- [ ] **Step 6: 运行测试**

Run: `flutter test test/services/database_helper_test.dart`
Expected: PASS（2 tests）

- [ ] **Step 7: Commit**

```bash
git add lib/services/database_helper.dart test/services/database_helper_test.dart
git commit -m "feat(rebound): v6 rebound_signals 表持久化列表信号"
```

---

## Task 2: ReboundSignalRepository（新）

**Files:**
- Create: `lib/services/rebound/rebound_signal_repository.dart`
- Test: `test/services/rebound_signal_repository_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/services/rebound_signal_repository_test.dart`：

```dart
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
    // 触发 onCreate（v6 含 rebound_signals 表）
    await helper.database;
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

    test('isLatestBar 0/1 正确往返', () async {
      await repo.upsert(_sig('A')..copyWith(isLatestBar: false));
      // 直接验证 isLatestBar=false 写入读回仍 false
      await repo.upsert(_sig('BTCUSDT')..copyWith(isLatestBar: false));
      final listed = await repo.queryListed(0, 50);
      expect(listed.firstWhere((s) => s.symbol == 'BTCUSDT').isLatestBar, false);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/services/rebound_signal_repository_test.dart`
Expected: FAIL（`rebound_signal_repository.dart` 不存在 / `ReboundSignalRepository` 未定义）

- [ ] **Step 3: 写实现**

Create `lib/services/rebound/rebound_signal_repository.dart`：

```dart
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/database_helper.dart';

/// 看板列表信号仓库（sqflite `rebound_signals` 表，v6）。
///
/// 由 [ReboundScoreProvider] 在低频路径（收盘/扫描命中）写库、启动时读回。
/// 与 [ReboundNotificationRepository]（仅已通知的高分记录）的区别：
/// 本仓库存"进列表(score≥70)"的全部信号，范围更大。
class ReboundSignalRepository {
  static const String _table = 'rebound_signals';

  final DatabaseHelper _helper;

  /// [helper] 可注入便于测试；默认用单例。
  ReboundSignalRepository([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  /// 插入或覆盖一条信号（PK: symbol+timeframe）。
  Future<void> upsert(ReboundSignal signal) async {
    final db = await _helper.database;
    await db.insert(
      _table,
      {
        'symbol': signal.symbol,
        'timeframe': signal.timeframe,
        'score': signal.score,
        'deadCatRiskScore': signal.deadCatRiskScore,
        'dropMagnitude': signal.dropMagnitude,
        'recoveryRatio': signal.recoveryRatio,
        'entryPrice': signal.entryPrice,
        'swingLowPrice': signal.swingLowPrice,
        'swingHighPrice': signal.swingHighPrice,
        'dropStartIndex': signal.dropStartIndex,
        'dropEndIndex': signal.dropEndIndex,
        'recoveryEndIndex': signal.recoveryEndIndex,
        'isLatestBar': signal.isLatestBar ? 1 : 0,
        'klineCloseTime': signal.timestamp.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除指定 (symbol, timeframe)。
  Future<void> delete(String symbol, String timeframe) async {
    final db = await _helper.database;
    await db.delete(
      _table,
      where: 'symbol = ? AND timeframe = ?',
      whereArgs: [symbol, timeframe],
    );
  }

  /// 按 score 降序返回 ≥ [minScore] 的信号（最多 [limit] 条）。
  Future<List<ReboundSignal>> queryListed(int minScore, int limit) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'score >= ?',
      whereArgs: [minScore],
      orderBy: 'score DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  ReboundSignal _fromRow(Map<String, Object?> row) => ReboundSignal(
        symbol: row['symbol'] as String,
        timeframe: row['timeframe'] as String,
        dropMagnitude: (row['dropMagnitude'] as num).toDouble(),
        recoveryRatio: (row['recoveryRatio'] as num).toDouble(),
        speed: 0, // 不持久化（展示不用），重建默认 0
        confluenceFilters: const {}, // 不持久化
        score: (row['score'] as num).toInt(),
        deadCatRiskScore: (row['deadCatRiskScore'] as num).toInt(),
        entryPrice: (row['entryPrice'] as num).toDouble(),
        swingLowPrice: (row['swingLowPrice'] as num).toDouble(),
        swingHighPrice: (row['swingHighPrice'] as num).toDouble(),
        dropStartIndex: (row['dropStartIndex'] as num).toInt(),
        dropEndIndex: (row['dropEndIndex'] as num).toInt(),
        recoveryEndIndex: (row['recoveryEndIndex'] as num).toInt(),
        isLatestBar: (row['isLatestBar'] as int) == 1,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(row['klineCloseTime'] as int),
      );
}
```

需在文件顶部加 import：`import 'package:sqflite/sqflite.dart';`（用于 `ConflictAlgorithm`）。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/services/rebound_signal_repository_test.dart`
Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add lib/services/rebound/rebound_signal_repository.dart test/services/rebound_signal_repository_test.dart
git commit -m "feat(rebound): ReboundSignalRepository 列表信号持久化"
```

---

## Task 3: Provider — repo 注入 + loadSignals + upsert(persist) + onSignalListed 跃迁

**Files:**
- Modify: `lib/providers/rebound_score_provider.dart`
- Test: `test/providers/rebound_score_provider_test.dart`

- [ ] **Step 1: 写失败测试**

在 `test/providers/rebound_score_provider_test.dart` 末尾（`_notifRecord` helper 之前）追加新 group：

```dart
  group('列表信号持久化', () {
    test('upsert(persist:true) 写库；loadSignals 读回', () async {
      final saved = <ReboundSignal>[];
      final inserted = <ReboundSignal>[];
      final p = ReboundScoreProvider(
        signalRepository: _FakeSignalRepo(
          onUpsert: inserted.add,
          queryListed: (_, __) async => saved,
        ),
      );
      p.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m', score: 85),
          persist: true);
      expect(inserted, hasLength(1));

      saved.add(_signal('BTCUSDT', '15m', score: 85));
      final p2 = ReboundScoreProvider(
        signalRepository: _FakeSignalRepo(queryListed: (_, __) async => saved),
      );
      await p2.loadSignals((_) async => saved);
      expect(p2.getSignal('BTCUSDT', '15m'), isNotNull);
      p.dispose();
      p2.dispose();
    });

    test('upsert(persist:false) 不写库', () {
      final inserted = <ReboundSignal>[];
      final p = ReboundScoreProvider(
        signalRepository: _FakeSignalRepo(onUpsert: inserted.add),
      );
      p.upsert('BTCUSDT', '15m', _signal('BTCUSDT', '15m'),
          persist: false);
      expect(inserted, isEmpty);
      p.dispose();
    });
  });

  group('onSignalListed 跃迁回调', () {
    ReboundSignal _s(int score) => _signal('X', '15m', score: score);

    test('null → ≥70 触发回调', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', _s(72));
      expect(listed, hasLength(1));
      expect(listed.first.score, 72);
      p.dispose();
    });

    test('<70 → ≥70 触发回调', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', _s(60));
      p.upsert('X', '15m', _s(75));
      expect(listed, hasLength(1), reason: '仅跨越 70 线那次触发');
      p.dispose();
    });

    test('≥70 → ≥70 不触发（已在列表）', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', _s(72));
      p.upsert('X', '15m', _s(80));
      expect(listed, hasLength(1), reason: '第二次仍在列表，不重复触发');
      p.dispose();
    });

    test('<70 不触发', () {
      final listed = <ReboundSignal>[];
      final p = ReboundScoreProvider()..onSignalListed = listed.add;
      p.upsert('X', '15m', _s(60));
      expect(listed, isEmpty);
      p.dispose();
    });
  });
```

并在文件底部（`_notifRecord` 之后）加 fake repo：

```dart
class _FakeSignalRepo {
  final void Function(ReboundSignal)? onUpsert;
  final Future<List<ReboundSignal>> Function(int minScore, int limit)?
      queryListed;
  _FakeSignalRepo({this.onUpsert, this.queryListed});
}
```

> 注：`_FakeSignalRepo` 是鸭子类型 stub——provider 仅依赖 `onUpsert`/`queryListed` 字段（见 Step 3 实现，repository 作 `dynamic` 或提取接口）。若用强类型，改为 `implements` 一个抽象接口。下方 Step 3 采用**抽象接口**方案以保证类型安全。

**修正 Step 1（类型安全版）**：先在 Step 3 定义 `abstract class ReboundSignalRepositoryInterface`，fake 用 `implements`。重写 `_FakeSignalRepo`：

```dart
class _FakeSignalRepo implements ReboundSignalRepositoryInterface {
  final List<ReboundSignal> inserted = [];
  final List<ReboundSignal> seed;
  _FakeSignalRepo({this.seed = const []});
  @override
  Future<void> upsert(ReboundSignal s) async => inserted.add(s);
  @override
  Future<void> delete(String s, String t) async {}
  @override
  Future<List<ReboundSignal>> queryListed(int minScore, int limit) async =>
      seed.where((s) => s.score >= minScore).toList();
}
```

并把上面测试里 `signalRepository:` 改为传 `_FakeSignalRepo(seed: [...])`，断言 `inserted`。`loadSignals` 直接调 `repo.queryListed`，所以测试用 seed。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/providers/rebound_score_provider_test.dart`
Expected: FAIL（`signalRepository` 参数 / `onSignalListed` / `persist` 参数 不存在）

- [ ] **Step 3: 实现 — 抽接口**

在 `lib/services/rebound/rebound_signal_repository.dart` 顶部加抽象接口（让 `ReboundSignalRepository` implements 它，便于测试 mock）：

```dart
/// 仓库抽象接口（便于测试注入 fake）。
abstract class ReboundSignalRepositoryInterface {
  Future<void> upsert(ReboundSignal signal);
  Future<void> delete(String symbol, String timeframe);
  Future<List<ReboundSignal>> queryListed(int minScore, int limit);
}
```

把 `class ReboundSignalRepository` 改为 `class ReboundSignalRepository implements ReboundSignalRepositoryInterface`。三个方法加 `@override`。

- [ ] **Step 4: 实现 — Provider 改造**

`lib/providers/rebound_score_provider.dart`：

顶部加 import：
```dart
import 'package:tomapp/services/rebound/rebound_signal_repository.dart';
```

`_signalsBySymbol` 字段附近加：
```dart
  /// 列表信号仓库（可选；注入后低频路径写库 + 启动恢复）。
  final ReboundSignalRepositoryInterface? _signalRepo;

  /// 进列表门槛：score≥此值视为"在列表"，触发 [onSignalListed]。
  static const int listedThreshold = 70;

  /// 信号首次进列表(score≥70)回调（alertService 注入以触发通知）。
  void Function(ReboundSignal)? onSignalListed;
```

改构造函数（当前是隐式 `ReboundScoreProvider()`）→ 显式：
```dart
  ReboundScoreProvider({ReboundSignalRepositoryInterface? signalRepository})
      : _signalRepo = signalRepository;
```

改 `upsert` 签名 + 实现（第 108-117 行）：
```dart
  /// 更新单个信号 + 通知监听者。
  ///
  /// [recentCloses]：可选 sparkline 数据。
  /// [persist]：true 时写库（仅收盘/扫描命中低频路径传 true；5 秒重评估传 false）。
  void upsert(String symbol, String tf, ReboundSignal? signal,
      {List<double>? recentCloses, bool persist = false}) {
    final old = _signalsBySymbol[symbol]?[tf];
    _signalsBySymbol.putIfAbsent(symbol, () => {});
    _signalsBySymbol[symbol]![tf] = signal;

    // 跃迁检测：旧值不在列表（null 或 <listedThreshold）且新值进列表 → 触发回调
    if (signal != null &&
        signal.score >= listedThreshold &&
        (old == null || old.score < listedThreshold)) {
      onSignalListed?.call(signal);
    }

    // 持久化（低频路径）
    if (_signalRepo != null) {
      if (signal != null) {
        if (persist) _signalRepo!.upsert(signal);
      } else {
        _signalRepo!.delete(symbol, tf);
      }
    }

    if (recentCloses != null) {
      _recentClosesBySymbol.putIfAbsent(symbol, () => {});
      _recentClosesBySymbol[symbol]![tf] = recentCloses;
    }
    notifyListeners();
  }
```

加 `loadSignals`（在 `loadNotificationHistory` 之后）：
```dart
  /// 从持久化恢复列表信号（启动调）。
  Future<void> loadSignals(
      Future<List<ReboundSignal>> Function(int minScore, int limit) loader) async {
    final loaded = await loader(listedThreshold, 100);
    for (final s in loaded) {
      _signalsBySymbol.putIfAbsent(s.symbol, () => {});
      _signalsBySymbol[s.symbol]![s.timeframe] = s;
    }
    notifyListeners();
  }
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/providers/rebound_score_provider_test.dart`
Expected: PASS（原有 + 新增全部）

> 若原有测试因构造函数变更报错（如 `ReboundScoreProvider()` 仍可用——named param 有默认值，OK）。

- [ ] **Step 6: Commit**

```bash
git add lib/providers/rebound_score_provider.dart lib/services/rebound/rebound_signal_repository.dart test/providers/rebound_score_provider_test.dart
git commit -m "feat(rebound): provider 持久化 + 进列表跃迁回调"
```

---

## Task 4: AlertService — _evaluateWindow + 5 秒定时器 + untrackSymbol 不删 + _dispatchListed

**Files:**
- Modify: `lib/services/rebound/rebound_alert_service.dart`
- Test: `test/services/rebound_alert_service_test.dart`

- [ ] **Step 1: 写失败测试（5 秒重评估 + 跃迁通知 + untrack 保留）**

在 `test/services/rebound_alert_service_test.dart` 的通知 group **替换**为下面两组（删除旧的"最新一根+high"group，因语义已变）：

```dart
  group('ReboundAlertService 进列表通知（provider 跃迁触发）', () {
    late _MockStreamService mockStream;
    late _SpyNotificationService notifSpy;
    late _SpyNotificationRepository repoSpy;
    late ReboundAlertService svc;

    setUp(() async {
      mockStream = _MockStreamService(BinanceApiService());
      notifSpy = _SpyNotificationService();
      repoSpy = _SpyNotificationRepository();
      svc = ReboundAlertService(
        streamService: mockStream,
        detector: detector,
        provider: provider,
        notificationService: notifSpy,
        notificationRepository: repoSpy,
      );
      await svc.start([]); // 注册 provider.onSignalListed = _dispatchListed
    });

    tearDown(() async => svc.stop());

    test('score≥70 首次进列表 → 推送 + 记录历史', () {
      provider.upsert('BTCUSDT', '15m', _highSignal('BTCUSDT'));
      expect(notifSpy.dispatched, hasLength(1));
      expect(repoSpy.inserted, hasLength(1));
      expect(provider.notificationHistory, hasLength(1));
    });

    test('score 70-74（medium 渠道）也推送', () {
      provider.upsert('X', '15m', _medListedSignal('X')); // score=72
      expect(notifSpy.dispatched, hasLength(1));
      expect(notifSpy.dispatched.first.level, AlertLevel.medium);
    });

    test('score<70 不推送', () {
      provider.upsert('Y', '15m', _medSignal('Y')); // score=60
      expect(notifSpy.dispatched, isEmpty);
    });

    test('isLatestBar=false 的 ≥70 信号仍推送（进列表即推）', () {
      provider.upsert('Z', '15m', _highSignal('Z', isLatestBar: false));
      expect(notifSpy.dispatched, hasLength(1));
    });

    test('同 symbol 4h 冷却：第二次进列表不重复推送', () {
      provider.upsert('A', '15m', _highSignal('A'));
      provider.upsert('B', '15m', _highSignal('A')); // 同 symbol 覆盖，已 in-list 不再触发跃迁
      // 跃迁只触发一次；即使触发，throttler 冷却也拦截
      expect(notifSpy.dispatched, hasLength(1));
    });
  });

  group('ReboundAlertService 5 秒重评估', () {
    test('reEvaluateTracked 对 tracked symbol 用 window 重检测 + upsert', () async {
      final mockStream = _MockStreamService(BinanceApiService());
      final svc = ReboundAlertService(
        streamService: mockStream,
        detector: detector,
        provider: provider,
        notificationRepository: _SpyNotificationRepository(),
      );
      final scanner = ReboundMarketScanner(
        fetchKlines: ({required symbol, required interval, required limit}) async => [],
        detector: detector,
        symbolsProvider: () async => [],
      );
      svc.attachScanner(scanner);
      await svc.start([]);
      scanner.onHits!({'ABCUSDT'});
      await Future<void>.delayed(Duration.zero);

      // 注入 V 型反弹 window（detector 会命中）
      mockStream.seededWindows['ABCUSDT'] = _vShapeWindow();
      await svc.reEvaluateTracked();

      expect(provider.getSignal('ABCUSDT', monitoredTimeframes.first), isNotNull,
          reason: '5 秒重评估应用最新 window 重新检测');
    });
  });

  group('ReboundAlertService untrackSymbol 保留信号', () {
    test('退出精跟不清 provider 信号', () async {
      final mockStream = _MockStreamService(BinanceApiService());
      final svc = ReboundAlertService(
        streamService: mockStream,
        detector: detector,
        provider: provider,
        notificationRepository: _SpyNotificationRepository(),
      );
      final scanner = ReboundMarketScanner(
        fetchKlines: ({required symbol, required interval, required limit}) async => [],
        detector: detector,
        symbolsProvider: () async => [],
      );
      svc.attachScanner(scanner);
      await svc.start([]);
      scanner.onHits!({'KEEPUSDT'});
      await Future<void>.delayed(Duration.zero);
      provider.upsert('KEEPUSDT', '15m', _makeSignal('KEEPUSDT', '15m'));

      await svc.untrackSymbol('KEEPUSDT');
      expect(svc.trackedCount, 0);
      expect(provider.getSignal('KEEPUSDT', '15m'), isNotNull,
          reason: '退出精跟后信号应保留');
    });
  });
```

在文件底部 helpers 区追加：
```dart
/// score=72（≥70 进列表，但分级为 medium 渠道）。
ReboundSignal _medListedSignal(String sym) => ReboundSignal(
      symbol: sym, timeframe: '15m',
      dropMagnitude: 2.5, recoveryRatio: 0.65, speed: 2,
      confluenceFilters: const {}, score: 72, deadCatRiskScore: 10,
      entryPrice: 100, swingLowPrice: 90, swingHighPrice: 100,
      dropStartIndex: 20, dropEndIndex: 22, recoveryEndIndex: 24,
      isLatestBar: true, timestamp: DateTime(2024),
    );

/// V 型反弹 window（稳定 → 下跌 → 回升），detector 应命中。
List<KlineData> _vShapeWindow() {
  final list = <KlineData>[];
  for (var i = 0; i < 20; i++) {
    list.add(KlineData(time: DateTime(2024, 1, 1, 0, i),
        open: 100, high: 101, low: 99, close: 100, volume: 10));
  }
  for (var i = 0; i < 3; i++) {
    list.add(KlineData(time: DateTime(2024, 1, 1, 0, 20 + i),
        open: 100 - i * 4.0, high: 101 - i * 4.0, low: 96 - i * 4.0,
        close: 97 - i * 4.0, volume: 10));
  }
  for (var i = 0; i < 2; i++) {
    list.add(KlineData(time: DateTime(2024, 1, 1, 0, 23 + i),
        open: 90 + i * 5.0, high: 95 + i * 5.0, low: 89 + i * 5.0,
        close: 95 + i * 5.0, volume: 20));
  }
  return list;
}
```

并在顶部 import 区确认有 `import 'package:tomapp/services/rebound/rebound_timeframes.dart';`（用 `monitoredTimeframes`）。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/services/rebound_alert_service_test.dart`
Expected: FAIL（`reEvaluateTracked` 不存在；`untrackSymbol` 仍清信号；通知组旧逻辑）

- [ ] **Step 3: 实现 — alertService 改造**

`lib/services/rebound/rebound_alert_service.dart`：

(a) 加 5 秒定时器字段（`_watchlistTimer` 附近）：
```dart
  /// 5 秒重评估定时器：对 tracked symbol 用最新 window 重新检测。
  Timer? _reEvalTimer;
  static const Duration _reEvalInterval = Duration(seconds: 5);
```

(b) `start()` 末尾（`_scanner?.start();` 之后）加：
```dart
    // 注册 provider 跃迁回调 → 统一通知触发点（scan/收盘/5秒重评估三路径）
    _provider.onSignalListed = _dispatchListed;
    // 5 秒重评估定时器
    _reEvalTimer = Timer.periodic(_reEvalInterval, (_) => reEvaluateTracked());
```

(c) `stop()` 内（`_scanner?.stop();` 之后）加：
```dart
    _reEvalTimer?.cancel();
    _reEvalTimer = null;
    _provider.onSignalListed = null;
```

(d) 抽 `_evaluateWindow` 公共方法 + 重写 `handleClosedKline` 调用它：

把现有 `handleClosedKline`（第 205-288 行）的步骤 3-7（detector 之后）抽到 `_evaluateWindow`。新结构：

```dart
  @visibleForTesting
  Future<void> handleClosedKline(ClosedKline c) async {
    // 1. warm-up 防护（保持原逻辑）
    if (_streamService.isWarmingUp(c.symbol, c.timeframe)) {
      if (!_warmingSymbols.contains(c.symbol)) {
        _warmingSymbols.add(c.symbol);
        _provider.updateWarmingUpSymbols(_warmingSymbols.toSet());
      }
      return;
    }
    if (_warmingSymbols.contains(c.symbol)) {
      final stillWarming = monitoredTimeframes.any(
        (tf) => _streamService.isWarmingUp(c.symbol, tf),
      );
      if (!stillWarming) {
        _warmingSymbols.remove(c.symbol);
        _provider.updateWarmingUpSymbols(_warmingSymbols.toSet());
      }
    }

    // 2. 取 window + 评估（isClosedEvent=true：写库 + missCount）
    final window = _streamService.windowOf(c.symbol, c.timeframe);
    if (window == null || window.isEmpty) return;
    await _evaluateWindow(c.symbol, c.timeframe, window, isClosedEvent: true);
  }

  /// 公共评估管线：detector → mtf 加分 → provider.upsert →（跃迁触发通知）。
  ///
  /// [isClosedEvent]：true=收盘事件路径（写库 + 更新 missCount）；
  /// false=5 秒重评估路径（只刷内存+UI，不写库，不算 missCount）。
  /// 通知不在本方法内——由 provider.upsert 的进列表跃迁统一触发 [_dispatchListed]。
  Future<void> _evaluateWindow(
    String symbol, String tf, List<KlineData> window, {
    required bool isClosedEvent,
  }) async {
    final rawSignal = _detector.evaluate(
      List<KlineData>.from(window), _params, symbol: symbol, timeframe: tf);
    final signal = rawSignal == null
        ? null
        : rawSignal.copyWith(
            isLatestBar: rawSignal.recoveryEndIndex == window.length - 1);

    _signalsBySymbol.putIfAbsent(symbol, () => {});
    _signalsBySymbol[symbol]![tf] = signal;

    final mtfScore = ReboundConfluenceScorer.scoreMultiTimeframe(
      _signalsBySymbol[symbol] ?? {});

    final closes = window.length > 20
        ? window.sublist(window.length - 20).map((k) => k.close).toList()
        : window.map((k) => k.close).toList();

    if (signal != null) {
      final enriched = signal.copyWith(
          score: (signal.score + mtfScore).clamp(0, 100));
      _provider.upsert(symbol, tf, enriched,
          recentCloses: closes, persist: isClosedEvent);
      if (isClosedEvent && _trackedSymbols.contains(symbol)) {
        _missCountBySymbol[symbol] = 0;
      }
    } else {
      _provider.upsert(symbol, tf, null,
          recentCloses: closes, persist: isClosedEvent);
      if (isClosedEvent && _trackedSymbols.contains(symbol)) {
        final count = (_missCountBySymbol[symbol] ?? 0) + 1;
        _missCountBySymbol[symbol] = count;
        if (count >= missThreshold) untrackSymbol(symbol);
      }
    }
  }

  /// 5 秒重评估：遍历 tracked symbols × timeframes，用最新 window 重新检测。
  /// 定时器在 start() 启动；本方法暴露供测试直接调用（不等 5 秒）。
  @visibleForTesting
  Future<void> reEvaluateTracked() async {
    for (final sym in List<String>.from(_trackedSymbols)) {
      for (final tf in monitoredTimeframes) {
        if (_streamService.isWarmingUp(sym, tf)) continue;
        final window = _streamService.windowOf(sym, tf);
        if (window == null || window.isEmpty) continue;
        await _evaluateWindow(sym, tf, window, isClosedEvent: false);
      }
    }
  }
```

(e) 改 `untrackSymbol`（第 131-137 行）——移除 `_provider.removeSymbol`：
```dart
  /// 退出精跟：unsubscribe + 清未命中计数。
  /// **不删 provider 信号**（per 需求：列表数据运行中不丢失）；
  /// 信号仅在 scanner/收盘路径 upsert(null) 且跌破门槛时移除。
  Future<void> untrackSymbol(String symbol) async {
    _trackedSymbols.remove(symbol);
    _streamService.unsubscribe([symbol]);
    _missCountBySymbol.remove(symbol);
  }
```

(f) 替换通知方法——删 `_dispatchIfHigh` + `notifyOnSignal`，加 `_dispatchListed`：

删除原 `notifyOnSignal`（第 295-297 行）和 `_dispatchIfHigh`（第 305-335 行），替换为：

```dart
  /// 进列表通知：由 provider.onSignalListed 跃迁回调触发。
  ///
  /// 跑 [AlertThrottler] 冷却(4h)+日上限+跨日重置（分级仅选渠道 high/med）；
  /// decision 非空 → 推送 + 写历史。输入信号均 score≥70（必过 medium 分级）。
  /// 不再要求 isLatestBar（进列表即推）。
  Future<void> _dispatchListed(ReboundSignal signal) async {
    final toggles = _alertSettings?.timeframeToggles ??
        {for (final tf in monitoredTimeframes) tf: true};
    final highTh = _alertSettings?.highThreshold ?? 75;
    final medTh = _alertSettings?.medThreshold ?? 50;

    final decision = _throttler?.evaluate(
      signal,
      timeframeToggles: toggles,
      highThreshold: highTh,
      medThreshold: medTh,
    );
    if (decision == null) return;

    await _notificationService.dispatch(decision);
    final now = DateTime.now();
    await _notificationRepository.insert(signal, notifiedAt: now);
    _provider.addNotificationHistory(ReboundNotificationRecord(
      symbol: signal.symbol,
      timeframe: signal.timeframe,
      score: signal.score,
      deadCatRiskScore: signal.deadCatRiskScore,
      dropMagnitude: signal.dropMagnitude,
      recoveryRatio: signal.recoveryRatio,
      notifiedAt: now,
    ));
  }
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/services/rebound_alert_service_test.dart`
Expected: PASS（原有保留的 + 新增三组全部）

> 若旧"通知"group 残留引用 `_highSignal` 的 isLatestBar 断言报错，确认已删除整组。

- [ ] **Step 5: Commit**

```bash
git add lib/services/rebound/rebound_alert_service.dart test/services/rebound_alert_service_test.dart
git commit -m "feat(rebound): 5 秒重评估 + 进列表跃迁通知 + untrack 保留信号"
```

---

## Task 5: Dashboard — 注入 repo + loadSignals + 时间列 + 移除 notifyOnSignal

**Files:**
- Modify: `lib/screens/rebound_dashboard_screen.dart`

- [ ] **Step 1: 注入 repo + loadSignals**

`_startAlertService` 内（第 73 行 `_notificationRepository = ...` 之后）加：
```dart
      final signalRepository = ReboundSignalRepository();
      provider.setSignalRepository(signalRepository); // 允许后注入（见 Step 2）
```

并在 `_alertService!.start([])` 之前（第 140 行附近）、`loadNotificationHistory` 旁边加：
```dart
      await provider.loadSignals(signalRepository.queryListed);
```

> 注：provider 的 `_signalRepo` 若改在构造时注入则无需 setter；但 dashboard 拿到 provider 是 `context.read`（已构造）。两选一：
> - 方案 A：provider 加 `setSignalRepository(repo)` setter。
> - 方案 B：dashboard 不注入，provider 构造时自己 `new ReboundSignalRepository()`。
>
> **采用方案 A**（DI 更可测，见 Step 2）。在 `loadSignals` 之前调 `setSignalRepository`。

- [ ] **Step 2: provider 加 setter（若 Task 3 未加）**

`lib/providers/rebound_score_provider.dart` 加：
```dart
  /// 后注入仓库（dashboard 在 _startAlertService 里拿到 provider 后调用）。
  void setSignalRepository(ReboundSignalRepositoryInterface repo) {
    // 字段需改为非 final：把 _signalRepo 声明从 final 去掉
  }
```
实际：把 `final ReboundSignalRepositoryInterface? _signalRepo;` 改为 `ReboundSignalRepositoryInterface? _signalRepo;`，加 setter 方法体 `_signalRepo = repo;`。

在 dashboard import 区加：`import 'package:tomapp/services/rebound/rebound_signal_repository.dart';`（若未引）。

- [ ] **Step 3: 移除 onScanComplete 里的 notifyOnSignal 调用**

第 129 行 `_alertService!.notifyOnSignal(enriched);` **删除**（通知改由 upsert 跃迁触发）。同时把该 upsert 改为 `persist: true`：
```dart
                provider.upsert(symEntry.key, tfEntry.key, enriched, persist: true);
```
（第 126 行原 `provider.upsert(symEntry.key, tfEntry.key, enriched);` 加 `persist: true`）

- [ ] **Step 4: _SignalRow 加触发时间列**

`_SignalRow.build`（第 562-578 行）"币种" SizedBox 之后插入时间列：

```dart
              const SizedBox(width: 4),
              // 触发时间（K 线收盘时间）
              SizedBox(
                width: 36,
                child: Text(
                  '${signal.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${signal.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
              ),
```

币种列宽从 48 缩到 40 以腾空间（第 567 行 `width: 48` → `width: 40`）。

- [ ] **Step 5: 运行全量测试确认无回归**

Run: `flutter test`
Expected: PASS（全部）

> dashboard 为 UI，无单测；时间列与 repo 注入手动验证（Task 7）。

- [ ] **Step 6: Commit**

```bash
git add lib/screens/rebound_dashboard_screen.dart lib/providers/rebound_score_provider.dart
git commit -m "feat(rebound): dashboard 注入持久化 + 触发时间列 + 通知由跃迁触发"
```

---

## Task 6: 全量回归 + 静态分析

- [ ] **Step 1: flutter analyze**

Run: `flutter analyze lib/services/rebound lib/providers/rebound_score_provider.dart lib/screens/rebound_dashboard_screen.dart`
Expected: No issues

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: ALL PASS

- [ ] **Step 3: 修复任何回归**（如有）

---

## Task 7: 手动验证清单（真机/模拟器）

> 桌面 ffi 测的是逻辑；以下需在 Android 真机/模拟器验证 UI 与通知。

- [ ] 启动 app → 反弹监控页：首轮扫描后列表出现 ≥70 分信号，每行显示 **HH:MM 触发时间**。
- [ ] 等待 5 秒：精跟标的的评分/价格**每 5 秒刷新**（无需等 15m K 线收盘）。
- [ ] 新信号进列表时：**手机收到系统通知**（high 渠道响铃+震动，或 med 渠道横幅）。
- [ ] 杀掉 app 重启：**列表信号恢复**（从 `rebound_signals` 表读回），历史区域通知记录也在。
- [ ] 同 symbol 4h 内不重复通知（冷却生效）。
- [ ] 字段说明对话框（? 图标）打开正常。

---

## 不做（YAGNI / 超范围）

- 不改 `scanInterval`（60s，限流约束）。
- 不改 `ReboundDetector` / `AlertThrottler` / `ReboundNotificationService`。
- 历史不分页/筛选；5 秒重评估不写库。
- 不做单独历史页面。
