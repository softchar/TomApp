import 'dart:math';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/macd_data.dart';

/// Bollinger Bands data
class BollingerBands {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;

  BollingerBands({
    required this.upper,
    required this.middle,
    required this.lower,
  });
}

/// Technical Indicators Calculator
class TechnicalIndicators {
  /// Calculate Simple Moving Average (MA)
  ///
  /// Returns a list of MA values with null for positions where there's insufficient data.
  /// [data] - List of KlineData points
  /// [period] - Number of periods to average (e.g., 5, 10, 20)
  List<double?> calculateMA(List<KlineData> data, int period) {
    final result = List<double?>.filled(data.length, null);

    for (int i = period - 1; i < data.length; i++) {
      double sum = 0;
      for (int j = 0; j < period; j++) {
        sum += data[i - j].close;
      }
      result[i] = sum / period;
    }

    return result;
  }

  /// Calculate Exponential Moving Average (EMA) - private method
  ///
  /// Uses SMA for the first EMA value, then applies the EMA formula.
  /// Formula: EMA = (current_price - previous_ema) × multiplier + previous_ema
  /// Multiplier = 2 / (period + 1)
  List<double?> _calculateEMA(List<KlineData> data, int period) {
    final result = List<double?>.filled(data.length, null);

    if (data.length < period) {
      return result;
    }

    // Calculate SMA for the first EMA value
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += data[i].close;
    }
    double ema = sum / period;
    result[period - 1] = ema;

    // Calculate multiplier
    final multiplier = 2.0 / (period + 1);

    // Calculate EMA for remaining values
    for (int i = period; i < data.length; i++) {
      ema = (data[i].close - ema) * multiplier + ema;
      result[i] = ema;
    }

