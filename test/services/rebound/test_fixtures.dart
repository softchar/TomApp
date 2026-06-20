import 'dart:math';

import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/funding_rate.dart';

/// 共享测试辅助函数，供 Phase 6 回测引擎、数据导入管线、FundingRateService 的单元测试使用。

/// 生成合成 K 线序列，价格从 [startPrice] 开始做随机游走。
///
/// 时间从 2025-01-01 00:00 起递增 15 分钟，共 [count] 根。
/// [volatility] 控制单根 K 线的波动幅度（默认 1.0 = ±1% 级别）。
/// 返回的 K 线序列中 open/high/low/close 均为正数且 high >= low。
List<KlineData> syntheticKlines(
  int count, {
  double startPrice = 100.0,
  double volatility = 1.0,
}) {
  final random = Random(42); // 固定种子保证可复现
  final klines = <KlineData>[];
  final baseTime = DateTime(2025, 1, 1);
  var price = startPrice;

  for (int i = 0; i < count; i++) {
    final open = price;
    // 随机游走：每一步变化服从 N(0, volatility) 近似
    final change = (random.nextDouble() - 0.5) * 2.0 * volatility;
    final close = open + change;
    final high = max(open, close) + random.nextDouble() * volatility * 0.5;
    final low = min(open, close) - random.nextDouble() * volatility * 0.5;
    final volume = 50.0 + random.nextDouble() * 200.0;

    klines.add(KlineData(
      time: baseTime.add(Duration(minutes: 15 * i)),
      open: open,
      high: high,
      low: max(low, 0.01), // 确保不为负
      close: close,
      volume: volume,
    ));

    price = close;
  }

  return klines;
}

