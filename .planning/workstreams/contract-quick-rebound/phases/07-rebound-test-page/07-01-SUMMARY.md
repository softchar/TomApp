---
phase: 07-rebound-test-page
plan: 01
subsystem: testing
tags: [candlestick-chart, fl-chart, test-orchestrator, simulation, rebound-detection]

# Dependency graph
requires:
  - phase: 02-rebound-detector
    provides: ReboundDetector.evaluate 纯函数
  - phase: 01-indicators
    provides: TechnicalIndicators (ATR/RSI/swing)
provides:
  - TestDataGenerator: 4 种 SimulationMode 模拟 K 线数据生成
  - TestOrchestrator: ChangeNotifier 定时驱动检测编排
  - ReboundTestScreen: K 线图 + 信号列表 + 控制栏测试页面
affects: [08-next-phase]

# Tech tracking
tech-stack:
  added: []
  patterns: [TestDataGenerator seed 可重现, TestOrchestrator ChangeNotifier 定时编排]

key-files:
  created:
    - lib/services/test/test_data_generator.dart
    - lib/services/test/test_orchestrator.dart
    - lib/screens/rebound_test_screen.dart
    - test/services/test/test_data_generator_test.dart
    - test/services/test/test_orchestrator_test.dart
  modified:
    - lib/screens/profile_screen.dart

key-decisions:
  - "TestDataGenerator 放在 lib/services/test/ 而非 lib/services/rebound/ — 测试工具与生产逻辑分离"
  - "ReboundTestScreen 使用 setState 而非 Provider — 页面状态简单，不需要跨组件共享"
  - "信号索引通过 offset 转换适配 window 滚动 — 信号生成时的绝对索引需映射到当前 window 位置"

patterns-established:
  - "SimulationMode 枚举 + TestDataGenerator: 4 种模式的模拟数据生成模式"
  - "TestOrchestrator ChangeNotifier: 定时驱动 + 状态管理 + 窗口/信号维护"

requirements-completed: [TEST-01, TEST-02, TEST-03, TEST-04]

# Metrics
duration: 15min
completed: 2026-06-27
status: complete
---

# Phase 07 Plan 01: 反弹检测测试页面 Summary

**TestDataGenerator 4 种模式模拟 K 线 + TestOrchestrator 定时驱动检测 + ReboundTestScreen K 线图信号可视化，从 ProfileScreen 可进入**

## Performance

- **Duration:** 15 min
- **Started:** 2026-06-26T17:33:13Z
- **Completed:** 2026-06-26T17:48:00Z
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- TestDataGenerator 支持 4 种 SimulationMode（vRebound/deadCatBounce/randomWalk/steadyDecline），seed 参数保证可重现
- TestOrchestrator 每 5 秒生成 K 线并送入 ReboundDetector.evaluate，维护 50 根窗口 + 20 条信号上限
- ReboundTestScreen 上半部分 CandlestickChart 根据信号高亮下跌段(红色)/拉回段(绿色)，下半部分展示 score>=60 信号
- 控制栏支持播放/暂停、模式切换、3 个参数 Slider（dropAtrMultiplier/recoveryMinRatio/volumeMultiplier）
- 15 个单测全部通过（9 个 TestDataGenerator + 6 个 TestOrchestrator）

## Task Commits

1. **Task 1: TestDataGenerator + TestOrchestrator + 单测** - `39ad22a` (test: TDD RED→GREEN)
2. **Task 2: ReboundTestScreen UI + ProfileScreen 入口** - `729a84f` (feat: UI + entry)

## Files Created/Modified

- `lib/services/test/test_data_generator.dart` - 模拟 K 线数据生成器，4 种 SimulationMode
- `lib/services/test/test_orchestrator.dart` - 测试编排器（ChangeNotifier），定时驱动检测
- `lib/screens/rebound_test_screen.dart` - 测试调试页面 UI（K 线图 + 信号列表 + 控制栏）
- `lib/screens/profile_screen.dart` - 新增「反弹检测测试」入口（bug_report_outlined 图标）
- `test/services/test/test_data_generator_test.dart` - TestDataGenerator 单测（9 个用例）
- `test/services/test/test_orchestrator_test.dart` - TestOrchestrator 单测（6 个用例）

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- lib/services/test/test_data_generator.dart 存在 ✓
- lib/services/test/test_orchestrator.dart 存在 ✓
- lib/screens/rebound_test_screen.dart 存在 ✓
- test/services/test/test_data_generator_test.dart 存在 ✓
- test/services/test/test_orchestrator_test.dart 存在 ✓
- 15 个测试全部通过 ✓
- flutter analyze 无 error ✓
