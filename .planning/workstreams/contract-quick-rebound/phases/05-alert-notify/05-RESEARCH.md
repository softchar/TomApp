# Phase 5: 推送提醒（分级 + 冷却 + 归并 + 总量上限）- RESEARCH

**Researched:** 2026-06-20
**Domain:** 移动端本地推送通知系统（Flutter/Android）、通知节流与去重策略
**Confidence:** HIGH

## Summary

Phase 5 在已有 ReboundAlertService（Phase 3 编排器）和 ReboundScoreProvider（Phase 3 Provider）基础上，新增一套**通知评估管线**——在信号检测后、推送触达前插入分级/冷却/归并/上限四层过滤。核心技术是 `flutter_local_notifications` 17.2.3 的多渠道分级推送 + 纯内存的冷却与归并逻辑 + SharedPreferences 持久化的日上限计数器。

Phase 5 不引入新的外部包——`flutter_local_notifications` 和 `shared_preferences` 已在 pubspec.yaml 中。所有节流逻辑为纯 Dart 实现（Map + DateTime 比较 + 计数器），无状态、可单测。

**Primary recommendation:** 在 `ReboundAlertService.handleClosedKline` 的最后一步（`_provider.upsert` 之后）插入 `AlertThrottler.evaluate(signal, context) → AlertDecision?` 管线，而非在现有 NotificationService 上打补丁。新建独立的 `ReboundNotificationService` 管理三个 Android 通知渠道（high/med/low），与既有的 funding_rate_channel/pump_alerts 完全隔离。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 通知渠道初始化 | API/Backend (Service) | — | Android 渠道必须在首次通知前由 Service 层创建 |
| 信号分级判定（high/med/low） | API/Backend (Service) | — | 基于 score 阈值 + deadCatRiskScore 的纯业务逻辑 |
| 冷却跟踪（per-symbol 时间戳） | API/Backend (Service) | — | 内存 Map，与 Provider 层解耦 |
| 跨周期归并（同币多 TF → 单条） | API/Backend (Service) | — | 发生在 Provider 更新之后、通知发送之前 |
| 日上限计数与持久化 | API/Backend (Service) | Data (SharedPreferences) | SharedPreferences 按日期键存储 |
| 周期独立开关配置 | Browser/Client (UI) | Data (SharedPreferences) | 用户在设置页操作，SharedPreferences 持久化 |
| 通知展示（响铃/横幅/无） | Browser/Client (Android) | — | 系统通知抽屉，非应用内 UI |
| 看板信号展示（所有级别） | Browser/Client (UI) | Provider | 低级别仅看板，不经过通知管线 |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_local_notifications | 17.2.3 | Android 本地通知多渠道分级推送 | 已在项目中；支持 Importance 枚举（none/min/low/defaultImportance/high/max）；Android 8.0+ 渠道强制要求 |
| shared_preferences | 2.2.2 | 日上限计数 + 周期开关持久化 | 已在项目中；轻量键值存储，适合计数值和布尔开关 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (无新增) | — | — | Phase 5 无需引入新外部依赖 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| flutter_local_notifications | awesome_notifications | awesome_notifications 提供更丰富 API 但额外依赖 ~8 个传递包；现有项目已用 flutter_local_notifications，保持一致 |
| SharedPreferences 日计数器 | SQLite (drift) 表 | drift 更可靠但过度设计——日上限仅一个 int，SharedPreferences 足够 |
| 内存 Map 冷却跟踪 | drift 表持久化冷却 | 持久化冷却可跨 app 重启，但 Phase 5 需求是 4h 窗口内的冷却，app 重启后冷却自然重置，内存足够 |

**Installation:**
```bash
# 无需安装新包——flutter_local_notifications 17.2.3 和 shared_preferences 2.2.2 已在 pubspec.yaml 中
flutter pub get  # 仅确认现有依赖
```

**Version verification:**
```bash
# flutter_local_notifications 17.2.3 — 已在 pubspec.lock 中确认
# shared_preferences 2.2.2 — 已在 pubspec.lock 中确认
```

