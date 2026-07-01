import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/alert_level.dart';
import 'package:tomapp/models/rebound_notification_record.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/providers/rebound_score_provider.dart';
import 'package:tomapp/services/rebound/rebound_confluence_scorer.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/rebound_kline_stream_service.dart';
import 'package:tomapp/services/rebound/rebound_market_scanner.dart';
import 'package:tomapp/services/rebound/rebound_notification_repository.dart';
import 'package:tomapp/services/rebound/rebound_timeframes.dart';

import 'package:tomapp/services/rebound/alert_throttler.dart';
import 'package:tomapp/services/rebound/rebound_notification_service.dart';
import 'package:tomapp/providers/alert_settings_provider.dart';

/// 反弹监控编排器。
///
/// 订阅 [ReboundKlineStreamService.closedKlines]，维护 per-(symbol,TF) 信号状态，
/// 调用 [ReboundDetector.evaluate]，运行 [ReboundConfluenceScorer.scoreMultiTimeframe]
/// 计算跨周期加分，更新 [ReboundScoreProvider]。
///
/// 每小时刷新 watchlist（剔除下架合约，添加新上线合约）。
class ReboundAlertService {
  final ReboundKlineStreamService _streamService;
  final ReboundDetector _detector;
  final ReboundScoreProvider _provider;
  final ReboundParams _params;

  /// symbol → timeframe → 信号快照（用于跨周期共振评分）
  final Map<String, Map<String, ReboundSignal?>> _signalsBySymbol = {};

  /// 收盘 K 线事件订阅
  StreamSubscription<ClosedKline>? _closedKlineSub;

  /// watchlist churn 定时器（每小时刷新 exchangeInfo）
  Timer? _watchlistTimer;

  /// 当前已订阅的 symbols
  final Set<String> _subscribedSymbols = {};

  /// 已知的全部合约（从 exchangeInfo 获取）
  Set<String>? _knownSymbols;

  /// warm-up 中的标的（由 handleClosedKline 更新，传给 provider）
  final Set<String> _warmingSymbols = {};

  /// 04-03 动态精跟：当前精跟中的 symbol 列表（List 保留 FIFO 顺序供驱逐）。
  final List<String> _trackedSymbols = [];

  /// symbol → 连续未命中（detector 返回 null）计数，达 [missThreshold] 退出精跟。
  final Map<String, int> _missCountBySymbol = {};

  /// 04-03 扫描器引用（attachScanner 注入，可空）。
  ReboundMarketScanner? _scanner;

  /// 精跟集合硬上限（per B2，防 WS 连接膨胀）。
  static const int maxTracked = 30;

  /// 连续未命中阈值（per D3，达此值退出精跟）。
  static const int missThreshold = 3;

  /// Phase 5：通知节流器（五道闸门管线）。
  AlertThrottler? _throttler;

  /// Phase 5：通知分发服务（双渠道：high/med）。可注入便于测试。
  final ReboundNotificationService _notificationService;

  /// 通知历史仓库（sqflite）。可注入便于测试。
  final ReboundNotificationRepository _notificationRepository;

  /// Phase 5：用户提醒设置 Provider（可选，按需注入）。
  final AlertSettingsProvider? _alertSettings;

  ReboundAlertService({
    required ReboundKlineStreamService streamService,
    required ReboundDetector detector,
    required ReboundScoreProvider provider,
    ReboundParams? params,
    AlertSettingsProvider? alertSettings,
    ReboundNotificationService? notificationService,
    ReboundNotificationRepository? notificationRepository,
  })  : _streamService = streamService,
        _detector = detector,
        _provider = provider,
        _params = params ?? const ReboundParams(),
        _alertSettings = alertSettings,
        _notificationService = notificationService ?? ReboundNotificationService(),
        _notificationRepository =
            notificationRepository ?? ReboundNotificationRepository();

