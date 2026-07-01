# 反弹监控：精跟 5 秒重检测 + 列表持久化 + 进列表通知

- 日期：2026-07-01
- 范围：合约反弹监控页（`ReboundDashboardScreen`）四项行为调整
- 状态：已批准，待实现

## 需求

1. **精跟 5 秒一次**：精跟中的标的每 5 秒重新评估一次反弹检测，不再干等 15m K 线收盘（约 15 分钟）。
2. **列表数据不丢失**：已经在看板列表中展示的信号不能丢失——app 重启后恢复，运行中退出精跟也保留。
3. **添加触发时间**：列表每行显示信号触发时间。
4. **进列表就通知**：有新信号进入列表（score≥70）即推送手机通知（不再要求 ≥75 且最新一根）。

## 硬约束（已与用户确认）

**全市场 REST 扫描无法做到 5 秒/轮**。`ReboundMarketScanner` 每轮需请求 400 合约 × 4 周期 ≈ 1600 次，Binance 限流 2400 weight/分钟，60 秒间隔已是最优（且单轮执行就要 40–50 秒）。强行 5 秒会瞬间触发 429 被封。

→ "加快"只能落在**精跟标的的重检测频率**上；`scanInterval` 保持 60 秒不变。

## 设计

### ① 精跟 5 秒重检测

- `ReboundAlertService` 新增 `Timer? _reEvalTimer`：
  - `start()` 末尾启动 `Timer.periodic(const Duration(seconds: 5), (_) => _reEvaluate())`。
  - `stop()` 取消。
- `_reEvaluate()`：遍历 `_trackedSymbols` × `monitoredTimeframes`，取 `streamService.windowOf(symbol, tf)`（rolling buffer，末根即 WS 最新价），调用公共评估方法。
- **抽取公共方法**（单一真源，避免两份重复逻辑）：

  ```dart
  Future<void> _evaluateWindow(
    String symbol, String tf, List<KlineData> window, {
    required bool isClosedEvent,
  })
  ```

  - 跑 `_detector.evaluate` → 算 mtf 加分 → `provider.upsert`（closedEvent 路径才写库，见 ②）→ 通知由 provider 跃迁触发（见 ④），不在评估方法里直接通知。
  - `handleClosedKline`（`isClosedEvent=true`）与 `_reEvaluate`（`isClosedEvent=false`）共用本方法。
- 跳过条件：warm-up 中的标的、window 为空。
- 未收盘 K 线评估会让评分随价小幅波动——这是"5 秒刷新"的预期效果，不是 bug。

### ② 列表持久化 + 运行中保留

**存储（sqflite v5 → v6）**
- `DatabaseHelper`：`version 5→6`，`onCreate` + `onUpgrade(oldVersion<6)` 建 `rebound_signals` 表：

  ```sql
  CREATE TABLE rebound_signals (
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    score INTEGER NOT NULL,
    deadCatRiskScore INTEGER NOT NULL,
    dropMagnitude REAL NOT NULL,
    recoveryRatio REAL NOT NULL,
    entryPrice REAL NOT NULL,
    swingLowPrice REAL NOT NULL,
    swingHighPrice REAL NOT NULL,
    dropStartIndex INTEGER NOT NULL,
    dropEndIndex INTEGER NOT NULL,
    recoveryEndIndex INTEGER NOT NULL,
    isLatestBar INTEGER NOT NULL,
    klineCloseTime INTEGER NOT NULL,
    updatedAt INTEGER NOT NULL,
    PRIMARY KEY (symbol, timeframe)
  )
  ```

  + 索引 `idx_rebound_signals_score(score DESC)`。
- 新 `ReboundSignalRepository`：`upsert(ReboundSignal)` / `delete(symbol, tf)` / `queryListed(int minScore, int limit)`。

**Provider 数据流**
- `ReboundScoreProvider` 注入 `ReboundSignalRepository?`（DI，便于测试）。
- 新增 `Future<void> loadSignals(repo)`：启动时从库恢复 `score≥70` 的信号到内存。
- `upsert(symbol, tf, signal)`：
  - **写库节流**：仅 `isClosedEvent=true`（收盘）与扫描命中两条低频路径写库；5 秒重评估（`isClosedEvent=false`）只刷内存+UI，避免高频 IO。
    - 实现：`upsert` 增加可选参数 `persist: bool = false`；只有调用方在低频路径传 `persist: true`。
    - app 被杀时最多丢 5 秒数据，下次 60 秒扫描重新命中即写回（可接受）。
  - `upsert(null)`（信号消失）→ `repo.delete`。