## Package Legitimacy Audit

> Phase 5 不安装新的外部包。既有包已在 Phase 1-3 中安装和审计。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_local_notifications | pub.dev | 7+ yrs | 顶级 Flutter 包 | github.com/MaikuB/flutter_local_notifications | [CITED: pub.dev/packages/flutter_local_notifications/versions/17.2.3] | 已批准（已有） |
| shared_preferences | pub.dev | 8+ yrs | Flutter 官方包 | github.com/flutter/packages | [CITED: pub.dev/packages/shared_preferences] | 已批准（已有） |

**Packages removed due to SLOP verdict:** 无
**Packages flagged as suspicious [SUS]:** 无
**New packages introduced by this phase:** 0

## Architecture Patterns

### System Architecture Diagram

```text
┌──────────────────────────────────────────────────────────────────┐
│                    ReboundAlertService                            │
│  handleClosedKline(ClosedKline)                                  │
│     │                                                            │
│     ├─ 1. warm-up check (不变)                                    │
│     ├─ 2. windowOf → detector.evaluate (不变)                     │
│     ├─ 3. mtfConfluence scoring (不变)                            │
│     ├─ 4. provider.upsert → UI 看板更新 (不变)                     │
│     │                                                            │
│     └─ 5. 【Phase 5 新增】AlertThrottler.evaluate()               │
│            │                                                     │
│            ├─ 5a. 分级: score ≥ highThreshold? deadCatCheck?      │
│            │         → AlertLevel {high, medium, low}            │
│            │                                                     │
│            ├─ 5b. 周期开关: timeframeEnabled[tf]?                  │
│            │         → false: skip (仅看板可见)                    │
│            │                                                     │
│            ├─ 5c. 冷却检查: now - lastAlert[symbol] < 4h?         │
│            │         → true: skip (冷却期内，看板可见)              │
│            │         → false: 记录 lastAlert[symbol]=now          │
│            │                                                     │
│            ├─ 5d. 跨周期归并: 同 symbol 的多个 TF 同时满足?         │
│            │         → 合并为 1 条 "多周期共振" 高级提醒            │
│            │         （当前 15m 单周期下此步骤恒跳过，               │
│            │          但归并架构保留供未来扩展）                     │
│            │                                                     │
│            └─ 5e. 日上限: todayCount < 20?                       │
│                      → false: 仅保留 highestScoreInQueue          │
│                      → true: 通过 → dispatch                      │
│                          │                                       │
│                          ▼                                       │
│              ReboundNotificationService.dispatch()                │
│                          │                                       │
│          ┌───────────────┼───────────────┐                        │
│          ▼               ▼               ▼                        │
│     channel:         channel:         (无通知)                     │
│     rebound_high     rebound_med      仅看板                       │
│     Importance.max   Importance.                                  │
│     + sound          defaultImportance                            │
│     + vibrate        + sound                                      │
│     + heads-up       (横幅)                                       │
│     (响铃+vibrate)                                               │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                AlertSettingsProvider (ChangeNotifier)             │
│                                                                  │
│  - Map<String, bool> timeframeToggles: 每 TF 独立开关              │
│  - int highThreshold / int medThreshold: 可调阈值                  │
│  - 持久化: SharedPreferences                                     │
│  - UI: 设置页 (ProfileScreen 或独立 AlertSettingsScreen)           │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      Data Persistence                            │
│                                                                  │
│  SharedPreferences:                                              │
│  - alert_daily_count_2026-06-20: int (日上限计数器)                 │
│  - alert_daily_date: String (上次计数日期，跨日重置)                │
│  - alert_high_queue: JSON (超额时保留的最高分候选队列)              │
│  - alert_tf_toggle_15m: bool                                     │
│  - alert_tf_toggle_1h: bool                                      │
│  - alert_tf_toggle_4h: bool                                      │
│  - alert_tf_toggle_1d: bool                                      │
│                                                                  │
│  内存 (非持久化，app 重启自然重置):                                  │
│  - Map<String, DateTime> _lastAlertTime: 每币最后推送时间           │
│  - Map<String, List<AlertCandidate>> _pendingCoalesce: 归并缓存    │
└──────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure
```
lib/
├── services/
│   ├── rebound/
│   │   ├── rebound_alert_service.dart     # 【修改】末尾插入 AlertThrottler 调用
│   │   ├── alert_throttler.dart           # 【新增】分级+冷却+归并+上限 核心管线
│   │   ├── rebound_notification_service.dart # 【新增】多渠道通知分发
│   │   └── ...                            # 现有文件不变
│   └── notification_service.dart          # 【不修改】保留 pump/funding 通知
├── providers/
│   ├── rebound_score_provider.dart        # 【不修改】
│   └── alert_settings_provider.dart       # 【新增】周期开关 + 阈值配置
├── models/
│   ├── rebound_signal.dart                # 【不修改】
│   └── alert_level.dart                   # 【新增】AlertLevel 枚举 + AlertDecision
└── screens/
    └── alert_settings_screen.dart         # 【新增】设置页 UI（可选，可嵌入 ProfileScreen）
