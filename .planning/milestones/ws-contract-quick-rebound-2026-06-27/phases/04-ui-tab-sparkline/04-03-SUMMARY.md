---
phase: 04-ui-tab-sparkline
plan: 03
subsystem: monitor
tags: [rebound, scanner, rest-polling, market-scan, precise-tracking, 15m, dashboard]

requires:
  - phase: 03-monitor-websocket
    provides: ReboundScoreProvider, ReboundAlertService, ReboundKlineStreamService, ReboundDetector
  - phase: 04-02
    provides: ReboundDashboardScreen 看板 UI、ReboundScoreProvider sparkline 数据
provides:
  - ReboundMarketScanner 全市场 REST 轮询扫描器（仅 15m）
  - ReboundAlertService 动态精跟（命中→精跟 / 评分回落→退出 / FIFO 上限 30）
  - ReboundKlineStreamService 增量 subscribe/unsubscribe（_streamToConn 索引）
  - monitoredTimeframes 单一周期常量源（rebound_timeframes.dart）
  - 看板去周期 Tab 改 15m 单页 + 扫描状态横幅
affects:
  - 05-push-alert（推送提醒可对接 scanner 命中事件）

tech-stack:
  added: []
  patterns: [全市场 REST 轮询扫描 + 命中精跟, timeframes 常量单一真源, WS 增量订阅]

key-files:
  created:
    - lib/services/rebound/rebound_timeframes.dart（monitoredTimeframes 单一周期配置源）
    - lib/services/rebound/rebound_market_scanner.dart（全市场 REST 轮询扫描器）
  modified:
    - lib/services/rebound/rebound_alert_service.dart（attachScanner/trackSymbols/untrackSymbol/FIFO/连续未命中退出 + monitoredTimeframes）
    - lib/services/rebound/rebound_kline_stream_service.dart（subscribe/unsubscribe 增量订阅 + _streamToConn + monitoredTimeframes）
    - lib/screens/rebound_dashboard_screen.dart（接 scanner + 去周期 Tab 单页 + 扫描横幅）
    - lib/providers/rebound_score_provider.dart（扫描状态字段 scanRound/trackedCount/lastScanTime）

key-decisions:
  - "收缩到 15m 单周期（brainstorming 决策）：新增 monitoredTimeframes=['15m'] 单一常量源，scanner/alert/stream 默认引用；多周期架构全部保留，未来恢复改常量即可。负载 1600→400 请求/轮（-75%）"
  - "全市场 REST 轮询（非全量 WS）：limit=99 weight=1，单轮 400 请求 weight=400 ≤ 2400/min（占 ~17%），错峰分批 batch=8 + 200ms，轮询 60s，_scanning 重入守卫 + 429 退避"
  - "命中精跟生命周期：命中→trackSymbols 增量 subscribe、连续 3 根未命中→untrack、FIFO 上限 30 防连接膨胀"
  - "WS 增量订阅方案 A（_streamToConn 索引 + SUBSCRIBE/UNSUBSCRIBE JSON）：避免 disconnect+reconnect 触发精跟标的重新 warm-up 信号真空"
  - "看板去周期 Tab 改单页：单周期无需 Tab；_timeframes/_tfLabels/_defaultSymbols 删除（unused），Tab 重建成本极低"
  - "副作用已知：单周期 mtfConfluence 跨周期共振加分恒 0，15m 评分上限降低，不影响 15m 内排序"

patterns-established:
  - "timeframes 单一真源: rebound_timeframes.dart const monitoredTimeframes，所有消费方引用，未来扩展改一处"
  - "全市场扫描+精跟: REST 轮询发现 → 命中增量 WS 精跟 → 评分回落退出，复用同一 ReboundDetector.evaluate"

requirements-completed: [MONITOR-01, MONITOR-03, MONITOR-04, DASH-01, DASH-04]

duration: —
completed: 2026-06-20
status: complete（实现完成，待人工 UAT）
---

# Phase 4 Plan 3: 全市场扫描 + 命中精跟 + 收缩到 15m 单周期 总结

**实现全市场 REST 轮询扫描器（ReboundMarketScanner），从全部 ~400 USDT 永续合约自动发现反弹候选（仅 15m 单周期），命中标的动态进入 WS 精跟（增量订阅 + FIFO 上限 + 评分回落退出）；看板移除周期 Tab 改 15m 单页 + 扫描状态横幅。执行中途按用户决策将范围从 4 周期收缩到 15m 单周期（降低 75% 扫描负载先跑通），多周期架构全部保留。**

## Performance

