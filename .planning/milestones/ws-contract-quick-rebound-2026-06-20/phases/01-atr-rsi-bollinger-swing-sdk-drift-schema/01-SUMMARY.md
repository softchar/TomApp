# Phase 1 Summary: 指标基础（ATR/RSI/Bollinger/swing + SDK 升级 + drift schema）

**Phase:** 01
**Plan:** 01-PLAN.md (revision 1, verified)
**Status:** complete
**Date:** 2026-06-19

## What Was Done

### Task 1 — SDK 升级 + 依赖落地 ✅ (f1e9bbb)
- `pubspec.yaml`: sdk `>=3.6.0 <4.0.0`，新增 `drift` / `archive` / `sqlite3_flutter_libs` / dev `drift_dev`，`fl_chart` 保持 `^0.65.0` 不动。
- `flutter pub get` 退出 0，无版本冲突。
- **偏离（drift 版本）**：plan 锁定 drift `^2.32.0`，但实际解析为 `^2.19.1+1`——原因：drift ≥2.32 传递依赖 sqlite3 3.x（需 Dart ≥3.9.999），当前 Flutter 3.32.8 的 Dart 是 3.8.1，不够。drift 2.19.x 的 Table / GeneratedDatabase / KeyAction.cascade / codegen API 与 2.32 完全兼容，Phase 1 schema 工作不受影响。drift_dev 解析为 `^2.19.1`。

