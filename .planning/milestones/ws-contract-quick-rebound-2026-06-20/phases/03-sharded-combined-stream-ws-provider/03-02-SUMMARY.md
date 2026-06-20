# Phase 3 Plan 02 Summary: ReboundAlertService + ReboundScoreProvider + main.dart

**Plan:** 03-02-PLAN.md
**Status:** complete
**Date:** 2026-06-19

## What Was Done

### A) ReboundScoreProvider (lib/providers/rebound_score_provider.dart)

ChangeNotifier 扩展，存储 per-(symbol, timeframe) 信号状态：
- `upsert(symbol, tf, signal)` — 更新单个信号 + notifyListeners()
- `upsertBatch()` — 批量更新 + 单次通知
- `getSignal(symbol, tf)` — 单个查询
- `getSignalsForTimeframe(tf)` — 按 score 降序返回
- `removeSymbol(symbol)` — watchlist churn 清理
- `clear()` — 断连清空
- 6 测试全过

### B) ReboundAlertService (lib/services/rebound/rebound_alert_service.dart)

编排器，连接 WS → detector → confluence → provider 全链路：
- `start(symbols, timeframes)` — 启动 WS 连接 + 订阅 closedKlines
- `stop()` — 停止 WS + 取消订阅 + 清空 provider
- `handleClosedKline(c)` — 核心管线：
  1. warm-up 检查 → 2. 获取 window → 3. 调用 ReboundDetector.evaluate → 4. 更新 per-(symbol,TF) 快照 → 5. ReboundConfluenceScorer.scoreMultiTimeframe → 6. enrichment (signal.score + mtfScore.clamp(0,100)) → 7. provider.upsert
- `updateSymbolList()` — watchlist churn 接口（移除下架 + 添加新上线 + warm-up）
- k.x==false 和 warming-up 期间不触发 detector
- 3 测试（closed kline 触发 + partial 不触发 + warming-up 防护）

### C) main.dart 集成

- `ReboundScoreProvider` 以 `ChangeNotifierProvider` 注册到 `MultiProvider`
- 编排器启动设计为 Phase 4 看板按需启动（避免 app 启动时建立 1600 路 WS）

### dart analyze 0 错误

## Artifacts

| 文件 | 作用 |
|------|------|
| `lib/providers/rebound_score_provider.dart` | ChangeNotifier，UI 消费信号状态 |
| `lib/services/rebound/rebound_alert_service.dart` | 编排器：WS→detector→confluence→provider |
| `test/providers/rebound_score_provider_test.dart` | Provider 6 测试 |
| `test/services/rebound/rebound_alert_service_test.dart` | 编排器 3 测试（全链路） |
| `lib/main.dart` | ReboundScoreProvider 注册到 MultiProvider |

---
*Plan 02 completed: 2026-06-19*
