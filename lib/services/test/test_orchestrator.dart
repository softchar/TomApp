import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';

/// 测试编排器：每 2 秒生成一根 K 线，送入 ReboundDetector 检测。
///
/// 管理状态：滚动窗口（最近 50 根）、信号历史（最多 20 条）、
/// 运行状态（运行中/暂停）。
class TestOrchestrator extends ChangeNotifier {
  TestDataGenerator _generator;
  final ReboundDetector _detector;
  ReboundParams _params;

  Timer? _timer;
  final List<KlineData> _window = [];
  final List<ReboundSignal> _signals = [];
  bool _isRunning = false;
  DateTime? _startTime;
  int _tickCount = 0;

  static const int windowSize = 200; // 增加到 200 根，查看更多历史数据
  static const int maxSignals = 20;
  static const Duration interval = Duration(seconds: 2);
  /// 只保留反弹结束位置在最近 N 根内的信号（与 ReboundMarketScanner.recentBars 一致）。
  static const int recentBars = 6;

  TestOrchestrator({
    required TestDataGenerator generator,
    required ReboundDetector detector,
    ReboundParams params = const ReboundParams(),
  })  : _generator = generator,
        _detector = detector,
        _params = params;

  /// 当前 K 线窗口（只读）。
  List<KlineData> get window => List.unmodifiable(_window);

  /// 当前信号列表（只读）。
  List<ReboundSignal> get signals => List.unmodifiable(_signals);

  /// 是否正在运行。
  bool get isRunning => _isRunning;

  /// 启动定时器，每 2 秒生成一根 K 线并检测。
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _startTime = DateTime.now();
    _timer = Timer.periodic(interval, (_) => tick());
    notifyListeners();
  }

  /// 暂停定时器。
  void pause() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  /// 重置窗口和信号。
  void reset() {
    _window.clear();
    _signals.clear();
    _tickCount = 0;
    _generator.reset();
    notifyListeners();
  }

  /// 切换数据生成模式。
  void changeMode(SimulationMode mode) {
    pause();
    // 创建新的生成器，保留 seed
    _generator = TestDataGenerator(mode: mode, seed: _generator.seed);
    _window.clear();
    _signals.clear();
    _tickCount = 0;
    notifyListeners();
  }

  /// 更新检测参数。
  void changeParams(ReboundParams params) {
    _params = params;
    notifyListeners();
  }

  /// 定时器回调：生成 K 线 → 检测 → 收集信号。
  ///
  /// 抽离为可测方法：单测可同步驱动 [tick] 而无需等待真实 2s Timer
  /// （与 ReboundAlertService.handleClosedKline 的 @visibleForTesting 同思路）。
  @visibleForTesting
  void tick() {
    // 计算模拟时间（每 2 秒一根）
    final currentTime =
        _startTime!.add(Duration(seconds: _tickCount * 2));
    final candle = _generator.nextCandle(currentTime);

    // 追加到窗口
    _window.add(candle);
    if (_window.length > windowSize) {
      _window.removeAt(0);
    }

    // 检测（warm-up 需满足检测器最小长度：atrPeriod + dropMaxCandles + recoveryMaxCandles + swingLookback + 2）
    final minLen = _params.atrPeriod + _params.dropMaxCandles +
        _params.recoveryMaxCandles + _params.swingLookback + 2;
    if (_window.length >= minLen) {
      final signal = _detector.evaluate(
        _window,
        _params,
        symbol: 'TESTUSDT',
        timeframe: '15m',
      );

      // 命中判定完全由 detector 三阶段门槛决定（移除 score>=60，向监控页对齐）。
      // recentBars 过滤：只保留最近 N 根内结束的反弹（与 ReboundMarketScanner 一致），
      // 短窗口（< recentBars）降级为不接受，避免放行历史反弹（per 04-REVIEW WR-02）。
      if (signal != null) {
        final threshold = _window.length >= recentBars
            ? _window.length - recentBars
            : _window.length;
        if (signal.recoveryEndIndex >= threshold) {
          _signals.insert(0, signal);
          if (_signals.length > maxSignals) {
            _signals.removeLast();
          }
        }
      }
    }

    _tickCount++;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
