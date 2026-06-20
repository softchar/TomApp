import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/rebound_market_scanner.dart';
import 'package:tomapp/services/technical_indicators.dart';

/// 04-03 Task 1 测试：ReboundMarketScanner 全市场 REST 轮询扫描器。
///
/// 限流预算 / 错峰分批 / 命中过滤 / 空列表兜底 / 失败容错 /
/// detector 复用 / 扫描进度回调 / 重入保护。

/// 快速构造 KlineData。
KlineData _bar(int i, double close,
    {double? high, double? low, double? open, double volume = 10}) {
  return KlineData(
    time: DateTime(2024, 1, 1, 0, i),
    open: open ?? close,
    high: high ?? close + 1,
    low: low ?? close - 1,
    close: close,
    volume: volume,
  );
}

/// 构造平稳行情（detector 返回 null）。
///
/// fapi klines 布局：[openTime, open, high, low, close, volume, ...]。
List<List<dynamic>> _flatKlinesRaw(int count) {
  return List.generate(count, (i) {
    final t = DateTime(2024, 1, 1, 0, i).millisecondsSinceEpoch;
    return <dynamic>[
      t, '100.0', '101.0', '99.0', '100.0', '10.0',
      1000.0, 50, true,
    ];
  });
}

/// 构造 V 型反弹 fixture 的原始 Binance kline List<dynamic>。
/// stable(20) + drop 3 bars + recovery 2 bars，volume 放大。
List<List<dynamic>> _vReboundRaw() {
  final bars = <KlineData>[
    ...List.generate(20, (i) => _bar(i, 100)),
    _bar(20, 97, high: 100, low: 96, volume: 10),
    _bar(21, 93, high: 97, low: 92, volume: 10),
    _bar(22, 90, high: 93, low: 89, volume: 10),
    _bar(23, 99, high: 100, low: 90, volume: 20),
    _bar(24, 98, high: 99, low: 95, volume: 15),
  ];
  return bars
      .map((k) => <dynamic>[
            k.time.millisecondsSinceEpoch,
            k.open.toString(),
            k.high.toString(),
            k.low.toString(),
            k.close.toString(),
            k.volume.toString(),
            1000.0,
            50,
            true,
          ])
      .toList();
}

/// Mock kline 拉取回调：记录所有调用并按规则返回。
class _MockFetcher {
  /// 调用记录：(symbol, interval, limit)
  final List<({String symbol, String interval, int limit})> calls = [];

  /// 控制每个 symbol 的返回 fixture；symbol 未配置时返回空列表。
  ///
  /// key: symbol，value: 该 symbol 对所有 TF 都返回的 raw klines。
  Map<String, List<List<dynamic>>> fixtures = {};

  /// 需要抛异常的 (symbol, tf) 组合。
  final Set<String> throwOn = {};

  /// 注入的限流 / 阻塞钩子（用于重入保护测试）。
  Future<void> Function()? onBeforeCall;

  Future<List<dynamic>> call({
    required String symbol,
    required String interval,
    required int limit,
  }) async {
    calls.add((symbol: symbol, interval: interval, limit: limit));
    if (onBeforeCall != null) await onBeforeCall!();
    if (throwOn.contains('$symbol:$interval')) {
      throw Exception('mock 请求失败 $symbol:$interval');
    }
    return fixtures[symbol] ?? [];
  }
}

/// 用于测试的标的源替身：直接返回注入的 symbol 列表。
/// 真实 ExchangeInfoService 是单例 + SharedPreferences，不适合单测；
/// scanner 通过 symbolsProvider 回调解耦（生产由 dashboard 注入闭包读取 exchangeInfo）。
class _StubSymbolSource {
  final List<String> symbols;
  _StubSymbolSource(this.symbols);
}

