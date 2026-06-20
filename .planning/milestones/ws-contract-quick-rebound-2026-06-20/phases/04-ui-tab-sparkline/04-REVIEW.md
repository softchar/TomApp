---
phase: 04-ui-tab-sparkline
reviewed: 2026-06-20T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/models/rebound_params.dart
  - lib/providers/rebound_score_provider.dart
  - lib/screens/rebound_dashboard_screen.dart
  - lib/services/rebound/rebound_alert_service.dart
  - lib/services/rebound/rebound_kline_stream_service.dart
  - lib/services/rebound/rebound_market_scanner.dart
findings:
  critical: 2
  warning: 7
  info: 4
  total: 13
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-06-20
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the rebound monitoring feature (uncommitted changes across scanner / stream service / alert service / provider / params / dashboard). The `connect()` aliasing fix (copying `timeframes` before clear+addAll) is correct, and the `recentBars` recency filter logic is sound for the normal case (`window.length >= recentBars`). However there are two BLOCKERs: a double-`scanner.start()` that fires two concurrent first-round scans and races on the `_scanning` guard, and a fire-and-forget `_openConnection(placeholder)` inside `_ensureCapacity` whose error/exception is silently swallowed and which subscribes an invalid `__placeholder__@noop` stream to Binance. Several additional warnings around race conditions, swallowed errors, and a jitter bias that defeats its own purpose.

The user-context highlights (divide-by-zero fix, onScanComplete write-through, recentBars filter, log panel, LOOSE_PARAMS switch) were each traced; the divide-by-zero and write-through paths are correct, the recentBars filter has a latent off-by-zero edge case (negative threshold when window shorter than recentBars), and the LOOSE_PARAMS switch is documented as test-only but ships unconditionally in production builds.

## Critical Issues

### CR-01: Scanner started twice — double `start()` races on the re-entry guard and fires two overlapping first-round scans

**File:** `lib/screens/rebound_dashboard_screen.dart:122` and `lib/services/rebound/rebound_alert_service.dart:147`
**Issue:** The dashboard calls `_scanner!.start()` explicitly at `rebound_dashboard_screen.dart:122` after `_alertService!.start([])`. But `ReboundAlertService.start()` itself calls `_scanner?.start()` again at `rebound_alert_service.dart:147` (because the scanner was attached via `attachScanner` at line 119). `ReboundMarketScanner.start()` is not idempotent against `Timer.run`: it does `_timer?.cancel()` (good) but also unconditionally schedules `Timer.run(() { if (!_scanning) _safeScan(); })` every call. Two `Timer.run` callbacks land back-to-back on the microtask queue; the first acquires `_scanning=true` inside `_safeScan → scanOnce`, the second's `if (!_scanning)` check sees the flag already set and no-ops — but only by luck of scheduling order. Worse, if the first scan completes its synchronous prefix and awaits `_symbolsProvider()` before the second `Timer.run` fires, both can pass the guard and double the first round's REST load (~1600 requests → ~3200), defeating the T-04-03-01 weight budget and risking an immediate 429 before any real traffic.
**Fix:** Make `start()` idempotent, or only call it from one place. Preferred: guard in the scanner itself.

```dart
void start() {
  if (_timer != null) return; // 已启动，幂等
  Timer.run(() { if (!_scanning) _safeScan(); });
  _timer = Timer.periodic(scanInterval, (_) {
    if (!_scanning) _safeScan();
  });
}
```

And in the dashboard, drop the redundant `_scanner!.start()` at `rebound_dashboard_screen.dart:122` (the alert service already starts it once the scanner is attached).

### CR-02: `_ensureCapacity` fire-and-forgets `_openConnection` on a placeholder stream and swallows its errors

**File:** `lib/services/rebound/rebound_kline_stream_service.dart:225-240`
**Issue:** When all existing connections are full, `_ensureCapacity` synthesizes a placeholder connection with stream `'__placeholder__@noop'`, calls `_openConnection(placeholder)` **without await**, then immediately `placeholder.streams.clear()`. Three concrete defects:

