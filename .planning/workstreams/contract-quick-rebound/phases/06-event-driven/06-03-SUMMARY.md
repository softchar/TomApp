---
phase: 06-event-driven
plan: 03
type: execute
subsystem: 回测 UI
tags:
  - provider
  - screen
  - widget
  - fl_chart
  - walk-forward
  - backtest
  - ui
status: complete
requires:
  - 06-02 (backtest engine + data import + models)
provides:
  - BacktestProvider (回测状态管理)
  - BacktestScreen (回测报告 UI)
  - EquityCurveChart (双权益曲线)
  - BacktestStatsCard (统计卡片)
  - BacktestTradeList (可排序交易列表)
affects:
  - lib/main.dart (Provider 注册)
  - lib/screens/profile_screen.dart (入口)
  - lib/screens/kline_screen.dart (下钻目标)
tech-stack:
  added:
    - drift/native (NativeDatabase for AppDatabase instantiation)
  patterns:
    - ChangeNotifier Provider 状态管理（参考 ReboundScoreProvider）
    - fl_chart LineChart 双系列渲染
    - Material Design 3 Card + token-based 设计系统
key-files:
  created:
    - lib/providers/backtest_provider.dart
    - lib/screens/backtest_screen.dart
    - lib/widgets/equity_curve_chart.dart
    - lib/widgets/backtest_stats_card.dart
    - lib/widgets/backtest_trade_list.dart
    - test/providers/backtest_provider_test.dart
    - test/widgets/equity_curve_chart_test.dart
    - test/screens/backtest_screen_test.dart
  modified:
    - lib/main.dart
    - lib/screens/profile_screen.dart
decisions:
  - BacktestProvider 内部创建 AppDatabase(NativeDatabase) 连接 drift — 通过 sqflite getDatabasesPath() 获取 tomapp.db 路径
  - BacktestEngine 所需的 ReboundDetector 用 TechnicalIndicators() 无参构造实例化
  - 日期范围限制 2020-01-01~today，最多 365 天（对齐 T-06-06 威胁缓解）
  - WalkForward 扫描使用单 symbol 模式（取 config.symbols.first 或 fallback TESTUSDT）
  - 所有颜色/字号/间距/圆角使用 AppColors/AppTextStyles/AppSpacing/AppRadius token，零硬编码
metrics:
  duration: 775s (12.9min)
  completed_date: 2026-06-20
  tasks: 3
  files_created: 8
  files_modified: 2
---

# Phase 06 Plan 03: 回测 UI Summary

**回测 UI 层完整构建：BacktestProvider 状态管理 + BacktestScreen 六状态报告界面 + ProfileScreen 入口接线 + main.dart Provider 注册**

## Tasks Executed

| Task | Name                    | Type        | Commit  | Files                                      |
|------|-------------------------|-------------|---------|--------------------------------------------|
| 1    | BacktestProvider 状态管理 | auto (TDD)  | 0bcad97 | lib/providers/backtest_provider.dart, test/providers/backtest_provider_test.dart |
| 2    | BacktestScreen + 3 Widgets + 测试 | auto | b3761e7 | lib/screens/backtest_screen.dart, lib/widgets/equity_curve_chart.dart, lib/widgets/backtest_stats_card.dart, lib/widgets/backtest_trade_list.dart, test/widgets/equity_curve_chart_test.dart, test/screens/backtest_screen_test.dart |
| 3    | ProfileScreen 入口 + main.dart 注册 | auto | ca864fb | lib/screens/profile_screen.dart, lib/main.dart |

### TDD Gate Sequence (Task 1)

| Gate    | Commit  | Description                                           |
|---------|---------|-------------------------------------------------------|
| RED     | 96c0f8f | test(06-03): add failing test for BacktestProvider state machine |
| GREEN   | 0bcad97 | feat(06-03): implement BacktestProvider state management |

## Deviations from Plan

### Rule 3 — API 签名不匹配

**1. [Rule 3 - Missing dependency] DataImportService.importHistoricalData 需要 AppDatabase 参数**

