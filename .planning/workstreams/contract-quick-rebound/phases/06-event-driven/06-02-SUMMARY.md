---
phase: 06-event-driven
plan: 02
subsystem: backtest
tags: [event-driven, backtest, walk-forward, lookahead-analysis, dart, flutter, drift]

# Dependency graph
requires:
  - phase: 06-event-driven
    plan: 01
    provides: "BacktestConfig/BacktestReport/BacktestTrade/Position/FundingRate models + DataImportService + FundingRateService"
  - phase: 02-detector-scoring
    provides: "ReboundDetector.evaluate pure function + ReboundSignal/ReboundParams models"
  - phase: 01-indicator-basics
    provides: "TechnicalIndicators (ATR, swingLow, RSI) + KlineData model"
provides:
  - "BacktestEngine: event-driven bar-by-bar backtest core, zero vectorization"
  - "TradeSimulator: position entry/exit management with stop-loss/take-profit/time-exit/costs"
  - "WalkForward: 3-fold anchored walk-forward with 320-param grid scanning (out-of-sample only)"
  - "ReportGenerator: backtest report with 7 metrics + dual equity curves"
  - "Lookahead-analysis test: Freqtrade-style bias detection (UAT BACKTEST-06 PASSED)"
affects: [06-03-ui-backtest-screen]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Event-driven bar-by-bar loop (禁止向量化，Pitfall 1)"
    - "Pure computation engine — 零 I/O, 复用 ReboundDetector.evaluate"
    - "TDD with RED→GREEN commit per task"
    - "Corrected TP formula: swingLow + dropRange * 0.618 (for long positions)"

key-files:
  created:
    - lib/services/rebound/backtest_engine.dart
    - lib/services/rebound/trade_simulator.dart
    - lib/services/rebound/walk_forward.dart
    - lib/services/rebound/report_generator.dart
    - test/services/rebound/backtest_engine_test.dart
    - test/services/rebound/trade_simulator_test.dart
    - test/services/rebound/walk_forward_test.dart
    - test/services/rebound/report_generator_test.dart
    - test/services/rebound/lookahead_test.dart
  modified:
    - test/services/rebound/test_fixtures.dart

key-decisions:
  - "TP 公式修正：plan 指定的 swingHigh - dropRange*0.618 对多头仓位将止盈设在 entry 以下；改为 swingLow + dropRange*0.618（标准 Fibonacci 回撤位）"
  - "BacktestEngine 构造函数不强制依赖 AppDatabase（改用 runBacktestOnKlines 纯数据接口）；drift 集成留待 BacktestProvider"
  - "vShapedQuickRecovery 夹具设计：40 根 15m K 线，3 根急跌 + 2 根反弹，与默认 ReboundParams 兼容（dropMaxCandles=3, recoveryMaxCandles=2）"

patterns-established:
  - "Event-driven 引擎模式：for (i in klines) → enter at bar[i].open → check exits → evaluate at bar[i].close"
  - "逐 bar 窗口约束：detector.evaluate(window[0..i]) 只用已发生 K 线，禁止 bar[i+1] 及以后"
  - "分批退出模型：TP1 触发 50% 仓位记录为独立 BacktestTrade，剩余 50% 继续跟踪"
  - "Walk-forward 切片：按月份分桶，train 窗口累进增长，test 窗口固定 1 月"

requirements-completed: [BACKTEST-02, BACKTEST-03, BACKTEST-04, BACKTEST-05, BACKTEST-06]

# Metrics
duration: 45min
completed: 2026-06-20
status: complete
---

# Phase 06 Plan 02: 回测引擎 + 模拟交易 + Walk-Forward + 报告 + 偏差测试 Summary

**Event-driven 逐 bar 回测引擎禁用向量化操作，4 个 Dart 服务类 + 5 个测试文件，18 测试全绿，Lookahead-Analysis UAT 硬标准通过**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-06-20T08:00:00Z
- **Completed:** 2026-06-20T08:45:00Z
- **Tasks:** 3 (all TDD with RED→GREEN commits)
- **Files created:** 9
- **Files modified:** 1

## Accomplishments