```

### Pattern 1: Pipeline / Chain of Responsibility（通知评估管线）

**What:** 信号依次通过分级 → 周期开关 → 冷却 → 归并 → 上限五道闸门，每道闸门可独立拒绝或修改信号。各步骤纯函数或仅依赖注入的 Map/计数器，可独立单测。

**When to use:** 需要多道独立的过滤逻辑作用于同一输入，且每道逻辑可独立启用/禁用/调参。

**Example:**
```dart
// 来源: 本 phase 设计，综合 PITFALLS.md Pitfall 11 和 ALERT-01~06 需求
class AlertThrottler {
  final Map<String, DateTime> _lastAlertTime = {}; // symbol → 最后推送时间
  int _todayCount = 0;
  String _todayDate = '';

  /// 主评估入口：纯逻辑，无副作用（除更新内部状态）
  AlertDecision? evaluate(ReboundSignal signal, {
    required Map<String, bool> timeframeToggles,
    required int highThreshold,
    required int medThreshold,
  }) {
    // Step 1: 分级
    final level = _classify(signal.score, signal.deadCatRiskScore, highThreshold, medThreshold);
    if (level == AlertLevel.low) return null; // low = 仅看板

    // Step 2: 周期开关
    if (timeframeToggles[signal.timeframe] == false) return null;

    // Step 3: 冷却检查
    final lastTime = _lastAlertTime[signal.symbol];
    if (lastTime != null &&
        DateTime.now().difference(lastTime).inHours < 4) {
      return null; // 冷却期内
    }

    // Step 4: 日上限
    _resetDailyIfNewDay();
    if (_todayCount >= 20) return null; // 超额丢弃

    // Step 5: 通过！更新状态
    _lastAlertTime[signal.symbol] = DateTime.now();
    _todayCount++;

    return AlertDecision(symbol: signal.symbol, level: level, signal: signal);
  }

  AlertLevel _classify(int score, int deadCatRisk, int highTh, int medTh) {
    if (score >= highTh && deadCatRisk < 50) return AlertLevel.high;
    if (score >= medTh) return AlertLevel.medium;
    return AlertLevel.low;
  }

