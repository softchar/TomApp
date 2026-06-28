# Phase 3 Plan 01 Summary: ReboundKlineStreamService

**Plan:** 03-01-PLAN.md
**Status:** complete
**Date:** 2026-06-19

## What Was Done

### lib/services/rebound/rebound_kline_stream_service.dart

`ReboundKlineStreamService` — sharded combined-stream WebSocket 管理器：

- **Sharding（D-02）**：按标的分片，每连接 ≤1024 stream，2 连接池。stream 名：`{symbolLower}@kline_{tf}`（mark price kline，D-08）。连接后 SUBSCRIBE JSON 消息追加。
- **k.x 过滤（D-03）**：`handleMessage()` 解析 combined-stream JSON。`k.x==true`（收盘确认）→ 触发 `ClosedKline` 事件。`k.x==false`（partial）→ 仅更新 buffer 尾部，不触发。硬断言杜绝 repaint。
- **Rolling buffer**：`Map<symbol, Map<tf, List<KlineData>>>`，最大 100 根/symbol+TF。同一 openTime 替换（partial→closed），新 openTime 追加。
- **Warm-up（D-04/D-06）**：`warmUp()` 方法 REST 拉 100 根历史，期间 `_warmingUp` 标记不触发信号。
- **Reconnect（D-07）**：指数退避 + jitter（1s 基础，60s 上限）。重连用 SUBSCRIBE 消息恢复。
- **@visibleForTesting handleMessage()**：公开消息处理器，测试直接注入模拟 WS 消息，无需真实连接。

### test/services/rebound_kline_stream_service_test.dart（7 测试）

| # | 场景 | 验证 |
|---|------|------|
| 1 | k.x==true → ClosedKline 事件 | 收盘 K 线触发 |
| 2 | k.x==false → 无事件，buffer 更新 | partial 不触发 |
| 3 | partial→收盘替换同一 openTime | buffer 原地替换 |
| 4 | 多根 K 线 buffer 增长 | 5 事件正确 |
| 5 | 不同 symbol/tf 独立 | buffer 独立 |
| 6 | 畸形消息不崩溃 | catch 静默 |
| 7 | mark price stream 格式 | BTCUSDT@kline_15m |

**flutter_test broadcast stream note**: 测试发现 flutter_test 的 FakeAsync zone 导致 broadcast StreamController `add()` 不同步交付——需要 `await Future<void>.value()` 刷新微任务队列。这是 flutter_test 框架行为，非代码 bug。生产环境 WebSocket listener 回调正常。

### dart analyze 0 错误

---
*Plan 01 completed: 2026-06-19*
