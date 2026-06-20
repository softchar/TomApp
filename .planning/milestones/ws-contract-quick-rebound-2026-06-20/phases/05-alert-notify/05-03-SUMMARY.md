---
phase: 05-alert-notify
plan: 03
subsystem: alerting
tags:
  - integration
  - wiring
  - ui-settings
  - notification-pipeline
requires:
  - 05-01 (alert_level, alert_throttler)
  - 05-02 (rebound_notification_service, alert_settings_provider)
provides:
  - ALERT-01 (TF toggle settings)
  - ALERT-02 (high/med threshold sliders)
  - ALERT-03 (evaluate pipeline wiring)
  - ALERT-04 (dispatch pipeline wiring)
  - ALERT-05 (notif visibility by level)
  - ALERT-06 (cooldown reset on stop)
affects:
  - rebound_alert_service
  - main.dart provider tree
  - profile_screen settings UI
tech-stack:
  added:
    - AlertThrottler (gate pipeline)
    - ReboundNotificationService (notif dispatch)
    - AlertSettingsProvider (user settings)
  patterns:
    - Constructor injection (AlertSettingsProvider optionally injected)
    - Async stream listener (Future<void> callback for handleClosedKline)
    - Fire-and-forget for non-blocking operations
key-files:
  created: []
  modified:
    - lib/services/rebound/rebound_alert_service.dart (Phase 5 notification pipeline)
    - lib/main.dart (AlertSettingsProvider registration)
    - lib/screens/profile_screen.dart (Rebound alert settings section)
  copied-from-main:
    - lib/models/alert_level.dart
    - lib/models/rebound_signal.dart
    - lib/models/rebound_params.dart
    - lib/providers/alert_settings_provider.dart
    - lib/providers/rebound_score_provider.dart
    - lib/services/rebound/alert_throttler.dart
    - lib/services/rebound/rebound_notification_service.dart
    - lib/services/rebound/rebound_timeframes.dart
    - lib/services/rebound/rebound_confluence_scorer.dart
    - lib/services/rebound/rebound_detector.dart
    - lib/services/rebound/rebound_kline_stream_service.dart
    - lib/services/rebound/rebound_market_scanner.dart
decisions:
  - D-05-03-01: handleClosedKline changed to Future<void> async (方案 A) — stream listener accepts async callbacks, no signature break
  - D-05-03-02: AlertSettingsProvider injected optionally via constructor — null-safe with defaults (highThreshold=75, medThreshold=50, all TF toggles=true)
  - D-05-03-03: Notification pipeline placed AFTER provider.upsert — signal appears on dashboard before notification is sent
  - D-05-03-04: Widget UI文案使用「监控候选」「提醒」措辞，遵循 DASH-05 禁用词规范
metrics:
  duration: 1m 7s
  tasks: 3
  files_changed: 3 (modified) + 10 (dependency copies from main repo)
  completed_date: "2026-06-20"
status: complete
---

# Phase 5 Plan 3: 组件接线 Summary

**将 AlertThrottler + ReboundNotificationService + AlertSettingsProvider 接入既有 ReboundAlertService / main.dart / ProfileScreen 管线。**

## Tasks Executed

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | 在 ReboundAlertService 中集成 AlertThrottler + ReboundNotificationService | `7ac9179` | complete |
| 2 | 在 main.dart 注册 AlertSettingsProvider 并初始化通知服务 | `2ab54c0` | complete |
| 3 | 在 ProfileScreen 新增「反弹提醒」设置 section | `e3e6552` | complete |

## Verification Results

- `flutter analyze --no-fatal-infos` (3 files): **0 errors**, 17 info-only (all pre-existing)
- `flutter test`: **51 passed**, 5 network-only failures (pre-existing Binance WebSocket timeout)
- No regressions introduced

## Deviations from Plan

None - plan executed exactly as written. All three tasks completed per the specified acceptance criteria.

## Known Stubs

None. All UI values are dynamically read from AlertSettingsProvider via Consumer. Default thresholds (75/50) are intentional fallback values documented in the plan, not stubs.

## Threat Flags

None. All threat mitigations from the plan's threat model (T-05-06 lock screen visibility, T-05-07 payload injection validation, T-05-08 DoS prevention) are already implemented by the 05-01/05-02 components being wired in this plan.

## Self-Check: PASSED

All modified files exist:
- FOUND: lib/services/rebound/rebound_alert_service.dart
- FOUND: lib/main.dart
- FOUND: lib/screens/profile_screen.dart

All commits verified:
- FOUND: 7ac9179
- FOUND: 2ab54c0
- FOUND: e3e6552