  void _resetDailyIfNewDay() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (today != _todayDate) {
      _todayDate = today;
      _todayCount = 0;
    }
  }
}
```

### Pattern 2: Service-per-Channel（多渠道通知服务）

**What:** 每个通知级别对应一个 Android NotificationChannel，由专门的 Service 类统一管理渠道创建和分发。

**When to use:** 需要不同侵入性的通知行为（响铃 vs 横幅 vs 静默）。

**Example:**
```dart
// 来源: flutter_local_notifications README + 官方 pub.dev 文档
class ReboundNotificationService {
  static const _highChannelId = 'rebound_high';
  static const _medChannelId = 'rebound_med';

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    // 创建 high 渠道 (Importance.max = heads-up + 响铃 + 震动)
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        _highChannelId,
        '反弹强信号',
        description: '高分反弹监控候选——响铃+震动提醒',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ),
    );

    // 创建 med 渠道 (Importance.defaultImportance = 横幅 + 声音)
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      const AndroidNotificationChannel(
        _medChannelId,
        '反弹提示',
        description: '中等反弹监控候选——横幅提醒',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
      ),
    );
  }

  Future<void> dispatch(AlertDecision decision) async {
    final (channelId, importance, priority, vibrate) = switch (decision.level) {
      AlertLevel.high => (
          _highChannelId, Importance.max, Priority.high, true),
      AlertLevel.medium => (
          _medChannelId, Importance.defaultImportance, Priority.defaultPriority, false),
      AlertLevel.low => (null, null, null, false), // 不发通知
    };
    if (channelId == null) return;

    await _plugin.show(
      decision.symbol.hashCode,
      _buildTitle(decision),
      _buildBody(decision),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          decision.level == AlertLevel.high ? '反弹强信号' : '反弹提示',
          importance: importance,
          priority: priority,
          enableVibration: vibrate,
        ),
      ),
      payload: decision.symbol, // 点击跳转 KlineScreen
    );
  }
}
```

### Pattern 3: Settings Provider with SharedPreferences

**What:** 用户可配置的周期开关和阈值，通过 Provider + SharedPreferences 实现响应式配置管理。

**When to use:** 运行时可调但需持久化的配置项。

### Anti-Patterns to Avoid
- **在 ReboundAlertService.handleClosedKline 内直接调 flutter_local_notifications:** 违反单一职责；handleClosedKline 已有 200+ 行，再加通知逻辑会不可测试。应通过 AlertThrottler 抽象。
- **冷却用 drift 表而非内存 Map:** 过度设计。4h 冷却窗口不需要跨 app 重启持久化——重启后冷却自然解禁，符合预期。
- **为每个 TF 创建独立 NotificationChannel:** 不需要。渠道按级别分（high/med），不按周期分。周期开关是代码层面的过滤。
- **日上限计数器用 DateTime.now() 在每次 evaluate 中创建新日期字符串:** 性能影响可忽略，但更好的做法是在 AlertThrottler 构造时或日变更时缓存日期字符串。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Android 本地通知 | 自建 Platform Channel + Android NotificationManager | flutter_local_notifications 17.2.3 | 跨平台兼容、渠道管理、权限处理、生命周期——自建需 300+ 行 Kotlin + Dart FFI |
| 通知渠道管理 | 手动 AndroidManifest 声明 | flutter_local_notifications AndroidNotificationChannel API | Android 8.0+ 渠道为运行时创建且不可逆；API 封装了兼容性 |
| 配置持久化 | SQLite/drift 表 | SharedPreferences | 周期开关是简单 bool，日上限是单个 int——键值存储最合适 |
| 日期计算与跨日重置 | 手动 DateTime 比较 + 时区 | Dart DateTime + `toIso8601String().substring(0,10)` | Dart 内置即可，无需 moment/timezone 重计算 |

**Key insight:** Phase 5 的核心复杂度在**业务逻辑（五道闸门的状态机）**而非基础设施。所有基础设施（通知、持久化）已有现成方案。不要为了"统一持久化"把计数器塞进 drift——SharedPreferences 是这个场景的标准方案。

## Common Pitfalls

### Pitfall 1: 冷却期误判——同币不同 TF 的信号各自独立冷却
**What goes wrong:** 15m 信号触发后，30 分钟后 1h 信号再次触发——如果冷却按 (symbol, TF) 维度，两个都被推送，违背"每币全局冷却"。
**Why it happens:** 自然倾向是按现有数据结构 `Map<symbol, Map<TF, signal>>` 来设计冷却键。
**How to avoid:** 冷却键必须仅用 `symbol`（不含 TF）。`_lastAlertTime[symbol]` 而非 `_lastAlertTime['$symbol-$tf']`。
**Warning signs:** 同一 symbol 的 15m 和 1h 在 4h 内都收到了推送。

### Pitfall 2: 日上限计数器跨日不重置
**What goes wrong:** 计数器递增后从未归零——第二天从 20 开始，一条推送都不发。
**Why it happens:** 忘记在 `evaluate()` 入口检查日期变更。
**How to avoid:** `_resetDailyIfNewDay()` 作为 `evaluate()` 的第一行调用；单测覆盖跨日场景（mock DateTime）。
**Warning signs:** 第二天看不到任何推送；日志显示 `_todayCount` 持续 >= 20。

### Pitfall 3: 通知渠道创建时机——首次通知时未初始化渠道
**What goes wrong:** 直接调 `_plugin.show()` 未先创建渠道 → Android 8.0+ 通知静默丢弃（不崩溃，不报错，纯丢失）。
**Why it happens:** 渠道创建在 `initialize()` 中，但 initialize() 未被调用或调用时序晚于首次通知。
**How to avoid:** `ReboundNotificationService` 构造后立即调 `initialize()`（在 `ReboundAlertService.start()` 前完成）。`initialize()` 幂等（重复调用不重建渠道）。
**Warning signs:** Android 8.0+ 设备上收不到通知，但日志无报错。

### Pitfall 4: AlertThrottler 状态在 ReboundAlertService.stop() 时未清理
**What goes wrong:** stop() → start() 后，旧的冷却 Map 仍保留——刚重启的标的被误判为冷却期内。
**Why it happens:** AlertThrottler 作为 ReboundAlertService 的成员，stop() 时忘记重置内部状态。
**How to avoid:** `ReboundAlertService.stop()` 中增加 `_throttler.reset()`；单测覆盖 stop/start 循环。
**Warning signs:** 重启监控后某些 symbol 迟迟没有推送。

### Pitfall 5: 归并窗口过短或过长
**What goes wrong:** 归并窗口太短——多 TF 信号分散在多根 K 线抵达（15m 的 K 线比 1h 早到最多 1h），错过归并。窗口太长——不相关信号被错误合并。
**Why it happens:** 不同 TF 的 K 线收盘时间不同步；15m 收盘 15 分钟一次，1h 收盘 1 小时一次。
**How to avoid:** 归并窗口按「最大 TF 的 K 线长度」设定——当前仅 15m，窗口 = 15min。未来启用多 TF 时改为 max(各 TF K 线长度)。`_pendingCoalesce` 定时清理过期条目（> 归并窗口）。
**Warning signs:** 多 TF 共振时仍然收到多条推送（归并失败）；不同 symbol 的信号被错误合并。

## Code Examples

Verified patterns from official sources:

### 三级别通知渠道创建
```dart
// 来源: flutter_local_notifications README (pub.dev 17.2.3)
// 综合 WebSearch 结果中 Importance 枚举说明
Future<void> _createChannels(FlutterLocalNotificationsPlugin plugin) async {
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;

  // HIGH: heads-up + sound + vibrate
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      'rebound_high',
      '反弹强信号',
      description: '高分反弹监控候选，响铃+震动',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    ),
  );

  // MEDIUM: banner + sound, no vibrate
  await android.createNotificationChannel(
    const AndroidNotificationChannel(
      'rebound_med',
      '反弹提示',
      description: '中等反弹监控候选，横幅提醒',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: false,
    ),
  );

  // LOW: no channel needed — signals stay on dashboard only
}
```

### 带冷却的评估管线核心逻辑
```dart
// 来源: Phase 5 设计（综合 PITFALLS.md Pitfall 11, ALERT-01~06）
// 来源: flutter_local_notifications pub.dev API reference (Importance/Priority enum)
AlertDecision? evaluate(ReboundSignal signal, {
  required Map<String, bool> timeframeToggles,
  required int highThreshold,
  required int medThreshold,
}) {
  // 日上限计数器跨日重置
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (today != _todayDate) { _todayDate = today; _todayCount = 0; }

  // 1. 分级
  final level = _classify(signal, highThreshold, medThreshold);
  if (level == AlertLevel.low) return null;

  // 2. 周期开关
  if (timeframeToggles[signal.timeframe] == false) return null;

  // 3. 全局冷却（4h，per-symbol 不含 TF）
  final last = _lastAlertTime[signal.symbol];
  if (last != null &&
      DateTime.now().difference(last).inHours < _cooldownHours) {
    return null;
  }

  // 4. 日上限（20 条/天）
  if (_todayCount >= _dailyLimit) return null;

  // 5. 通过
  _lastAlertTime[signal.symbol] = DateTime.now();
  _todayCount++;
  return AlertDecision(symbol: signal.symbol, level: level, signal: signal);
}