  /// 当前订阅的 symbol 列表。
  Set<String> get subscribedSymbols => Set.unmodifiable(_subscribedSymbols);

  /// 当前精跟中的 symbol 数量（per B3，供 Provider/UI 读取）。
  int get trackedCount => _trackedSymbols.length;

  /// 接入扫描器（per D4，scanner.onHits → trackSymbols）。
  void attachScanner(ReboundMarketScanner scanner) {
    _scanner = scanner;
    scanner.onHits = (hits) => trackSymbols(hits);
  }

  /// 把命中集合加入精跟（per D3/D7）。
  ///
  /// - 差集得到新精跟（避免重复订阅）
  /// - 超过 [maxTracked] 时按 FIFO 驱逐最早加入者
  /// - 通过 streamService.subscribe 增量订阅（含 warm-up）
  Future<void> trackSymbols(Set<String> hits) async {
    final newTracked =
        hits.difference(_trackedSymbols.toSet());
    if (newTracked.isNotEmpty) {
      _provider.addLog(
          '精跟 +${newTracked.length}（共 ${_trackedSymbols.length + newTracked.length}，上限 $maxTracked）');
    }
    for (final sym in newTracked) {
      // FIFO 驱逐
      while (_trackedSymbols.length >= maxTracked) {
        final evicted = _trackedSymbols.removeAt(0);
        await untrackSymbol(evicted);
      }
      _trackedSymbols.add(sym);
      _missCountBySymbol[sym] = 0;
      await _streamService.subscribe([sym]);
    }
  }

  /// 退出精跟：unsubscribe + 移除 provider 信号 + 清未命中计数（per D3）。
  Future<void> untrackSymbol(String symbol) async {
    _trackedSymbols.remove(symbol);
    _streamService.unsubscribe([symbol]);
    _provider.removeSymbol(symbol);
    _missCountBySymbol.remove(symbol);
  }

  /// 启动编排器：连接 WS + 订阅收盘事件 + 启动 watchlist churn。
  ///
  /// [symbols]：初始订阅的合约列表。
  /// [timeframes]：监控周期，默认 15m/1h/4h/1d。
  ///
  /// 04-03: 若已 attachScanner，传入 symbols 被忽略，改为空占位连接
  /// （精跟由 scanner 驱动），并启动 scanner timer。
  Future<void> start(
    List<String> symbols, {
    List<String> timeframes = monitoredTimeframes,
  }) async {
    final initialSymbols = _scanner != null ? const <String>[] : symbols;
    _subscribedSymbols.addAll(initialSymbols);

    if (_scanner != null) {
      // 标记空集合为 warm-up（实际由 scanner 命中后增量 warm-up）
    } else {
      _warmingSymbols.addAll(initialSymbols);
      _provider.updateWarmingUpSymbols(_warmingSymbols.toSet());
    }

    // 连接 WS（scanner 模式下用空占位，后续由 subscribe 增量订阅）
    await _streamService.connect(initialSymbols, timeframes);

    // Phase 5：构造节流器新实例 + 初始化通知渠道（幂等）
    _throttler = AlertThrottler();
    try {
      await _notificationService.initialize();
    } catch (_) {
      // 通知渠道初始化失败（如测试环境无 Flutter binding）不阻塞启动
      debugPrint('ReboundAlertService: notification init skipped (no Flutter binding?)');
    }

    // 订阅收盘事件（k.x==true，per D-03）
    _closedKlineSub = _streamService.closedKlines.listen(handleClosedKline);

    // 启动 watchlist churn（每小时刷新，per D-09）
    _watchlistTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _refreshWatchlist(),
    );

