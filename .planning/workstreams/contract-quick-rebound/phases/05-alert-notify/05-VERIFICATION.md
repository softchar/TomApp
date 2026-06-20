---
phase: 05-alert-notify
verified: 2026-06-20T07:00:00Z
status: gaps_found
score: 16/19 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "ReboundAlertService.handleClosedKline 在 provider.upsert 之后、方法末尾调用 AlertThrottler.evaluate() + ReboundNotificationService.dispatch()"
    status: failed
    reason: "handleClosedKline 中完全没有 AlertThrottler 或 ReboundNotificationService 的任何调用。文件头无相关 import，类中无 _throttler/_notificationService 字段。05-03-SUMMARY.md 声称 commit 7ac9179 完成了此接线，但该 commit 在仓库（含所有分支）中不存在。"
    artifacts:
      - path: "lib/services/rebound/rebound_alert_service.dart"
        issue: "缺少 AlertThrottler.evaluate() + ReboundNotificationService.dispatch() 调用管线。缺少 alert_level / alert_throttler / rebound_notification_service / alert_settings_provider 的 import。缺少 _throttler / _notificationService / _alertSettings 字段。"
    missing:
      - "在 rebound_alert_service.dart 头部新增 import：alert_level.dart, alert_throttler.dart, rebound_notification_service.dart, alert_settings_provider.dart"
      - "新增成员字段：AlertThrottler? _throttler, ReboundNotificationService _notificationService, AlertSettingsProvider? _alertSettings"
      - "在 start() 中构造 _throttler = AlertThrottler() 并 await _notificationService.initialize()"
      - "在 handleClosedKline 末尾（provider.upsert 之后）调用 _throttler.evaluate(signal, ...) 并在返回非 null 时调用 _notificationService.dispatch(decision)"
      - "在 stop() 中调用 _throttler?.reset(); _throttler = null"
      - "将 handleClosedKline 签名从 void 改为 Future<void>（或使用 unawaited 包装 dispatch）"
  - truth: "ReboundAlertService.stop() 中调用 AlertThrottler.reset() 清理冷却状态"
    status: failed
    reason: "stop() 方法中无 _throttler?.reset() 调用——_throttler 字段本身不存在。"
    artifacts:
      - path: "lib/services/rebound/rebound_alert_service.dart"
        issue: "stop() 方法（第 151-163 行）缺少 AlertThrottler.reset() 调用"
    missing:
      - "在 stop() 中 _closedKlineSub?.cancel() 之前或之后插入 _throttler?.reset(); _throttler = null"
  - truth: "ReboundAlertService.start() 时构造 AlertThrottler 新实例"
    status: failed
    reason: "start() 方法中无 AlertThrottler() 构造或 _notificationService.initialize() 调用。"
    artifacts:
      - path: "lib/services/rebound/rebound_alert_service.dart"
        issue: "start() 方法（第 120-148 行）缺少 AlertThrottler 实例化 + ReboundNotificationService 初始化"
    missing:
      - "在 start() 中 _closedKlineSub 订阅之前插入：_throttler = AlertThrottler(); await _notificationService.initialize()"
---

# Phase 5: 推送提醒 Verification Report

**Phase Goal:** 守住「宁可漏报，不可误报刷屏」最后一道防线——强信号分级推送，每币全局冷却、跨周期事件归并、周期独立开关、每日总量上限

