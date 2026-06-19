# Stack Research

**Domain:** 合约快速反弹监控 (Contract V-rebound detection + multi-timeframe monitoring + dashboard + alerts + backtest) — Flutter/Dart brownfield addition to TomApp
**Researched:** 2026-06-19
**Confidence:** HIGH (versions verified against pub.dev API & Binance official docs; engineering judgments flagged as MEDIUM)

> **Scope note (read first):** This file covers ONLY the newly-needed stack for the `contract-quick-rebound` milestone. Existing validated capabilities (PUMP-01 pump engine, DATA-01 Binance REST+WS, DATA-02 market display, APP-01 Flutter framework) are NOT re-researched. Every recommendation below is tied to one of the six target features in PROJECT.md.

> **⚠ Critical correction:** PROJECT.md / CLAUDE.md state "Riverpod for state management", but the **actual `pubspec.yaml` and `.planning/codebase/ARCHITECTURE.md` show `provider: ^6.1.0` (the `provider` package, ChangeNotifier pattern), NOT Riverpod.** All integration guidance below targets the REAL stack (`provider` + 4-layer UI→Provider→Service→Data). Roadmapper must confirm with the user which is authoritative before phase planning; if Riverpod migration is intended, that is a separate prerequisite phase.

---

## Recommended Stack

### Core Technologies (NEW additions)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **drift** | `2.33.0` (or `2.32.x` if SDK stays at 3.0) | Type-safe reactive SQLite layer for historical kline OHLCV storage + backtest run cache | Actively maintained (pub.dev verified 2026-05-03, publisher simonbinder.eu); SQLite foundation matches existing `sqflite` mental model; reactive `Stream<List<Kline>>` fits `provider`/ChangeNotifier; time-series queries on `(symbol, interval, openTime)` index are natural. See "Why not Hive/Isar" below. |
| **archive** | `^4.0.2` | Unzip `data.binance.vision` monthly kline ZIP archives during backtest data import | Pure-Dart ZIP/TAR reader; drift's own dev-dependency so no new transitive burden; avoids shelling out to a native unzip on Android/iOS. |
| **fl_chart** | **UPGRADE `0.65.0` → `1.2.0`** | Candlestick chart for V-rebound visualization + backtest equity curves + score histograms | `CandlestickChart` type landed in v1.0.0 (verified pub.dev 2026-03-13); project already depends on fl_chart, so this is a version bump not a new dep. |

### Supporting Libraries (NEW)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **flutter_local_notifications** | **`17.2.3` — ALREADY IN PROJECT** | In-app + foreground-service local push alerts (signal grading, per-timeframe toggles) | v1 alerts: real-time monitor already runs in-process on candle close, so local notifications suffice — no server needed. Use immediately. |
| **flutter_background_service** | **`5.0.10` — ALREADY IN PROJECT** | Android foreground service to keep the WS-subscribed monitor alive when app is backgrounded | Reuse for the rebound monitor exactly as the pump detector already does. No new dep. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **build_runner** | `^2.6.0` (already present) | Generates drift table/companion code | Add `drift_dev` as dev-dependency; run `dart run build_runner build` after schema changes. |
| **drift_dev** | `^2.6.0` (NEW dev-dependency) | drift code generator paired with drift runtime | Pin to match drift major; drift 2.33 ↔ drift_dev 2.6+. |

---

## Feature-by-Feature Stack Decisions

### 1. Technical indicators (ATR / RSI / Bollinger / candle patterns) — BUILD, DON'T INSTALL

**Decision: implement from scratch in `lib/services/rebound/indicators/`.**

| Indicator | LOC (approx) | Why hand-rolled |
|-----------|--------------|-----------------|
| ATR(14) | ~20 | Wilder smoothing; needed in `2×ATR` drop threshold AND `0.3×ATR` stop buffer — must be the SAME instance to guarantee consistency |
| RSI(14) | ~25 | Wilder smoothing; reused in confluence filter AND scoring |
| Bollinger Bands(20, 2σ) | ~15 | SMA + std; confluence "close touches lower band" |
| SMA / swing-high / swing-low | ~15 | building blocks |

