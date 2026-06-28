# Phase 2 Plan 02 Summary: ReboundDetector 综合单测（11 场景）

**Plan:** 02-02-PLAN.md
**Status:** complete
**Date:** 2026-06-19

## What Was Done

### test/services/rebound_detector_test.dart（248 行，11 场景）

全部使用合成 fixture（无网络、无真实数据），11 个测试全过：

| # | 场景 | 验证需求 | 结果 |
|---|------|---------|------|
| 1 | V 型反弹完整三阶段 | DETECT-01/02/03, SCORE-01 | score>70, recoveryRatio>0.5, speed≤2, deadCatRisk<50 ✓ |
| 2 | warm-up 数据不足 | DETECT-04 | null, 不抛异常 ✓ |
| 3 | 死猫反弹弱回补 | SCORE-02 | score<50, deadCatRisk>60 ✓ |
| 4 | 下跌中继回补不足 | DETECT-02 | null（<50%不触发）✓ |
| 5 | lookahead 抵御 | DETECT-04 | 未达阈值不触发 ✓ |
| 6 | 纯函数幂等 | DETECT-04 | 两次调用结果完全一致 ✓ |
| 7 | RSI 超卖拐头共振 | DETECT-03 | confluenceFilters 含 rsiOversoldTurning ✓ |
| 8 | 放量确认共振 | DETECT-03 | confluenceFilters 含 volumeConfirmation ✓ |
| 9 | 评分范围 [0, 100] | SCORE-01/02 | 多场景验证 ✓ |
| 10 | ConfluenceScorer 单 TF | SCORE-01 | 返回 0 ✓ |
| 11 | ConfluenceScorer 多 TF | SCORE-01 | (3-1)×5=10 ✓ |

### 修复的 fixture 问题

- Test 1 (V-rebound)：初版 score=65（<70），因 recovery 首根（close=96）recoveryRatio 仅 58%。调高回补至 close=99（recoveryRatio=83%），score≈71 通过。
- Test 3 (dead-cat)：初版 deadCatRisk=55（<60），因 recovery K 线长下影线触发了 bullishCandlePattern（+1 共振 → 少了 +20 死猫分）。调整 low 更靠近 close，不触发形态，deadCatRisk=75 通过。
- Test 7 (RSI)：初版返回 null，因窗口 22 根 < minLen(23)。加 1 根 bar 满足阈值。

### flutter test exit 0，dart analyze exit 0（1 info，非 error）

## Artifacts

| 文件 | 行数 | 作用 |
|------|------|------|
| `test/services/rebound_detector_test.dart` | 248 | ReboundDetector + ConfluenceScorer 综合单测 |

---
*Plan 02 completed: 2026-06-19*
