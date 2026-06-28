# Phase 02: Code Review Report

**Reviewed:** 2026-06-27
**Depth:** deep
**Files Reviewed:** 4
**Status:** all_fixed

## Summary

Phase 02 修改了反弹检测管线的 4 个文件：swingLow fallback、midpoint 条件移除、双周期 RSI 共振、默认参数调整、TestDataGenerator 重写。全部 18 个测试通过。

## Findings

### CR-01: 硬编码 fast RSI 周期 (7) — ✅ 已修复

**文件:** `lib/services/rebound/rebound_detector.dart`
**问题:** 快速 RSI 周期硬编码为 7，无法在 Phase 6 参数扫描中调优。
**修复:** 添加 `fastRsiPeriod` 参数到 `ReboundParams`（默认 7），detector 使用 `params.fastRsiPeriod`。

### WR-01: TestDataGenerator.mode 改为可选 — ✅ 已修复

**文件:** `lib/services/test/test_data_generator.dart`
**问题:** `mode` 从 `required` 改为默认值，静默掩盖调用方 bug。
**修复:** 恢复 `required this.mode`。

### WR-02: 双 RSI 重复创建 sublist — ✅ 已修复

**文件:** `lib/services/rebound/rebound_detector.dart`
**问题:** `window.sublist(0, recoveryEndIdx + 1)` 调用两次，违反 DRY。
**修复:** 提取为局部变量 `rsiWindow`。

### IN-03: test_orchestrator 硬编码 minLen=25 — ✅ 已修复

**文件:** `lib/services/test/test_orchestrator.dart`
**问题:** warm-up 阈值硬编码 25，与 dropMaxCandles 变更耦合。
**修复:** 从 `_params` 动态计算 `minLen`。

### IN-01: open.roundTo2() 冗余 — ⏭️ 跳过

**文件:** `lib/services/test/test_data_generator.dart`
**问题:** `open` 已是上一轮 `close.roundTo2()` 的结果，`.roundTo2()` 是 no-op。
**决策:** 保留作为防御性编码，无实际影响。

### IN-02: midpoint 移除扩大接受区间 — ℹ️ 已知

**问题:** 移除 midpoint 条件后，close 刚好在 midpoint 的边界信号会被接受。
**决策:** 设计决策，已记录在代码注释中。

## 测试结果

```
rebound_detector_test.dart:  11/11 passed ✅
alert_settings_provider_test.dart:  7/7 passed ✅
Total: 18/18 passed
```

## 修改文件清单

| 文件 | 变更 |
|------|------|
| `lib/models/rebound_params.dart` | 添加 `fastRsiPeriod` 参数 + copyWith |
| `lib/services/rebound/rebound_detector.dart` | 使用 `params.fastRsiPeriod` + 提取 `rsiWindow` |
| `lib/services/test/test_data_generator.dart` | 恢复 `required this.mode` |
| `lib/services/test/test_orchestrator.dart` | 从 params 动态计算 minLen |