**运行中保留**
- `ReboundAlertService.untrackSymbol` **移除** `_provider.removeSymbol(symbol)` 调用：退出精跟只断 WS 订阅 + 清 `_missCountBySymbol`，列表信号保留。
- 信号从列表移除的唯一途径：scanner/收盘路径 `upsert(symbol, tf, null)`（detector 返回 null 且该 symbol 本轮未命中）。
- `stop()` 仍 `clear()` 内存（dispose 时），但库内有，下次启动 `loadSignals` 恢复。

**dashboard**
- `_startAlertService` 注入 repo；`await provider.loadSignals(repo.queryListed)` 在扫描启动前恢复列表。

### ③ 触发时间列

- `_SignalRow` 在"币种"右侧加一列 HH:MM 小灰字，取 `signal.timestamp`（K 线收盘时间）：

  ```dart
  Text('${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}',
      style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'monospace'))
  ```

- 布局微调（币种列宽略缩）。

### ④ 进列表就通知（统一触发点）

**核心改动**：通知触发点从"dashboard 显式调 `notifyOnSignal`"改为"provider 检测到信号首次进列表"——scan / 收盘 / 5 秒重评估三条路径统一。

- `ReboundScoreProvider`：
  - `static const int listedThreshold = 70;`
  - 字段 `void Function(ReboundSignal)? onSignalListed;`
  - `upsert` 内：检测跃迁 `(旧值==null || 旧值.score<listedThreshold) && 新值!=null && 新值.score>=listedThreshold` → 触发 `onSignalListed(signal)`。

- `ReboundAlertService`：
  - `start()` 时设 `_provider.onSignalListed = _dispatchListed;`
  - 新方法 `_dispatchListed(ReboundSignal signal)`：
    - 跑 `_throttler.evaluate(signal, ...)`（**保留冷却 4h + 日上限 20 + 跨日重置**；分级仅用于选渠道 high/med）。
    - decision 非空 → `_notificationService.dispatch(decision)` + `_notificationRepository.insert` + `provider.addNotificationHistory`。
  - **移除** `_dispatchIfHigh` 的 `isLatestBar` 前置判断与 `level==high` 限制——改为 decision 非空即推（输入都≥70，必过 medium 分级，decision 必非 null；冷却/上限由 throttler 把关）。

- `rebound_dashboard_screen.dart`：`onScanComplete` 循环内**移除** `_alertService!.notifyOnSignal(enriched)` 调用（通知改由 provider 跃迁自动触发）。

**去重保证**：跃迁检测可能让某标的反复跨越 70 线，但 throttler 的 per-symbol 4h 冷却会拦截重复推送。

## 改动文件

- `lib/services/database_helper.dart`：v6 建 `rebound_signals` 表
- `lib/services/rebound/rebound_signal_repository.dart`：**新**
- `lib/services/rebound/rebound_alert_service.dart`：5 秒定时器 + `_evaluateWindow` 公共方法 + `untrackSymbol` 不删信号 + `_dispatchListed` + 移除 `notifyOnSignal`/`_dispatchIfHigh` 旧逻辑
- `lib/providers/rebound_score_provider.dart`：repo 注入 + `loadSignals` + `upsert(persist:)` 写库节流 + `onSignalListed` 跃迁回调
- `lib/screens/rebound_dashboard_screen.dart`：注入 repo + `loadSignals` + `_SignalRow` 时间列 + 移除 `notifyOnSignal` 调用

## 测试

- `database_helper_test`：v6 migration 建 `rebound_signals` 表
- `rebound_signal_repository_test`（新）：upsert/queryListed/delete（in-memory sqflite）
- `rebound_alert_service_test`：
  - 5 秒重评估：tracked symbol 用 partial window 重新检测 + upsert（mock streamService.windowOf）
  - `_evaluateWindow` 被 closed 与重评估路径共用
  - `_dispatchListed`：provider 跃迁触发 → throttler 冷却生效 → 推送 + 写历史
  - `untrackSymbol` 不再清 provider 信号
- `rebound_score_provider_test`：
  - `loadSignals` 从 repo 恢复
  - `upsert(persist:true)` 写库、`persist:false` 不写库
  - `onSignalListed` 跃迁：null→≥70 触发、<70→≥70 触发、≥70→≥70 不触发、≥70→<70 不触发
- dashboard UI 无单测（手动审查）

## 不做（YAGNI）

- 不改 `scanInterval`（60 秒，限流约束）。
- 不改 `ReboundDetector`、`AlertThrottler`、`ReboundNotificationService`。
- 历史记录不分页/不筛选。
- 5 秒重评估不写库（仅收盘/扫描写库）。
- 不做单独历史/持久化页面（信号在监控页列表内恢复即可）。