- **BacktestEngine**: event-driven 逐 bar for 循环，window[0..i] 只含已发生 K 线，零向量化操作（grep 验证 0 匹配 `.shift()/.diff()/DataFrame`）
- **TradeSimulator**: 完整实现 D-01 至 D-06 全部交易规则——next-open 进场、bar.low 止损、bar.high 双止盈（61.8%/100% Fib）、时间退出 maxHoldBars、taker 0.06% + 滑点 0.1% 成本扣除、UTC 00:00/08:00/16:00 资金费结算
- **WalkForward**: 3-fold 锚定切片 + 320 参数组合（4×5×4×4）全量扫描 + aggregateOutOfSample 只报 OOS
- **ReportGenerator**: 7 项统计指标（winRate/avgR/profitFactor/maxDrawdown/sampleCount/totalPnL/avgRPerTrade）+ 双权益曲线（零成本/含成本）
- **Lookahead-Analysis UAT**: close 替换为 next open 后信号时间/数量/评分完全不变——引擎零前视偏差通过 BACKTEST-06 硬标准

## Task Commits

Each task was committed atomically with TDD RED→GREEN cycles:

1. **Task 1: BacktestEngine + TradeSimulator**
   - `53f992d` test(06-02): add failing tests for BacktestEngine + TradeSimulator (RED, 9 tests)
   - `2e2fcf3` feat(06-02): implement BacktestEngine + TradeSimulator event-driven core (GREEN)

2. **Task 2: WalkForward + ReportGenerator**
   - `6e05327` test(06-02): add failing tests for WalkForward + ReportGenerator (RED, 7 tests)
   - `4d78eeb` feat(06-02): implement WalkForward + ReportGenerator (GREEN)

3. **Task 3: Lookahead-Analysis**
   - `fd9732b` test(06-02): add lookahead-analysis bias test (UAT BACKTEST-06) (2 tests)

**Plan metadata:** to be committed by this executor (docs: complete plan)

## Files Created/Modified

| File | Kind | Description |
|------|------|-------------|
| `lib/services/rebound/backtest_engine.dart` | Created | Event-driven 逐 bar 回测引擎核心 |
| `lib/services/rebound/trade_simulator.dart` | Created | 模拟交易：进场/止损/止盈/时间退出/成本扣费 |
| `lib/services/rebound/walk_forward.dart` | Created | 3-fold 锚定 walk-forward + 320 参数网格扫描 |
| `lib/services/rebound/report_generator.dart` | Created | 回测报告生成：7 项统计 + 双权益曲线 |
| `test/services/rebound/backtest_engine_test.dart` | Created | 4 tests: V 型全流程/止损/下一根进场/不叠加仓位 |
| `test/services/rebound/trade_simulator_test.dart` | Created | 5 tests: 进场/止损/双止盈/时间退出/成本 |
| `test/services/rebound/walk_forward_test.dart` | Created | 3 tests: 6月WF/切片验证/buildParamGrid(320) |
| `test/services/rebound/report_generator_test.dart` | Created | 4 tests: 混合盈亏/inf/零笔/maxDrawdown |
| `test/services/rebound/lookahead_test.dart` | Created | 2 tests: 500根合成/V型 close→nextOpen 信号一致 |
| `test/services/rebound/test_fixtures.dart` | Modified | 新增 vShapedQuickRecovery() 夹具（与默认参数兼容） |

## Decisions Made

- **TP 公式修正 [Rule 1 - Bug]**: Plan 指定的 `swingHighPrice - dropRange * 0.618` 对多头仓位计算有误——恢复至标准 Fibonacci `swingLowPrice + dropRange * 0.618`，使 TP1 位于 entry 上方成为有效止盈目标
- **引擎无 drift 依赖**: BacktestEngine 设计为纯数据驱动（`runBacktestOnKlines` 接受 `List<KlineData>`）；drift 读取逻辑留待 BacktestProvider/上层编排（Phase 6-03）；这样做到了引擎零副作用、测试直接可控
- **vShapedQuickRecovery 夹具**: 原有 vShapedRecovery 跌 30% 经 30 根 bar（远超过 dropMaxCandles=3），无法触发信号；新建 40 根 3 根急跌 + 2 根反弹夹具，low 值经精心设计确保 swingLow 检测正确
- **分批退出独立 BacktestTrade**: TP1 触发 50% 仓位和 TP2 触发剩余 50% 各记录为独立的 BacktestTrade（二者共享同一 entryTime），重叠检测跳过同 entryTime 的交易

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TP 公式修正（多头 Fibonacci 回撤位）**
- **Found during:** Task 1 (TradeSimulator.enterPosition implementation)
- **Issue:** Plan 指定 `takeProfit1 = swingHighPrice - dropRange * 0.618`（例：100 - 25×0.618 = 84.55），对多头仓位 entry 位于恢复段（约 88-90）时 TP1 在 entry 下方，成为止损而非止盈
- **Fix:** 改为标准 Fibonacci 回撤计算：`takeProfit1 = swingLowPrice + dropRange * 0.618`（例：74 + 25×0.618 = 90.45），entry 位于 88-90 时 TP1 在上方成为有效止盈目标
- **Files modified:** `lib/services/rebound/trade_simulator.dart` line 33
- **Verification:** 所有 18 测试通过，V 型反弹正常触发 TP1→TP2 全流程
- **Committed in:** `2e2fcf3`

