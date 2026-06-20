import 'dart:async';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/rebound_timeframes.dart';

/// 单轮扫描的进度快照。
///
/// [round] 为已完成的扫描轮次计数（每完成一轮 +1，per B3）。
/// [scanned] 为当前已扫描的 symbol 数；[total] 为本轮待扫描总数。
/// [lastScanTime] 为最近一次完整完成扫描的时间（进行中为 null）。
class ScanProgress {
  final int round;
  final int scanned;
  final int total;
  final DateTime? lastScanTime;

  const ScanProgress({
    required this.round,
    required this.scanned,
    required this.total,
    this.lastScanTime,
  });
}

/// 单轮扫描的完整结果。
class ScanResult {
  /// 命中反弹的 symbol 集合（任意 TF 命中即视为命中）。
  final Set<String> hitSymbols;

  /// symbol → timeframe → 信号快照（仅命中的 TF 有非 null 值）。
  final Map<String, Map<String, ReboundSignal?>> signalsBySymbolTf;

  /// 本轮扫描完成时间。
  final DateTime scannedAt;

  /// 本轮扫描的轮次序号。
  final int round;

  const ScanResult({
    required this.hitSymbols,
    required this.signalsBySymbolTf,
    required this.scannedAt,
    required this.round,
  });
}

/// REST kline 拉取回调（生产由 dashboard 注入 `api.getRecentKlines` 闭包）。
///
/// 单独抽象为回调而非直接依赖 [BinanceApiService]，便于单测注入 mock
/// —— `getRecentKlines` 在 `KlineApi` extension 中定义，无法被子类 override。
typedef KlinesFetcher = Future<List<dynamic>> Function({
  required String symbol,
  required String interval,
  required int limit,
});

/// 全市场 REST 轮询扫描器（gap closure 04-03）。
///
/// 按固定间隔从 fapi `/fapi/v1/klines` 拉取全部 USDT 永续合约的近期 K 线，
/// 喂给纯函数 [ReboundDetector.evaluate]（live/backtest 单一真源），
/// 输出命中反弹的标的集合，由编排器驱动 WS 实时精跟。
///
/// **限流策略（per D1/D2 + T-04-03-01）:**
/// - `limit=99` → weight=1（最省）
/// - 全市场 ~400 × 4 TF = 1600 请求/轮，单轮 weight=1600 ≤ 2400/min 上限
/// - 错峰分批: `batchSize=8` 并发，批间 `batchDelay=200ms` 间隔
/// - 轮询间隔默认 60s（保留 33% 余量）
/// - `_scanning` 重入守卫：防 _scanOnce 自重叠导致瞬时 weight 翻倍触发 429
/// - 429 退避：捕获含 "429" 的异常时本轮跳过剩余 + 暴露 [rateLimitedCount]
class ReboundMarketScanner {
  final KlinesFetcher _fetchKlines;
  final ReboundDetector _detector;
  final Future<List<String>> Function() _symbolsProvider;
  final ReboundParams _params;

  /// 批大小（批内并发 symbol 数）。
  final int batchSize;

  /// 批间错峰延迟（生产默认 200ms，测试可注入 1ms）。
  final Duration batchDelay;

  /// 轮询间隔（默认 60s）。
  final Duration scanInterval;

  /// 每请求拉取的 K 线根数（默认 99，weight=1）。
  final int klineLimit;

  /// 扫描周期列表。
  final List<String> timeframes;

  /// 只保留反弹结束位置在最近 N 根 K 线内的信号（per 04-03 用户需求：
  /// 仅检测最近发生的反弹，而非窗口内的历史反弹）。默认 6 根。
  final int recentBars;

  // ─── 回调（可选）──────────────────────────────────────────
  final void Function(ScanResult result)? onScanComplete;
  /// 命中回调（可重新赋值——编排器 attachScanner 时接管，per D4）。
  void Function(Set<String> hits)? onHits;
  final void Function(ScanProgress progress)? onProgress;