/// 生成 V 型走势 fixture：先下跌约 30% 再回补约 80% 的跌幅。
///
/// 共 60 根 K 线（约 15 小时 15m 数据）：
/// - 前 25 根：缓慢下跌（累计约 −30%）
/// - 第 26-30 根：加速下跌（触及最低点）
/// - 第 31-60 根：快速反弹（回补跌幅的 80%）
///
/// 供回测引擎单测验证反弹信号检测逻辑。
List<KlineData> vShapedRecovery() {
  final klines = <KlineData>[];
  final baseTime = DateTime(2025, 3, 15, 0, 0);
  const startPrice = 100.0;
  const totalBars = 60;
  const dropBars = 30; // 前 30 根完成下跌
  const dropTarget = 0.70; // 跌至起始价的 70%（跌 30%）
  const recoveryTarget = 0.94; // 回补至起始价的 94%（回补跌幅的 80%）

  for (int i = 0; i < totalBars; i++) {
    double close;
    if (i < dropBars) {
      // 下跌段：从 100 线性跌至 70
      final progress = i / (dropBars - 1);
      close = startPrice * (1.0 - (1.0 - dropTarget) * progress);
    } else {
      // 反弹段：从 70 反弹至 94
      final progress = (i - dropBars) / (totalBars - 1 - dropBars);
      close = startPrice * (dropTarget + (recoveryTarget - dropTarget) * progress);
    }

    final open = i == 0 ? startPrice : klines[i - 1].close;
    final high = max(open, close) * 1.005;
    final low = min(open, close) * 0.995;
    final volume = 100.0 + (i >= dropBars ? 200.0 : 50.0); // 反弹段放量

    klines.add(KlineData(
      time: baseTime.add(Duration(minutes: 15 * i)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    ));
  }

  return klines;
}

/// 生成 V 型走势 fixture（快速版）：3 根急跌 + 2 根急弹，配合默认 ReboundParams。
///
/// 共 40 根 K 线（10 小时 15m 数据）：
/// - 前 20 根：平稳波动（warm-up，价格在 ~100 附近小幅浮动）
/// - 第 21-23 根：急跌（~99 → 85 → 75，跌约 25%，间隔大以确保 swing 检测）
/// - 第 24-25 根：急弹（75 → 83 → 96，回补高比例）
/// - 第 26-40 根：继续上涨（巩固反弹形态，确保 close > midpoint）
///
/// 设计考虑：下跌和反弹段中每根 bar 的 low 明确递增以使 swingLow 检测能
/// 找到 bar 23 为最低点。反弹 bar 的 low 比最低点 bar 的 low 高 3+ 单位，
/// 以确保 swingLow(lookback=2) 能检出最低点。
List<KlineData> vShapedQuickRecovery() {
  final klines = <KlineData>[];
  final baseTime = DateTime(2025, 3, 15, 0, 0);
  final random = Random(42);

  // 前 20 根：平稳波动（warm-up，窄幅震荡确保 ATR 小）
  var price = 100.0;
  for (int i = 0; i < 20; i++) {
    final open = price;
    final change = (random.nextDouble() - 0.5) * 0.5; // 微小波动 ±0.5
    final close = open + change;
    final high = open > close ? open + 0.3 : close + 0.3;
    final low = open < close ? open - 0.3 : close - 0.3;
    klines.add(KlineData(
      time: baseTime.add(Duration(minutes: 15 * i)),
      open: open,
      high: high,
      low: low > 0 ? low : 0.01,
      close: close,
      volume: 80.0 + random.nextDouble() * 40.0,
    ));
    price = close;
  }

  // 第 20-22 根：急跌（3 根内从 ~100 跌到 75，low 逐根降低）
  // bar 20: high swing, close lower
  final prev0 = klines[19];
  klines.add(KlineData(
    time: baseTime.add(Duration(minutes: 15 * 20)),
    open: prev0.close,
    high: prev0.close + 1.5, // 高点（将作为 swingHigh）
    low: 95.0,
    close: 96.0,
    volume: 150.0,
  ));
  // bar 21: lower
  klines.add(KlineData(
    time: baseTime.add(Duration(minutes: 15 * 21)),
    open: 96.0,
    high: 96.5,
    low: 83.0,
    close: 85.0,
    volume: 180.0,
  ));
  // bar 22: lowest (V bottom) — low 为整个窗口最低
  klines.add(KlineData(
    time: baseTime.add(Duration(minutes: 15 * 22)),
    open: 85.0,
    high: 86.0,
    low: 74.0, // 全 window 最低点
    close: 75.0,
    volume: 200.0,
  ));

  // 第 23-24 根：急弹（2 根内从 75 回补到 96，low 逐根提高）
  // bar 23: 快速反弹，low 比最低点高 3+ 单位，确保 swingLow 识别最低点
  klines.add(KlineData(
    time: baseTime.add(Duration(minutes: 15 * 23)),
    open: 75.0,
    high: 85.0,
    low: 77.0, // 比 bar 22 的 low(74) 高 3，确保不为 swingLow
    close: 83.0,
    volume: 250.0,
  ));
  // bar 24: 继续反弹，close 远高于 midpoint
  klines.add(KlineData(
    time: baseTime.add(Duration(minutes: 15 * 24)),
    open: 83.0,
    high: 97.0,
    low: 81.0,
    close: 96.0, // > midpoint ≈ (100+74)/2 = 87
    volume: 300.0,
  ));

  // 第 25-39 根：继续上涨（巩固反弹形态，确保后续 K 线 close 高于 midpoint）
  price = 96.0;
  for (int i = 25; i < 40; i++) {
    price += 0.3 + random.nextDouble() * 0.5;
    final open = klines[i - 1].close;
    final close = price;
    final high = close + 0.3;
    final low = open < close ? open - 0.2 : close - 0.3;
    klines.add(KlineData(
      time: baseTime.add(Duration(minutes: 15 * i)),
      open: open,
      high: high,
      low: low > 0 ? low : 0.01,
      close: close,
      volume: 100.0 + random.nextDouble() * 50.0,
    ));
  }

  return klines;
}

/// 生成模拟资金费率数据，用于 FundingRateService 单元测试。
///
/// 从 [baseTime] 开始每 8 小时一条，共 [count] 条。
/// 费率随机分布在 −0.05% 到 +0.05% 之间。
List<FundingRate> mockFundingRates(String symbol, int count) {
  final random = Random(123); // 固定种子
  final rates = <FundingRate>[];
  final baseTime = DateTime(2025, 1, 1);

  for (int i = 0; i < count; i++) {
    final ratePercent = (random.nextDouble() - 0.5) * 0.001; // −0.05% ~ +0.05%
    final fundingTime = baseTime.add(Duration(hours: 8 * i));

    rates.add(FundingRate(
      symbol: symbol,
      fundingRate: ratePercent,
      markPrice: 50000.0,
      indexPrice: 50000,
      estimatedSettleTime: fundingTime.millisecondsSinceEpoch.toDouble(),
      fundingTime: fundingTime.millisecondsSinceEpoch,
    ));
  }

  return rates;
}