1. `_openConnection` reads `conn.streams.first` synchronously (`rebound_kline_stream_service.dart:273`) — at that instant `first` is `'__placeholder__@noop'`, which becomes the stream name in the connect URI `wss://fstream.binance.com/stream?streams=__placeholder__@noop`. Binance rejects this as an invalid stream; the connection may close immediately or subscribe to a stream that never sends data.
2. Because `_openConnection` is not awaited, any exception it throws (URI parse, WebSocket connect failure, `await conn.channel!.ready` rejection) is uncaught and becomes an unhandled async error.
3. `placeholder.streams.clear()` runs right after the fire-and-forget call. If `_openConnection`'s SUBSCRIBE block (`conn.streams.length > 1`, computed later after `await conn.channel!.ready`) reads `streams` after the clear, it sees the real streams the caller appended and may double-subscribe, or sees an empty list and skips.

The net effect: under capacity pressure (which is the explicit design case — `maxTracked=30` symbols × 4 TFs = 120 streams, well under 1024 but the placeholder path is reachable during bursts), new tracked symbols can land on a half-broken connection and silently lose their kline stream.
**Fix:** Build the connection from the caller's actual first stream, not a placeholder. The cleanest fix is to make `_ensureCapacity` return a fresh empty connection whose real first stream is added by the caller before `_openConnection` is invoked — and to await `_openConnection` or attach an error handler.

```dart
_ShardConnection _ensureCapacity(int streamsPerSymbol) {
  for (final conn in _connections) {
    if (conn.streams.length + streamsPerSymbol <= maxStreamsPerConnection) {
      return conn;
    }
  }
  // 新建空 connection，由调用方填充首个真实 stream 后再 openConnection。
  final conn = _ShardConnection(<String>[]);
  _connections.add(conn);
  return conn;
}
```

Then in `subscribe`, before calling `_ensureCapacity`, ensure the first stream is appended; or restructure so the caller invokes `_openConnection` and awaits it. At minimum, wrap the unawaited call: `_openConnection(placeholder).catchError((e) { /* log + remove conn */ });`.

## Warnings

### WR-01: `subscribe` mutates `conn.streams` and `_streamToConn` before `_openConnection` has connected — partial state on connect failure