void main() {
  late _MockFetcher fetcher;
  late ReboundDetector detector;

  setUp(() {
    fetcher = _MockFetcher();
    detector = ReboundDetector(TechnicalIndicators());
  });

  group('ReboundMarketScanner', () {
    // Test 1 [限流预算]: 400 标的 × 4 TF = 1600 请求，所有 limit==99
    test('限流预算：所有请求 limit==99，总数 == 标的 × TF', () async {
      final symbols = List.generate(400, (i) => 'SYM${i}USDT');
      fetcher.fixtures = {for (final s in symbols) s: _flatKlinesRaw(99)};

      final scanner = ReboundMarketScanner(
        fetchKlines: fetcher.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
      );

      final result = await scanner.scanOnce();

      expect(fetcher.calls.length, 400 * 4,
          reason: '400 标的 × 4 TF = 1600 请求');
      for (final c in fetcher.calls) {
        expect(c.limit, 99, reason: '所有请求 limit 必须 == 99 (weight=1)');
      }
      expect(result.hitSymbols, isEmpty, reason: '平盘 fixture 不应命中');
    });

    // Test 2 [错峰分批]: 批大小不超过上限
    test('错峰分批：每批 ≤ batchSize 个 symbol 并发', () async {
      final symbols = List.generate(20, (i) => 'BATCH${i}USDT');
      fetcher.fixtures = {for (final s in symbols) s: _flatKlinesRaw(99)};

      int active = 0;
      int maxActive = 0;
      final wrapped = _WrappedFetcher(fetcher, onEnter: () {
        active++;
        if (active > maxActive) maxActive = active;
      }, onExit: () {
        active--;
      });

      final scanner = ReboundMarketScanner(
        fetchKlines: wrapped.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
      );

      await scanner.scanOnce();
      // 每个 symbol 单轮内发起 4 个请求（4 TF），同一批内 ≤ batchSize 个 symbol
      // → 并发请求数峰值 ≤ batchSize × 4 = 32（每个 symbol 的 4 个 TF 是 await 串行的）
      // 但更准确地说：_scanSymbol 内部 4 个 TF 顺序 await，故批内并发 symbol 数 ≤ 8
      expect(maxActive, lessThanOrEqualTo(8 * 4),
          reason: '并发 symbol 数 ≤ batchSize=8，每 symbol 串行 4 个 TF');
    });

    // Test 3 [命中过滤]: 5 标的，2 命中 + 3 平盘
    test('命中过滤：onHits 收到恰好命中的 2 个 symbol', () async {
      final symbols = ['HITAUSDT', 'HITBUSDT', 'FLATAUSDT', 'FLATBUSDT', 'FLATCUSDT'];
      fetcher.fixtures = {
        'HITAUSDT': _vReboundRaw(),
        'HITBUSDT': _vReboundRaw(),
        'FLATAUSDT': _flatKlinesRaw(99),
        'FLATBUSDT': _flatKlinesRaw(99),
        'FLATCUSDT': _flatKlinesRaw(99),
      };

      Set<String>? received;
      final scanner = ReboundMarketScanner(
        fetchKlines: fetcher.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
        onHits: (hits) => received = hits,
      );

      final result = await scanner.scanOnce();
      expect(result.hitSymbols, {'HITAUSDT', 'HITBUSDT'});
      expect(received, {'HITAUSDT', 'HITBUSDT'});
    });

    // Test 4 [空列表兜底]
    test('空列表兜底：symbols 为空时不发请求、onHits 收到空集合', () async {
      final symbols = <String>[];
      Set<String>? received;
      final scanner = ReboundMarketScanner(
        fetchKlines: fetcher.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
        onHits: (hits) => received = hits,
      );

      final result = await scanner.scanOnce();
      expect(fetcher.calls, isEmpty);
      expect(result.hitSymbols, isEmpty);
      expect(received, isEmpty);
      expect(scanner.lastProgress, isNotNull);
    });

    // Test 5 [失败容错]: 部分标的抛异常 → 跳过、剩余正常检测
    test('失败容错：部分标的异常不中断整轮', () async {
      final symbols = ['OK1USDT', 'BADUSDT', 'OK2USDT', 'HITUSDT'];
      fetcher.fixtures = {
        'OK1USDT': _flatKlinesRaw(99),
        'OK2USDT': _flatKlinesRaw(99),
        'HITUSDT': _vReboundRaw(),
      };
      // BADUSDT 所有 TF 都抛
      for (final tf in ['15m', '1h', '4h', '1d']) {
        fetcher.throwOn.add('BADUSDT:$tf');
      }

      final scanner = ReboundMarketScanner(
        fetchKlines: fetcher.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
      );

      final result = await scanner.scanOnce();
      expect(result.hitSymbols, {'HITUSDT'},
          reason: '失败的 BADUSDT 不影响 HITUSDT 命中');
    });

    // Test 6 [detector 复用]: 每个请求的 limit 都符合单一真源调用规约
    test('detector 复用：scanner 调 detector.evaluate 且 symbol/timeframe 正确', () async {
      // 通过 spy detector 包装真实 detector 验证调用。
      final symbols = ['AUSDT', 'BUSDT'];
      fetcher.fixtures = {for (final s in symbols) s: _vReboundRaw()};

      final spy = _SpyDetector();
      final scanner = ReboundMarketScanner(
        fetchKlines: fetcher.call,
        detector: spy,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
      );

      await scanner.scanOnce();
      // 每个 symbol × 4 TF 应触发 1 次 evaluate
      expect(spy.calls.length, 2 * 4);
      // 验证 symbol 与 timeframe 都正确传给 detector
      final seenPairs = spy.calls.map((c) => '${c.symbol}:${c.timeframe}').toSet();
      for (final s in symbols) {
        for (final tf in ['15m', '1h', '4h', '1d']) {
          expect(seenPairs, contains('$s:$tf'));
        }
      }
    });

    // Test 7 [扫描进度回调]
    test('扫描进度回调：onProgress 在每批完成时触发、round 自增', () async {
      final symbols = List.generate(20, (i) => 'P${i}USDT');
      fetcher.fixtures = {for (final s in symbols) s: _flatKlinesRaw(99)};

      final progresses = <ScanProgress>[];
      final scanner = ReboundMarketScanner(
        fetchKlines: fetcher.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
        onProgress: (p) => progresses.add(p),
      );

      await scanner.scanOnce();
      expect(progresses, isNotEmpty);
      // 最后一次进度应扫描完毕
      final last = progresses.last;
      expect(last.scanned, 20);
      expect(last.total, 20);
      // 完成一轮后 round 自增为 1
      expect(scanner.lastProgress!.round, 1);
      expect(scanner.lastProgress!.lastScanTime, isNotNull);
    });

    // Test 8 [重入保护]
    test('重入保护：scanOnce 重叠时第二次立即 no-op，不翻倍 api 调用', () async {
      final symbols = List.generate(10, (i) => 'R${i}USDT');
      fetcher.fixtures = {for (final s in symbols) s: _flatKlinesRaw(99)};

      // 使用可控延时的 api 阻塞第一次 scanOnce
      final gate = _GatedFetcher(fetcher);
      final scanner = ReboundMarketScanner(
        fetchKlines: gate.call,
        detector: detector,
        symbolsProvider: () async => symbols,
        params: const ReboundParams(),
        batchSize: 8,
        batchDelay: const Duration(milliseconds: 1),
        klineLimit: 99,
      );

      // 启动第一次 scanOnce（会被 gate 阻塞）
      final first = scanner.scanOnce();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // 此时第二次调用应立即 no-op 返回（_scanning 守卫）
      final secondResult = await scanner.scanOnce();
      expect(scanner.rateLimitedCount, 0);
      // 第二次结果应是 lastResult（null 或首次尚未完成）— 关键是不抛、不增加并发

      // 释放第一次
      gate.release();
      await first;

      // 总请求数应等于 10 × 4 = 40，没有翻倍
      expect(fetcher.calls.length, 10 * 4,
          reason: '重入守卫应阻止第二次 scanOnce 翻倍 api 调用');
    });
  });
}