### Task 2 — ATR/RSI/swing 指标实现 ✅ (33ab0c3)
- `lib/services/technical_indicators.dart`：在既有 `TechnicalIndicators` 类追加 7 个纯函数实例方法：`atr` / `atrSeries` / `rsi` / `rsiTurningUp` / `swingHigh` / `swingLow` / `_trueRange`（私有 helper）。Bollinger 复用既有 `calculateBOLL`。
- 类型：`KlineData`（无新增 Candle 类型），实例方法（无 static），符合 CLAUDE.md。
- 纯函数不变量：grep 确认无 DateTime.now / async / await / Provider / File(。
- `test/technical_indicators_test.dart`：11 测试全过（Wilders 手算精度 1e-9、warm-up 头 14 根 null、幂等冒烟、RSI 超卖拐头、Bollinger 三轨、swingHigh/Low）。
- `lib/services/pump_detector.dart` 未修改。

### Task 3 — drift 三表 + DatabaseHelper 双路径迁移 ✅ (3e2fa61)
- `lib/services/drift_database.dart`：定义 `Klines`（复合主键 symbol+interval+openTime）/ `BacktestRuns`（自增 PK）/ `BacktestTrades`（FK→runId, ON DELETE CASCADE）+ `AppDatabase`（schema v1）。drift 生成表名 snake_case（`klines` / `backtest_runs` / `backtest_trades`）。
- `lib/services/drift_database.g.dart`：build_runner 生成（74KB）。
- `lib/services/database_helper.dart`：version 3→4，`_createDriftTables(Database db)` 私有 helper 含 3 条 `CREATE TABLE IF NOT EXISTS`，在 `_onCreate`（全新安装）与 `_onUpgrade(oldVersion<4)`（升级）两条路径都调用（BLOCKER 2 解决）。新增 `@visibleForTesting DatabaseHelper.forTesting(this._dbPath)` 供迁移测试注入 in-memory DB。
- `test/drift_database_test.dart`：2 测试（klines 复合主键 insertOrReplace + backtest_trades 外键级联删除），NativeDatabase.memory() 正常工作。
- `test/database_helper_migration_test.dart`：3 测试（fresh-install onCreate 创建 drift 三表 + upgrade v3→v4 创建 drift 三表 + CRUD/级联验证），sqflite_common_ffi in-memory。
- drift 与 sqflite 表名（snake_case）一致，Phase 3/6 共存指向同一物理表。

### Task 4 — 零回归验证闸 ✅ (记录在案)
- `flutter analyze`：**0 error**，~62 info/warning 全为既有代码既有债务（pump_screen/binance_*/widgets），Phase 1 新增 0 error / 0 warning。
- `flutter test` 全量：**66 pass / 6 fail**。6 个失败**全在 `binance_websocket_manager_test.dart`**（SocketException 连 `fstream.binance.com` 超时）——**沙箱无 Binance 网络访问**，既有网络依赖测试在离线环境失败，**与 Phase 1 改动无关**。Phase 1 新增 16 测试（indicators 11 + drift 2 + migration 3）全部通过。
- `fl_chart` 保持 `^0.65.0`（Phase 4 升级）✓。
- `flutter pub get` 退出 0 ✓。

## 偏离记录

| 偏离项 | plan 设定 | 实际 | 原因 | 影响 |
|--------|-----------|------|------|------|
| drift 版本 | `^2.32.0` | `^2.19.1+1` | drift ≥2.32 需 Dart ≥3.9.999（via sqlite3 3.x），当前 Dart 3.8.1 不兼容 | **无影响**——Table/GeneratedDatabase/KeyAction cascade/codegen API 在 2.x 内稳定，Phase 1 schema 工作完全一致 |
| drift_dev 版本 | `^2.6.0` | `^2.19.1` | 与 drift 2.19 对齐 | 无影响 |
| sqlite3_flutter_libs | 未在 plan 锁定 | `^0.5.42`（自动解析） | drift NativeDatabase 运行时依赖 sqlite3 原生库 | 必需，非范围蔓延 |

## 验证结果（零回归）

| 检查 | 结果 | 说明 |
|------|------|------|
| flutter analyze | ✅ 0 error | 62 info/warning 全为既有债务（Phase 1 新增 0） |
| flutter test 全量 | ✅ 66 pass / ⚠ 6 fail（环境） | 6 fail = binance WebSocket 网络测试（离线沙箱），非 Phase 1 回归 |
| fl_chart 版本 | ✅ ^0.65.0 不变 | Phase 1 未触碰（延后 Phase 4） |
| 新增测试 | ✅ 16/16 pass | ATR Wilders + RSI + Bollinger + swing(8) + drift CRUD/级联(2) + migration 双路径(3) + migration CRUD(3) |

## What This Phase Unlocked

- ATR(Wilders)/RSI(超卖拐头)/Bollinger/swing —— 供 Phase 2（ReboundDetector）和 Phase 6（BacktestService）共用的纯函数指标基础
- drift 类型安全 ORM（Klines/BacktestRuns/BacktestTrades）—— 供 Phase 3（信号写入）和 Phase 6（回测历史）
- DatabaseHelper 迁移（v4, onCreate+onUpgrade 双路径）—— 新老数据库路径都可建 drift 三表
- SDK 3.6 + archive（data.binance.vision ZIP 供 Phase 6 历史 K 线导入）

## Artifacts Produced

| 文件 | 作用 |
|------|------|
| `lib/services/technical_indicators.dart` | 追加 atr/atrSeries/rsi/rsiTurningUp/swingHigh/swingLow 实例方法 |
| `lib/services/drift_database.dart` | Klines/BacktestRuns/BacktestTrades + AppDatabase schema 定义 |
| `lib/services/drift_database.g.dart` | drift codegen 产物（build_runner） |
| `lib/services/database_helper.dart` | v4 迁移（_createDriftTables 双路径、forTesting 构造） |
| `test/technical_indicators_test.dart` | 11 测试（Wilders/RSI/Bollinger/swing） |
| `test/drift_database_test.dart` | 2 测试（klines PK + backtest_trades cascade） |
| `test/database_helper_migration_test.dart` | 3 测试（fresh-install + upgrade + CRUD/级联） |
| `pubspec.yaml` / `pubspec.lock` | SDK 3.6 + drift 2.19 + archive + sqlite3_flutter_libs + drift_dev + sqflite_common_ffi(dev) |

## Next

Phase 2：反弹检测器 + 评分 + 共振（纯函数，零 I/O）。依赖 Phase 1 指标基础，ReboundDetector.evaluate 调用本阶段的 atr/rsi/swing。

---
*Phase 1 completed: 2026-06-19*