    // scanner 模式：启动扫描 timer
    _scanner?.start();
  }

  /// 停止编排器：断开 WS + 取消订阅 + 清空 provider。
  Future<void> stop() async {
    _closedKlineSub?.cancel();
    _closedKlineSub = null;
    _watchlistTimer?.cancel();
    _watchlistTimer = null;
    _scanner?.stop();
    _throttler?.reset();
    _throttler = null;
    _streamService.disconnect();
    _signalsBySymbol.clear();
    _warmingSymbols.clear();
    _trackedSymbols.clear();
    _missCountBySymbol.clear();
    _provider.clear();
  }

  /// 收盘 K 线回调（核心管线，per D-04）。
  /// 生产路径由 closedKlines stream listener 调用；测试直接调用。
  @visibleForTesting
  Future<void> handleClosedKline(ClosedKline c) async {
    // 1. warm-up 期间不触发（per D-06）
    if (_streamService.isWarmingUp(c.symbol, c.timeframe)) {
      // 更新 warm-up 状态到 provider
      if (!_warmingSymbols.contains(c.symbol)) {
        _warmingSymbols.add(c.symbol);
        _provider.updateWarmingUpSymbols(_warmingSymbols.toSet());
      }
      return;
    }

    // warm-up 完成后从集合中移除（检查该 symbol 所有 TF 是否都结束 warm-up）
    if (_warmingSymbols.contains(c.symbol)) {
      final stillWarming = monitoredTimeframes.any(
        (tf) => _streamService.isWarmingUp(c.symbol, tf),
      );
      if (!stillWarming) {
        _warmingSymbols.remove(c.symbol);
        _provider.updateWarmingUpSymbols(_warmingSymbols.toSet());
      }
    }

    // 2. 获取 rolling window
    final window = _streamService.windowOf(c.symbol, c.timeframe);
    if (window == null || window.isEmpty) return;

    // 3. 调用纯函数检测器（Phase 2，per D-01）
    final rawSignal = _detector.evaluate(
      List<KlineData>.from(window),
      _params,
      symbol: c.symbol,
      timeframe: c.timeframe,
    );
    // 标记反弹是否在最新一根确认（recoveryEndIndex == window 末根），用于收紧通知门槛。
    final signal = rawSignal == null
        ? null
        : rawSignal.copyWith(
            isLatestBar: rawSignal.recoveryEndIndex == window.length - 1);

    // 4. 更新 per-(symbol,TF) 信号快照
    _signalsBySymbol.putIfAbsent(c.symbol, () => {});
    _signalsBySymbol[c.symbol]![c.timeframe] = signal;

    // 5. 跨周期共振评分（per D-04 / SCORE-01 mtfConfluence）
    final mtfScore = ReboundConfluenceScorer.scoreMultiTimeframe(
      _signalsBySymbol[c.symbol] ?? {},
    );

    // 提取最近最多 20 根收盘价用于 sparkline 渲染
    final closes = window.length > 20
        ? window.sublist(window.length - 20).map((k) => k.close).toList()
        : window.map((k) => k.close).toList();

    // 6. 将 mtfScore 加到 signal.score（clamp 0-100）并更新 provider
    ReboundSignal? enriched;
    if (signal != null) {
      enriched = signal.copyWith(
        score: (signal.score + mtfScore).clamp(0, 100),
      );
      _provider.upsert(c.symbol, c.timeframe, enriched,
          recentCloses: closes);
      // 04-03: 命中 → 重置未命中计数（维持精跟）
      if (_trackedSymbols.contains(c.symbol)) {
        _missCountBySymbol[c.symbol] = 0;
      }
    } else {
      _provider.upsert(c.symbol, c.timeframe, null,
          recentCloses: closes);
      // 04-03: 连续未命中达 missThreshold → 退出精跟（per D3）
      if (_trackedSymbols.contains(c.symbol)) {
        final count = (_missCountBySymbol[c.symbol] ?? 0) + 1;
        _missCountBySymbol[c.symbol] = count;
        if (count >= missThreshold) {
          // fire-and-forget：handleClosedKline 为 sync void，不破坏 stream listener 签名
          untrackSymbol(c.symbol);
        }
      }
    }

    // 7. 通知管线——用 enriched（含 mtf 加分 + isLatestBar），仅最新一根 + high 才推送并记录历史。
    if (enriched != null) {
      await _dispatchIfHigh(enriched);
    }
  }

  /// 扫描命中立即通知入口（供 dashboard onScanComplete 调用）。
  ///
  /// 与 [handleClosedKline] 共享同一通知判定 [_dispatchIfHigh] → 共享
  /// [_throttler] 节流状态：同一 symbol 扫描命中通知后，4h 内 WS 收盘再判定
  /// 会被冷却拦截，避免扫描与收盘双重通知。
  Future<void> notifyOnSignal(ReboundSignal signal) async {
    await _dispatchIfHigh(signal);
  }

  /// 通知判定：经 [AlertThrottler] 五道闸门后，仅 high 级推送给 [_notificationService]。
  ///
  /// scanner（[notifyOnSignal]）与 WS 收盘（[handleClosedKline]）共享本方法 →
  /// 共享 [_throttler] 节流状态，同 symbol 4h 冷却内不重复通知。
  /// 仅当 [ReboundSignal.isLatestBar]（最新一根确认）且 high 级才推送，
  /// 避免通知数根前的旧反弹 + 中低分打扰；推送后写入通知历史。
  Future<void> _dispatchIfHigh(ReboundSignal signal) async {
    // 只通知最新一根确认的反弹（需求：最新蜡烛是反弹才通知）。
    if (!signal.isLatestBar) return;
    final toggles = _alertSettings?.timeframeToggles ??
        {for (final tf in monitoredTimeframes) tf: true};
    final highTh = _alertSettings?.highThreshold ?? 75;
    final medTh = _alertSettings?.medThreshold ?? 50;

    final decision = _throttler?.evaluate(
      signal,
      timeframeToggles: toggles,
      highThreshold: highTh,
      medThreshold: medTh,
    );

    if (decision != null && decision.level == AlertLevel.high) {
      await _notificationService.dispatch(decision);
      // 持久化 + 同步内存历史（用同一时间戳保持一致）
      final now = DateTime.now();
      await _notificationRepository.insert(signal, notifiedAt: now);
      _provider.addNotificationHistory(ReboundNotificationRecord(
        symbol: signal.symbol,
        timeframe: signal.timeframe,
        score: signal.score,
        deadCatRiskScore: signal.deadCatRiskScore,
        dropMagnitude: signal.dropMagnitude,
        recoveryRatio: signal.recoveryRatio,
        notifiedAt: now,
      ));
    }
  }

  /// watchlist churn：对比已知合约列表，移除下架、添加新上线（per D-09）。
  ///
  /// 注意：exchangeInfoService 由外部提供（main.dart 注入）。
  /// 此处提供符号列表更新接口，实际 exchangeInfo 调用在 main.dart 或上层。
  void updateSymbolList(Set<String> currentSymbols) {
    final newSymbols =
        currentSymbols.difference(_subscribedSymbols);
    final delisted =
        _subscribedSymbols.difference(currentSymbols);

    // 移除下架合约
    for (final sym in delisted) {
      _subscribedSymbols.remove(sym);
      _signalsBySymbol.remove(sym);
      _provider.removeSymbol(sym);
    }

    // 添加新上线合约（触发 warm-up）
    if (newSymbols.isNotEmpty) {
      _subscribedSymbols.addAll(newSymbols);
      // warm-up 由 ReboundKlineStreamService 内部处理
      for (final sym in newSymbols) {
        _streamService.warmUp(sym, monitoredTimeframes);
      }
    }

    _knownSymbols = currentSymbols;
  }

  /// watchlist churn 定时回调（内部，per D-09）。
  void _refreshWatchlist() {
    if (_knownSymbols != null) {
      // 使用上次已知的 symbol 列表（由 main.dart 的 exchangeInfoService 提供更新）
      // 实际更新由上层调用 updateSymbolList()
    }
  }
}
