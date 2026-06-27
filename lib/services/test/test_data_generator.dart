import 'dart:math';
import 'package:tomapp/models/kline_data.dart';

/// 扩展方法：四舍五入到 2 位小数。
extension DoubleRound on double {
  double roundTo2() => (this * 100).round() / 100;
}

/// 模拟数据生成模式枚举。
enum SimulationMode {
  vRebound,      // V 型反弹：急跌后快速回升
  deadCatBounce, // 死猫反弹：弱回补、低量、高死猫风险
  randomWalk,    // 随机游走：无明显趋势
  steadyDecline, // 持续下跌：无反弹
}

/// 随机 K 线数据生成器。
///
/// 使用真实的随机游走算法生成 OHLCV 数据，
/// 模拟真实市场的价格波动特征。
/// 支持 seed 参数保证可重现。
class TestDataGenerator {
  final SimulationMode mode;
  final double initialPrice;
  final int? _seed;
  late Random _random;
  late double _lastClose;
  int _step = 0;

  /// 波动率参数（可调整）
  final double volatility; // 基础波动率（默认 0.02 = 2%）
  final double trendStrength; // 趋势强度（默认 0.001）

  TestDataGenerator({
    required this.mode,
    this.initialPrice = 100.0,
    this.volatility = 0.02,
    this.trendStrength = 0.001,
    int? seed,
  }) : _seed = seed {
    _random = Random(_seed);
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

  /// 生成真实的随机 K 线数据。
  ///
  /// 使用几何布朗运动模型：
  /// - 价格变化服从正态分布
  /// - 包含随机波动率
  /// - 模拟真实市场的跳跃和趋势
  KlineData _generateRandomCandle(DateTime time, {double? trendBias, double volumeBoost = 1.0}) {
    final open = _lastClose;

    // 生成随机收益率（正态分布近似）
    final randomReturn = _gaussianRandom() * volatility;

    // 添加趋势偏移
    final trend = trendBias ?? (trendStrength * (_random.nextDouble() - 0.5));

    // 计算收盘价
    final close = (open * (1 + randomReturn + trend)).roundTo2();

    // 生成高低价（基于波动率）
    final range = (open * volatility * (_random.nextDouble() * 0.5 + 0.5)).roundTo2();
    final high = (max(open, close) + range * _random.nextDouble()).roundTo2();
    final low = (min(open, close) - range * _random.nextDouble()).roundTo2();

    // 生成成交量（对数正态分布 + 阶段性放量）
    // volumeBoost 用于在急跌/回拉段注入放量，使成交量共振过滤器可验证
    final baseVolume = 100.0;
    final volumeMultiplier = exp(_gaussianRandom() * 0.5) * volumeBoost;
    final volume = (baseVolume * volumeMultiplier).roundTo2();

    _lastClose = close;
    _step++;

    return KlineData(
      time: time,
      open: open.roundTo2(),
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  /// V 型反弹：30 根一个周期。
  ///
  /// 0-19 平稳 → 20-22 急跌（放量 2.5x）→ 23-24 快速回升（放量 1.8x）→ 25+ 新平稳
  KlineData _generateVRebound(DateTime time) {
    final phase = _step % 30;

    if (phase < 20) {
      // 平稳段：小幅随机波动
      return _generateRandomCandle(time, trendBias: 0.001);
    } else if (phase < 23) {
      // 急跌段：每根跌 3-5%，成交量放大 2.5 倍（恐慌抛售）
      return _generateRandomCandle(time, trendBias: -0.04, volumeBoost: 2.5);
    } else if (phase < 25) {
      // 快速回升：每根涨 4-6%，成交量放大 1.8 倍（抄底资金入场）
      return _generateRandomCandle(time, trendBias: 0.05, volumeBoost: 1.8);
    } else {
      // 新周期平稳
      return _generateRandomCandle(time, trendBias: 0.001);
    }
  }

  /// 死猫反弹：30 根一个周期。
  ///
  /// 0-19 平稳 → 20-22 急跌（放量 2.5x）→ 23-24 弱回补（缩量 0.6x）→ 25-29 继续下跌
  KlineData _generateDeadCatBounce(DateTime time) {
    final phase = _step % 30;

    if (phase < 20) {
      // 平稳段
      return _generateRandomCandle(time, trendBias: 0.001);
    } else if (phase < 23) {
      // 急跌段：成交量放大 2.5 倍（恐慌抛售）
      return _generateRandomCandle(time, trendBias: -0.04, volumeBoost: 2.5);
    } else if (phase < 25) {
      // 弱回补：每根涨 1-2%，缩量（无人抄底）
      return _generateRandomCandle(time, trendBias: 0.015, volumeBoost: 0.6);
    } else {
      // 继续下跌
      return _generateRandomCandle(time, trendBias: -0.02);
    }
  }

  /// 随机游走：无明显趋势。
  KlineData _generateRandomWalk(DateTime time) {
    return _generateRandomCandle(time);
  }

  /// 持续下跌：每根跌 1-2%。
  KlineData _generateSteadyDecline(DateTime time) {
    return _generateRandomCandle(time, trendBias: -0.015);
  }

  /// 生成服从标准正态分布的随机数（Box-Muller 变换）。
  double _gaussianRandom() {
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}
