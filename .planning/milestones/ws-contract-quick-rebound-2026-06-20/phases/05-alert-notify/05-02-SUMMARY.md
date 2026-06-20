---
phase: 05-alert-notify
plan: 02
subsystem: 推送提醒 - 通知分发与设置
tags: [notification, shared_preferences, provider, android-channels]
requires:
  - 05-01
provides:
  - ALERT-01
  - ALERT-04
affects:
  - lib/services/rebound/
  - lib/providers/
tech-stack:
  added: []
  patterns:
    - Service-per-Channel（多渠道通知服务，与现有 NotificationService 隔离）
    - ChangeNotifier + SharedPreferences 持久化配置模式
key-files:
  created:
    - lib/services/rebound/rebound_notification_service.dart
    - lib/providers/alert_settings_provider.dart
    - test/services/rebound/rebound_notification_service_test.dart
    - test/providers/alert_settings_provider_test.dart
  modified: []
decisions:
  - "ReboundNotificationService 与现有 NotificationService 完全独立——各自持有 FlutterLocalNotificationsPlugin 实例，渠道 ID 命名空间隔离"
  - "dispatch(AlertLevel.low) 在 initialize() 之前 early-return——low 级别不需要通知渠道初始化"
  - "lockScreenVisibility: high=public（锁屏可见）, med=private（仅解锁后显示）per T-05-04"
  - "symbol 跳转前正则校验 ^[A-Z0-9]{5,20}$ per T-05-05，防 payload 注入"
  - "日上限计数器不在 AlertSettingsProvider 中（per RESEARCH.md Pitfall 2）——由 AlertThrottler 内存维护"
metrics:
  duration: 9min
  completed: 2026-06-20
  tasks: 3
  files: 4
status: complete
---

# Phase 05 Plan 02: 通知分发服务与用户设置 Provider 摘要

**一句话概述**：通过 ReboundNotificationService 实现 Android 双渠道分级推送（high 响铃振动 / med 横幅 / low 仅看板）+ AlertSettingsProvider 提供 SharedPreferences 持久化的 TF 开关和阈值配置，10 个测试全部通过。

## 完成情况

| 任务 | 名称 | 状态 | 提交 |
|------|------|------|------|
| 1 | 创建 ReboundNotificationService（TDD RED） | 完成 | 6bf1587 |
| 1 | 创建 ReboundNotificationService（TDD GREEN） | 完成 | 9820117 |
| 2 | 创建 AlertSettingsProvider（TDD RED） | 完成 | 644f32d |
| 2 | 创建 AlertSettingsProvider（TDD GREEN） | 完成 | a15c8d9 |
| 3 | 最终测试文件验证与增强 | 完成 | 81ff139 |

### 已创建的文件

| 文件 | 用途 | 行数 |
|------|------|------|
| `lib/services/rebound/rebound_notification_service.dart` | 多渠道通知创建与分发服务 | ~195 |
| `lib/providers/alert_settings_provider.dart` | TF 开关 + 阈值 SP 持久化 Provider | ~105 |
| `test/services/rebound/rebound_notification_service_test.dart` | 通知渠道创建 + 三级分发测试 | ~95 |
| `test/providers/alert_settings_provider_test.dart` | 配置读写 + SP 持久化测试 | ~90 |

### 测试结果

```
flutter test test/services/rebound/rebound_notification_service_test.dart \
            test/providers/alert_settings_provider_test.dart

00:00 +10: All tests passed!
```

- ReboundNotificationService: 4 tests（渠道创建 smoke + high/med/low 三级分发）
- AlertSettingsProvider: 6 tests（默认值 + TF 开关 + 阈值 clamp + SP 持久化 + all TFs default true）

## 实现要点

### ReboundNotificationService

- **双渠道架构**：`rebound_high`（Importance.max + 振动 + heads-up）和 `rebound_med`（Importance.defaultImportance + 声音），与现有 `funding_rate_channel`/`pump_alerts` 完全隔离
- **三级分发**：
  - `AlertLevel.high` → `rebound_high` 渠道（响铃+振动+heads-up，锁屏可见 public）
  - `AlertLevel.medium` → `rebound_med` 渠道（横幅+声音，锁屏隐藏 private）
  - `AlertLevel.low` → 直接 return（仅看板可见，不创建/初始化通知渠道）
- **安全性**：
  - T-05-04: lockScreenVisibility 按级别设置（high=public, med=private）
  - T-05-05: 通知点击跳转前校验 symbol 格式（`^[A-Z0-9]{5,20}$`）
- **initialize() 幂等**：`AndroidFlutterLocalNotificationsPlugin.createNotificationChannel()` 在渠道已存在时自动跳过

### AlertSettingsProvider

- **ChangeNotifier 模式**：继承现有 Provider 模式（参考 `ReboundScoreProvider`）
- **持久化配置**：通过 SharedPreferences 存储 4 TF 开关（`alert_tf_toggle_{tf}`）+ 高/中阈值（`alert_high_threshold`/`alert_med_threshold`）
- **输入校验**：setter 强制 `clamp(0, 100)` per ASVS V5（T-05-03）
- **默认值**：所有 TF 开关 true，highThreshold=75，medThreshold=50
- **日上限计数器分离**：不在 Provider 中维护（per RESEARCH.md Pitfall 2），由 AlertThrottler 内存管理

## 偏差记录

无偏差——计划完全按书面内容执行。

## 已知存根

无——所有功能已完整实现，无占位代码。

## 威胁标记

无新增威胁面——所有安全边界已在计划 `<threat_model>` 中覆盖并缓解。

## 自检

- [x] `lib/services/rebound/rebound_notification_service.dart` 存在
- [x] `lib/providers/alert_settings_provider.dart` 存在
- [x] `test/services/rebound/rebound_notification_service_test.dart` 存在
- [x] `test/providers/alert_settings_provider_test.dart` 存在
- [x] 所有提交存在（6bf1587, 9820117, 644f32d, a15c8d9, 81ff139）
- [x] `flutter test` 10/10 全绿
- [x] `dart analyze` 零错误零警告（仅 1 info-level lint）
