---
phase: 04-ui-tab-sparkline
plan: 02
subsystem: ui
tags: [flutter, provider, fl_chart, sparkline, dashboard, kline, navigation]

# Dependency graph
requires:
  - phase: 03-monitor-websocket
    provides: ReboundScoreProvider, ReboundAlertService, ReboundKlineStreamService, ReboundDetector
  - phase: 04-01
    provides: fl_chart ^1.2.0（用于迷你 sparkline 渲染）
provides:
  - ReboundDashboardScreen 反弹监控看板（TabBar 分周期 + 信号列表 + sparkline）
  - MainNavigation 反弹 Tab 集成（第 6 个底部导航项）
  - KlineScreen 高亮标注（highlightStartMs/highlightEndMs 参数 + _HighlightPainter）
  - ReboundScoreProvider 增强（recentCloses + warmingUpSymbols）
  - ReboundAlertService warm-up 状态追踪
affects:
  - 05-push-alert（推送提醒 Phase 可能依赖看板状态）
  - 06-backtest（回测可能复用 KlineScreen 高亮标注）

# Tech tracking
tech-stack:
  added: []
  patterns: [ChangeNotifier Provider 消费模式, fl_chart 1.2 LineChart 迷你图]

key-files:
  created:
    - lib/screens/rebound_dashboard_screen.dart（462 行反弹看板页面）
  modified:
    - lib/providers/rebound_score_provider.dart（新增 recentCloses + warmingUpSymbols）
    - lib/services/rebound/rebound_alert_service.dart（传递收盘价 + warm-up 追踪）
    - lib/screens/main_navigation.dart（新增第 6 个反弹 Tab）
    - lib/screens/kline_screen.dart（新增 highlightStartMs/EndMs 参数）
    - lib/widgets/kline_chart_widget.dart（新增 _HighlightPainter 高亮标注）

key-decisions:
  - "fl_chart 1.2 保留 FlGridData/FlBorderData/FlTitlesData/FlDotData 等 Fl 前缀类型名——迷你 sparkline 使用 Fl 前缀 API"
  - "warm-up 状态追踪通过 Provider 的 warmingUpSymbols 集合 + AlertService 的 per-kline 检测实现——O(4) per kline（4 个 TF × 1 symbol），避免 O(n×4) 扫描"
  - "下钻高亮时间戳通过 signal 的 dropStartIndex/recoveryEndIndex + timeframe duration 反推——不精确但无需额外数据字段"
  - "看板按需启动 ReboundAlertService（initState → start），dispose 时停止——符合 Phase 3 设计，避免 app 启动时建立 1600 路 WS"
  - "UI 文案全部中文；用'监控候选'替代'信号'；无'买入'/'强买'等执行性措辞"

patterns-established:
  - "迷你 sparkline: fl_chart 1.2 LineChart + LineChartBarData + FlSpot，无轴/无网格/无边框，按涨跌着色"
  - "反弹 Tab 集成: IndexedStack 第 6 个 child + BottomNavigationBarItem，Icons.trending_up 图标"
  - "K 线高亮标注: Stack + IgnorePointer + CustomPaint(_HighlightPainter)，时间戳→数据索引→比例映射 x 坐标"

requirements-completed: [DASH-01, DASH-02, DASH-03, DASH-04, DASH-05, DASH-06]

# Metrics
duration: 6min
completed: 2026-06-19
status: complete
---

# Phase 4 Plan 2: ReboundDashboardScreen 看板 + 导航集成 + K 线下钻 总结

