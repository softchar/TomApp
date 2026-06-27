import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/technical_indicators.dart';

/// 反弹信号检测器（纯函数，零 I/O）。
///
/// 三阶段管线：下跌段 → 拉回段 → 共振过滤，输出 ReboundSignal?。
/// live 路径（Phase 3）与回测路径（Phase 6）调用同一份 evaluate 代码。
/// 实例无状态，所有中间变量为局部变量，不依赖当前时钟/异步/状态管理框架/文件或网络 IO。
class ReboundDetector {
  /// 技术指标实例（Phase 1 提供的无状态实例方法：atr/rsiTurningUp/swingLow 等）
  final TechnicalIndicators _ti;

  ReboundDetector(this._ti);

  /// 检测窗口内是否存在反弹信号。
  ///
  /// [window]：滑动窗口（≥50 根，由 Phase 3 编排器维护 rolling buffer）。
  /// [params]：全部可调阈值（业务先验起步值，Phase 6 校准）。
  /// [symbol]/[timeframe]：由调用方传入（KlineData 不携带交易对/周期信息）。
  ///
  /// 返回 null 表示窗口内无有效反弹信号（warm-up/无下跌/无回补/不满足阈值）。
  /// 纯函数：同一输入 live 与回测调用结果完全一致（per DETECT-04 / D-01）。
  ReboundSignal? evaluate(
    List<KlineData> window,
    ReboundParams params, {
    required String symbol,
    required String timeframe,
  }) {
    // ─── warm-up 抵御 ─────────────────────────────────────
    final minLen = params.atrPeriod + params.dropMaxCandles +
        params.recoveryMaxCandles + params.swingLookback + 2;
    if (window.length < minLen) return null;

    // ─── Stage 1：下跌段检测（DETECT-01）──────────────────
    final drop = _detectDropLeg(window, params, timeframe);
    if (drop == null) return null;
    final (startIdx, lowIdx, dropMagnitude, atr) = drop;

    // ─── Stage 2：拉回段检测（DETECT-02）──────────────────
    final recov = _detectRecoveryLeg(window, params, startIdx, lowIdx);
    if (recov == null) return null;
    final (recoveryEndIdx, recoveryRatio, speed) = recov;

    // ─── Stage 3：共振过滤（DETECT-03）────────────────────
    final (confluenceFilters, volumeRatio) =
        _checkConfluence(window, params, startIdx, lowIdx, recoveryEndIdx);

    // ─── 评分（SCORE-01）──────────────────────────────────
    final score = _calculateScore(recoveryRatio, speed, volumeRatio,
        confluenceFilters.length, params);

    // ─── 死猫风险分（SCORE-02）────────────────────────────
    final rsiVal = _ti.rsi(window.sublist(0, recoveryEndIdx + 1),
        period: params.rsiPeriod);
    final deadCatRisk = _calculateDeadCatRisk(
        volumeRatio, rsiVal, recoveryRatio, confluenceFilters.length);

    // ─── 构造输出（timestamp 从 window 最后一根取，不用系统时钟）──
    return ReboundSignal(
      symbol: symbol,
      timeframe: timeframe,
      dropMagnitude: dropMagnitude,
      recoveryRatio: recoveryRatio,
      speed: speed,
      confluenceFilters: confluenceFilters,
      score: score,
      deadCatRiskScore: deadCatRisk,
      entryPrice: window[recoveryEndIdx].close,
      swingLowPrice: window[lowIdx].low,
      swingHighPrice: window[startIdx].high,
      dropStartIndex: startIdx,
      dropEndIndex: lowIdx,
      recoveryEndIndex: recoveryEndIdx,
      timestamp: window[recoveryEndIdx].time,
    );
  }

