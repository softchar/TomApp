---
phase: 06-event-driven
fixed_at: 2026-06-20T10:30:00Z
review_path: .planning/workstreams/contract-quick-rebound/phases/06-event-driven/06-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 06: Code Review Fix Report

**Fixed at:** 2026-06-20T10:30:00Z
**Source review:** `.planning/workstreams/contract-quick-rebound/phases/06-event-driven/06-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 9（CR-01, CR-02, CR-03, WR-01 至 WR-06）
- Fixed: 9
- Skipped: 0
- Info findings (IN-01 至 IN-06)：不在本次 fix scope，保持原状

每个修复均通过 `dart analyze`（Tier 2 语法/类型检查）验证零新增错误；
仅有的 2 条遗留 warning/info（`tpExitType` 未使用变量、`ReboundParams()` const 提示）
均为修复前已存在的预存问题，已用 `git stash` 对照确认。

**测试说明：** `flutter test` 因 sandbox 无网络访问无法执行 pub 依赖解析，
已退化为 Tier 2 静态分析（已修改的所有 8 个源文件 + 1 个测试文件 `dart analyze`）。
CR-03 修改的 `trade_simulator_test.dart` 测试断言「pnlWithCost < rMultiple」在新签名下依然成立
（成本为正减法不变），无需调整断言。

**遗留 lint（均为修复前已存在的预存问题，非本次修复引入）：**
- `backtest_engine.dart:110` `tpExitType` 未使用变量（warning）
- `walk_forward.dart:65` `ReboundParams()` 应为 const（info）
- `trade_simulator_test.dart` 测试辅助函数 `_getSignalFromVShapedFixture` / `_bar` 下划线前缀（info），
  及 `ReboundParams()` 应为 const（info）

**补丁（本次会话）：** CR-03 测试编辑遗留的 2 个未使用 import
（`position.dart`、`backtest_config.dart`）已清理，`dart analyze` 通过确认。

## Fixed Issues

### CR-01: BacktestProvider 数据库连接 double-close 崩溃风险

**Files modified:** `lib/providers/backtest_provider.dart`
**Commit:** `49a9d19`
**Applied fix:** 在 `runBacktest()` 的三个早期返回路径（`insertedCount == 0`、数据读取循环内 `_cancelled`、
数据读取后 `_cancelled`）中，`await db.close()` 后立即 `db = null;`，防止 `finally` 块 `db?.close()`
对已关闭的 Drift 数据库二次调用抛出 `StateError`。同步使用 `db!` 空断言满足 Dart null safety 流分析。

### CR-02: 资金费率历史未传入回测引擎——资金费扣费始终为零

**Files modified:** `lib/providers/backtest_provider.dart`, `lib/services/rebound/walk_forward.dart`,
`lib/services/rebound/funding_rate_service.dart`
**Commit:** `8c1bc94`
**Applied fix:**
- `FundingRateService` 新增公开方法 `buildHistoryMap()`，从 `_cache` 构建 `{fundingTime(ms): fundingRate}`
- `WalkForward.runWalkForward` 与 `_runFold` 新增 `fundingRateHistory` 可选参数，透传至 `engine.runBacktestOnKlines`
- `BacktestProvider` 在引擎调用前 `prefetch` 资金费率并构建 history map 传入；
  预拉取失败时 try/catch 退化为空 map（不扣资金费）不阻断回测主流程

### CR-03: 交易成本计算单位不匹配——价格比率与 R 倍数混合计算（需人工核验）

**Files modified:** `lib/services/rebound/trade_simulator.dart`, `lib/services/rebound/backtest_engine.dart`,
`test/services/rebound/trade_simulator_test.dart`
**Commit:** `e1b64e8`
**Status:** `fixed: requires human verification`（逻辑修复）
**Applied fix:** `applyTransactionCost` 新增 `stopLoss` 参数，成本换算分母从 `entryPrice` 改为
`|entryPrice - stopLoss|`（1R 对应的真实价格距离）。`BacktestEngine._buildReport` 中全部 8 处调用
同步传入 `position.stopLoss`；测试用例更新传入 `stopLoss=95` 并修正注释中的预期值（约 0.0656R）。

**示例：** entryPrice=100、stopLoss=95（1R=5）、费用 0.328 → 修复后 costInR = 0.0656R（原错误为 0.00328R，
低估约 20 倍）。

### WR-01: Walk-Forward 数据不足时退化折叠使用全量数据（In-Sample）

**Files modified:** `lib/services/rebound/walk_forward.dart`
**Commit:** `bc37c2c`
**Applied fix:** `months.length < 2` 时不再退化为 `trainKlines = testKlines = allKlines` 单折（产出 IS 结果），
改为返回空 `folds` 列表，由 `aggregateOutOfSample` 经 `ReportGenerator.generate` 生成空报告
（`BacktestReport.empty`），与 D-10/D-11「仅报告 Out-of-Sample」约束一致。

### WR-02: profitFactor 在无盈亏时的不一致——ReportGenerator vs BacktestEngine

**Files modified:** `lib/services/rebound/backtest_engine.dart`
**Commit:** `8950f39`
**Applied fix:** `BacktestEngine._buildReport` 的 `profitFactor` 边界处理对齐 `ReportGenerator.generate`：
`negativePnl.abs() == 0 && positivePnl == 0`（全 0 PnL）时返回 `0.0`，仅当有盈利无亏损时返回 `infinity`。

### WR-03: BacktestScreen 多处使用 `dynamic` 类型丢失类型安全

**Files modified:** `lib/screens/backtest_screen.dart`
**Commit:** `9b30c72`
**Applied fix:** 四个构建方法的 `report`/`config` 参数从 `dynamic` 改为强类型 `BacktestReport` / `BacktestConfig`
（`_buildEquityCurveCard`、`_buildStatsGrid`、`_buildTradeListCard`、`_buildDisclosuresCard`）。
`_buildDisclosuresCard` 中 `if (report == null)` 死代码检查一并移除（caller `_buildCompleteContent`
已保证 `report != null`）。新增对应 import。

### WR-04: TradeSimulator.applyFundingFee 硬编码 15 分钟 Bar 时长

**Files modified:** `lib/services/rebound/trade_simulator.dart`, `lib/services/rebound/backtest_engine.dart`
**Commit:** `978740e`
**Applied fix:** `applyFundingFee` 新增可选参数 `barDuration`（默认 15min 向后兼容），
内部 `barEnd` 改用 `barTime.add(barDuration)`。`BacktestEngine` 新增 `_barDurationFromInterval(interval)`
从 Binance interval 字符串（"15m"/"1h"/"4h"/"1d"/"1w"）解析时长，调用 `applyFundingFee` 时按实际 interval 传入。

### WR-05: DataImportService.importHistoricalData 返回值包含重复计数

**Files modified:** `lib/services/rebound/data_import_service.dart`
**Commit:** `c4d3ac9`
**Applied fix:** 每个 batch 写入前后用 `db.selectOnly(db.klines)` + `openTime.count()` 查询总行数，
取差值为实际新增行数（`.clamp(0, chunk.length)`），消除 `insertOrIgnore` 跳过的重复行计数。
文档注释同步说明返回值语义为「实际新增行数」。import 改为完整 `drift/drift.dart`（使用 count 表达式扩展）。

### WR-06: BacktestScreen 错误消息拼接有误

**Files modified:** `lib/screens/backtest_screen.dart`
**Commit:** `1b97c41`
**Applied fix:** `_buildErrorContent` 第二行 `Text` 字符串移除行首多余的「。」，
独立成句「请检查数据源和网络连接后重试。」，避免与上一行 errorMessage 拼接时产生双标点。

---

_Fixed: 2026-06-20T10:30:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