**Why NOT `deriv_technical_analysis` (the only real Dart TA lib):**
- Coupled to Deriv's `tick` model (single-price streaming), not OHLCV candles — adapter code ≈ reimplementation.
- Last meaningful release stale; low maintenance signal.
- Adds a dependency for ~300 lines of textbook formulas we must own anyway for ATR-normalization correctness.
- Existing `KlineProvider` already hand-computes MA/BOLL/MACD (`lib/providers/kline_provider.dart:122`) — extend that established pattern.

**Integration:** new `lib/services/rebound/indicator_engine.dart` — a pure-Dart, stateless function module: `IndicatorSeries compute(List<Kline> candles)`. Consumed by both the live monitor (Service layer) and the backtester. No Flutter/Dart version constraints beyond Dart 3.0.

**Confidence: HIGH** (engineering judgment, MEDIUM; library absence is a fact, HIGH).

### 2. Historical kline data for BACKTEST — `data.binance.vision` ZIPs (primary) + REST gap-fill

**Primary source — bulk ZIP downloads (no rate limit, months per file):**
```
https://data.binance.vision/data/futures/um/monthly/klines/{SYMBOL}/{INTERVAL}/{SYMBOL}-{INTERVAL}-{YYYY}-{MM}.zip
```
- Example: `https://data.binance.vision/data/futures/um/monthly/klines/BTCUSDT/15m/BTCUSDT-15m-2025-06.zip`
- Each `.zip` contains a CSV with the standard 12-column OHLCV schema; `.CHECKSUM` sibling file for integrity.
- Daily granularity also available at `.../daily/klines/...` for the most recent partial month.
- For ~400 USDT-perp symbols × 4 timeframes × ~1–2yr history, this is the only sane path (REST would need thousands of paginated calls).

**Gap-fill source — REST pagination (recent / fill missing day):**
- Endpoint: `GET https://fapi.binance.com/fapi/v1/klines?symbol=BTCUSDT&interval=15m&startTime=...&limit=1500`
- **Max 1500 klines/request**, default 500. Paginate by setting next `startTime = lastReturnedOpenTime + intervalMs`.
- Subject to IP weight limits (verify against live `General Info` docs before batch runs — values change).
- Use only for: (a) the most recent period not yet in monthly ZIPs, (b) re-fetching after a WS disconnect.

**Integration:** new `lib/services/rebound/backtest/kline_importer.dart` (Service layer) → writes to drift kline tables (Data layer). Run import as an explicit user action with progress UI (one-time per symbol/timeframe).

**Confidence: HIGH** (Binance official docs + data.binance.vision directory structure confirmed).

### 3. WebSocket combined-stream at scale (~400 symbols × 4 timeframes = 1600 streams) — SHARD

**Facts (Binance USD-M futures, official docs):**
- Base URL: `wss://fstream.binance.com/stream?streams=<s1>/<s2>/.../<sN>`
- Stream name format: `{symbolLower}@kline_{interval}` → e.g. `btcusdt@kline_15m`
- **Max 1024 streams per connection.**
- Incoming message cap: 10 msg/sec per connection (futures).
- Combined-stream payload wraps each event as `{"stream": "...", "data": {…kline…}}`.
- `k.x == true` in the kline payload = candle closed → trigger incremental compute. (`k.x` is the close flag.)

**Scale problem:** 400 × 4 = 1600 streams > 1024 limit. URL length is a non-issue vs. the hard stream-count limit.

**Decision: shard into 2 connections of ~800 streams each, grouped by symbol** (not by timeframe) so each connection carries all 4 timeframes for its symbol subset. Rationale: a symbol's 4 timeframes all close-aligned; grouping keeps per-symbol compute local. Alternatively shard by timeframe (4 × ~400) — simpler reconnection semantics, preferred if per-timeframe toggle is a hard requirement.

**Reconnect / partial-fill handling:**
- Existing `WebSocketManager` (`lib/services/binance_websocket_manager.dart`) already does reconnection — extend it with a `MultiStreamWebSocketManager` that manages N pooled connections.
- On reconnect, **always REST-backfill** the gap (klines that closed during the outage) before resuming incremental compute — drift stores last-seen openTime per (symbol, interval) for this.
- Use the `SUBSCRIBE` JSON-message method (post-connect) rather than embedding all streams in the URL: avoids any proxy URL-length truncation and lets you add/remove streams for per-timeframe toggles without reconnecting.
  ```json
  {"method":"SUBSCRIBE","params":["btcusdt@kline_15m","btcusdt@kline_1h"],"id":1}
  ```

