# 反弹通知：最新一根才通知 + 通知历史

- 日期：2026-06-30
- 范围：通知新鲜度收紧 + 通知历史持久化与展示
- 状态：已批准，待实现

## 需求

1. **最新一根确认才通知**：反弹拉回段必须在最新一根 K 线确认（`recoveryEndIndex == window.length-1`）才推送，避免通知数根前的旧反弹。
2. **通知历史**：保存每次推送的通知，在监控页显示历史列表。

## 设计

### 需求 1：新鲜度收紧

- `ReboundSignal` 加字段 `isLatestBar`（bool，默认 false，向后兼容）。
- `scanner._scanSymbol` 命中后设 `isLatestBar = recoveryEndIndex == window.length-1`（有准确 window）。
- `alertService.handleClosedKline` detector 返回后同样标记（有 window）。
- **通知条件 = `isLatestBar && high`**：dashboard `onScanComplete` 仅对 `isLatestBar` 调 `notifyOnSignal`；`handleClosedKline` 仅对 `isLatestBar` 调 `_dispatchIfHigh`。
- 列表显示门槛不变（`recentBars=6`、`score≥70`）——通知比显示更严。

### 需求 2：通知历史

**存储（sqflite）**
- `DatabaseHelper`：`version 4→5`，`onCreate` + `onUpgrade(oldVersion<5)` 建 `rebound_notifications` 表：`(id PK, symbol, timeframe, score, deadCatRiskScore, dropMagnitude, recoveryRatio, notifiedAt)` + 索引 `idx_notified_at(notifiedAt DESC)`。
- 新 model `ReboundNotificationRecord`：上述字段 + `notifiedAt: DateTime`。
- 新 `ReboundNotificationRepository`：`insert(ReboundSignal)` / `queryRecent(int limit) → List<ReboundNotificationRecord>`。

**数据流**
- `alertService` 注入 `ReboundNotificationRepository`（DI，便于测试）。
- `_dispatchIfHigh`：throttler 通过且 `level==high` → `dispatch` + `repository.insert(signal)`。
- `ReboundScoreProvider` 加 `List<ReboundNotificationRecord> notificationHistory` + `loadNotificationHistory(repo)` + `addNotificationHistory(record)`。
- alertService insert 后调 `provider.addNotificationHistory` 同步内存。
- dashboard 启动 `loadNotificationHistory`；底部加**可折叠历史区域**显示最近 N 条（时间、币种、评分、跌幅）。

## 改动文件

- `lib/models/rebound_signal.dart`：加 `isLatestBar`
- `lib/models/rebound_notification_record.dart`：新（历史记录 model）
- `lib/services/database_helper.dart`：v5 建表
- `lib/services/rebound/rebound_notification_repository.dart`：新
- `lib/services/rebound/rebound_market_scanner.dart`：标记 `isLatestBar`
- `lib/services/rebound/rebound_alert_service.dart`：DI repo + `_dispatchIfHigh` 收紧 + 记录历史
- `lib/providers/rebound_score_provider.dart`：历史列表
- `lib/screens/rebound_dashboard_screen.dart`：onScanComplete `isLatestBar` 判断 + 历史 UI

## 测试

- `database_helper_test`：v5 migration 建 `rebound_notifications` 表
- `rebound_notification_repository_test`：insert/queryRecent（in-memory sqflite）
- `rebound_market_scanner_test`：`isLatestBar` 标记（最新一根 vs 历史反弹）
- `rebound_alert_service_test`：`_dispatchIfHigh` 仅 `isLatestBar && high` 推送 + 记录历史；非最新一根不推送
- `rebound_score_provider_test`：历史列表 load/add
- dashboard UI 无单测（手动审查）

## 不做（YAGNI）

- 不改 detector（保持纯函数）。
- 历史不分页/不筛选，仅最近 N 条。
- 不做单独历史页面（用户选监控页内区域）。
