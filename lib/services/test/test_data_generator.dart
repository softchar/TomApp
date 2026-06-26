import 'dart:math';
import 'package:tomapp/models/kline_data.dart';

/// 模拟数据生成模式枚举。
enum SimulationMode {
  vRebound,      // V 型反弹：急跌后快速回升
  deadCatBounce, // 死猫反弹：弱回补、低量、高死猫风险
  randomWalk,    // 随机游走：无明显趋势
  steadyDecline, // 持续下跌：无反弹
}

/// 模拟 K 线数据生成器。
///
/// 每次调用 [nextCandle] 返回一根新的模拟 K 线，
/// 根据 [SimulationMode] 生成不同模式的价格序列。
/// 支持 seed 参数保证可重现。
class TestDataGenerator {
  final SimulationMode mode;
  final double initialPrice;
  final int? _seed;
  late Random _random;
  late double _lastClose;
  int _step = 0;

  TestDataGenerator({
    required this.mode,
    this.initialPrice = 100.0,
    int? seed,
  }) : _seed = seed {
    _random = Random(seed);
    _lastClose = initialPrice;
  }

  /// 当前步数（只读）。
  int get step => _step;

  /// 构造时传入的 seed（只读）。
  int? get seed => _seed;

  /// 生成下一根 K 线数据。
  KlineData nextCandle(DateTime time) {
    switch (mode) {
      case SimulationMode.vRebound:
        return _generateVRebound(time);
      case SimulationMode.deadCatBounce:
        return _generateDeadCatBounce(time);
      case SimulationMode.randomWalk:
        return _generateRandomWalk(time);
      case SimulationMode.steadyDecline:
        return _generateSteadyDecline(time);
    }
  }

  /// 重置生成器状态到初始值。
  void reset() {
    _random = Random(_seed);
    _lastClose = initialPrice;
    _step = 0;
  }

  // V 型反弹：30 根一个周期
  // 0-19 平稳 → 20-22 急跌（每根跌 3-4%）→ 23-24 快速回升（每根涨 4-5%，volume 放大）→ 25+ 新平稳
  KlineData _generateVRebound(DateTime time) {
    final phase = _step % 30;
    final open = _lastClose;
    double close;
    double high;
    double low;
    double volume;

    if (phase < 20) {
      // 平稳段
      close = open + (_random.nextDouble() - 0.5) * 1.0;
      high = max(open, close) + _random.nextDouble() * 0.5;
      low = min(open, close) - _random.nextDouble() * 0.5;
      volume = 10 + _random.nextDouble() * 5;
    } else if (phase < 23) {
      // 急跌段：每根跌 3-4%
      close = open * (0.96 - _random.nextDouble() * 0.01);
      high = open;
      low = close - _random.nextDouble() * 0.5;
      volume = 10 + _random.nextDouble() * 5;
    } else if (phase < 25) {
      // 快速回升：每根涨 4-5%，volume 放大
      close = open * (1.04 + _random.nextDouble() * 0.01);
      high = close + _random.nextDouble() * 0.5;
      low = open - _random.nextDouble() * 0.5;
      volume = 20 + _random.nextDouble() * 10;
    } else {
      // 新周期平稳
      close = open + (_random.nextDouble() - 0.5) * 1.0;
      high = max(open, close) + _random.nextDouble() * 0.5;
      low = min(open, close) - _random.nextDouble() * 0.5;
      volume = 10 + _random.nextDouble() * 5;
    }

    _lastClose = close;
    _step++;

    return KlineData(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  // 死猫反弹：30 根一个周期
  // 0-19 平稳 → 20-22 急跌 → 23-24 弱回补（每根涨 1-2%，volume 缩半）→ 25-29 继续下跌
  KlineData _generateDeadCatBounce(DateTime time) {
    final phase = _step % 30;
    final open = _lastClose;
    double close;
    double high;
    double low;
    double volume;

    if (phase < 20) {
      // 平稳段
      close = open + (_random.nextDouble() - 0.5) * 1.0;
      high = max(open, close) + _random.nextDouble() * 0.5;
      low = min(open, close) - _random.nextDouble() * 0.5;
      volume = 10 + _random.nextDouble() * 5;
    } else if (phase < 23) {
      // 急跌段：每根跌 3-4%（同 vRebound）
      close = open * (0.96 - _random.nextDouble() * 0.01);
      high = open;
      low = close - _random.nextDouble() * 0.5;
      volume = 10 + _random.nextDouble() * 5;
    } else if (phase < 25) {
      // 弱回补：每根涨 1-2%，volume 缩半
      close = open * (1.01 + _random.nextDouble() * 0.01);
      high = close + _random.nextDouble() * 0.3;
      low = open - _random.nextDouble() * 0.3;
      volume = 5 + _random.nextDouble() * 3;
    } else {
      // 继续下跌
      close = open * (0.97 - _random.nextDouble() * 0.01);
      high = open;
      low = close - _random.nextDouble() * 0.5;
      volume = 10 + _random.nextDouble() * 5;
    }

    _lastClose = close;
    _step++;

    return KlineData(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  // 随机游走：每根 close = lastClose * (1 + (random - 0.5) * 0.02)
  KlineData _generateRandomWalk(DateTime time) {
    final open = _lastClose;
    final close = open * (1 + (_random.nextDouble() - 0.5) * 0.02);
    final high = max(open, close) + _random.nextDouble() * 0.5;
    final low = min(open, close) - _random.nextDouble() * 0.5;
    final volume = 10 + _random.nextDouble() * 5;

    _lastClose = close;
    _step++;

    return KlineData(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  // 持续下跌：每根 close = lastClose * (0.98 - random * 0.01)
  KlineData _generateSteadyDecline(DateTime time) {
    final open = _lastClose;
    final close = open * (0.98 - _random.nextDouble() * 0.01);
    final high = open;
    final low = close - _random.nextDouble() * 0.5;
    final volume = 10 + _random.nextDouble() * 5;

    _lastClose = close;
    _step++;

    return KlineData(
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }
}