- **Tasks:** 3（scanner / 精跟+增量订阅 / 看板+provider）
- **Tests:** 53 全通过（scanner 9 含参数化回归 1 + alert + stream + provider + detector）
- **flutter analyze:** 改动文件 0 issues

## 范围调整（2026-06-20，执行中途 brainstorming 决策）

原 04-03 设计为全市场 × **4 周期**（15m/1h/4h/1d）= 1600 请求/轮。用户决策「功能稳定后再扩展」，**收缩为仅 15m 单周期**：

- 新增 `lib/services/rebound/rebound_timeframes.dart` → `const monitoredTimeframes = ['15m']`（单一真源）
- scanner / alert_service / stream_service 默认 timeframes 引用 monitoredTimeframes（消除 5 处散落硬编码）
- 限流：1600→**400 请求/轮**（weight 400，占 2400/min 上限 ~17%，余量充足）
- 看板移除周期 Tab，改 15m 单页列表
- 多周期架构（timeframe 字段 / 各周期参数 / 共振评分器 / Provider 多 TF map）**全部保留**，未来恢复改 `monitoredTimeframes` 一行即可
- 副作用：单周期 mtfConfluence 跨周期共振加分恒 0，评分上限降低（不影响 15m 内排序）

详见 04-03-PLAN 决策 D8。

## Accomplishments

- **ReboundMarketScanner**（324 行）——全市场 REST 轮询：错峰分批（batch=8 + 200ms）、limit=99 weight=1、`_scanning` 重入守卫、429 退避（跳 2 轮）、扫描进度回调（round/scanned/total/lastScanTime）
- **ReboundAlertService 动态精跟**——attachScanner / trackSymbols（差集+增量 subscribe）/ untrackSymbol / FIFO 驱逐（maxTracked=30）/ 连续 missThreshold=3 退出 / trackedCount getter
- **ReboundKlineStreamService 增量订阅**——subscribe/unsubscribe + `_streamToConn` 索引 + SUBSCRIBE/UNSUBSCRIBE JSON（方案 A，避免重连 warm-up 真空）
- **ReboundScoreProvider 扫描状态**——scanRound / trackedCount / lastScanTime + updateScanState
- **看板改造**——移除 TabBar/TabController/`_defaultSymbols`/`sublist(0,50)`，接 scanner 全市场扫描，去周期 Tab 改 15m 单页，新增扫描状态横幅
- **timeframes 单一真源**——消除 scanner/alert/stream/dashboard 共 5 处散落 `['15m','1h','4h','1d']` 硬编码

## Files Created/Modified

- `lib/services/rebound/rebound_timeframes.dart`（新建）——monitoredTimeframes 单一周期配置源
- `lib/services/rebound/rebound_market_scanner.dart`——全市场扫描器，默认 timeframes=monitoredTimeframes
- `lib/services/rebound/rebound_alert_service.dart`——动态精跟 + monitoredTimeframes（start/handleClosedKline/updateSymbolList）
- `lib/services/rebound/rebound_kline_stream_service.dart`——增量订阅 + 3 处 fallback→monitoredTimeframes
- `lib/screens/rebound_dashboard_screen.dart`——接 scanner + 去周期 Tab 单页 + 扫描横幅
- `lib/providers/rebound_score_provider.dart`——扫描状态字段
- `test/services/rebound_market_scanner_test.dart`——默认 15m 断言（400 请求）+ 4 TF 参数化回归（1600）
- `test/services/rebound_alert_service_test.dart`、`test/services/rebound_kline_stream_service_test.dart`——精跟 / 增量订阅测试
- `test/providers/rebound_score_provider_test.dart`——扫描状态字段 3 测试

## Deviations from Plan

**范围调整（已记录于 PLAN 决策 D8）**：执行中途将监控周期从 4 周期收缩到 15m 单周期（用户 brainstorming 决策）。PLAN 的 truths / 限流测算 / 测试断言 / success_criteria 已同步更新为 15m。这不是偏离，是用户主动决策的范围调整。

## Issues Encountered

- dashboard 初版 analyze 报 2 error：`ReboundParams` 未 import、`onProgress` 为 final 不能构造后赋值——已修（加 import + onProgress 改为构造时注入）。

## User Setup Required

None。

## Next Phase Readiness

- 04-03 实现完成，53 测试全绿，analyze 0 error
- **待人工 UAT**：`/gsd-verify-work 04`（看板单页渲染、扫描横幅、KlineScreen 高亮、warm-up 行为）——当前 verification status: `human_needed`
- 通过后 Phase 04 完成，可进入 Phase 5（推送提醒）/ Phase 6（回测）

---
*Phase: 04-ui-tab-sparkline*
*Plan: 03*
*Completed: 2026-06-20*
