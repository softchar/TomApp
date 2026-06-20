---
phase: 5
slug: alert-notify
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-20
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test + mockito |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `flutter test test/services/alert_throttler_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/services/alert_throttler_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | ALERT-01 | — | 高/中/低三级分级推送，high=响铃+vibrate+heads-up，med=横幅，low=仅看板 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | ALERT-02 | Pitfall 11 | 4h per-symbol 冷却，同币不重复推送 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 1 | ALERT-03 | — | 同币多周期共振合并为 1 条「多周期共振」提醒 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 2 | ALERT-04 | — | 每周期独立开关推送 | widget | `flutter test` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 2 | ALERT-05 | — | 每日推送总量上限 20 条/天，超额仅留最高分 | unit | `flutter test` | ❌ W0 | ⬜ pending |
| 05-02-03 | 02 | 2 | ALERT-06 | Pitfall 11 | 同币连续 4 根 K 线满足信号只推 1 条（UAT 硬标准） | unit | `flutter test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/services/alert_throttler_test.dart` — stubs for ALERT-01/02/03/05/06
- [ ] `test/services/rebound_notification_service_test.dart` — stubs for notification channel creation and display
- [ ] `test/providers/alert_settings_provider_test.dart` — stubs for ALERT-04

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 真机推送弹窗（响铃+vibrate） | ALERT-01 | flutter_local_notifications 真机行为无法在单元测试中验证 | 在 Android 真机上触发 high 级别信号，确认收到 heads-up notification 并伴随响铃和震动 |
| 通知渠道设置可见 | ALERT-04 | Android NotificationChannel 设置由系统 Settings 管理 | 在 Android 真机上进入 App 通知设置，确认可见三个渠道（High/Medium/Low） |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