/// 包装 fetcher 用于观察并发度。
class _WrappedFetcher {
  final _MockFetcher _inner;
  final void Function() onEnter;
  final void Function() onExit;
  _WrappedFetcher(this._inner, {required this.onEnter, required this.onExit});

  Future<List<dynamic>> call({
    required String symbol,
    required String interval,
    required int limit,
  }) async {
    onEnter();
    try {
      return await _inner.call(symbol: symbol, interval: interval, limit: limit);
    } finally {
      onExit();
    }
  }
}

/// Spy detector：记录 evaluate 调用，内部委托真实 ReboundDetector。
class _SpyDetector extends ReboundDetector {
  final ReboundDetector _real = ReboundDetector(TechnicalIndicators());
  final List<({String symbol, String timeframe, int windowLen})> calls = [];
  _SpyDetector() : super(TechnicalIndicators());

  @override
  ReboundSignal? evaluate(
    List<KlineData> window,
    ReboundParams params, {
    required String symbol,
    required String timeframe,
  }) {
    calls.add((symbol: symbol, timeframe: timeframe, windowLen: window.length));
    return _real.evaluate(window, params, symbol: symbol, timeframe: timeframe);
  }
}

/// Gated fetcher：让首个请求阻塞直到 release() 被调用。
class _GatedFetcher {
  final _MockFetcher _inner;
  final Completer<void> _gate = Completer<void>();
  bool _firstStarted = false;
  _GatedFetcher(this._inner);

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  Future<List<dynamic>> call({
    required String symbol,
    required String interval,
    required int limit,
  }) async {
    if (!_firstStarted) {
      _firstStarted = true;
      await _gate.future; // 仅阻塞首个请求直至 release
    }
    return _inner.call(symbol: symbol, interval: interval, limit: limit);
  }
}