**Message volume reality check:** 1600 streams × ~1 update/sec each at peak = ~1600 msg/sec sustained worst case — high but Dart's event loop + a lightweight parse-and-dedupe (only act on `k.x==true` close events) makes this tractable. Expect the vast majority of updates to be no-ops; filter early.

**Integration:** extend Service layer with `ReboundStreamManager extends/uses WebSocketManager`; emits closed-candle events into a `ReboundComputeProvider` (Provider layer) which runs `IndicatorEngine` + scoring and notifies the dashboard.

**Confidence: HIGH** (Binance official docs).

### 4. Backtesting — ROLL-YOUR-OWN event replay (no Dart framework exists worth using)

**Decision: build a small event-replay engine in `lib/services/rebound/backtest/`.**

No mature, maintained Dart backtesting framework targets this use case (crypto futures, candle-replay, ATR-based stops, fee modeling). Python's backtrader/vectorbt dominate this space but are not an option here. A focused ~400-LOC engine is the right call.

**Engine contract (`lib/services/rebound/backtest/backtest_engine.dart`):**
- Input: `BacktestConfig { symbols, interval, dateRange, strategyParams, feeBps, slippageBps, capital }`
- Replay: iterate candles in chronological order from drift; on each candle close, invoke `ReboundStrategy.evaluate(candlesUpToNow, indicatorSeries)` → returns `Signal?`
- Trade simulation (per PROJECT spec):
  - **Entry:** on signal candle's close price (next-open is more realistic but PROJECT says signal-close — confirm with user).
  - **Stop:** swing-low − `0.3×ATR(14)` (ATR from the SAME indicator series as the entry signal).
  - **Targets:** 61.8% Fibonacci retracement of the drop, and full (100%) retracement.
  - **Fees:** taker `0.04%` notional default (USDT-perp), configurable; slippage `n` bps on entry & exit.
- Output: `BacktestResult { trades[], equityCurve[], stats{ winRate, profitFactor, maxDrawdown, sharpe, avgRR } }` — persisted to drift for dashboard comparison.
- **Parameter sweep:** the engine accepts a `List<BacktestConfig>` (grid over `dropAtrMult`, `recoveryPct`, confluence thresholds) and runs them concurrently via `Future.wait` with a small concurrency cap to avoid memory spikes.

**Why this is fine:** the strategy is deterministic (no lookahead, no ML), candles are pre-loaded from drift, and Dart's single-threaded model guarantees ordered replay. Isolates can be used later only if sweep throughput becomes a bottleneck — NOT for v1.

**Confidence: HIGH** (engineering; framework-absence is a fact).

### 5. Local storage / cache for klines — DRIFT (new), keep sqflite for legacy

**Decision: add `drift` for kline OHLCV + backtest artifacts; leave existing `sqflite`/`DatabaseHelper` untouched for pump data.**

**Schema sketch (drift tables in `lib/data/rebound/tables.dart`):**
```dart
class Klines extends Table {
  TextColumn get symbol = text()();
  TextColumn get interval = text()();  // '15m','1h','4h','1d'
  IntColumn get openTime = integer()();
  RealColumn get o = real(); RealColumn get h = real();
  RealColumn get l = real(); RealColumn get c = real();
  RealColumn get v = real();
  @override Set<Column> get primaryKey => {symbol, interval, openTime};
}
// + BacktestRuns, BacktestTrades tables
```
- Primary key `(symbol, interval, openTime)` gives O(log n) range scans and dedup on upsert.
- drift's `insertOnConflictUpdate` makes WS gap-fill idempotent.

**Why drift over alternatives (verified 2026-06):**
| Option | Verdict |
|--------|---------|
| **drift 2.33** | ✅ Chosen — actively maintained, type-safe, SQLite (familiar), reactive streams. Verified pub.dev 2026-05-03. |
| Hive / Hive CE | ❌ Original Hive deprecated by author; Hive CE is a community fork with thinner track record. Avoid for new code. |
| Isar | ❌ Reported abandoned by original author; uncertain future. Too risky for a storage layer we'll depend on for years. |
| sqflite (raw) | ⚠ Already in project for pump data — fine, but lacks typed schema & reactive queries. Don't force kline tables into it. |
| ObjectBox | ⚡ Fast, but native-binary overhead + less query flexibility for time-series range scans than SQL. Overkill here. |