AlertLevel _classify(ReboundSignal s, int highTh, int medTh) {
  if (s.score >= highTh && s.deadCatRiskScore < 50) return AlertLevel.high;
  if (s.score >= medTh) return AlertLevel.medium;
  return AlertLevel.low;
}
```

### SharedPreferences 日上限持久化
```dart
// 来源: shared_preferences pub.dev 官方用法
class DailyCapTracker {
  final SharedPreferences _prefs;
  static const _countKey = 'alert_daily_count';
  static const _dateKey = 'alert_daily_date';

  int get todayCount => _prefs.getInt(_countKey) ?? 0;

  Future<void> increment() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = _prefs.getString(_dateKey);
    if (storedDate != today) {
      await _prefs.setString(_dateKey, today);
      await _prefs.setInt(_countKey, 1);
    } else {
      await _prefs.setInt(_countKey, todayCount + 1);
    }
  }

  bool isAtLimit(int limit) => todayCount >= limit;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| PumpAlertService 无节流直接推送 | AlertThrottler 五道闸门过滤 | Phase 5 | 降低误报率、防刷屏 |
| 单渠道 `funding_rate_channel` 所有通知 | 多渠道 `rebound_high` / `rebound_med` / 无通知(low) | Phase 5 | 按级别差异化推送行为 |
| 无冷却、无日上限 | per-symbol 4h 冷却 + 日 20 条上限 | Phase 5 | 用户免于通知轰炸 |