- **Found during:** Task 1 (BacktestProvider 实现)
- **Issue:** 计划中写 `DataImportService().importHistoricalData(config: _config)`，但实际 API 签名为 `importHistoricalData({required AppDatabase db, required BacktestConfig config})`
- **Fix:** BacktestProvider 内部通过 `getDatabasesPath()` + `AppDatabase(NativeDatabase(File(dbPath)))` 创建 drift 数据库连接，传入 importHistoricalData
- **Files modified:** `lib/providers/backtest_provider.dart`

**2. [Rule 3 - Missing constructor arg] ReboundDetector 需要 TechnicalIndicators 参数**

- **Found during:** Task 1（编译错误）
- **Issue:** `ReboundDetector()` 无参构造不存在，实际签名 `ReboundDetector(this._ti)` 需要一个 `TechnicalIndicators` 实例
- **Fix:** 用 `ReboundDetector(TechnicalIndicators())` 实例化
- **Files modified:** `lib/providers/backtest_provider.dart`

**3. [Rule 3 - API mismatch] fl_chart 1.2.0 API 差异**

- **Found during:** Task 2（编译错误）
- **Issue:** `LineTouchTooltipData` 不能直接赋给 `lineTouchData`，需通过 `LineTouchData(touchTooltipData: ...)` 包装；`dashArray` 参数类型为 `List<int>?` 非 `List<double>?`
- **Fix:** 调整 API 调用方式匹配 fl_chart 1.2.0 实际类型签名
- **Files modified:** `lib/widgets/equity_curve_chart.dart`

**4. [Rule 3 - Build tooling] 网络不可达导致 pub get 失败**

- **Found during:** Task 1（flutter analyze/test 执行前）
- **Issue:** pub.dev 不可达，flutter analyze 无法解析依赖。工作树（worktree）的 `.dart_tool` 目录为空
- **Fix:** 从主仓库复制 `pubspec.lock` 和 `.dart_tool/` 到工作树以恢复依赖解析
- **Files modified:** none（仅环境修复）

## Declared Contract Fulfillment

| Requirement    | Status | Evidence                                                                  |
|----------------|--------|---------------------------------------------------------------------------|
| D-20 四项强制披露 | PASS | BacktestScreen complete 状态渲染全部四项绿色勾选标记的披露项              |
| D-21 免责声明   | PASS | 固定文字 "回测表现通常需打 30-50% 折扣作为实盘预期；本工具不构成投资建议。" 存在于 BacktestScreen 底部 |
| D-22 零执行词   | PASS | `grep -r '买入\|强买\|推荐'` 在所有新建文件中返回 0 匹配                 |
| 双权益曲线      | PASS | EquityCurveChart 渲染零成本橙色实线和含成本紫色虚线                       |
| 7 项统计卡      | PASS | GridView 2 列布局展示胜率/平均R/盈亏比/最大回撤/样本数/总PnL/均笔R       |
| 可排序交易列表  | PASS | BacktestTradeList 支持 5 列点击排序（升/降切换），行点击下钻 KlineScreen |
| 六状态覆盖      | PASS | idle/running/complete/error/0 trades/disclosures 全部有对应 UI            |
| T-06-06 缓解    | PASS | runBacktest 入口同步验证：startDate>=2020-01-01、endDate<=today、startDate<endDate、范围<=365 天 |

## Test Results

```
14/14 tests passed:
  - 8 BacktestProvider state machine tests
  - 3 EquityCurveChart widget tests
  - 3 BacktestScreen idle state tests
flutter analyze: 0 errors in all new files
```

## Known Stubs

None — all data flows are wired. BacktestProvider.runBacktest() fully connects to DataImportService → AppDatabase → WalkForward → aggregateOutOfSample → report display.

## Threat Flags

None — all new surface is covered by the existing threat model (T-06-06 input validation mitigated in BacktestProvider; T-06-07 information disclosure accepted, no PII in reports).

## Commits

- `96c0f8f`: test(06-03): add failing test for BacktestProvider state machine
- `0bcad97`: feat(06-03): implement BacktestProvider state management
- `b3761e7`: feat(06-03): implement BacktestScreen + 3 widgets + tests
- `ca864fb`: feat(06-03): add ProfileScreen entry + main.dart Provider registration