**⚠ SDK compatibility note:** drift 2.33 requires Dart `>=3.10.0`. Project's `pubspec.yaml` declares `sdk: '>=3.0.0 <4.0.0'`. Two options — **roadmapper must pick one**:
- (A) **Bump project SDK to `>=3.6.0 <4.0.0`** (matches Flutter 3.27.x toolchain already in use) → use drift `2.33.0`. RECOMMENDED.
- (B) Keep SDK at 3.0 → use drift `2.32.x` (last version supporting older SDK; still gets bugfixes via the workspace). Acceptable fallback.

**Confidence: HIGH** (versions/abandonment verified; SDK pick is the only open item).

### 6. Push notifications — LOCAL for v1, DEFER firebase_messaging

**Decision: use `flutter_local_notifications` (already in project) for v1; do NOT add `firebase_messaging` yet.**

- The rebound monitor runs **in-process** (foreground or Android foreground-service via `flutter_background_service`). When a candle closes and a signal fires, `flutter_local_notifications.show(...)` is called directly — zero infrastructure, zero cost.
- Per-timeframe toggles + signal grading = different notification channels / IDs / priorities — all natively supported by `flutter_local_notifications`.
- **`firebase_messaging` (~15.x, tied to FlutterFire BoM 4.7.0 / Dec 2025) is deferred** until there's a real requirement for: cross-device push when app is fully terminated, or a server-side trigger. Adding FCM means: Firebase project, APNs certs (iOS), a backend to send, FCM token registration — out of scope for v1 per PROJECT.md's "no server" brownfield posture.
- iOS caveat: local notifications work fine but background delivery is less reliable than Android's foreground service — acceptable for v1, revisit if users complain.

**Integration:** new `lib/services/rebound/alert_dispatcher.dart` (Service layer) — subscribes to `ReboundComputeProvider` signals, applies per-timeframe toggle settings (shared_preferences, already in project), fires `flutter_local_notifications`. Mirrors existing pump notification flow.

**Confidence: HIGH** (engineering; FCM version range MEDIUM — verify exact `firebase_messaging` version if/when added).

### 7. Charting for dashboard & backtest — UPGRADE fl_chart to 1.2.0

**Decision: bump `fl_chart` 0.65.0 → 1.2.0; evaluate dropping `flutter_chen_kchart 2.0.4`.**

- **fl_chart 1.2.0** (verified pub.dev 2026-03-13, sdk `>=3.6.2`, flutter `>=3.27.4`): native `CandlestickChart` (added 1.0.0), `LineChart` for equity curve / ATR-over-time, `BarChart` for score histograms and per-timeframe signal counts.
- The SDK bump to `>=3.6.0` (needed for drift anyway) also satisfies fl_chart 1.2.0's `>=3.6.2` constraint — they align cleanly.
- **`flutter_chen_kchart 2.0.4`** is currently used by `KlineScreen` for candlestick rendering. Options:
  - Keep for the existing K-line screen (no migration risk), use fl_chart 1.2.0 `CandlestickChart` only for the new rebound dashboard. → SAFER for v1.
  - Migrate K-line screen to fl_chart candlestick too → unified dep, less code. → Defer to a cleanup phase.
- **AVOID:** Syncfusion Flutter Charts (commercial license, registration required), `trading_chart` (low maintenance), `candlesticks` (thin feature set).

**Confidence: HIGH** (version verified; migration-scope call is MEDIUM engineering judgment).

---

## Installation