  // ─── 状态 ────────────────────────────────────────────────
  ScanProgress? _lastProgress;
  ScanResult? _lastResult;
  int _round = 0;
  bool _scanning = false;
  Timer? _timer;

  /// 触发 429 限流的累计次数（人工观察，per W5）。
  int _rateLimitedCount = 0;

  /// 429 退避窗口：剩余需跳过的扫描轮数。
  int _rateLimitSkipRounds = 0;

  /// 最近一次进度快照。
  ScanProgress? get lastProgress => _lastProgress;

  /// 最近一次完整扫描结果。
  ScanResult? get lastResult => _lastResult;

  /// 累计触发 429 的次数。
  int get rateLimitedCount => _rateLimitedCount;

  ReboundMarketScanner({
    required KlinesFetcher fetchKlines,
    required ReboundDetector detector,
    required Future<List<String>> Function() symbolsProvider,
    ReboundParams params = const ReboundParams(),
    this.batchSize = 8,
    this.batchDelay = const Duration(milliseconds: 200),
    this.scanInterval = const Duration(seconds: 60),
    this.klineLimit = 99,
    this.timeframes = monitoredTimeframes,
    this.recentBars = 6,
    this.onScanComplete,
    this.onHits,
    this.onProgress,
  })  : _fetchKlines = fetchKlines,
        _detector = detector,
        _symbolsProvider = symbolsProvider,
        _params = params;

  /// 启动定时轮询（首轮立即触发）。
  void start() {
    // 幂等：dashboard 与 alertService.start() 都可能调用 start()，
    // 不加守卫会触发两轮首轮扫描竞争重入保护 → 请求翻倍触发 429（per 04-REVIEW CR-01）
    if (_timer != null) return;
    // 首轮立即触发
    Timer.run(() {
      if (!_scanning) _safeScan();
    });
    _timer = Timer.periodic(scanInterval, (_) {
      if (!_scanning) _safeScan();
    });
  }

  Future<void> _safeScan() async {
    try {
      await scanOnce();
    } catch (_) {
      // 单轮异常不致命，下一轮重试
    }
  }

  /// 执行单轮扫描（重入守卫：上一轮未完成时立即返回 lastResult）。
  ///
  /// 429 退避窗口内：跳过本轮请求，仅递减跳过计数。
  Future<ScanResult> scanOnce() async {
    // 重入守卫（per B4）
    if (_scanning) {
      return _lastResult ??
          ScanResult(
            hitSymbols: {},
            signalsBySymbolTf: {},
            scannedAt: DateTime.now(),
            round: _round,
          );
    }

    // 429 退避窗口
    if (_rateLimitSkipRounds > 0) {
      _rateLimitSkipRounds--;
      return _lastResult ??
          ScanResult(
            hitSymbols: {},
            signalsBySymbolTf: {},
            scannedAt: DateTime.now(),
            round: _round,
          );
    }

    _scanning = true;
    try {
      final symbols = await _symbolsProvider();
      final total = symbols.length;
      final hits = <String>{};
      final signalsBySymbolTf = <String, Map<String, ReboundSignal?>>{};
      var scanned = 0;
      bool rateLimitedThisRound = false;

      // 错峰分批扫描
      for (var i = 0; i < symbols.length; i += batchSize) {
        // 429 命中：跳过本轮剩余 symbol
        if (rateLimitedThisRound) {
          break;
        }
        final batch = symbols
            .skip(i)
            .take(batchSize)
            .toList();
        final batchResults =
            await Future.wait(batch.map((s) => _scanSymbol(s, hits, signalsBySymbolTf)));
        // 任一 symbol 触发 429 → 本轮剩余跳过
        if (batchResults.any((r) => r == _ScanOutcome.rateLimited)) {
          rateLimitedThisRound = true;
          _rateLimitedCount++;
          _rateLimitSkipRounds = 2; // 默认跳 2 轮 = 120s 退避窗口
        }
        scanned += batch.length;
        _lastProgress = ScanProgress(
          round: _round,
          scanned: scanned,
          total: total,
          lastScanTime: null,
        );
        onProgress?.call(_lastProgress!);
        // 批间错峰延迟
        if (i + batchSize < symbols.length) {
          await Future.delayed(batchDelay);
        }
      }

      // 完成一轮
      _round++;
      final now = DateTime.now();
      _lastProgress = ScanProgress(
        round: _round,
        scanned: scanned,
        total: total,
        lastScanTime: now,
      );
      onProgress?.call(_lastProgress!);

      final result = ScanResult(
        hitSymbols: hits,
        signalsBySymbolTf: signalsBySymbolTf,
        scannedAt: now,
        round: _round,
      );
      _lastResult = result;
      onScanComplete?.call(result);
      onHits?.call(Set.unmodifiable(hits));
      return result;
    } finally {
      _scanning = false;
    }
  }