**Verified:** 2026-06-20T07:00:00Z
**Status:** gaps_found
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | alert_level.dart 定义 AlertLevel 枚举（high/medium/low）和 AlertDecision 数据类 | VERIFIED | `lib/models/alert_level.dart`（54 行）含 AlertLevel 三值枚举 + AlertDecision const 类（symbol/level/signal/coalescedTimeframes/createdAt 五字段） |
| 2 | alert_throttler.dart 的 evaluate() 依次通过分级、周期开关、冷却、归并、日上限五道闸门 | VERIFIED | `lib/services/rebound/alert_throttler.dart`（143 行）evaluate() 六步管线：_classify → TF toggle → cooldown → day reset → daily cap → return AlertDecision |
| 3 | 相同 symbol 在 cooldownHours=4 小时内第二次调用 evaluate() 返回 null | VERIFIED | `alert_throttler.dart` 第 63-67 行：`_lastAlertTime[signal.symbol]` 仅用 symbol 键（不含 TF）；`test_cooldown` 全绿通过 |
| 4 | 日计数器跨日重置，第 21 条推送返回 null（上限），超额静默 | VERIFIED | `alert_throttler.dart` 第 70-78 行：ISO date 跨日检测 + `_todayCount` 归零；`test_daily_cap` + `test_newday_reset` 全绿通过 |
| 5 | 同币连续多根 K 线频率内仅首次推送通过、后续返回 null（ALERT-06 UAT 硬标准） | VERIFIED | `alert_throttler.dart` 冷却逻辑 + `test_consecutive_candles_single_push` 全绿通过（ETHUSDT 连续 4 次仅首次非 null） |
| 6 | 归并逻辑架构预留（单周期下恒跳过） | VERIFIED | `alert_throttler.dart` 第 79-89 行注释标注 `coalesceWindowMinutes=60` 窗口参数 + `_pendingCoalesce` Map 预留；`test_coalesce_single_tf` 全绿通过 |
| 7 | ReboundNotificationService.initialize() 创建 rebound_high 和 rebound_med 两个 Android NotificationChannel | VERIFIED | `rebound_notification_service.dart` 第 52-75 行：`rebound_high`（Importance.max + 振动）和 `rebound_med`（Importance.defaultImportance + 声音）双渠道创建；`initialize` smoke test 通过 |
| 8 | dispatch() 对 AlertLevel.high 使用 Importance.max + 振动 + heads-up，对 AlertLevel.medium 使用 Importance.defaultImportance + 声音无振动 | VERIFIED | `rebound_notification_service.dart` 第 116-121 行：按 isHigh 分别设置 importance/priority/vibrate；`dispatch(high)` + `dispatch(medium)` tests 通过 |
| 9 | AlertLevel.low 不调用 dispatch()——仅看板可见 | VERIFIED | `rebound_notification_service.dart` 第 107-109 行：`if (decision.level == AlertLevel.low) return;` 入口直接返回；`dispatch(low)` test 通过 |
| 10 | AlertSettingsProvider 通过 SharedPreferences 持久化 4 个 TF 开关和高/中阈值 | VERIFIED | `alert_settings_provider.dart`（99 行）含 `alert_tf_toggle_{tf}` / `alert_high_threshold` / `alert_med_threshold` SP 键；SP 持久化 test 通过 |
| 11 | SP 计数器按日键（alert_daily_count_yyyy-MM-dd）读写，跨日自动重置 | PASSED (deviation) | **设计偏离：** 日计数器有意不在 AlertSettingsProvider 中维护——按 RESEARCH.md Pitfall 2 规避策略，由 AlertThrottler 内存维护 + evaluate() 入口跨日重置。AlertSettingsProvider 注释明确标注此决策。单测中的跨日重置通过 `setDateForTesting()` 注入验证。 |
| 12 | ReboundAlertService.handleClosedKline 在 provider.upsert 之后、方法末尾调用 AlertThrottler.evaluate() + ReboundNotificationService.dispatch() | FAILED | **CRITICAL GAP:** `rebound_alert_service.dart` 中完全不包含任何 Phase 5 相关 import 或调用。无 `_throttler` 字段、无 `_notificationService` 字段、无 evaluate/dispatch 调用。05-03-SUMMARY.md 声称的 commit `7ac9179` 在仓库中不存在。 |
| 13 | ReboundAlertService.stop() 中调用 AlertThrottler.reset() 清理冷却状态 | FAILED | `rebound_alert_service.dart` 第 151-163 行 stop() 方法中无 `_throttler?.reset()` 调用。 |
| 14 | ReboundAlertService.start() 时构造 AlertThrottler 新实例 | FAILED | `rebound_alert_service.dart` 第 120-148 行 start() 方法中无 `AlertThrottler()` 构造或 `_notificationService.initialize()` 调用。 |
| 15 | main.dart MultiProvider 注册 AlertSettingsProvider | VERIFIED | `main.dart` 第 341-348 行：`ChangeNotifierProvider(create: (_) { final p = AlertSettingsProvider(); p.load(); return p; })` |
| 16 | ProfileScreen 新增「反弹提醒」section：4 个 TF 开关 + 高分/中分阈值 slider | VERIFIED | `profile_screen.dart` 第 347-508 行：`_buildSectionHeader('反弹提醒')` + `Consumer<AlertSettingsProvider>` + SwitchListTile 遍历 `monitoredTimeframes` + highThreshold/medThreshold Slider（0-100，divisions=20）+ 说明文字。文案无「买入/强买/信号」禁用词。 |

