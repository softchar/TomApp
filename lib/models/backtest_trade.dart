/// 单笔回测交易记录（不可变数据类）。
///
/// 记录一次完整的模拟交易：进场 → 持仓 → 出场。
/// exitReason 枚举值对齐 CONTEXT.md D-02/D-03/D-04。
class BacktestTrade {
  /// 交易对（如 "BTCUSDT"）
  final String symbol;

  /// 进场时间（bar[t+1].open 的时刻，对齐 D-01 next-open 进场）
  final DateTime entryTime;

  /// 进场价格
  final double entryPrice;

  /// 出场时间（null 表示仍在持仓中）
  final DateTime? exitTime;

  /// 出场价格（null 表示仍在持仓中）
  final double? exitPrice;

  /// 出场原因：
  /// - "stopLoss": 触及止损价
  /// - "takeProfit1": 触及 61.8% Fib 止盈
  /// - "takeProfit2": 触及 100% Fib 止盈
  /// - "timeExit": 持仓超过 maxHoldBars
  /// - "manual": 手动平仓（回测结束强制平仓）
  final String exitReason;

  /// 含成本后净盈亏（R 倍数），含手续费、滑点、资金费率
  final double pnl;

  /// 纯 R 倍数（不含成本），方便对比成本影响
  final double rMultiple;

  const BacktestTrade({
    required this.symbol,
    required this.entryTime,
    required this.entryPrice,
    this.exitTime,
    this.exitPrice,
    required this.exitReason,
    required this.pnl,
    required this.rMultiple,
  });

  /// 从 JSON 反序列化（用于 drift BacktestTrades 表 JSON 字段）。
  factory BacktestTrade.fromJson(Map<String, dynamic> json) {
    return BacktestTrade(
      symbol: json['symbol'] as String,
      entryTime: DateTime.fromMillisecondsSinceEpoch(json['entryTime'] as int),
      entryPrice: (json['entryPrice'] as num).toDouble(),
      exitTime: json['exitTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['exitTime'] as int)
          : null,
      exitPrice: json['exitPrice'] != null
          ? (json['exitPrice'] as num).toDouble()
          : null,
      exitReason: json['exitReason'] as String? ?? 'manual',
      pnl: (json['pnl'] as num).toDouble(),
      rMultiple: (json['rMultiple'] as num).toDouble(),
    );
  }

  /// 序列化为 JSON（用于 drift BacktestTrades 表 JSON 字段）。
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'entryTime': entryTime.millisecondsSinceEpoch,
      'entryPrice': entryPrice,
      'exitTime': exitTime?.millisecondsSinceEpoch,
      'exitPrice': exitPrice,
      'exitReason': exitReason,
      'pnl': pnl,
      'rMultiple': rMultiple,
    };
  }

  /// 不可变副本，支持覆盖任意字段。
  BacktestTrade copyWith({
    String? symbol,
    DateTime? entryTime,
    double? entryPrice,
    DateTime? exitTime,
    double? exitPrice,
    String? exitReason,
    double? pnl,
    double? rMultiple,
  }) {
    return BacktestTrade(
      symbol: symbol ?? this.symbol,
      entryTime: entryTime ?? this.entryTime,
      entryPrice: entryPrice ?? this.entryPrice,
      exitTime: exitTime ?? this.exitTime,
      exitPrice: exitPrice ?? this.exitPrice,
      exitReason: exitReason ?? this.exitReason,
      pnl: pnl ?? this.pnl,
      rMultiple: rMultiple ?? this.rMultiple,
    );
  }

  /// 是否已平仓。
  bool get isClosed => exitTime != null;

  @override
  String toString() =>
      'BacktestTrade($symbol entry=${entryPrice.toStringAsFixed(2)} '
      'exit=${exitPrice?.toStringAsFixed(2) ?? "open"} '
      'reason=$exitReason pnl=${pnl.toStringAsFixed(4)}R '
      'rMultiple=${rMultiple.toStringAsFixed(4)}R)';
}