**Deprecated/outdated:**
- 现有 `NotificationService` 的 `funding_rate_channel` 和 `pump_alerts` 渠道保持不变——Phase 5 新增 `rebound_high`/`rebound_med` 渠道，不合并到现有渠道中。

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | flutter_local_notifications 17.2.3 支持 Importance.max 触发 heads-up 通知（经 WebSearch 确认） | Standard Stack | 若 Android 版本或厂商 ROM 限制 heads-up，high 级别将退化为普通通知——用户体感降级但不会丢失信号 |
| A2 | 冷却内存 Map 在 app 重启后丢失是可接受的——重启后冷却自然重置 | Architecture Patterns | 若用户频繁重启 app，可能收到重复推送。影响有限（4h 窗口 × 仅 15m 周期 × 精跟 ≤30 标的） |
| A3 | SharedPreferences 读写同步足够快（< 1ms），不会阻塞 UI 线程 | Don't Hand-Roll | 若极低端设备上 SP 写入阻塞，可能导致 handleClosedKline 轻微延迟——可改为异步写入 |
| A4 | dailyLimit=20 和 cooldownHours=4 是合理的初始值（来自 ROADMAP.md 建议 + STATE.md blocker 区域） | Common Pitfalls | 若实际信号量远超预期（如 50+ unique symbols/day），上限可能过紧。UAT 阶段可通过 SharedPreferences 远程调参 |
| A5 | AlertThrottler.evaluate() 在 handleClosedKline 末尾调用是正确时机——Provider 已更新且后续无异步依赖 | Architecture Patterns | 若 handleClosedKline 改为异步，需确保 throttler 调用在 Provider 更新之后 |

**If this table is empty:** N/A — 5 assumptions logged.

## Open Questions

