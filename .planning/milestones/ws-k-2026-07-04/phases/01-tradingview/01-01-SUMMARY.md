---
phase: 01-tradingview
plan: 01
subsystem: ui
tags: [tradingview, lightweight-charts, webview, kline, localization]

# Dependency graph
requires:
  - phase: existing
    provides: TradingViewKlineWidget base implementation, KlineData model, ReboundTestScreen integration
provides:
  - TradingViewKlineWidget with D-01~D-21 configuration (barSpacing=6, rightOffset=5, fixLeftEdge/fixRightEdge, zh-CN localization)
  - Volume color convention: 涨绿跌红 (international)
  - ECharts component removed, flutter_echarts dependency cleaned
affects: [01-tradingview, rebound-test-screen]

# Tech tracking
tech-stack:
  added: [webview_flutter ^4.4.2]
  patterns: [TradingView Lightweight Charts 4.1.3 CDN, WebView chart rendering, JS localization via timeFormatter/priceFormatter]

key-files:
  created: []
  modified:
    - lib/widgets/tradingview_kline_widget.dart
    - pubspec.yaml

key-decisions:
  - "成交量颜色改为涨绿跌红（国际习惯），蜡烛颜色保持涨红跌绿（中国习惯）"
  - "webview_flutter 添加到 pubspec.yaml 替代缺失依赖"
  - "flutter pub get 因国内网络失败，需本地执行更新 pubspec.lock"

patterns-established:
  - "TradingView chart config pattern: createChart options + localization + timeScale settings"
  - "Volume color convention: 涨绿跌红 for volume bars, 涨红跌绿 for candlesticks"

requirements-completed: [TV-01, TV-02, TV-03, CHART-01, CHART-02, CHART-03, DATA-01]

# Metrics
duration: 5min
completed: 2026-06-27
status: complete
---

# Phase 01 Plan 01: TradingView 配置调整与 ECharts 清理 Summary

**TradingView 图表配置对齐 D-01~D-21 决策：barSpacing=6 固定粗细、右对齐显示、zh-CN 中文本地化、成交量涨绿跌红，ECharts 组件清理**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-27T08:05:15Z
- **Completed:** 2026-06-27T08:10:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- TradingView 图表配置完全对齐 CONTEXT.md 24 项决策（D-01~D-21）
- 中文本地化支持：locale zh-CN、时间格式 MM-dd HH:mm、价格千位分隔符
- 成交量颜色修正为涨绿跌红（国际习惯），蜡烛颜色保持涨红跌绿（中国习惯）
- 可见范围从左侧起始改为最新数据在右侧，可见蜡烛数从 30 增至 50
- ECharts 组件文件移除，webview_flutter 依赖添加

## Task Commits

Each task was committed atomically:

1. **Task 1: TradingView 配置调整与中文本地化** - `cac9d16` (feat)
2. **Task 2: ECharts 清理与依赖更新** - `e1213f1` (feat)

## Files Created/Modified
- `lib/widgets/tradingview_kline_widget.dart` - TradingView 图表配置：barSpacing=6, rightOffset=5, fixLeftEdge/fixRightEdge=true, shiftVisibleRangeOnNewBar=true, scaleMargins 调整, localization(zh-CN/timeFormatter/priceFormatter), 成交量涨绿跌红
- `pubspec.yaml` - 添加 webview_flutter: ^4.4.2 依赖

## Decisions Made
- 成交量颜色采用涨绿跌红（国际习惯），蜡烛颜色保持涨红跌绿（中国习惯）—— per D-06
- webview_flutter 添加到 pubspec.yaml（工作树中原先缺失此依赖）
- flutter pub get 因国内网络环境失败，需用户本地执行 `flutter pub get` 更新 pubspec.lock

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added webview_flutter dependency to worktree pubspec.yaml**
- **Found during:** Task 2 (ECharts cleanup)
- **Issue:** Worktree pubspec.yaml (based on commit d20dc96) did not contain webview_flutter, but TradingViewKlineWidget requires it
- **Fix:** Added `webview_flutter: ^4.4.2` to pubspec.yaml dependencies
- **Files modified:** pubspec.yaml
- **Verification:** Dependency listed in pubspec.yaml
- **Committed in:** e1213f1 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Auto-fix necessary for correctness -- TradingViewKlineWidget imports webview_flutter and would fail to compile without it. No scope creep.

## Issues Encountered
- `flutter pub get` failed due to network issues (pub.dev unreachable from current environment). pubspec.lock not updated. User needs to run `flutter pub get` locally to resolve dependencies.
- ECharts widget file (echarts_kline_widget.dart) was untracked in main repo, not present in worktree git history. Copied to worktree, then deleted. The deletion won't appear in git diff since it was never committed.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- TradingViewKlineWidget fully configured per D-01~D-21 decisions
- Ready for Phase 2: real-time data integration
- User must run `flutter pub get` locally before building

---
*Phase: 01-tradingview*
*Completed: 2026-06-27*

## Self-Check: PASSED

- FOUND: lib/widgets/tradingview_kline_widget.dart
- CONFIRMED: lib/widgets/echarts_kline_widget.dart deleted
- FOUND: commit cac9d16 (Task 1)
- FOUND: commit e1213f1 (Task 2)
