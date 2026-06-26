---
phase: 07-rebound-test-page
plan: 02
subsystem: test
tags: [bug-fix, test-orchestrator, mode-switching, seed-reproducibility]
dependency_graph:
  requires: [07-01]
  provides: [change-mode-fix, seed-getter]
  affects: [test-orchestrator, test-data-generator]
tech_stack:
  added: []
  patterns: [TDD, seed-reproducibility]
key_files:
  created: []
  modified:
    - lib/services/test/test_orchestrator.dart
    - lib/services/test/test_data_generator.dart
    - test/services/test/test_orchestrator_test.dart
decisions:
  - "TestDataGenerator 通过 seed getter 暴露内部 seed，供 TestOrchestrator.changeMode() 创建新生成器时保留可重现性"
  - "TestOrchestrator._generator 从 final 改为非 final，允许 changeMode() 替换生成器实例"
  - "测试策略：直接测试 TestDataGenerator 模式特征，避免依赖 Timer 等待"
metrics:
  duration_seconds: 111
  completed_at: "2026-06-26T17:48:37Z"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 3
status: complete
---

# Phase 07 Plan 02: 修复 changeMode() 模式切换 Summary

修复 TestOrchestrator.changeMode() 模式切换失效的阻断性 bug，暴露 seed getter 保证可重现性，新增 10 个测试验证模式切换后数据特征。

## Tasks Completed

| # | Name | Status | Commit |
|---|------|--------|--------|
| 1 | 修复 changeMode() + 暴露 seed getter + 增强测试 | Done | 3426213 |

## What Was Built

### Bug 修复：changeMode() 模式切换失效

**问题：** `TestOrchestrator.changeMode(SimulationMode mode)` 接收参数但未使用，仅调用 `_generator.reset()` 而未创建新模式生成器，导致切换无效。

**修复：**
- `lib/services/test/test_data_generator.dart`：添加 `int? get seed => _seed` 只读 getter
- `lib/services/test/test_orchestrator.dart`：
  - `_generator` 字段从 `final` 改为非 final
  - `changeMode()` 方法体替换为 `_generator = TestDataGenerator(mode: mode, seed: _generator.seed)`

### 新增测试（10 个）

| 测试组 | 测试名 | 验证内容 |
|--------|--------|----------|
| TestDataGenerator mode 特征验证 | steadyDecline close 严格递减 | 30 根 K 线 close 逐根递减 |
| | vRebound 第 20-22 根 close 递减 | 急跌段特征 |
| | seed getter 返回 seed | getter 正确暴露 |
| | seed getter 无 seed 返回 null | 无 seed 时返回 null |
| | 相同 seed + 相同模式 = 相同数据 | 可重现性 |
| | 相同 seed + 不同模式 = 不同数据 | 模式差异性 |
| changeMode 数据特征验证 | steadyDecline 后数据持续下跌 | 切换后数据特征正确 |
| | vRebound 后数据符合 V 型特征 | 切换后数据特征正确 |
| | changeMode 保留 seed 可重现性 | 切换后 seed 保留 |
| TestOrchestrator | changeMode 切换后 isRunning = false | 状态正确 |

## Decisions Made

1. **seed getter 暴露方式：** 通过 `int? get seed => _seed` 只读 getter 暴露，不暴露可写接口
2. **_generator 字段可变性：** 从 `final` 改为非 final，允许 changeMode() 替换实例
3. **测试策略：** 直接测试 TestDataGenerator 模式特征，避免依赖 Timer 等待（方案 B）

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- `flutter test test/services/test/test_orchestrator_test.dart`：16/16 通过
- `flutter analyze lib/services/test/test_orchestrator.dart lib/services/test/test_data_generator.dart`：No issues found

## Self-Check: PASSED

- [x] lib/services/test/test_data_generator.dart 存在
- [x] lib/services/test/test_orchestrator.dart 存在
- [x] test/services/test/test_orchestrator_test.dart 存在
- [x] 07-02-SUMMARY.md 存在
- [x] Commit 3426213 存在
