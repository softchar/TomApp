# 合约反弹监控页：扫描命中立即通知（只推 high）

- 日期：2026-06-29
- 范围：监控页通知触发时机 + 门槛
- 状态：已批准，待实现

## 背景

监控页已有完整通知管线（`ReboundNotificationService` 双渠道 + `AlertThrottler` 五道闸门），但有缺口：

1. **扫描命中不通知**：信号在 `scanner.onScanComplete` 时已上板，但通知只在 WS 收到下一根 15m **收盘 K 线**时（`handleClosedKline`）触发 → 信号出现后最长等 15 分钟才推送。
2. 用户阈值未注入（`AlertSettingsProvider` 存在但 dashboard 没传给 alertService）—— 本次不处理。
3. 通知门槛：`score≥50` 推送（high+med），更低分只看板。

## 目标

- 信号一上板（扫描命中）就推送，不等收盘。
- 只推 high 级强信号，避免打扰。

## 设计

### 触发
`scanner.onScanComplete` 命中信号 → 调 `alertService.notifyOnSignal(enriched)`（用 mtf 加分后的 score）。

### 门槛
只推 high 级（`score≥75 且 deadCatRiskScore<50`）。medium / low 仅看板可见，不推送。

### 节流 / 去重（关键）
复用现有 `AlertThrottler`（per-symbol 4h 冷却 + 日上限 20 + 跨日重置）。**scanner 与 WS 收盘路径共享同一 throttler 实例** → 同一 symbol 扫描命中通知后，4h 内 WS 收盘再判定被冷却拦截，天然不重复。

## 改动

1. **`lib/services/rebound/rebound_alert_service.dart`**
   - 抽私有 `Future<void> _dispatchIfHigh(ReboundSignal signal)`：`_throttler.evaluate(...)` 后，仅 `decision.level == AlertLevel.high` 时 `_notificationService.dispatch(decision)`。
   - 公开 `Future<void> notifyOnSignal(ReboundSignal signal)` → 调 `_dispatchIfHigh`（供 dashboard onScanComplete 调用）。
   - `handleClosedKline` 现有内联通知段（第 268-285 行）改用 `_dispatchIfHigh(signal)`。**行为变更**：WS 路径从 high+med 收窄到只 high，与扫描路径统一。

2. **`lib/screens/rebound_dashboard_screen.dart`**
   - `onScanComplete` 命中循环内，对 `enriched` 信号调 `_alertService!.notifyOnSignal(enriched)`（fire-and-forget）。

## 不做（YAGNI）

- 缺口2（`AlertSettingsProvider` 注入）：默认 `high=75` 已满足"只推 high"；用户可调阈值/TF 开关另开任务。
- 不改 `ReboundNotificationService`、`AlertThrottler`、`ReboundDetector`。

## 测试

`test/services/rebound_alert_service_test.dart` 新增：
- `notifyOnSignal` 对 high 级信号推送、对 medium/low 不推送。
- 节流生效：同 symbol 4h 内第二次被冷却拦截；日上限拦截。
- scanner 与 WS 共享 throttler：一条路径通知后另一条路径同 symbol 被拦截。

dashboard 为 UI，不加单测。