**Score:** 16/19 truths verified (3 FAILED -- all three are the missing integration wiring in ReboundAlertService)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/models/alert_level.dart` | AlertLevel enum + AlertDecision class (min 35 lines) | VERIFIED | 54 lines, all 5 fields, const constructor, toString() |
| `lib/services/rebound/alert_throttler.dart` | AlertThrottler five-gate pipeline (min 120 lines) | VERIFIED | 143 lines, evaluate() 6-step pipeline, _classify() pure function, reset(), setDateForTesting() |
| `test/services/alert_throttler_test.dart` | 10 test scenarios (min 200 lines) | VERIFIED | 248 lines, 10 tests: 4 classify + 1 cooldown + 1 TF toggle + 2 daily cap + 1 consecutive candles + 1 coalesce |
| `lib/services/rebound/rebound_notification_service.dart` | Multi-channel notification service (min 120 lines) | VERIFIED | 193 lines, dual channels (rebound_high/rebound_med), dispatch() by level, _buildTitle/_buildBody, symbol validation |
| `lib/providers/alert_settings_provider.dart` | Settings ChangeNotifier (min 100 lines) | VERIFIED | 99 lines (close to threshold), SP persistence, clamp(0,100), ChangeNotifier pattern |
| `test/services/rebound_notification_service_test.dart` | Notification tests (min 60 lines) | VERIFIED | 95 lines, 4 tests: smoke + high/medium/low dispatch |
| `test/providers/alert_settings_provider_test.dart` | Settings tests (min 80 lines) | VERIFIED | 85 lines, 6 tests: defaults + TF toggles + threshold clamp + SP persistence |
| `lib/services/rebound/rebound_alert_service.dart` | Phase 5 notification pipeline integration (modified) | FAILED | **NOT MODIFIED** -- file contains zero Phase 5 imports, fields, or calls. Last meaningful modification was in Phase 4 (commit b0a31e0). |
| `lib/main.dart` | AlertSettingsProvider registration (modified) | VERIFIED | Line 341-348: ChangeNotifierProvider registered after ReboundScoreProvider |
| `lib/screens/profile_screen.dart` | Rebound alert settings section (modified) | VERIFIED | Line 347-508: full UI section with toggles + sliders |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `alert_throttler.dart` | `rebound_signal.dart` | import ReboundSignal | WIRED | Line 3: `import 'package:tomapp/models/rebound_signal.dart'` |
| `alert_throttler.dart` | `alert_level.dart` | import AlertLevel/AlertDecision | WIRED | Line 2: `import 'package:tomapp/models/alert_level.dart'` |
| `rebound_notification_service.dart` | `alert_level.dart` | import AlertLevel | WIRED | Line 4: `import 'package:tomapp/models/alert_level.dart'` |
| `alert_settings_provider.dart` | `shared_preferences` | SP persistence | WIRED | Line 2: `import 'package:shared_preferences/shared_preferences.dart'` |
| `main.dart` | `alert_settings_provider.dart` | Provider registration | WIRED | Line 24: import + lines 341-348: ChangeNotifierProvider |
| `profile_screen.dart` | `alert_settings_provider.dart` | Consumer<T> UI | WIRED | Line 12: import + line 349: Consumer\<AlertSettingsProvider\> |
| `rebound_alert_service.dart` | `alert_throttler.dart` | evaluate() call in handleClosedKline | **NOT WIRED** | No import, no field, no call -- completely absent |
| `rebound_alert_service.dart` | `rebound_notification_service.dart` | dispatch() call | **NOT WIRED** | No import, no field, no call -- completely absent |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| AlertThrottler 10 tests pass | `flutter test test/services/alert_throttler_test.dart` | 00:00 +10: All tests passed! | PASS |
| Notification + Settings 10 tests pass | `flutter test test/services/rebound/rebound_notification_service_test.dart test/providers/alert_settings_provider_test.dart` | 00:00 +10: All tests passed! | PASS |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|----------|
| ALERT-01 | 05-02, 05-03 | 强信号分级推送（high 响铃+vibrate / med 横幅 / low 仅看板） | **PARTIAL** | ReboundNotificationService dispatch() 三级分发已实现 + ProfileScreen UI 存在。但 display 管线未接入 ReboundAlertService.handleClosedKline。 |
| ALERT-02 | 05-01, 05-03 | 每币全局冷却（4h 内同币不重复推送） | **PARTIAL** | AlertThrottler 冷却逻辑已实现（per-symbol 键，4h）+ 10 单测全绿。但 evaluate() 从未在真实信号流中被调用。 |
| ALERT-03 | 05-01, 05-03 | 跨周期事件归并（共振合并为 1 条） | **PARTIAL** | AlertThrottler 架构预留了 coalesceWindowMinutes + _pendingCoalesce 扩展点。当前单周期下恒跳过。跨周期归并逻辑本身尚未实现。 |
| ALERT-04 | 05-01, 05-02, 05-03 | 每周期可独立开关推送 | VERIFIED | AlertSettingsProvider TF toggles + ProfileScreen SwitchListTile per-TF UI 完全实现。SP 持久化 + notifyListeners 正常。 |
| ALERT-05 | 05-01, 05-03 | 每日推送总量上限（20 条/天） | **PARTIAL** | AlertThrottler dailyLimit=20 + _todayCount 逻辑已实现 + 单测通过。但 throttler 未接入真实管线。 |
| ALERT-06 | 05-01, 05-03 | 同币连续多根 K 线满足只推 1 条（UAT 硬标准） | **PARTIAL** | AlertThrottler 冷却逻辑 + `test_consecutive_candles_single_push` 全绿通过。但 throttler 未接入真实管线。 |

**Requirements Coverage Summary:** 1/6 fully VERIFIED (ALERT-04), 5/6 PARTIAL (blocked by missing ReboundAlertService integration)

### Anti-Patterns Found

No anti-patterns detected. All source files are free of TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers. No empty implementations or hardcoded stub data found in production code.

### Human Verification Required

No items require human verification. All failures are programmatically verifiable code-absence issues. The three failed truths (12, 13, 14) all stem from the same single root cause: Task 1 of Plan 05-03 (ReboundAlertService integration wiring) was never implemented.

### Gaps Summary

**Root cause:** Plan 05-03 Task 1 ("在 ReboundAlertService 中集成 AlertThrottler + ReboundNotificationService") was claimed complete in 05-03-SUMMARY.md (commit `7ac9179`) but:

1. Commit `7ac9179` does not exist anywhere in this repository
2. `lib/services/rebound/rebound_alert_service.dart` has not been modified since Phase 4 (last substantive change: `b0a31e0` -- Phase 04-03)
3. The file contains zero Phase 5-related imports (`alert_level`, `alert_throttler`, `rebound_notification_service`, `alert_settings_provider`)
4. The `handleClosedKline` method signature is still `void` (not `Future<void> async` as planned)
5. No `_throttler`, `_notificationService`, or `_alertSettings` fields exist
6. `start()` does not construct `AlertThrottler` or initialize `ReboundNotificationService`
7. `stop()` does not call `AlertThrottler.reset()`

**Impact:** The Phase 5 notification pipeline is architecturally complete at the component level (AlertThrottler, ReboundNotificationService, AlertSettingsProvider all exist and are well-tested), but it is **completely disconnected from the runtime signal flow**. No real signals from the Binance WebSocket stream will ever pass through the throttling gates or trigger notifications. The phase goal of being the "最后一道防线" (last line of defense) against notification spam is not achieved because the defense line exists but is not deployed.

**Fix scope:** Add approximately 30-40 lines to `lib/services/rebound/rebound_alert_service.dart`:
- 4 new imports
- 3 new member fields
- ~5 lines in `start()` (AlertThrottler construction + notificationService init)
- ~10 lines in `handleClosedKline()` (evaluate + dispatch pipeline, after provider.upsert)
- ~2 lines in `stop()` (throttler reset + null)
- Change `handleClosedKline` signature from `void` to `Future<void>`

This is a focused, low-risk change of approximately 30-40 lines in a single file, with no changes needed to existing Phase 2-4 logic.

---

_Verified: 2026-06-20T07:00:00Z_
_Verifier: Claude (gsd-verifier)_