  /// 扫描单个 symbol 的全部 TF。
  ///
  /// 单 symbol / 单 TF 失败不中断整轮（per T-04-03-02）。
  /// 返回 [_ScanOutcome.rateLimited] 表示该 symbol 触发了 429 限流。
  Future<_ScanOutcome> _scanSymbol(
    String symbol,
    Set<String> hits,
    Map<String, Map<String, ReboundSignal?>> signalsBySymbolTf,
  ) async {
    bool rateLimited = false;
    for (final tf in timeframes) {
      try {
        final raw = await _fetchKlines(
          symbol: symbol,
          interval: tf,
          limit: klineLimit,
        );
        if (raw.isEmpty) continue;
        final window = _mapKlines(raw);
        final signal = _detector.evaluate(
          window,
          _params,
          symbol: symbol,
          timeframe: tf,
        );
        // 只保留最近 recentBars 根内结束的反弹（per 04-03）；
        // window.length < recentBars（新上市/短窗口）时无"最近 N 根"概念，
        // 降级为不接受（数据不足），避免负阈值放行历史反弹（per 04-REVIEW WR-02）
        final threshold = window.length >= recentBars
            ? window.length - recentBars
            : window.length;
        final effective =
            (signal == null || signal.recoveryEndIndex >= threshold)
                ? signal
                : null;
        signalsBySymbolTf.putIfAbsent(symbol, () => {});
        signalsBySymbolTf[symbol]![tf] = effective;
        if (effective != null) {
          hits.add(symbol);
        }
      } catch (e) {
        final msg = e.toString();
        // 429 限流识别
        if (msg.contains('429')) {
          rateLimited = true;
          continue; // 仍尝试记录，但本轮后续 batch 会跳过
        }
        // 其他异常（超时 / 5xx / 畸形 JSON）：跳过该 TF，不中断
        continue;
      }
    }
    return rateLimited ? _ScanOutcome.rateLimited : _ScanOutcome.ok;
  }

  /// 将 Binance fapi kline List<dynamic> 映射为 KlineData 列表。
  ///
  /// 沿用 [ReboundKlineStreamService.warmUp] 中相同的字段顺序（per action）：
  /// [0]=openTime, [1]=open, [2]=high, [3]=low, [4]=close, [5]=volume。
  List<KlineData> _mapKlines(List<dynamic> raw) {
    return raw.map((k) {
      final list = k as List<dynamic>;
      return KlineData(
        time: DateTime.fromMillisecondsSinceEpoch(list[0] as int),
        open: double.parse(list[1].toString()),
        high: double.parse(list[2].toString()),
        low: double.parse(list[3].toString()),
        close: double.parse(list[4].toString()),
        volume: double.parse(list[5].toString()),
      );
    }).toList();
  }

  /// 停止定时轮询。
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 手动确认 429 已退避完毕，清除剩余跳过计数。
  void ackRateLimit() {
    _rateLimitSkipRounds = 0;
  }
}

/// 单 symbol 扫描结果枚举（内部用）。
enum _ScanOutcome { ok, rateLimited }
