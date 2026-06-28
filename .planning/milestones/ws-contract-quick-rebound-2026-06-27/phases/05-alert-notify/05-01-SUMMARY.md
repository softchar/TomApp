---
phase: 05-alert-notify
plan: 01
subsystem: alert-throttling
tags: [alert, throttling, notification, model]
requires: [rebound-signal, rebound-timeframes]
provides: [alert-level-model, alert-throttler-pipeline]
affects: [rebound-alert-service]
tech-stack:
  added: []
  patterns: [chain-of-responsibility, pipeline, pure-dart-sync]
key-files:
  created:
    - lib/models/alert_level.dart
    - lib/services/rebound/alert_throttler.dart
    - test/services/alert_throttler_test.dart
  modified: []
decisions:
  - "AlertThrottler 为纯 Dart 同步逻辑，无 I/O 依赖——冷却用内存 Map，日上限用内存计数器"
  - "冷却键仅用 symbol（不含 TF），实现 per-symbol 全局 4h 冷却（Pitfall 1 规避）"
  - "跨日重置在 evaluate() 入口执行（Pitfall 2 规避）"
  - "归并架构预留但单周期下恒跳过（Pitfall 5 规避）"
  - "死猫过滤：deadCatRiskScore >= 50 时即使 score >= highThreshold 也降为 medium"
metrics:
  duration: "15min"
  completed_date: "2026-06-20"
  tasks: 2
  files: 3
status: complete
---

# Phase 05 Plan 01: AlertThrottler 五道闸门评估管线

**One-liner:** 实现 AlertLevel 分级模型与 AlertThrottler 纯 Dart 五道闸门管线——分级/周期开关/冷却/日上限/归并架构预留

## Tasks Summary

| Task | Name | Type | Commit | Status |
|------|------|------|--------|--------|
| 1 | 创建 AlertLevel 模型 + AlertThrottler 五道闸门管线 | auto (tdd) | `1da7f16` (RED), `b4955df` (GREEN) | COMPLETE |
| 2 | 创建 alert_throttler_test.dart 测试文件 | auto | `1da7f16` (RED) | COMPLETE |

## Implementation Details

### Task 1: AlertLevel 模型 + AlertThrottler（TDD）

**RED 阶段** (`1da7f16`): 创建包含 10 个测试用例的 `alert_throttler_test.dart`，验证编译失败（实现文件不存在）。

**GREEN 阶段** (`b4955df`): 创建两个实现文件：

1. `lib/models/alert_level.dart` (47 行)
   - `AlertLevel` 枚举：`high`（响铃+震动）、`medium`（横幅）、`low`（仅看板）
   - `AlertDecision` 不可变数据类：`symbol`/`level`/`signal`/`coalescedTimeframes`/`createdAt`
   - `const` 构造函数 + `toString()` 调试输出

2. `lib/services/rebound/alert_throttler.dart` (150 行)
   - `AlertThrottler` 类，纯 Dart 同步逻辑（无 I/O）
   - `evaluate()` 六步管线：分级 → 周期开关 → 冷却 → 日重置 → 上限 → 放行
   - `_classify()` 纯函数分级：score >= highTh && deadCatRiskScore < 50 → high
   - Pitfall 1 规避：冷却键仅用 symbol（不含 TF）
   - Pitfall 2 规避：跨日重置在 evaluate() 入口执行
   - Pitfall 5 规避：归并逻辑架构预留（单周期下恒跳过）
   - `reset()` 方法供 ReboundAlertService.stop() 调用
   - `@visibleForTesting setDateForTesting()` 供跨日测试注入

### Task 2: 测试文件

测试文件作为 Task 1 TDD RED 阶段创建（`1da7f16`），包含 10 个测试用例：
- 分级判定：high（score>=75 + deadCat<50）、medium（score>=50）、low 返回 null、死猫降级
- 冷却检查：同 symbol 4h 内第二次调用返回 null
- 周期开关：关闭 TF 的信号返回 null
- 日上限：前 20 次通过，第 21 次 null
- 跨日重置：注入假日期后恢复正常
- 连续 K 线：同 symbol 连续 4 次仅首次通过（ALERT-06 UAT 硬标准）
- 归并架构：单周期下 coalescedTimeframes 恒为 [signal.timeframe]

## Verification Results

```
flutter test test/services/alert_throttler_test.dart
00:00 +10: All tests passed!

flutter analyze lib/models/alert_level.dart lib/services/rebound/alert_throttler.dart
No issues found!
```

## Deviations from Plan

### Rule 3 - Blocking Issues

**1. [Rule 3 - Missing files] 复制缺失依赖文件到工作树**
- **发现于:** Task 1 开始
- **问题:** 工作树基于提交 `494c95f`（早于 Phase 2-4 反弹模块），缺少 `lib/models/rebound_signal.dart` 和 `lib/services/rebound/rebound_timeframes.dart`
- **修复:** 从主仓库复制依赖文件到工作树
- **已修改文件:** `lib/models/rebound_signal.dart`, `lib/services/rebound/rebound_timeframes.dart`
- **提交:** `1da7f16`

**2. [Rule 3 - Package resolution] 复制 .dart_tool 和 pubspec.lock 解决离线依赖解析**
- **发现于:** Task 1 RED 阶段
- **问题:** 工作树缺少 `.dart_tool/package_config.json`，网络不可达 pub.dev
- **修复:** 从主仓库复制 `.dart_tool/`, `pubspec.lock`, `.flutter-plugins*`
- **文件:** 生成文件（已 gitignored），未提交

### Plan Structure Deviation

**3. [Test count] 10 个测试而非计划的 9 个**
- 计划的 Task 2 列出 9 个测试，但行为部分 Test 8（归并架构）未包含在 Task 2 列表中
- 实际实现了 10 个测试（4 个分级 + 1 冷却 + 1 开关 + 2 日上限 + 1 连续K线 + 1 归并）
- 提供了更完整的覆盖，符合所有验收标准

## Threat Flags

无新增威胁面。AlertThrottler 为纯 Dart 同步逻辑，无网络端点、无 I/O、无持久化。计划的威胁模型覆盖已足够。

## Known Stubs

无。所有实现为完整逻辑，无硬编码空值、占位符或未连接数据源。

## Self-Check

- [x] `lib/models/alert_level.dart` 存在且包含 AlertLevel 枚举 + AlertDecision 类
- [x] `lib/services/rebound/alert_throttler.dart` 存在且包含 AlertThrottler 类 + evaluate() 方法
- [x] `test/services/alert_throttler_test.dart` 存在且包含 10 个测试用例
- [x] 所有测试通过 (`flutter test` 10/10)
- [x] 静态分析无问题 (`flutter analyze` 无 issues)
- [x] RED 提交 `1da7f16` 存在（测试文件先于实现）
- [x] GREEN 提交 `b4955df` 存在（实现文件使测试通过）
- [x] CLAUDE.md 约定遵守（中文注释、Provider 架构未涉及、无违规模式）