**创建「合约反弹监控」实时看板页面，按周期分 Tab（15m/1h/4h/1d），信号按评分降序排列，每行展示币种/评分/跌幅/回补%/迷你 sparkline/死猫风险/止损位，点击信号下钻到 KlineScreen 并高亮标注反弹窗口。全项目文案合规（无买入/强买等措辞）。**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-19T11:27:49Z
- **Completed:** 2026-06-19T11:34:34Z
- **Tasks:** 3
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments
- ReboundDashboardScreen（462 行）——4 个周期 Tab + 信号列表 + 迷你 sparkline + 死猫风险标注 + warm-up 状态条 + 底部风险提示
- ReboundScoreProvider 增强——getRecentCloses（sparkline 数据）、warmingUpSymbols（warm-up 状态追踪）
- ReboundAlertService 增强——传递最近 20 根收盘价到 Provider、warm-up state 实时追踪
- MainNavigation 新增第 6 个底部 Tab「反弹」——IndexedStack + Icons.trending_up
- KlineScreen 下钻路由——可选 highlightStartMs/highlightEndMs 参数，支持反弹窗口高亮标注
- KlineChartWidget 高亮标注——_HighlightPainter CustomPainter，绿色半透明矩形标注反弹区域
- 全项目 flutter analyze 仅 2 个预存 integration_test 错误，无新增问题
- 新文件 grep 无 UI 文案「买入」「强买」；UI 中用「监控候选」替代「信号」

## Task Commits

Each task was committed atomically:

1. **Task 1 (TDD RED): 添加 failing test for recentCloses sparkline data flow** - `b5ce4e2` (test)
2. **Task 1 (TDD GREEN): 实现 recentCloses sparkline 数据流** - `3432953` (feat)
3. **Task 2: ReboundDashboardScreen 看板页面** - `77b2427` (feat)
4. **Task 3: MainNavigation 集成 + KlineScreen 下钻 + 高亮标注** - `44371d4` (feat)

**Plan metadata:** 将在 SUMMARY.md 提交时创建

## Files Created/Modified
- `lib/screens/rebound_dashboard_screen.dart` - 反弹监控看板页面（462 行，中文 UI）
- `lib/providers/rebound_score_provider.dart` - 新增 _recentClosesBySymbol、_warmingUpSymbols、getRecentCloses/updateWarmingUpSymbols
- `lib/services/rebound/rebound_alert_service.dart` - handleClosedKline 传递 recentCloses、warm-up 状态追踪
- `lib/screens/main_navigation.dart` - 新增第 6 个反弹 Tab（Icons.trending_up）
- `lib/screens/kline_screen.dart` - 新增 highlightStartMs/highlightEndMs 可选参数
- `lib/widgets/kline_chart_widget.dart` - 新增 _HighlightPainter CustomPainter 高亮标注
- `test/providers/rebound_score_provider_test.dart` - 新增 5 个 recentCloses 测试

## Decisions Made
- **fl_chart 1.2 保留 Fl 前缀类型名：** 迷你 sparkline 使用 FlGridData/FlBorderData/FlTitlesData/FlDotData 等 API——与 Plan 04-01 发现一致
- **warm-up 状态追踪 O(4) per kline：** 在 AlertService.handleClosedKline 中检查单个 symbol 的 4 个 TF warm-up 状态，而非 O(n×4) 全量扫描
- **下钻高亮时间戳反推：** 通过 signal.dropStartIndex/recoveryEndIndex + tfDurationMs 计算 startMs/endMs——不精确但无需额外数据字段
- **看板按需启动编排器：** initState → ReboundAlertService.start()，dispose → stop()——符合 Phase 3 设计（避免 app 启动时建立 1600 路 WS）
- **UI 文案合规：** 全部中文；用「监控候选」替代「信号」；无「买入」「强买」「发财」「保证」「盈利」等措辞

## Deviations from Plan

None - plan executed exactly as written. No auto-fixes, no blocking issues, no architectural changes needed.

## Issues Encountered
None. All tasks completed on first attempt.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ReboundDashboardScreen 看板页面完整可用（编译通过、flutter analyze 0 错误）
- 反弹 Tab 已集成到 MainNavigation（第 6 个底部导航项）
- KlineScreen 下钻路由 + highlight 标注已完成
- Phase 3 既有 14 个测试全通过（无回归）
- 准备好进入 Phase 5（推送提醒）或 Phase 6（回测验证）

---
*Phase: 04-ui-tab-sparkline*
*Completed: 2026-06-19*