  // ─── Stage 1：下跌段 ────────────────────────────────────
  /// 返回 (startIdx, lowIdx, dropMagnitude, atr) 或 null。
  (int, int, double, double)? _detectDropLeg(
    List<KlineData> window,
    ReboundParams params,
    String timeframe,
  ) {
    // 用 Phase 1 的 swingLow 找最近局部低点
    int? lowIdx = _ti.swingLow(window, lookback: params.swingLookback);

    // fallback：swingLow 在急跌后回升时可能找不到（严格不等式条件要求
    // low < 左右各 lookback 根，但回升阶段后面的 K 线 low 会逐步抬高）。
    // 改用更宽的搜索窗口找最低 low，并验证它确实是下跌终点（前面有更高 high）。
    if (lowIdx == null) {
      final searchWindow = params.dropMaxCandles + params.recoveryMaxCandles + 1;
      final start = (window.length - searchWindow).clamp(0, window.length);
      if (start >= window.length) return null;
      double minLow = double.infinity;
      int minIdx = -1;
      for (int i = start; i < window.length; i++) {
        if (window[i].low < minLow) {
          minLow = window[i].low;
          minIdx = i;
        }
      }
      // 验证最低点前面有更高 high（确认是下跌终点，不是平稳段噪声）
      if (minIdx > 0) {
        final searchStart = (minIdx - params.dropMaxCandles).clamp(0, minIdx);
        double highestBefore = window[searchStart].high;
        for (int i = searchStart + 1; i < minIdx; i++) {
          if (window[i].high > highestBefore) highestBefore = window[i].high;
        }
        if (highestBefore > window[minIdx].low) {
          lowIdx = minIdx;
        }
      }
    }

    if (lowIdx == null || lowIdx < params.atrPeriod) return null;

    // 从 lowIdx 向前找对应 swing high（下跌起始点）
    // 取 lowIdx 之前 dropMaxCandles 范围内的最高 high
    final searchStart = (lowIdx - params.dropMaxCandles).clamp(0, lowIdx);
    int startIdx = searchStart;
    double highestHigh = window[searchStart].high;
    for (int i = searchStart + 1; i < lowIdx; i++) {
      if (window[i].high > highestHigh) {
        highestHigh = window[i].high;
        startIdx = i;
      }
    }
    // 确保 startIdx 在 lowIdx 之前（下跌从高点到低点）
    if (startIdx >= lowIdx) return null;

    // 下跌幅度
    final drop = highestHigh - window[lowIdx].low;
    if (drop <= 0) return null;

    // ATR 归一化跌幅（per D-02）
    final atr = _ti.atr(window.sublist(0, lowIdx + 1),
        period: params.atrPeriod);
    if (atr == null || atr <= 0) return null;
    final dropMagnitude = drop / atr;

    // 验证跌幅 ≥ ATR 倍数阈值
    if (dropMagnitude < params.dropAtrMultiplier) return null;

    // 验证跌幅发生在 ≤ dropMaxCandles 根 K 线内
    if (lowIdx - startIdx > params.dropMaxCandles) return null;

    // 验证跌幅 ≥ 对应周期的 % 兜底阈值（per DETECT-01）
    final dropPct = drop / highestHigh * 100;
    if (dropPct < params.dropMinPctForTimeframe(timeframe)) return null;

    return (startIdx, lowIdx, dropMagnitude, atr);
  }

  // ─── Stage 2：拉回段 ────────────────────────────────────
  /// 返回 (recoveryEndIdx, recoveryRatio, speed) 或 null。
  (int, double, int)? _detectRecoveryLeg(
    List<KlineData> window,
    ReboundParams params,
    int startIdx,
    int lowIdx,
  ) {
    final dropRange = window[startIdx].high - window[lowIdx].low;
    if (dropRange <= 0) return null;

    // 从 lowIdx 之后扫描回补
    // 只保留 recoveryRatio >= recoveryMinRatio 条件，
    // 移除 midpoint 绝对价格条件（过于严格，噪声导致大量漏检）。
    final scanEnd =
        (lowIdx + params.recoveryMaxCandles + 1).clamp(0, window.length);
    for (int i = lowIdx + 1; i < scanEnd; i++) {
      final recoveryRatio = (window[i].close - window[lowIdx].low) / dropRange;
      if (recoveryRatio >= params.recoveryMinRatio) {
        return (i, recoveryRatio, i - lowIdx);
      }
    }
    return null;
  }

