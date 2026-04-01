class PumpModel {
  final String symbol;
  final double priceChange;
  final DateTime triggerTime;
  final double currentPrice;

  PumpModel({
    required this.symbol,
    required this.priceChange,
    required this.triggerTime,
    required this.currentPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'priceChange': priceChange,
      'triggerTime': triggerTime.toIso8601String(),
      'currentPrice': currentPrice,
    };
  }

  factory PumpModel.fromMap(Map<String, dynamic> map) {
    return PumpModel(
      symbol: map['symbol'] as String,
      priceChange: map['priceChange'] as double,
      triggerTime: DateTime.parse(map['triggerTime'] as String),
      currentPrice: map['currentPrice'] as double,
    );
  }
}