1. **评分阈值具体数值（highThreshold / medThreshold）**
   - What we know: ROADMAP.md 建议 "只高分(≥阈值)才推送"，但具体数值未定
   - What's unclear: high 阈值建议 75-80? med 阈值建议 50-60?
   - Recommendation: 先用 `highThreshold=75, medThreshold=50` 起步，标记为「UAT 调参」。这些值通过 AlertSettingsProvider 暴露，用户可在设置页调整

2. **跨周期归并窗口精确值**
   - What we know: 当前仅 15m 单周期运行，归并步逻辑上恒跳过
   - What's unclear: 未来多周期恢复时，归并窗口用 1h（最大 K 线长度）还是更长？
   - Recommendation: 归并窗口架构参数 `coalesceWindowMinutes = 60`（1h），当前不生效。恢复多周期后单测验证

3. **超额时"仅留最高分"的实现细节**
   - What we know: ALERT-05 要求超额时仅保留最高分
   - What's unclear: 是丢弃队列中最低分的已发通知（不可撤销），还是维护一个 pending 队列、日末统一排序后推送 top 20？
   - Recommendation: 采用「实时计数 + 满额静默」策略——前 20 条实时推送，第 21 条起静默不推（不缓存延迟推送）。简单可测，且符合"宁可漏报"原则。若未来需要 pending 队列策略，Phase 5 架构预留 `_pendingQueue` 扩展点

4. **设置页 UI 位置**
   - What we know: 需要 UI 展示周期开关和阈值配置
   - What's unclear: 独立 AlertSettingsScreen 还是嵌入现有 ProfileScreen？
   - Recommendation: 嵌入 ProfileScreen 作为新 section（最小 UI 改动）。若设置项超过 3 个，再拆独立页面

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | 编译/测试/运行 | YES | 3.32.8 | — |
| Dart SDK | 编译/测试/运行 | YES | 3.8.1 | — |
| Android SDK | 通知渠道测试 | YES | — (需 >= API 26) | — |
| flutter_local_notifications | 多渠道通知推送 | YES | 17.2.3 (已安装) | — |
| shared_preferences | 配置/计数器持久化 | YES | 2.2.2 (已安装) | — |
| flutter_test | 单元测试 | YES | SDK 内置 | — |
| mockito | Mock 依赖 | YES | 5.4.0 (已安装) | — |