  // ─── Stage 3：共振过滤 ──────────────────────────────────
  /// 返回 (confluenceFilters, volumeRatio)。
  (Set<ConfluenceType>, double) _checkConfluence(
    List<KlineData> window,
    ReboundParams params,
    int startIdx,
    int lowIdx,
    int recoveryEndIdx,
  ) {
    final filters = <ConfluenceType>{};
    double volumeRatio = 0;

    // 段均量计算
    final dropCandles = window.sublist(startIdx, lowIdx + 1);
    final recoveryCandles = window.sublist(lowIdx + 1, recoveryEndIdx + 1);
    final avgDropVol =
        dropCandles.fold<double>(0, (s, k) => s + k.volume) / dropCandles.length;
    if (recoveryCandles.isNotEmpty && avgDropVol > 0) {
      final avgRecoveryVol = recoveryCandles.fold<double>(
              0, (s, k) => s + k.volume) /
          recoveryCandles.length;
      volumeRatio = avgRecoveryVol / avgDropVol;
    }

    // RSI 超卖拐头（per DETECT-03）
    // 使用双周期判定：快速 RSI 对急跌更敏感，标准 RSI 捕捉中期趋势。
    // 任一满足即可触发共振，解决标准 RSI 在短期急跌中反应迟钝的问题。
    if (params.confluenceRsiOversoldTurning) {
      final rsiWindow = window.sublist(0, recoveryEndIdx + 1);
      final fastRsiResult = _ti.rsiTurningUp(rsiWindow,
          period: params.fastRsiPeriod, oversold: params.rsiOversold);
      final stdRsiResult = _ti.rsiTurningUp(rsiWindow,
          period: params.rsiPeriod, oversold: params.rsiOversold);
      if (fastRsiResult.oversoldTurningUp || stdRsiResult.oversoldTurningUp) {
        filters.add(ConfluenceType.rsiOversoldTurning);
      }
    }

    // 放量确认（per DETECT-03）
    if (params.confluenceVolumeConfirm) {
      if (volumeRatio >= params.volumeMultiplier) {
        filters.add(ConfluenceType.volumeConfirmation);
      }
    }

    // 支撑位（per DETECT-03）：swing low 附近（±2%）有前期支撑
    if (params.confluenceSupportLevel) {
      final priorLow =
          _ti.swingLow(window.sublist(0, startIdx), lookback: params.swingLookback);
      if (priorLow != null) {
        final priorLowPrice = window[priorLow].low;
        final currentLowPrice = window[lowIdx].low;
        if (currentLowPrice > 0 &&
            (currentLowPrice - priorLowPrice).abs() / currentLowPrice < 0.02) {
          filters.add(ConfluenceType.atSupportLevel);
        }
      }
    }

    // K 线形态：长下影线（per DETECT-03）
    if (params.confluenceCandlePattern) {
      final candle = window[recoveryEndIdx];
      final range = candle.high - candle.low;
      if (range > 0) {
        final lowerWick = (candle.open < candle.close
                ? candle.open
                : candle.close) -
            candle.low;
        final body = (candle.close - candle.open).abs();
        if (lowerWick / range > 0.6 && body / range < 0.3) {
          filters.add(ConfluenceType.bullishCandlePattern);
        }
      }
    }

    return (filters, volumeRatio);
  }

  // ─── 评分（SCORE-01）────────────────────────────────────
  /// 权重业务先验固定（Phase 6 校准，不进参数扫描）。
  int _calculateScore(
    double recoveryRatio,
    int speed,
    double volumeRatio,
    int confluenceCount,
    ReboundParams params,
  ) {
    // 回补比例权重 30：50%→15, 61.8%→22, 100%→30（线性插值）
    double recoveryScore;
    if (recoveryRatio >= 1.0) {
      recoveryScore = 30;
    } else if (recoveryRatio >= params.fibLevel618) {
      recoveryScore = 22 + (recoveryRatio - params.fibLevel618) /
          (1.0 - params.fibLevel618) * 8;
    } else if (recoveryRatio >= params.fibLevel500) {
      recoveryScore = 15 + (recoveryRatio - params.fibLevel500) /
          (params.fibLevel618 - params.fibLevel500) * 7;
    } else {
      recoveryScore = recoveryRatio / params.fibLevel500 * 15;
    }

    // 速度权重 20：1 candle→20, 2→15, 3→10
    final speedScore = speed <= 1
        ? 20.0
        : speed == 2
            ? 15.0
            : 10.0;

    // 量能权重 20：volumeRatio 线性映射到 0-20（cap at 3×）
    final volumeScore = (volumeRatio / 3.0 * 20).clamp(0, 20);

    // 共振权重 15：每个通过的过滤器 +3.75（4 个全过 = 15）
    final confluenceScore = (confluenceCount * 3.75).clamp(0, 15);

    // 多周期共振权重 15：Phase 2 单 TF 固定为 0（Phase 3 组合时填入）
    const mtfScore = 0.0;

    final total = recoveryScore + speedScore + volumeScore +
        confluenceScore + mtfScore;
    return total.clamp(0, 100).round();
  }

  // ─── 死猫风险分（SCORE-02）──────────────────────────────
  /// 独立维度 0-100，越高越可能是死猫反弹。
  int _calculateDeadCatRisk(
    double volumeRatio,
    double? rsiValue,
    double recoveryRatio,
    int confluenceCount,
  ) {
    int risk = 0;

    // 低量反弹（volumeRatio < 0.8）→ +30
    if (volumeRatio < 0.8) risk += 30;

    // RSI 卡在 50 以下（rsi < 50 且未拐头）→ +25
    if (rsiValue != null && rsiValue < 50) risk += 25;

    // 回补不足（recoveryRatio < 0.382 = Fib 38.2%）→ +25
    if (recoveryRatio < 0.382) risk += 25;

    // 无共振过滤通过 → +20
    if (confluenceCount == 0) risk += 20;

    return risk.clamp(0, 100);
  }
}