```bash
# 1. (Recommended prerequisite) bump project Dart SDK constraint
#    pubspec.yaml: environment.sdk: '>=3.6.0 <4.0.0'
#    then: flutter pub get

# 2. New runtime dependencies
flutter pub add drift:^2.33.0 archive:^4.0.2

# 3. Upgrade existing dependency
flutter pub add fl_chart:^1.2.0

# 4. New dev dependency (drift codegen)
flutter pub add --dev drift_dev:^2.6.0

# 5. Generate drift code after defining tables
dart run build_runner build --delete-conflicting-outputs

# NOTE: flutter_local_notifications (17.2.3), flutter_background_service (5.0.10),
# shared_preferences, http, web_socket_channel, sqflite, build_runner, mockito
# are ALREADY in pubspec.yaml — no action needed.
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| **Hand-rolled ATR/RSI/Bollinger** | `deriv_technical_analysis` | Only if the team later wants 50+ exotic indicators (Stochastic, ADX, Ichimoku) AND is willing to write the OHLCV adapter. Not justified by v1's 4 indicators. |
| **drift** for klines | raw `sqflite` (extend `DatabaseHelper`) | If minimizing new deps is a hard rule and team accepts hand-written SQL + manual migrations. Loses type safety & reactive streams. |
| **drift** for klines | Hive CE | Only for ephemeral hot-cache of the most-recent N candles; still pair with drift/SQLite for full history. Don't use as the system of record. |
| **data.binance.vision ZIPs** | REST-only pagination | Only for tiny symbol sets (<10) or very short windows. Infeasible for 400 symbols × multi-year. |
| **Sharded WS by symbol (2×800)** | Sharded WS by timeframe (4×~400) | If per-timeframe independent on/off is the dominant UX (likely — PROJECT mentions per-timeframe toggles). Pick the sharding axis that matches the toggle axis. |
| **Hand-rolled backtest engine** | Python backtrader via FFI/dart:ffi | Never for this project — adds a Python runtime dependency, breaks the pure-Flutter deploy posture. |
| **fl_chart 1.2.0 candlestick** | Keep `flutter_chen_kchart` | If the existing `KlineScreen` chen-kchart integration is working well and you want zero migration risk for v1 — use fl_chart only for the new dashboard. |
| **Local notifications v1** | `firebase_messaging` (FCM) | Only when users need push while app is fully terminated across devices, or a server-side signal source is added. Defer. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Hive** (original) | Officially deprecated by author; unmaintained. | drift (or Hive CE only for throwaway hot-cache). |
| **Isar** | Author abandoned; uncertain maintenance future; risky foundation. | drift. |
| **`deriv_technical_analysis`** | Tick-model coupled, stale, adapter cost ≈ rewrite; only 4 indicators needed. | Hand-rolled `IndicatorEngine`. |
| **syncfusion_flutter_charts** | Commercial license + registration wall; legal overhead for a personal/small-team app. | fl_chart 1.2.0. |
| **trading_chart / candlesticks / interactive_chart** | Low maintenance, thin features, risk for a long-lived codebase. | fl_chart 1.2.0 `CandlestickChart`. |
| **firebase_messaging (FCM) in v1** | Requires Firebase project + APNs certs + a backend to send; PROJECT.md has no server. | flutter_local_notifications (already present). |
| **REST-only historical backfill** | 400 symbols × multi-year = thousands of paginated calls, rate-limit-bound. | data.binance.vision ZIP bulk download. |
| **Single WS connection for 1600 streams** | Exceeds Binance's hard 1024-stream/conn limit. | Shard across ≥2 connections. |
| **Lookahead in backtest** | Using future candles to compute an indicator at time T inflates results. | IndicatorEngine takes `candles[0..i]` only; enforce in tests. |

---

## Stack Patterns by Variant

**If per-timeframe independent toggling is the top UX priority:**
- Shard the WS pool by **timeframe** (4 connections × ~400 symbol-streams each).
- Each connection can be torn down / rebuilt independently when a user toggles a timeframe off.
- Because each connection < 1024 streams and aligns with the toggle axis.

**If minimizing connection count is the priority:**
- Shard by **symbol** (2 connections × 800 streams, each carrying all 4 timeframes).
- Fewer sockets, but toggling a timeframe requires SUBSCRIBE/UNSUBSCRIBE messages across both.

**If backtest sweep throughput becomes slow (>minutes):**
- Move the replay loop into a Dart `Isolate` (compute-heavy, no Flutter bindings needed) — feed candle chunks via ports.
- NOT needed for v1 single-config runs; only for wide parameter grids.

**If the user later wants cross-device / server-side alerts:**
- Add `firebase_messaging` then; keep `flutter_local_notifications` as the foreground renderer (FCM data messages route through it on Android).

---

## Version Compatibility

| Package | Version | Requires (Dart/Flutter) | Verified | Notes |
|---------|---------|-------------------------|----------|-------|
| drift | 2.33.0 | Dart `>=3.10.0` | pub.dev 2026-05-03 | Needs SDK bump to ≥3.10 OR use drift 2.32.x (Dart ≥3.5) / 2.30.x (Dart ≥3.5). |
| drift (fallback) | 2.32.1 | Dart `>=3.5.0` | pub.dev 2026-03-22 | If project bumps to 3.6 but not 3.10. |
| fl_chart | 1.2.0 | Dart `>=3.6.2`, Flutter `>=3.27.4` | pub.dev 2026-03-13 | Aligns with recommended SDK bump to 3.6. |
| archive | 4.0.2 | Dart (broad) | transitively pinned by drift dev-deps | Pure Dart, no native. |
| drift_dev | ~2.6.x | matches drift major | — | Add as dev_dependency. |
| flutter_local_notifications | 17.2.3 | already resolved | in pubspec | No change. |
| flutter_background_service | 5.0.10 | already resolved | in pubspec | No change. |
| web_socket_channel | 2.4.0 | already resolved | in pubspec | Reuse for sharded WS manager. |
| firebase_messaging | ~15.x (DEFERRED) | FlutterFire BoM 4.7.0 | web search Dec 2025 | Not added in v1. Exact version re-verify if/when adopted. |
| Project SDK today | `>=3.0.0 <4.0.0` | — | pubspec.yaml | **Bump to `>=3.6.0 <4.0.0`** to unlock drift + fl_chart 1.2. |

---

## Integration with Existing 4-Layer Architecture (UI → Provider → Service → Data)

New modules slot into the existing layers without disturbing pump-detection code:

```
UI Layer      : ReboundDashboardScreen (TabBar: 15m/1h/4h/1d)
                ReboundBacktestScreen (config form + results charts)
                ↳ uses fl_chart 1.2.0 CandlestickChart / LineChart / BarChart