**Missing dependencies with no fallback:** 无
**Missing dependencies with fallback:** 无

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK 内置) + mockito 5.4.0 |
| Config file | analysis_options.yaml |
| Quick run command | `flutter test test/services/alert_throttler_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ALERT-01 | 分级推送：high→响铃+vibrate，med→横幅，low→仅看板 | unit | `flutter test test/services/rebound_notification_service_test.dart` | Wave 0 创建 |
| ALERT-02 | 全局冷却：同币 4h 内不重复推送 | unit | `flutter test test/services/alert_throttler_test.dart::test_cooldown` | Wave 0 创建 |
| ALERT-03 | 跨周期归并：多 TF 共振合并为 1 条 | unit | `flutter test test/services/alert_throttler_test.dart::test_coalesce` | Wave 0 创建 |
| ALERT-04 | 周期独立开关：关闭的 TF 不推送 | unit | `flutter test test/services/alert_throttler_test.dart::test_timeframe_toggle` | Wave 0 创建 |
| ALERT-05 | 日上限：20 条/天，超额静默 | unit | `flutter test test/services/alert_throttler_test.dart::test_daily_cap` | Wave 0 创建 |
| ALERT-06 | UAT 硬标准：同币连续 4 根 K 线只推 1 条 | integration | `flutter test test/services/alert_throttler_test.dart::test_consecutive_candles_single_push` | Wave 0 创建 |

### Sampling Rate
- **Per task commit:** `flutter test test/services/alert_throttler_test.dart`
- **Per wave merge:** `flutter test` (全套)
- **Phase gate:** `flutter test` 全绿 + `flutter analyze` 零 error

### Wave 0 Gaps
- [ ] `test/services/alert_throttler_test.dart` — 覆盖 ALERT-02/03/04/05/06 所有冷却/归并/开关/上限场景
- [ ] `test/services/rebound_notification_service_test.dart` — 覆盖 ALERT-01 渠道创建与分发
- [ ] `test/providers/alert_settings_provider_test.dart` — 覆盖配置读写与跨日重置
- [ ] Framework install: 无需额外安装——flutter_test 和 mockito 已在 dev_dependencies

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | 无用户认证——app 为本地工具 |
| V3 Session Management | no | 无会话管理 |
| V4 Access Control | no | 无多用户/角色 |
| V5 Input Validation | yes (minimal) | 配置值（阈值、开关）从 SharedPreferences 反序列化时进行范围校验（score 0-100, bool 类型检查） |
| V6 Cryptography | no | 无加密需求——推送内容不涉及敏感信息 |

### Known Threat Patterns for Flutter + SharedPreferences

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| 恶意篡改 SharedPreferences 阈值/开关 | Tampering | Android SharedPreferences 为应用私有存储（MODE_PRIVATE），非 root 设备不可外部写入 |
| 通知内容泄露（锁屏可见） | Information Disclosure | Android NotificationChannel 可设置 `lockScreenVisibility`——high 级别建议设为 `NotificationVisibility.public`（用户需快速看到），med 级别设为 `NotificationVisibility.private`（仅解锁后显示详情） |
| 通知轰炸 DoS（恶意构造信号触发大量通知） | Denial of Service | AlertThrottler 的五道闸门（冷却+上限）本身就是限流防护 |

## Sources

### Primary (HIGH confidence)
- [flutter_local_notifications pub.dev 17.2.3](https://pub.dev/packages/flutter_local_notifications/versions/17.2.3) — 版本确认、Importance/Priority 枚举、渠道创建 API
- [flutter_local_notifications README (GitHub)](https://raw.githubusercontent.com/MaikuB/flutter_local_notifications/d65e61807b819d85f5e370d3d741a0f99876ce73/flutter_local_notifications/README.md) — 多渠道示例、heads-up 配置
- [shared_preferences pub.dev](https://pub.dev/packages/shared_preferences) — 键值存储 API，日上限计数器实现参考

### Secondary (MEDIUM confidence)
- [WebSearch: "flutter_local_notifications AndroidNotificationDetails importance priority vibration"](https://academy.droidcon.com/course/mastering-flutter-local-notifications-implementing-instant-scheduled-alerts-on-ios-android) — Importance 枚举完整行为说明
- [WebSearch: "flutter_local_notifications readme usage different channels importance vibration heads-up"](https://blog.csdn.net/weixin_29001683/article/details/158895923) — 中文渠道配置详解

### Tertiary (LOW confidence)
- PITFALLS.md Pitfall 11-13 — 提醒轰炸、合约专属陷阱、虚假信心（项目内部文档）
- CONCERNS.md Notification Queue Size — 提醒队列扩展建议

### Codebase (直接参考)
- `lib/services/notification_service.dart` — 现有 NotificationService 实现（funding_rate_channel + pump_alerts），渠道初始化模式参考
- `lib/services/rebound/rebound_alert_service.dart` — ReboundAlertService 现有管线，Phase 5 插入点定位
- `lib/providers/rebound_score_provider.dart` — ReboundScoreProvider API，信号状态读取
- `lib/models/rebound_signal.dart` — ReboundSignal 字段（score, deadCatRiskScore, symbol, timeframe）
- `lib/services/rebound/rebound_timeframes.dart` — monitoredTimeframes 常量（当前 `['15m']`）
- `pubspec.lock` — 确认 flutter_local_notifications 17.2.3, shared_preferences 2.2.2 已安装

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 所有依赖已在项目中安装且版本确认
- Architecture: HIGH — 基于现有 ReboundAlertService 管线的明确插入点；五道闸门模式为经典责任链
- Pitfalls: HIGH — PITFALLS.md Pitfall 11 直接针对 Phase 5 场景；所有潜在陷阱已有明确预防策略

**Research date:** 2026-06-20
**Valid until:** 2026-07-20 (30 days — 通知 API 稳定，flutter_local_notifications 版本锁定)
