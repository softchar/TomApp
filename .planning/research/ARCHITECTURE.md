# Architecture Patterns

**Project:** TomApp — 合约快速反弹监控 (Contract Quick-Rebound Monitoring)
**Researched:** 2026/06/19
**Mode:** Project Research (ARCHITECTURE) — subsequent milestone, brownfield integration
**Confidence:** HIGH (grounded in actual codebase inspection: `lib/services/*`, `lib/providers/*`, `.planning/codebase/`)

---

## 0. TL;DR for the Roadmapper

The rebound feature is **a parallel of the existing pump stack**, not an extension of it. Build a new orchestrator service (`ReboundAlertService`, twin of `PumpAlertService`) that wires a new **multi-symbol multi-timeframe kline stream** (modeled on `BinanceWebSocketManager`'s `!ticker@arr` combined-stream pattern — NOT the single-symbol `KlineWebSocketService`) into a **pure-function detector** (`ReboundDetector`) that is equally runnable **live and on historical data** for backtests. Extend `TechnicalIndicators` with ATR/RSI, add a Riverpod `ReboundScoreProvider` for the dashboard, add a `BacktestService` that reuses the same detector, and add a dedicated notification channel for graded signals.

Detector logic MUST live in one pure class so live + backtest share a single source of truth.

---

## 1. Existing Architecture Recap (what we integrate INTO)

From `.planning/codebase/ARCHITECTURE.md` + file inspection:

**4-layer model:**
```
UI (lib/screens/, lib/widgets/)
  → Provider (lib/providers/ — ChangeNotifier, Riverpod-style provider tree)
    → Service (lib/services/ — business logic, WS, REST, detectors, repos)
      → Data (lib/models/, SQLite via DatabaseHelper, SharedPreferences, Binance API)
```

**Existing pieces the rebound feature will touch/clone (with file evidence):**

| Existing component | File | Role relevant to rebound |
|---|---|---|
| `BinanceWebSocketManager` | `lib/services/binance_websocket_manager.dart` | **Combined-stream pattern** to copy: subscribes to `!ticker@arr` (one WS, all USDT perps). We build an equivalent for klines. |
| `KlineWebSocketService` | `lib/services/kline_websocket_service.dart` | **Single-symbol/single-interval** WS for the chart. NOT reusable for 400 symbols — only for the drill-down chart. Emits raw `KlineData` on each tick (not just on close). |
| `KlineProvider` | `lib/providers/kline_provider.dart` | Single-symbol chart state. NOT reused for monitoring. Shows the existing indicator-compute-on-update seam to mirror. |
| `BinanceApiService.getKlines()` | `lib/services/binance_api_service.dart:475,491` | **Historical klines REST endpoint** (`/fapi/v1/klines`) — already exists, reused by `BacktestService` for historical replay. |
| `TechnicalIndicators` | `lib/services/technical_indicators.dart` | Has `calculateMA`, `_calculateEMA`, `calculateBOLL`, `calculateMACD`. **Missing ATR and RSI** — must extend (shared infra for live + backtest). |
| `KlineCacheService` | `lib/services/kline_cache_service.dart` | SQLite-backed `kline_cache` table (symbol+interval→JSON). **Reusable as-is** for backtest historical storage and seed data. |
| `PumpDetector` + strategies | `lib/services/pump_detector.dart`, `lib/services/strategies/*` | The **architectural template** for the detector (strategy pattern, pure-ish `check(...)`). Rebound detector parallels this. |
| `PumpAlertService` | `lib/services/pump_alert_service.dart` | The **orchestrator template**: WS-manager → detector → store → repository → notification. Rebound copies this wiring shape. |
| `PumpStore` | `lib/services/pump_store.dart` | In-memory ring buffer for active pumps. Pattern to clone for in-memory rebound-signal state. |
| `NotificationService` | `lib/services/notification_service.dart` | Singleton, channel-based (`pump_alerts`, `funding_rate_channel`). Rebound needs a NEW channel + graded logic. |
| `DatabaseHelper` | `lib/services/database_helper.dart` | SQLite bootstrap + manual migrations. Rebound needs new tables (signals, backtest runs). |

**Key constraint (from CONCERNS.md):** no rate limiting, fragile WS reconnect, single-threaded Dart event loop, ~200-symbol tracking capacity in pump detector. The rebound scanner over ~400 symbols × 4 timeframes must be efficient and must not duplicate reconnect storms.

---

## 2. Recommended Architecture

### 2.1 New components — where each sits in the 4-layer model

| Layer | NEW component | Purpose | Talks to |
|---|---|---|---|
| **Service** | `ReboundKlineStreamService` | Combined kline WS: subscribes to up to ~200 streams per connection (Binance limit: 1024 streams/conn, 5s msg limit) across symbols × 4 timeframes (15m/1h/4h/1d). Emits closed-kline events. Pattern cloned from `BinanceWebSocketManager`. | Binance WS, feeds `ReboundDetector` |
| **Service** | `ReboundDetector` (PURE) | Stateless signal engine. Input: a window of `KlineData[]` + params. Output: `ReboundSignal?` (with stage results + raw score components). **No I/O, no Dart `async`, no WS.** Runnable identically in live and backtest. | `TechnicalIndicators` (ATR/RSI/BOLL) |
| **Service** | `ReboundConfluenceScorer` (PURE) | Cross-timeframe confluence scoring. Input: per-timeframe `ReboundSignal?` for one symbol. Output: combined `ReboundScore` (0–100). Pure function. | called by `ReboundAlertService` |
| **Service** | `ReboundAlertService` | Orchestrator (twin of `PumpAlertService`). Wires: `ReboundKlineStreamService` → per-TF kline buffer → `ReboundDetector` → confluence scorer → `ReboundScoreProvider` (state) → `ReboundAlertService` graded alert path → `NotificationService` + repository. | All of the above |
| **Service** | `BacktestService` | Pulls historical klines via `BinanceApiService.getKlines()` (cached in `KlineCacheService`), replays the SAME `ReboundDetector` over rolling windows, simulates trades, aggregates stats, runs param sweeps. | `BinanceApiService`, `KlineCacheService`, `ReboundDetector`, `ReboundConfluenceScorer` |
| **Provider** | `ReboundScoreProvider` (ChangeNotifier) | Dashboard state: `Map<Timeframe, List<ReboundScore>>` sorted by score, per-timeframe enable flags, status enum. The dashboard reads this. | `ReboundAlertService` |
| **Provider** | `BacktestProvider` (ChangeNotifier) | Backtest UI state: run config, progress, results, param-sweep matrix. | `BacktestService` |
| **UI** | `ReboundDashboardScreen` + widgets | Tab per timeframe (15m/1h/4h/日), score-sorted list, score sparkline, drill-down to `KlineScreen`. | `ReboundScoreProvider` |
| **UI** | `BacktestScreen` + widgets | Config form (symbol/date-range/param-sweep), progress, results table (win rate, avg R, payoff), equity curve. | `BacktestProvider` |
| **Data/Models** | `ReboundSignal`, `ReboundScore`, `ReboundConfig`, `BacktestRun`, `BacktestTrade`, `BacktestStats` | Immutable data classes with `copyWith()` / `fromJson`. | — |

### 2.2 Component boundaries (responsibility matrix)

| Component | Responsibility | Does NOT do |
|---|---|---|
| `ReboundKlineStreamService` | WS connect/subscribe/reconnect, parse kline, **buffer rolling window per (symbol,TF)**, emit **closed-kline** events | compute indicators, decide signals, talk to UI |
| `ReboundDetector` | pure signal math (3-stage check: drop leg / recovery leg / confluence filter) | state, I/O, timing |
| `ReboundConfluenceScorer` | pure cross-TF scoring | state |
| `ReboundAlertService` | orchestration, debouncing, dispatching to provider + alerts | UI rendering |
| `ReboundScoreProvider` | UI-facing reactive state, sorting, per-TF toggles | WS, detector math |
| `BacktestService` | replay + sim + stats; calls detector as a function | live WS, UI |
| `NotificationService` (extended) | display local notifications, channel routing | deciding when to alert (caller decides) |

### 2.3 End-to-end LIVE data flow

```text
Binance fstream (USDT-perp klines)
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ ReboundKlineStreamService (NEW, Service layer)            │
│   • combined WS subscription: <symbol>@kline_<TF> ×4 TFs  │
│   • per-(symbol,TF) rolling List<KlineData> buffer         │
│   • on each kline msg:                                     │
│       - update buffer (replace last if same openTime,      │
│         append if new)                                     │
│       - if k.x == true (CLOSED): emit ClosedKline event    │
└──────────────────────┬─────────────────────────────────────┘
                       │  Stream<ClosedKline(symbol, TF, window)>
                       ▼
┌──────────────────────────────────────────────────────────┐
│ ReboundAlertService (NEW, Service layer — orchestrator)   │
│   for each ClosedKline:                                    │
│     1. hand window+params to ReboundDetector.evaluate()    │
│        → ReboundSignal? (dropLegOK, recoveryLegOK,         │
│           confluenceFilterOK, components)                  │
│     2. store per-(symbol,TF) latest signal in in-memory    │
│        Map<symbol, Map<TF, ReboundSignal?>>                │
│     3. ReboundConfluenceScorer.score(map[symbol])          │
│        → ReboundScore (0-100, tier: high/med/low/none)     │
│     4. push ReboundScore into ReboundScoreProvider         │
│     5. if tier crosses into 'med'/'high' AND TF enabled:   │
│           → ReboundAlertService.fireGradedAlert(score)     │
└─────────┬───────────────────────────────────────┬──────────┘
          │                                       │
          ▼                                       ▼
┌─────────────────────────────┐   ┌──────────────────────────────┐
│ ReboundScoreProvider (NEW)  │   │ NotificationService (MOD)     │
│   • ChangeNotifier           │   │   • NEW channel 'rebound_*'   │
│   • Map<TF, List<Score>>     │   │   • graded: high=响铃+vibrate,│
│   • notifyListeners()        │   │     med=横幅, low=仅看板       │
│   • UI rebuilds dashboard    │   │   • coalesce within TF window │
└──────────┬──────────────────┘   └───────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────┐
│ ReboundDashboardScreen (NEW, UI)                          │
│   TabBar: 15m | 1h | 4h | 日                               │
│   per-Tab: Consumer<ReboundScoreProvider>                 │
│     → score-sorted list of (symbol, score, components)    │
│   tap row → existing KlineScreen (REUSED, not rebuilt)    │
└──────────────────────────────────────────────────────────┘
```

**Seams to call out:**
- **Stream seam (Service→Service):** `ReboundKlineStreamService.closedKlineStream` → `ReboundAlertService`. Pure `Stream<ClosedKline>`, decouples WS from logic.
- **Pure seam (Service→Service):** `ReboundDetector.evaluate(window, params) → ReboundSignal?`. No async, no side effects — this is THE seam that makes live+backtest reuse work.
- **State seam (Service→Provider):** `ReboundAlertService` calls `ReboundScoreProvider.upsert(score)`. Provider is the only thing the UI listens to.
- **Kline close vs tick:** ONLY closed klines (`k.x == true`) trigger detection. In-progress ticks only refresh the buffer tail. This matches the project constraint "K 线收盘后尽快计算".

### 2.4 Multi-timeframe architecture decision

**Decision: ONE orchestrator (`ReboundAlertService`), ONE stream service, with per-(symbol,TF) detector invocations — NOT four separate detector instances.**

Rationale:
- The 3-stage signal logic (drop leg / recovery leg / confluence filter) is **identical across timeframes**; only the `KlineData` window and the ATR period differ. Parameterizing the detector by `(window, params)` is cleaner than 4 classes.
- The **confluence scorer** inherently cross-cuts timeframes, so a single owner of `Map<symbol, Map<TF, signal>>` is required anyway.
- One stream service manages one combined WS per Binance-allowed stream-batch (≤1024 streams/conn), reducing reconnect-storm risk flagged in CONCERNS.md.

**Where the cross-TF confluence state lives:** in `ReboundAlertService` as `Map<String, Map<Timeframe, ReboundSignal?>>`. The scorer is a pure function over this map; the service owns and mutates it. Provider/State layer never owns confluence state (it only reads materialized `ReboundScore`s).

### 2.5 Backtest data flow (emphasizing detector reuse)

```text
BacktestScreen (UI) → BacktestProvider → BacktestService.run(config)
        │
        ▼
┌──────────────────────────────────────────────────────────┐
│ BacktestService.run(BacktestConfig)                        │
│  1. For each (symbol, TF) in config.symbols×config.tfs:    │
│       klines = KlineCacheService.getCached(...)            │
│              ?? await BinanceApiService.getKlines(...)     │
│              then KlineCacheService.saveCache(...)         │
│  2. For each time index i (stepping TF by TF):             │
│       window = klines.sublist(max(0,i-N), i+1)             │
│       signal = ReboundDetector.evaluate(window, params)    │ ← SAME pure fn as live
│       if signal != null && confluence passes:              │
│         trade = SimulateTrade.open(symbol, entry=i, ...)   │
│  3. Walk forward; close trade by exit rule (fixed N bars   │
│     or stop/target from ATR).                              │
│  4. Aggregate BacktestStats: winRate, avgR, payoff,        │
│     expectancy, maxDD, count.                              │
│  5. (optional) param sweep: re-run with param grid;        │
│     ReboundConfluenceScorer.score reused per bar.          │
│  6. Persist BacktestRun to SQLite + emit progress via      │
│     BacktestProvider.                                       │
└──────────────────────────────────────────────────────────┘
```

**The load-bearing requirement:** `ReboundDetector.evaluate(List<KlineData> window, ReboundParams params) → ReboundSignal?` is called from BOTH paths. Live path passes a live-maintained buffer; backtest passes a sliced historical array. Identical code, identical output → backtest validity = live validity. The detector MUST NOT: read system time, call `DateTime.now()`, hit the network, depend on Provider, or hold mutable state between calls.

---

## 3. NEW vs MODIFIED (explicit, per component)

### 3.1 NEW (greenfield files)

| Path | Component |
|---|---|
| `lib/services/rebound/rebound_kline_stream_service.dart` | `ReboundKlineStreamService` (combined kline WS) |
| `lib/services/rebound/rebound_detector.dart` | `ReboundDetector` (pure 3-stage engine) |
| `lib/services/rebound/rebound_confluence_scorer.dart` | `ReboundConfluenceScorer` (pure cross-TF) |
| `lib/services/rebound/rebound_alert_service.dart` | `ReboundAlertService` (orchestrator) |
| `lib/services/rebound/rebound_params.dart` | `ReboundParams` (thresholds, all marked "starting values") |
| `lib/services/backtest/backtest_service.dart` | `BacktestService` |
| `lib/services/backtest/simulate_trade.dart` | `SimulateTrade` helper |
| `lib/providers/rebound_score_provider.dart` | `ReboundScoreProvider` |
| `lib/providers/backtest_provider.dart` | `BacktestProvider` |
| `lib/screens/rebound/rebound_dashboard_screen.dart` | Dashboard + tab widgets |
| `lib/screens/rebound/widgets/*` | Score card, sparkline, TF toggle |
| `lib/screens/backtest/backtest_screen.dart` | Backtest config + results UI |
| `lib/models/rebound_signal.dart` | `ReboundSignal`, `ReboundSignalComponents` |
| `lib/models/rebound_score.dart` | `ReboundScore`, `ScoreTier` enum |
| `lib/models/rebound_config.dart` | `ReboundConfig` |
| `lib/models/backtest_run.dart`, `backtest_trade.dart`, `backtest_stats.dart` | Backtest data models |

### 3.2 MODIFIED (existing files, minimal changes)

| Existing file | Change | Why |
|---|---|---|
| `lib/services/technical_indicators.dart` | **ADD** `calculateATR(data, period)` and `calculateRSI(data, period)`. Pure additions, no behavior change to existing indicators. | Detector needs ATR (drop normalization) + RSI (oversold confluence). Shared by live + backtest. |
| `lib/services/notification_service.dart` | **ADD** `showReboundNotification({symbol, score, tier, timeframe})` + NEW channels `rebound_high`, `rebound_med`. Add coalescing map. | Graded alerts; existing channels untouched. |
| `lib/services/database_helper.dart` | **ADD** tables `rebound_signals`, `backtest_runs`, `backtest_trades` + bump schema version with migration. | Persistence for signal history + backtest results. |
| `lib/services/binance_websocket_manager.dart` | **ADD** an exported enum/const for combined-stream URL builder (or extract a small `BinanceWsUri` helper). Optional refactor. | Rebound stream reuses URL-building know-how; avoids drift. |
| `lib/services/binance_api_service.dart` | **ADD** a paged `getKlinesPaged()` helper if backtest needs >1000 candles (REST limit). Reuses existing `getKlines()`. | Backtest historical depth. |
| `lib/services/kline_cache_service.dart` | **MINOR**: widen cache TTL override for backtest seeds, or add `saveCacheForced()`. | Backtest wants stale-but-present historical data. |
| `lib/screens/main_navigation.dart` | **ADD** bottom-nav items: 反弹看板, 回测. | Surface new screens. |
| `lib/main.dart` | **ADD** provider registration for `ReboundScoreProvider`, `BacktestProvider`; start `ReboundAlertService` alongside existing pump background service. | Wire into app bootstrap. Mirror existing provider tree. |
| `lib/screens/kline_screen.dart` | **MINOR**: accept an optional initial indicator set / annotation param so the rebound drill-down can highlight the detected drop+recovery window. | Reuse the existing chart for drill-down instead of building a new one. |

### 3.3 NOT touched (deliberate non-reuse)

| Component | Why not reused |
|---|---|
| `KlineWebSocketService` | Single-symbol/single-TF; chart-only. Cannot monitor 400 symbols × 4 TFs. New combined stream service is required. |
| `KlineProvider` | Single-symbol chart state. Wrong shape for dashboard monitoring. |
| `PumpDetector` / `PumpAlertService` | Different domain (pump vs rebound). Architectural **template** only; do not subclass or couple. Keeps pump stack stable. |

---

## 4. Patterns to Follow (verified present in codebase)

### Pattern 1: Orchestrator-service wiring (clone of `PumpAlertService`)
**What:** One service owns the full pipeline (WS → detector → store → repo → notification).
**When:** Any live monitoring feature.
**Evidence:** `lib/services/pump_alert_service.dart` lines 45–117.
**Example shape (rebound):**
```dart
class ReboundAlertService {
  final ReboundKlineStreamService _stream = ReboundKlineStreamService();
  final Map<String, Map<Timeframe, ReboundSignal?>> _latest = {};
  StreamSubscription? _sub;

  Future<void> start() async {
    await _stream.connect(symbols, timeframes);
    _sub = _stream.closedKlineStream.listen(_onClosedKline);
  }

  void _onClosedKline(ClosedKline c) {
    final window = _stream.windowOf(c.symbol, c.tf);
    final signal = ReboundDetector.evaluate(window, _params);   // PURE
    _latest.putIfAbsent(c.symbol, () => {})[c.tf] = signal;
    final score = ReboundConfluenceScorer.score(_latest[c.symbol]!); // PURE
    _provider.upsert(score);
    if (score.tier.index >= ScoreTier.med.index && _enabledTfs[c.tf]) {
      _notify(score);
    }
  }
}
```

### Pattern 2: Pure detector + params object (clone of `PumpDetector.check`)
**What:** Detector takes data + params, returns optional result, no side effects.
**When:** ANY signal math — enables backtest reuse.
**Hard rule:** `ReboundDetector.evaluate` must be sync and side-effect-free.

### Pattern 3: Combined-stream WS (clone of `BinanceWebSocketManager`)
**What:** One WS connection, Binance combined-stream URL `/stream?streams=a@b,c@d`, single `onMessage` parses and dispatches.
**When:** Monitoring many symbols/timeframes.
**Evidence:** `binance_websocket_manager.dart` uses `!ticker@arr` (one stream, all symbols). For klines we use the explicit combined `/stream?streams=...` endpoint since there is no `!kline@arr` all-market kline stream.
**Note on limit:** Binance allows ≤1024 streams per connection and ≤5 subs/sec. For 400 symbols × 4 TFs = 1600 streams → **2 connections** (split by TF, or by symbol batch). Document this as a service-config concern.

### Pattern 4: Strategy/config object (clone of `PumpConfig` + `strategies/`)
**What:** Thresholds in a serializable config object (`load()`/`save()` to SharedPreferences), all marked "starting values" per PROJECT.md key decision.
**When:** Tunable params that backtest later calibrates.

### Pattern 5: Repository + fallback (clone of `RepositoryFactory`)
**What:** SQLite repo with in-memory fallback.
**When:** Persisting rebound signals / backtest runs. Follows existing `SqlitePumpRepository` / `MemoryPumpRepository` shape.

---

## 5. Anti-Patterns to Avoid (codebase-specific)

### Anti-Pattern 1: Time/I/O inside the detector
**What goes wrong:** `ReboundDetector` calls `DateTime.now()`, the WS, or a Provider.
**Why bad:** Breaks backtest determinism; backtest would "detect" different signals than live. Core value prop destroyed.
**Instead:** Detector is `ReboundSignal? evaluate(List<KlineData> window, ReboundParams p)`. Period.

### Anti-Pattern 2: Reusing `KlineWebSocketService` for monitoring
**What goes wrong:** N×4 single-symbol WS connections → reconnect storm, Binance bans, battery drain (CONCERNS.md flags exactly this).
**Instead:** One combined-stream service with ≤2 connections.

### Anti-Pattern 3: Coupling rebound to `PumpDetector`
**What goes wrong:** Shared mutable threshold state, pump changes break rebound.
**Instead:** Separate detector class; share only the pure `TechnicalIndicators` math library.

### Anti-Pattern 4: `notifyListeners()` on every WS tick
**What goes wrong:** Rebuild storms (CONCERNS.md: "Provider Notifier Timing" fragile area).
**Instead:** Only emit to provider on **closed-kline** events; debounce if multiple TFs close near-simultaneously.

### Anti-Pattern 5: Generic `Exception()` for signal/backtest errors
**What goes wrong:** CONCERNS.md flags generic exceptions across the codebase; rebound inherits the disease.
**Instead:** Define `ReboundConfigError`, `BacktestDataError`, etc. (small typed exceptions).

### Anti-Pattern 6: No rate limiting on REST historical pulls
**What goes wrong:** Backtest param-sweep triggers thousands of `getKlines()` calls → IP ban (CONCERNS.md "No API Rate Limiting").
**Instead:** `BacktestService` MUST cache aggressively (`KlineCacheService`) and throttle REST calls; never re-pull in a sweep.

---

## 6. Scalability Considerations

| Concern | ~400 symbols × 4 TF (v1) | 10× growth | Mitigation |
|---|---|---|---|
| WS stream count | 1600 streams → 2 connections | 16000 → need sharding | Make connection-count a service config; shard by symbol-batch. |
| Per-close CPU | 4 closes/sec/symbol worst case → 1600 evals/sec | 16000 evals/sec | Detector is O(window) ≈ O(100); profile, cache indicator tails (CONCERNS.md flags indicator recompute). |
| Memory (rolling buffers) | 400 × 4 × ~300 candles × ~50 bytes ≈ 24 MB | 240 MB | Cap window length; LRU-evict inactive symbols. |
| Reconnect storm | 2 connections, coordinated | — | Single reconnect coordinator; reuse `BinanceWebSocketManager`'s exponential-backoff-with-cap (5s→60s). |
| REST rate (backtest) | Cached after first pull | — | `KlineCacheService` + explicit throttle; param sweeps never re-pull. |
| Notification spam | Graded + coalesced per TF window | — | Coalesce map in `NotificationService`; per-TF enable flags in provider. |

---

## 7. Suggested BUILD ORDER (dependency-aware → feeds roadmap phases)

The roadmapper converts this into phases. Each step lists **dependencies** and **what it unblocks**.

1. **Indicator foundations (ATR + RSI).** Modify `technical_indicators.dart`.
   - Deps: none. Unblocks: step 2.
   - Why first: detector and backtest both depend on it; it's a pure addition with zero risk to existing pump/chart features. Unit-testable in isolation.

2. **Pure detector + params + signal models.** NEW `rebound_detector.dart`, `rebound_params.dart`, `rebound_signal.dart`, `rebound_score.dart`, `rebound_confluence_scorer.dart`.
   - Deps: step 1. Unblocks: steps 3, 4, 5 (everything downstream).
   - Why second: this is the single source of truth for signal logic. Make it 100% unit-tested with synthetic kline fixtures BEFORE wiring any I/O. Pure → trivially testable.

3. **Live monitoring wiring.** NEW `rebound_kline_stream_service.dart`, `rebound_alert_service.dart`, `rebound_score_provider.dart`. MODIFY `main.dart` (provider reg), `main_navigation.dart` (tab).
   - Deps: step 2. Unblocks: step 4 (dashboard), step 5 (alerts).
   - Why third: detector exists; now feed it real data. Can be validated headlessly (log signals) before UI exists.

4. **Dashboard UI.** NEW `rebound_dashboard_screen.dart` + widgets. REUSE `KlineScreen` for drill-down.
   - Deps: step 3 (provider). Unblocks: user-visible v1.
   - Why fourth: provider state exists; UI is pure consumption. Drill-down reuses existing chart screen (modify minimally).

5. **Graded alerts.** MODIFY `notification_service.dart` (new channels + coalescing); wire from `ReboundAlertService`.
   - Deps: step 3. Unblocks: user-visible v1.
   - Can run in parallel with step 4 (both consume step 3).

6. **Backtest service.** NEW `backtest_service.dart`, `simulate_trade.dart`, backtest models, `backtest_provider.dart`. REUSE `BinanceApiService.getKlines()` + `KlineCacheService` + `ReboundDetector`.
   - Deps: step 2 (detector) + step 1 (indicators). Unblocks: step 7.
   - Why sixth: the whole point is to reuse the detector from step 2 against historical data. Must come AFTER the detector is locked, so backtest results are valid against the live logic. Backtest does NOT need steps 3–5.

7. **Backtest UI.** NEW `backtest_screen.dart` + widgets; MODIFY `database_helper.dart` (backtest tables).
   - Deps: step 6. Unblocks: param-calibration loop (key PROJECT.md decision: "回测 + 参数扫描即校准引擎").
   - Last: pure consumption of step 6.

**Optional / cross-cutting (can slot anywhere after step 2):**
- Schema migration for `rebound_signals` persistence (modify `database_helper.dart`).
- Coalescing + per-TF enable settings (SharedPreferences, mirroring `pump_config_service.dart`).

**Phase-mapping hint for roadmapper:**
- Phase A = steps 1–2 (foundations + detector; fully unit-tested, no UI).
- Phase B = steps 3–5 (live monitoring + dashboard + alerts; user-visible MVP).
- Phase C = steps 6–7 (backtest + calibration; closes the param-tuning loop).

---

## 8. Confidence Assessment

| Area | Confidence | Reason |
|---|---|---|
| Integration points with existing services | HIGH | Verified by reading actual files (`pump_alert_service.dart`, `binance_websocket_manager.dart`, `kline_websocket_service.dart`, `binance_api_service.dart:getKlines`, `technical_indicators.dart`). |
| NEW vs MODIFIED split | HIGH | Each modification is minimal and additive; existing behavior preserved. |
| Live + backtest detector reuse | HIGH | Pure-function design enforced; matches existing `PumpDetector.check` template. |
| Multi-TF architecture (single orchestrator) | MEDIUM-HIGH | Sound for v1 (4 TFs); scaling beyond ~10 TFs or 4000 symbols would require sharding (noted). |
| Combined-stream WS feasibility | HIGH | Binance documented `/stream?streams=` + 1024-stream limit; mirrors existing `!ticker@arr` pattern. |
| Build order | HIGH | Each step's dependencies verified against the component graph. |

---

## 9. Gaps to Address in Phase-Specific Research

- **Exact Binance combined-kline message shape** and `k.x` (closed) field semantics for the rebound stream service — confirm against current Binance fapi docs during Phase B planning.
- **ATR/RSI period defaults** and the 2×ATR drop threshold — PROJECT.md marks these "starting values"; backtest (Phase C) calibrates. Initial values need a brief feasibility check against a sample symbol during Phase A.
- **Exit-rule design for backtest trades** (fixed N bars vs ATR stop/target) — deferred to Phase C SPEC.
- **Notification coalescing window length** per TF — UX tuning, decide in Phase B UAT.
- **DB schema for `rebound_signals` / `backtest_runs`** — concrete columns deferred to Phase A/C PLAN files.

---

## Sources

- `.planning/PROJECT.md` (milestone scope, key decisions: ATR normalization, 4-TF independent + confluence, no auto-trade, thresholds = starting values)
- `.planning/codebase/ARCHITECTURE.md` (4-layer model, component responsibilities, data-flow patterns)
- `.planning/codebase/CONVENTIONS.md` (naming, provider/singleton/repository patterns, error handling, Chinese-first comments)
- `.planning/codebase/CONCERNS.md` (tech debt to respect: no rate limiting, WS reconnect storms, provider notifier timing, indicator recompute, generic exceptions)
- Direct file inspection: `lib/services/binance_websocket_manager.dart`, `lib/services/kline_websocket_service.dart`, `lib/services/pump_alert_service.dart`, `lib/services/notification_service.dart`, `lib/services/technical_indicators.dart`, `lib/services/kline_cache_service.dart`, `lib/services/binance_api_service.dart` (`getKlines` at lines 475/491)
