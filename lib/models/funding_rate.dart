/// 币安合约资金费率模型。
///
/// 用于实时行情展示（premiumIndex 端点）和回测历史费率（fundingRate 端点）。
/// 不可变类，相等性基于 symbol + fundingTime 组合。
class FundingRate {
  String symbol;
  double fundingRate;
  double markPrice;
  int indexPrice;
  double estimatedSettleTime;
  int fundingTime;
  DateTime? lastUpdate;
  int _fundingIntervalHours = 8; // 默认8小时，可通过setter修改

  FundingRate({
    required this.symbol,
    required this.fundingRate,
    required this.markPrice,
    required this.indexPrice,
    required this.estimatedSettleTime,
    required this.fundingTime,
    this.lastUpdate,
  });

  factory FundingRate.fromJson(Map<String, dynamic> json) {
    return FundingRate(
      symbol: json['symbol'] ?? '',
      fundingRate: double.tryParse(json['lastFundingRate']?.toString() ?? '0') ?? 0.0,
      markPrice: double.tryParse(json['markPrice']?.toString() ?? '0') ?? 0.0,
      indexPrice: int.tryParse(json['indexPrice']?.toString() ?? '0') ?? 0,
      estimatedSettleTime: double.tryParse(json['nextFundingTime']?.toString() ?? '0') ?? 0.0,
      fundingTime: int.tryParse(json['fundingTime']?.toString() ?? '0') ?? 0,
      lastUpdate: DateTime.now(),
    );
  }

  /// 从币安API premiumIndex响应创建
  factory FundingRate.fromPremiumIndex(Map<String, dynamic> json) {
    return FundingRate(
      symbol: json['symbol'] ?? '',
      fundingRate: double.tryParse(json['lastFundingRate']?.toString() ?? '0') ?? 0.0,
      markPrice: double.tryParse(json['markPrice']?.toString() ?? '0') ?? 0.0,
      indexPrice: (double.tryParse(json['indexPrice']?.toString() ?? '0') ?? 0.0).toInt(),
      estimatedSettleTime: double.tryParse(json['nextFundingTime']?.toString() ?? '0') ?? 0.0,
      fundingTime: int.tryParse(json['fundingTime']?.toString() ?? '0') ?? 0,
      lastUpdate: DateTime.now(),
    );
  }

  /// 从币安 /fapi/v1/fundingRate 端点响应创建（回测历史数据用）。
  ///
  /// 响应字段：fundingRate(String)、fundingTime(int 毫秒)、symbol(String)。
  factory FundingRate.fromFundingRateEndpoint(Map<String, dynamic> json) {
    return FundingRate(
      symbol: json['symbol'] as String? ?? '',
      fundingRate:
          double.tryParse(json['fundingRate']?.toString() ?? '0') ?? 0.0,
      markPrice: 0.0,
      indexPrice: 0,
      estimatedSettleTime: 0.0,
      fundingTime: json['fundingTime'] as int? ?? 0,
    );
  }

  /// 获取下一次资金费率时间
  DateTime get nextFundingTime =>
      DateTime.fromMillisecondsSinceEpoch(estimatedSettleTime.toInt());

  /// 格式化资金费率百分比
  String get fundingRatePercent {
    final rate = fundingRate * 100;
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(4)}%';
  }

  /// 格式化标记价格
  String get formattedMarkPrice => markPrice.toStringAsFixed(4);

  /// 是否为正费率
  bool get isPositiveRate => fundingRate >= 0;

  /// 计算资金费率周期（小时）
  int get fundingIntervalHours => _fundingIntervalHours;

  /// 设置资金费率周期（小时）
  void setFundingIntervalHours(int hours) {
    _fundingIntervalHours = hours;
  }

  /// 是否为1小时周期
  bool get isOneHourInterval => _fundingIntervalHours == 1;

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'fundingRate': fundingRate,
      'markPrice': markPrice,
      'indexPrice': indexPrice,
      'estimatedSettleTime': estimatedSettleTime,
      'fundingTime': fundingTime,
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  /// 相等性基于 symbol + fundingTime 组合。
  /// 同一币种同一结算时刻的费率视为同一条记录。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FundingRate &&
        other.symbol == symbol &&
        other.fundingTime == fundingTime;
  }

  @override
  int get hashCode => Object.hash(symbol, fundingTime);

  FundingRate copyWith({
    String? symbol,
    double? fundingRate,
    double? markPrice,
    int? indexPrice,
    double? estimatedSettleTime,
    int? fundingTime,
    DateTime? lastUpdate,
    int? fundingIntervalHours,
  }) {
    final copy = FundingRate(
      symbol: symbol ?? this.symbol,
      fundingRate: fundingRate ?? this.fundingRate,
      markPrice: markPrice ?? this.markPrice,
      indexPrice: indexPrice ?? this.indexPrice,
      estimatedSettleTime: estimatedSettleTime ?? this.estimatedSettleTime,
      fundingTime: fundingTime ?? this.fundingTime,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
    copy._fundingIntervalHours = fundingIntervalHours ?? _fundingIntervalHours;
    return copy;
  }
}
