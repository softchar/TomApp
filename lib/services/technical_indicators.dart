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
}
