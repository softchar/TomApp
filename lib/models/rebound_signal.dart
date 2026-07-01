/// 共振过滤器类型枚举。
enum ConfluenceType {
  /// RSI 超卖拐头向上
  rsiOversoldTurning,

  /// 拉回段放量确认
  volumeConfirmation,

  /// 价格在 swing low 支撑位附近
  atSupportLevel,

  /// 看涨 K 线形态（长下影线）
  bullishCandlePattern,
}

/// 反弹信号数据（不可变，由 ReboundDetector.evaluate 输出）。
///
/// 包含三阶段检测结果、强度评分（0-100）、死猫风险分（0-100），
/// 以及进场/止损参考价位。live 与回测调用同一 evaluate 保证同源。
class ReboundSignal {
  /// 交易对（如 "BTCUSDT"）
  final String symbol;

  /// 周期标识（"15m"/"1h"/"4h"/"1d"）
  final String timeframe;

  /// 下跌幅度（ATR 倍数，如 2.5 = 2.5×ATR）
  final double dropMagnitude;

  /// 回补比例（0.0-1.0+，0.5 = 回补了跌幅的 50%）
  final double recoveryRatio;

  /// 回补所用 K 线数（speed）
  final int speed;

  /// 通过的共振过滤器集合
  final Set<ConfluenceType> confluenceFilters;

  /// 强度评分 0-100（recoveryRatio 30 + speed 20 + volume 20 + confluence 15 + mtf 15）
  final int score;

  /// 死猫反弹风险分 0-100（独立维度，越高越可能是死猫）
  final int deadCatRiskScore;

  /// 确认 K 线收盘价（进场参考）
  final double entryPrice;

  /// 下跌段最低价（止损参考）
  final double swingLowPrice;

  /// 下跌段起始最高价
  final double swingHighPrice;

  /// 下跌段起始索引（window 内）
  final int dropStartIndex;

  /// 下跌段结束索引（swing low 位置）
  final int dropEndIndex;

  /// 拉回段结束索引
  final int recoveryEndIndex;

  /// 反弹是否在最新一根 K 线确认（recoveryEndIndex == window.length-1）。
  /// 由 scanner/handleClosedKline 设置；用于收紧通知门槛（仅最新一根才推送）。
  final bool isLatestBar;

  /// 确认 K 线时间（从 window 最后一根 K 线的 time 取，非 DateTime.now）
  final DateTime timestamp;

  const ReboundSignal({
    required this.symbol,
    required this.timeframe,
    required this.dropMagnitude,
    required this.recoveryRatio,
    required this.speed,
    required this.confluenceFilters,
    required this.score,
    required this.deadCatRiskScore,
    required this.entryPrice,
    required this.swingLowPrice,
    required this.swingHighPrice,
    required this.dropStartIndex,
    required this.dropEndIndex,
    required this.recoveryEndIndex,
    this.isLatestBar = false,
    required this.timestamp,
  });

  /// 不可变副本，支持覆盖任意字段。
  ReboundSignal copyWith({
    String? symbol,
    String? timeframe,
    double? dropMagnitude,
    double? recoveryRatio,
    int? speed,
    Set<ConfluenceType>? confluenceFilters,
    int? score,
    int? deadCatRiskScore,
    double? entryPrice,
    double? swingLowPrice,
    double? swingHighPrice,
    int? dropStartIndex,
    int? dropEndIndex,
    int? recoveryEndIndex,
    bool? isLatestBar,
    DateTime? timestamp,
  }) {
    return ReboundSignal(
      symbol: symbol ?? this.symbol,
      timeframe: timeframe ?? this.timeframe,
      dropMagnitude: dropMagnitude ?? this.dropMagnitude,
      recoveryRatio: recoveryRatio ?? this.recoveryRatio,
      speed: speed ?? this.speed,
      confluenceFilters: confluenceFilters ?? this.confluenceFilters,
      score: score ?? this.score,
      deadCatRiskScore: deadCatRiskScore ?? this.deadCatRiskScore,
      entryPrice: entryPrice ?? this.entryPrice,
      swingLowPrice: swingLowPrice ?? this.swingLowPrice,
      swingHighPrice: swingHighPrice ?? this.swingHighPrice,
      dropStartIndex: dropStartIndex ?? this.dropStartIndex,
      dropEndIndex: dropEndIndex ?? this.dropEndIndex,
      recoveryEndIndex: recoveryEndIndex ?? this.recoveryEndIndex,
      isLatestBar: isLatestBar ?? this.isLatestBar,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() =>
      'ReboundSignal($symbol/$timeframe score=$score deadCat=$deadCatRiskScore '
      'drop=${dropMagnitude.toStringAsFixed(1)}×ATR recovery=${(recoveryRatio * 100).toStringAsFixed(0)}% '
      'speed=$speed confluence=${confluenceFilters.length})';
}