**2. [Rule 2 - Missing Critical] 回测夹具不兼容默认参数**
- **Found during:** Task 1 testing
- **Issue:** vShapedRecovery() 下跌段 30 根 bar 远超 dropMaxCandles=3，默认 ReboundParams 下信号为 null——全部引擎测试无法执行
- **Fix:** 新增 vShapedQuickRecovery() 夹具：40 根 15m K 线，3 根急跌（low 逐根降低确保 swingLow 检出）+ 2 根反弹（low 逐根提高确保最低点唯一），反弹段 close 回补比率 >= 0.5
- **Files modified:** `test/services/rebound/test_fixtures.dart` (added vShapedQuickRecovery function)
- **Verification:** V 型反弹全流程测试通过，lookahead-analysis test 2 通过
- **Committed in:** `2e2fcf3` (bundled with implementation)

**3. [Rule 2 - Missing Critical] 不叠加仓位测试需要跳过同仓位分批退出**
- **Found during:** Task 1 testing
- **Issue:** 重叠检测将同一仓位 TP1(50%) + TP2(50%) 的两笔 BacktestTrade 判为"仓位重叠"（因共享同一 entryTime，exitTime 自然交错）
- **Fix:** 修改重叠检测逻辑——同一 entryTime 的 trades 视为同仓位，跳过比较；仅在不同 entryTime 的 trades 间检测重叠
- **Files modified:** `test/services/rebound/backtest_engine_test.dart` (test 4 重叠检测逻辑)
- **Verification:** 不叠加仓位测试通过
- **Committed in:** `2e2fcf3` (via test fixture edits)

**4. [Rule 3 - Blocking] BacktestEngine 不需要 AppDatabase 依赖**
- **Found during:** Task 1 implementation
- **Issue:** Plan 要求 BacktestEngine 构造函数接受 `required AppDatabase db`，但测试需直接传入 K 线列表（不经过 drift）——入参不可用 null 替代 required 参数
- **Fix:** 移除 AppDatabase 依赖，公开方法改为 `runBacktestOnKlines(List<KlineData> klines, ...)` 纯数据驱动；drift 集成留待 BacktestProvider 层
- **Files modified:** `lib/services/rebound/backtest_engine.dart` (constructor + method signature)
- **Verification:** 所有引擎测试直接使用合成 K 线通过
- **Committed in:** `2e2fcf3`

---

**Total deviations:** 4 auto-fixed (1 bug, 2 missing critical, 1 blocking)
**Impact on plan:** 所有自动修复均为正确性必需。无范围蔓延。核心架构（event-driven 逐 bar 推进、禁用向量化）完全保持不变。

## Issues Encountered

- `flutter test --no-pub` 在 worktree 中需要复制 `.dart_tool/` 从主仓库以解析依赖——无网络环境下手动解决了包解析问题
- `syntheticKlines(500)` 使用宽松参数（`ReboundParams.looseForTesting`）以确保触发足够的信号——随机游走数据默认参数下可能触发 0 笔交易

## Known Stubs

None - 所有引用的类和文件均已实现，无占位符代码。

## Threat Flags

None - 实现的四个服务类均为纯计算逻辑（零 I/O），不引入新的网络端点、认证路径或文件访问模式。威胁面不变。

## Next Phase Readiness

- BacktestEngine/TradeSimulator/WalkForward/ReportGenerator 四个核心服务类就绪
- Lookahead-Analysis UAT 通过（BACKTEST-06 门控满足）
- 5 个测试文件 + 共享夹具就绪
- 等待 Phase 06-03（UI 回测屏幕）接入 engine 和 report generator

---
*Phase: 06-event-driven*
*Completed: 2026-06-20*