Provider Layer: ReboundComputeProvider (ChangeNotifier) ← list of ReboundSignal, sorted by score
                ReboundSettingsProvider   ← per-timeframe toggles (shared_preferences)
BacktestProvider ← BacktestResult + equity curve
Service Layer : ReboundStreamManager     ← sharded WS pool (extends WebSocketManager)
                IndicatorEngine          ← pure Dart ATR/RSI/Bollinger/SMA
                ReboundStrategy          ← drop/recovery/confluence + 0-100 scoring
                AlertDispatcher          ← flutter_local_notifications
                BacktestEngine           ← event replay + trade sim + sweep
                KlineImporter            ← data.binance.vision ZIP + REST gap-fill
Data Layer    : drift Klines / BacktestRuns / BacktestTrades tables (NEW)
                shared_preferences (existing) for toggles
                REST via BinanceApiService (existing) for gap-fill
```
- **Reuses** `BinanceApiService`, `WebSocketManager` (extended), `shared_preferences`, `flutter_background_service`, `flutter_local_notifications`, `build_runner`, `mockito`.
- **Does NOT touch** `PumpDetector`, `PumpRepository`, `KlineProvider`, `DatabaseHelper` (sqflite pump store) — clean module boundary.

---

## Sources

- pub.dev API (authoritative) — `fl_chart` 1.2.0 (2026-03-13), `drift` 2.33.0 (2026-05-03). **HIGH confidence.**
- Binance Official Docs — USD-M futures WS market streams (1024 streams/conn, 10 msg/sec, `fstream.binance.com/stream`, `symbol@kline_interval`). **HIGH.**
- Binance Official Docs — Kline Candlestick REST (`fapi.binance.com/fapi/v1/klines`, limit max 1500, startTime pagination). **HIGH.**
- data.binance.vision — directory structure `data/futures/um/monthly/klines/{SYMBOL}/{INTERVAL}/{SYMBOL}-{INTERVAL}-{YYYY}-{MM}.zip` + `.CHECKSUM`. **HIGH.**
- Greenrobot / community surveys (2025) — Hive deprecated, Isar abandoned, drift actively maintained. **HIGH** (multi-source consensus).
- FlutterFire docs / release notes — `firebase_messaging` version range tied to BoM 4.7.0 (Dec 2025). **MEDIUM** (exact patch version not pinned; re-verify on adoption).
- Engineering judgments (hand-rolled indicators, sharded WS axis, event-replay backtest, local-notifications-first) — author's domain reasoning. **MEDIUM.**

---
*Stack research for: 合约快速反弹监控 (Contract V-rebound monitoring)*
*Researched: 2026-06-19*
