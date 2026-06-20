/// 回测持仓状态（不可变数据类）。
///
/// 记录当前持仓的进场信息、止损/止盈价位、以及仓位分批状态。
/// 对齐 CONTEXT.md D-02/D-03（固定止损 + 双止盈）。
class Position {
  /// 交易对（如 "BTCUSDT"）
  final String symbol;

  /// 进场时间（bar[t+1].open 的时刻）
  final DateTime entryTime;

  /// 进场价格
  final double entryPrice;

  /// 名义仓位价值（用于计算 funding 扣费）
  final double quantity;

  /// 止损价位（swingLow − 0.3×ATR）
  final double stopLoss;

  /// 第一止盈价位（61.8% Fib 水平）
  final double takeProfit1;

  /// 第二止盈价位（100% Fib 水平 = swingHigh）
  final double takeProfit2;

  /// 61.8% Fib 止盈是否已触发一半仓位
  final bool exitedHalf;

  const Position({
    required this.symbol,
    required this.entryTime,
    required this.entryPrice,
    required this.quantity,
    required this.stopLoss,
    required this.takeProfit1,
    required this.takeProfit2,
    this.exitedHalf = false,
  });

  /// 不可变副本，支持覆盖任意字段。
  ///
  /// 关键行为（对齐 CONTEXT.md behavior）：
  /// copyWith 传入 stopLoss=null 不重置 stopLoss。
  Position copyWith({
    String? symbol,
    DateTime? entryTime,
    double? entryPrice,
    double? quantity,
    double? stopLoss,
    double? takeProfit1,
    double? takeProfit2,
    bool? exitedHalf,
  }) {
    return Position(
      symbol: symbol ?? this.symbol,
      entryTime: entryTime ?? this.entryTime,
      entryPrice: entryPrice ?? this.entryPrice,
      quantity: quantity ?? this.quantity,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit1: takeProfit1 ?? this.takeProfit1,
      takeProfit2: takeProfit2 ?? this.takeProfit2,
      exitedHalf: exitedHalf ?? this.exitedHalf,
    );
  }

  @override
  String toString() =>
      'Position($symbol entry=${entryPrice.toStringAsFixed(2)} '
      'sl=${stopLoss.toStringAsFixed(2)} tp1=${takeProfit1.toStringAsFixed(2)} '
      'tp2=${takeProfit2.toStringAsFixed(2)} exitedHalf=$exitedHalf)';
}