    return result;
  }

  /// Calculate Bollinger Bands
  ///
  /// Returns a BollingerBands object with upper, middle, and lower bands.
  /// [data] - List of KlineData points
  /// [period] - Number of periods for MA (default: 20)
  /// [stdDev] - Number of standard deviations (default: 2.0)
  BollingerBands calculateBOLL(
    List<KlineData> data, {
    int period = 20,
    double stdDev = 2.0,
  }) {
    // Calculate middle band (SMA)
    final middle = calculateMA(data, period);

    // Calculate upper and lower bands
    final upper = List<double?>.filled(data.length, null);
    final lower = List<double?>.filled(data.length, null);

    for (int i = period - 1; i < data.length; i++) {
      // Calculate standard deviation
      double sum = 0;
      for (int j = 0; j < period; j++) {
        final diff = data[i - j].close - middle[i]!;
        sum += diff * diff;
      }
      final variance = sum / period;
      final standardDeviation = sqrt(variance);

      // Calculate bands
      upper[i] = middle[i]! + (stdDev * standardDeviation);
      lower[i] = middle[i]! - (stdDev * standardDeviation);
    }

    return BollingerBands(
      upper: upper,
      middle: middle,
      lower: lower,
    );
  }

  /// Calculate MACD indicator
  ///
  /// Returns MACDData with DIF, DEA, and MACD histogram values.
  /// Returns null if there's insufficient data.
  /// [data] - List of KlineData points
  /// [fastPeriod] - Fast EMA period (default: 12)
  /// [slowPeriod] - Slow EMA period (default: 26)
  /// [signalPeriod] - Signal line EMA period (default: 9)
  MACDData? calculateMACD(
    List<KlineData> data, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    // Need at least slowPeriod + signalPeriod data points
    if (data.length < slowPeriod + signalPeriod) {
      return null;
    }

    // Calculate fast and slow EMAs
    final fastEMA = _calculateEMA(data, fastPeriod);
    final slowEMA = _calculateEMA(data, slowPeriod);

    // Calculate DIF (fastEMA - slowEMA)
    final difValues = List<double?>.filled(data.length, null);
    for (int i = 0; i < data.length; i++) {
      if (fastEMA[i] != null && slowEMA[i] != null) {
        difValues[i] = fastEMA[i]! - slowEMA[i]!;
      }
    }

    // Create temporary KlineData objects for DIF values to calculate DEA
    final difKlineData = <KlineData>[];
    for (int i = 0; i < data.length; i++) {
      difKlineData.add(KlineData(
        time: data[i].time,
        open: difValues[i] ?? 0,
        high: difValues[i] ?? 0,
        low: difValues[i] ?? 0,
        close: difValues[i] ?? 0,
        volume: 0,
      ));
    }

    // Calculate DEA (EMA of DIF)
    final deaValues = _calculateEMA(difKlineData, signalPeriod);

    // Calculate MACD histogram: (DIF - DEA) × 2
    final macdValues = List<double?>.filled(data.length, null);
    for (int i = 0; i < data.length; i++) {
      if (difValues[i] != null && deaValues[i] != null) {
        macdValues[i] = (difValues[i]! - deaValues[i]!) * 2;
      }
    }

    return MACDData(
      dif: difValues,
      dea: deaValues,
      macd: macdValues,
      time: data.map((d) => d.time).toList(),
    );
  }

  // ─── Phase 1 新增：ATR / RSI / swing（纯函数实例方法，沿用 KlineData）────
  // 设计约束（per SUMMARY.md / PLAN 01 must_haves）：
  //  - 无状态实例方法（与既有 calculateMA/calculateBOLL/calculateMACD 风格一致，
  //    不引入新的 OHLC 类型、不混用类级与实例级方法）。
  //  - 纯函数：不依赖当前时钟、不含异步、不依赖状态管理框架、不做文件或网络 IO。
  //  - live 路径与 Phase 6 回测调用同一份代码（同源不变量）。

  /// 单根 True Range。首根无 prevClose 时取 high-low。
  double _trueRange(List<KlineData> klines, int i) {
    if (i == 0) return klines[0].high - klines[0].low;
    final prevClose = klines[i - 1].close;
    final hl = klines[i].high - klines[i].low;
    final hc = (klines[i].high - prevClose).abs();
    final lc = (klines[i].low - prevClose).abs();
    double m = hl;
    if (hc > m) m = hc;
    if (lc > m) m = lc;
    return m;
  }

  /// ATR(14) 单值（最新根）。长度 <= period 返回 null（warm-up）。
  /// Wilders/RMA 平滑，2×ATR 跌幅阈值与 0.3×ATR 止损阈值在 live/回测同源。
  double? atr(List<KlineData> klines, {int period = 14}) {
    final series = atrSeries(klines, period: period);
    if (series.isEmpty) return null;
    return series.last;
  }

  /// ATR(14) 序列：前 period 个为 null（warm-up），其后 Wilders 平滑。
  /// 供回测逐根取值，与 [atr] 同源。种子 = 头 period 根 TR 简单平均。
  List<double?> atrSeries(List<KlineData> klines, {int period = 14}) {
    final n = klines.length;
    final res = List<double?>.filled(n, null);
    if (n <= period) return res; // 需 period+1 根才有首个 ATR（warm-up，per D-06）
    // 种子：TR[1..period] 的简单平均（Wilder 标准：TR 从索引 1 开始，
    // TR[0] 无 prevClose、退化为 high-low，不计入种子）。
    // 修正：原实现用 TR[0..period-1] 且循环用 TR[i-1]，整体滞后一根（off-by-one）。
    double seed = 0;
    for (int i = 1; i <= period; i++) {
      seed += _trueRange(klines, i);
    }
    double a = seed / period;
    res[period] = a;
    // Wilders 平滑：atr[i] = (atr[i-1]*(period-1) + tr[i]) / period
    for (int i = period + 1; i < n; i++) {
      final tr = _trueRange(klines, i);
      a = (a * (period - 1) + tr) / period;
      res[i] = a;
    }
    return res;
  }

  /// 由平均 gain/loss 计算 RSI（avgLoss==0 → 100）。
  double _rsiFromAvg(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - 100.0 / (1.0 + rs);
  }

  /// RSI(14) 序列（供拐头判定）；前 period 个为 null。Wilders 平滑。
  List<double?> _rsiSeries(List<KlineData> klines, {int period = 14}) {
    final n = klines.length;
    final res = List<double?>.filled(n, null);
    if (n <= period) return res; // 需 period 个 delta（≥ period+1 根）
    double avgGain = 0;
    double avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final ch = klines[i].close - klines[i - 1].close;
      if (ch >= 0) {
        avgGain += ch;
      } else {
        avgLoss -= ch;
      }
    }
    avgGain /= period;
    avgLoss /= period;
    res[period] = _rsiFromAvg(avgGain, avgLoss);
    for (int i = period + 1; i < n; i++) {
      final ch = klines[i].close - klines[i - 1].close;
      final gain = ch > 0 ? ch : 0.0;
      final loss = ch < 0 ? -ch : 0.0;
      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;
      res[i] = _rsiFromAvg(avgGain, avgLoss);
    }
    return res;
  }

  /// RSI(14) 单值（最新根）；长度 <= period 返回 null。
  double? rsi(List<KlineData> klines, {int period = 14}) {
    final series = _rsiSeries(klines, period: period);
    for (int i = series.length - 1; i >= 0; i--) {
      if (series[i] != null) return series[i];
    }
    return null;
  }

  /// 超卖拐头判定：前一根 RSI < [oversold] 且 当前根 RSI > 前一根。
  /// 长度不足时返回 (rsi: null, oversoldTurningUp: false)。
  ({double? rsi, bool oversoldTurningUp}) rsiTurningUp(
    List<KlineData> klines, {
    int period = 14,
    double oversold = 30,
  }) {
    final series = _rsiSeries(klines, period: period);
    double? prev;
    double? curr;
    for (int i = series.length - 1; i >= 0; i--) {
      if (series[i] != null) {
        if (curr == null) {
          curr = series[i];
        } else if (prev == null) {
          prev = series[i];
          break;
        }
      }
    }
    if (prev == null || curr == null) {
      return (rsi: curr, oversoldTurningUp: false);
    }
    final turning = (prev < oversold) && (curr > prev);
    return (rsi: curr, oversoldTurningUp: turning);
  }

  /// 最近 swing high 索引：high 严格大于左右各 [lookback] 根。找不到返回 null。
  int? swingHigh(List<KlineData> klines, {int lookback = 2}) {
    final n = klines.length;
    for (int i = n - 1 - lookback; i >= lookback; i--) {
      final h = klines[i].high;
      bool isSwing = true;
      for (int j = 1; j <= lookback; j++) {
        if (!(h > klines[i - j].high) || !(h > klines[i + j].high)) {
          isSwing = false;
          break;
        }
      }
      if (isSwing) return i;
    }
    return null;
  }

  /// 最近 swing low 索引：low 严格小于左右各 [lookback] 根。找不到返回 null。
  int? swingLow(List<KlineData> klines, {int lookback = 2}) {
    final n = klines.length;
    for (int i = n - 1 - lookback; i >= lookback; i--) {
      final l = klines[i].low;
      bool isSwing = true;
      for (int j = 1; j <= lookback; j++) {
        if (!(l < klines[i - j].low) || !(l < klines[i + j].low)) {
          isSwing = false;
          break;
        }
      }
      if (isSwing) return i;
    }
    return null;
  }
}