**File:** `lib/services/rebound/rebound_kline_stream_service.dart:172-192`
**Issue:** In the incremental subscribe path, `conn.streams.add(streamName)` and `_streamToConn[streamName] = conn` are committed, then `conn.channel?.sink.add(SUBSCRIBE…)` is sent, then `warmUp` is fire-and-forget. If the placeholder connection from `_ensureCapacity` never actually connects (see CR-02) or connects and drops, the indices still claim the symbol is subscribed, so `isSymbolSubscribed` returns true and `unsubscribe` will try to `sink.add` on a null channel (silently no-op'd by `?.`). The symbol is permanently stuck: appears subscribed, never receives data, never gets retried.
**Fix:** On connection failure (`_onConnectionError` / `_onConnectionDone` for a placeholder that never opened), remove the orphaned streams from `_streamToConn` and `conn.streams`, and either retry or surface via a `connectionLost` stream the alert service can react to.

### WR-02: `recencyFilter` produces a negative threshold when `window.length < recentBars`, admitting every historical rebound

**File:** `lib/services/rebound/rebound_market_scanner.dart:284-287`
**Issue:** `signal.recoveryEndIndex >= window.length - recentBars`. With `klineLimit=99` and `recentBars=6` this is `>= 93` — correct. But the filter is also evaluated against windows shorter than `recentBars` (e.g. a newly listed contract where Binance returns < 6 klines, or a `raw.isEmpty`-then-partial edge): `window.length - recentBars` goes negative, the predicate `recoveryEndIndex >= -3` is true for any non-negative index, and every signal — including ancient rebounds at the start of the window — passes the "recent only" filter. The user requirement "仅检测最近发生的反弹" is violated for short windows.
**Fix:** Clamp the threshold to a non-negative minimum, and require the window to be at least `recentBars` long.

```dart
final threshold = window.length >= recentBars
    ? window.length - recentBars
    : window.length; // 短窗口：只接受结尾就是反弹末端的信号
final effective = (signal == null || signal.recoveryEndIndex >= threshold)
    ? signal
    : null;
```

### WR-03: Reconnect jitter is always additive and biased — defeats thundering-herd avoidance

**File:** `lib/services/rebound/rebound_kline_stream_service.dart:411-426`
**Issue:** The jitter computation `(delay.inMilliseconds * 0.25 * (now.ms % 100 - 50) / 50).abs()` takes absolute value, so `jitter ∈ [0, +0.25·delay]` — it can only *add* delay, never subtract. The stated intent (`±25%`) requires jitter ∈ [-0.25·delay, +0.25·delay]. Combined with using `DateTime.now().millisecondsSinceEpoch % 100` as a PRNG (low entropy, predictable), when many connections drop simultaneously (e.g. Binance side restart) they all compute similar `now % 100` values and reconnect in a tight cluster, the exact thundering herd the jitter was meant to prevent.
**Fix:** Drop `.abs()` and use a real PRNG.

```dart
final rnd = Random();
final jitterMs = (delay.inMilliseconds * 0.25 * (rnd.nextDouble() * 2 - 1)).toInt();
final total = delay + Duration(milliseconds: jitterMs);
```

### WR-04: `untrackSymbol` called fire-and-forget from a sync `handleClosedKline` — exceptions silently lost

**File:** `lib/services/rebound/rebound_alert_service.dart:236`
**Issue:** `untrackSymbol(c.symbol)` is an `async` Future (calls `_streamService.unsubscribe` and `_provider.removeSymbol`); invoked without `await` or `.catchError` inside the sync `handleClosedKline`. The code comment acknowledges this ("fire-and-forget"), but any exception (e.g. provider listener throwing during `notifyListeners`) becomes an unhandled future error. Over a long session these accumulate and on Flutter they crash in `FlutterError.onError` zones.
**Fix:** Attach a catchError handler.

```dart
untrackSymbol(c.symbol).catchError((e) {
  // 记录但不破坏 stream listener
  _provider.addLog('退出精跟失败 $c.symbol: $e');
});
```

### WR-05: `handleMessage` swallows all parse exceptions with no counter, no log, no circuit breaker

**File:** `lib/services/rebound/rebound_kline_stream_service.dart:298-343`
**Issue:** The `catch (_) {}` block has a comment saying "Phase 3 可增加 _parseErrorCount + 熔断逻辑" but as shipped there is zero observability. A malformed payload from Binance (or a stream-corruption bug) produces silent data loss with no signal to the operator that the entire pipeline is dark. The inline comment also contradicts the docstring of `handleMessage` which claims production usage. This is a robustness gap that will make field debugging extremely difficult.
**Fix:** At minimum increment a counter and log via `debugPrint` (or feed into the provider log panel that already exists). A hard cap on consecutive parse failures that triggers a reconnect would be better.

### WR-06: `handleClosedKline` warm-up completion check iterates `monitoredTimeframes` (global constant), not the connection's actual subscribed TFs

**File:** `lib/services/rebound/rebound_alert_service.dart:181-188`
**Issue:** `final stillWarming = monitoredTimeframes.any((tf) => _streamService.isWarmingUp(c.symbol, tf));`. `monitoredTimeframes` is currently `['15m']` (single TF), so this works today. But the moment the constant is reverted to `['15m','1h','4h','1d']` (which the `rebound_timeframes.dart` docstring explicitly invites as a one-line change), the check keys off the global constant rather than the TFs the symbol is actually subscribed to via `subscribe`/`connect`. If the stream service was constructed with a different TF set (test injection, future per-symbol TF customization), the alert service will mis-report warm-up completion.
**Fix:** Query the stream service for the symbol's actually-subscribed TFs, or thread the TF list through `trackSymbols`.

### WR-07: `onScanComplete` writes scanner signals with `score` that does NOT include the `mtfScore` enrichment applied in `handleClosedKline`

**File:** `lib/screens/rebound_dashboard_screen.dart:101-116` vs `lib/services/rebound/rebound_alert_service.dart:216-222`
**Issue:** The scanner's `ReboundDetector.evaluate` produces a raw `score`. `handleClosedKline` later adds `ReboundConfluenceScorer.scoreMultiTimeframe(...)` and clamps (`(signal.score + mtfScore).clamp(0,100)`). But the dashboard's `onScanComplete` writes `tfEntry.value` directly to the provider with the raw detector score. So a symbol shown immediately after a scan displays a *lower* score than the same symbol will show a few minutes later when a WS closed kline re-evaluates it — and with `monitoredTimeframes=['15m']`, the mtf scorer degenerates but the score still differs because the window changed. This is a visible UI flicker / inconsistency that an operator will notice ("why did the score just jump?"). It also means scanner-driven entries are ranked by an inconsistent score relative to WS-driven entries in the same sorted list.
**Fix:** Either run the same enrichment in `onScanComplete` before writing, or document and accept the transient. Cleanest: have the scanner or a shared helper apply the scorer so both paths are identical.

## Info

### IN-01: `looseForTesting` ships in production builds via `bool.fromEnvironment('LOOSE_PARAMS')`

**File:** `lib/models/rebound_params.dart:139-152`, `lib/screens/rebound_dashboard_screen.dart:20`
**Issue:** The LOOSE_PARAMS switch is gated only by a dart-define. A release build invoked with `--dart-define=LOOSE_PARAMS=true` (intentionally or via a stale CI script / launch config checked into the repo) will run with detection thresholds so loose that 0.3% drops trigger signals — effectively disabling the feature's quality gate. There is no `kReleaseMode` guard. The legend dialog also always shows the "测试期宽松参数" warning regardless of whether LOOSE_PARAMS is actually set (`rebound_dashboard_screen.dart:362-364`), which is misleading when running with strict defaults.
**Fix:** Add a release-mode guard, and gate the legend warning on `_looseForTesting`.

```dart
const _looseForTesting =
    !kReleaseMode && bool.fromEnvironment('LOOSE_PARAMS');
```

### IN-02: `debugPrint` left in production code path

**File:** `lib/screens/rebound_dashboard_screen.dart:114`
**Issue:** `debugPrint('[反弹] $msg');` runs on every completed scan round in production. `debugPrint` is throttled but still writes to stdout in release mode (it's not stripped). The same message is already added to the in-app log panel via `provider.addLog(msg)`, making the `debugPrint` redundant.
**Fix:** Remove the `debugPrint`, or gate behind `if (kDebugMode)`.

### IN-03: `_refreshWatchlist` is a no-op stub left in production

**File:** `lib/services/rebound/rebound_alert_service.dart:272-277`
**Issue:** The hourly `_watchlistTimer` (set at line 141-144) calls `_refreshWatchlist()`, whose entire body is an `if (_knownSymbols != null) { /* comment */ }` with no effect. The watchlist churn feature (per D-09) is effectively dead code — `updateSymbolList` is never called from anywhere in this review scope, so delisted/new contracts are never reconciled after startup. The provider will retain signals for delisted symbols indefinitely.
**Fix:** Either wire `_refreshWatchlist` to actually call the injected exchangeInfo service and then `updateSymbolList`, or remove the timer + method to avoid implying the feature works.

### IN-04: `_chunkSymbols` uses `.clamp(0, length)` on `sublist` end index — silent empty chunk risk

**File:** `lib/services/rebound/rebound_kline_stream_service.dart:263-269`
**Issue:** `(i + chunkSize).clamp(0, symbols.length)`. When `chunkSize` is 0 (reachable if `shardSize ~/ tfs.length` evaluates to 0 — e.g. `shardSize=1` with multi-TF `tfs.length=4`), the loop `i += 0` is an infinite loop. The current single-TF config masks this, but the multi-TF path (which the codebase explicitly supports) would hang. The defensive `clamp(0, …)` should be `max(i+1, …)` to guarantee progress.
**Fix:**

```dart
final end = (i + chunkSize).clamp(1, symbols.length); // 至少前进 1
chunks.add(symbols.sublist(i, end));
```

And guard `chunkSize` against 0 at the call site (`shardSize ~/ tfs.length` → `(shardSize ~/ tfs.length).clamp(1, …)`).

---

_Reviewed: 2026-06-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
