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
