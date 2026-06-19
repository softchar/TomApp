# Phase 2 Plan 01 Summary: 数据模型 + ReboundDetector + ReboundConfluenceScorer

**Plan:** 02-01-PLAN.md
**Status:** complete
**Date:** 2026-06-19

## What Was Done

### 新建 4 个纯 Dart 文件（零 Flutter/零 I/O）

1. **lib/models/rebound_params.dart** — `ReboundParams` 不可变数据类，21 个可调阈值字段（全部含默认值，注释标记「业务先验起步值，Phase 6 校准」），提供 `copyWith()` 和 `dropMinPctForTimeframe()` 辅助方法。

2. **lib/models/rebound_signal.dart** — `ConfluenceType` 枚举（4 值：rsiOversoldTurning/volumeConfirmation/atSupportLevel/bullishCandlePattern）+ `ReboundSignal` 不可变数据类（15 个字段：symbol/timeframe/dropMagnitude/recoveryRatio/speed/confluenceFilters/score/deadCatRiskScore/entryPrice/swingLowPrice/swingHighPrice/dropStartIndex/dropEndIndex/recoveryEndIndex/timestamp），提供 `copyWith()`。

3. **lib/services/rebound/rebound_detector.dart** — `ReboundDetector` 类，核心纯函数方法：
   - `ReboundSignal? evaluate(window, params, {symbol, timeframe})` — 三阶段管线
   - Stage 1 `_detectDropLeg`：swingLow + ATR 归一化跌幅（≥2×ATR + %兜底 + ≤3 根）
   - Stage 2 `_detectRecoveryLeg`：回补 ≥50% + ≤2 根 + 收盘站上中点
   - Stage 3 `_checkConfluence`：RSI 超卖拐头 + 放量 ≥1.5× + 支撑位 ±2% + 长下影线
   - `_calculateScore`：5 维加权（recoveryRatio 30 + speed 20 + volume 20 + confluence 15 + mtf 0）
   - `_calculateDeadCatRisk`：独立 0-100 维度（低量+30 / RSI<50+25 / <38.2%+25 / 无共振+20）
   - 纯函数验证：无 DateTime.now/async/await/Provider/File(

4. **lib/services/rebound/rebound_confluence_scorer.dart** — `ReboundConfluenceScorer` 类，静态方法 `scoreMultiTimeframe(Map<String, ReboundSignal?>)` 返回 0-15 跨周期加分。Phase 2 单 TF 固定返回 0，Phase 3 编排器消费。

### 关键设计决策

- evaluate 接受滑动窗口（非全历史），Phase 3 编排器维护 rolling buffer
- symbol/timeframe 由调用方传入（KlineData 不携带这些字段）
- TechnicalIndicators 实例通过构造函数注入（不内部 new）
- 评分权重业务先验固定，不进参数扫描（Phase 6 校准）

### dart analyze 无错误（exit 0）

## Artifacts

| 文件 | 行数 | 作用 |
|------|------|------|
| `lib/models/rebound_params.dart` | ~160 | ReboundParams 数据类 |
| `lib/models/rebound_signal.dart` | ~130 | ConfluenceType 枚举 + ReboundSignal |
| `lib/services/rebound/rebound_detector.dart` | ~260 | 三阶段纯函数检测器 |
| `lib/services/rebound/rebound_confluence_scorer.dart` | ~30 | 跨周期共振评分 |

---
*Plan 01 completed: 2026-06-19*
