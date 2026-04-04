/// K线数据点（原始OHLCV）
class KlineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// 从币安API响应创建
  factory KlineData.fromBinanceResponse(List<dynamic> response) {
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(response[0] as int),
      open: double.parse(response[1].toString()),
      high: double.parse(response[2].toString()),
      low: double.parse(response[3].toString()),
      close: double.parse(response[4].toString()),
      volume: double.parse(response[5].toString()),
    );
  }

  /// 转换为Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'time': time.millisecondsSinceEpoch,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }

  /// 从Map创建
  factory KlineData.fromMap(Map<String, dynamic> map) {
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      open: (map['open'] as num).toDouble(),
      high: (map['high'] as num).toDouble(),
      low: (map['low'] as num).toDouble(),
      close: (map['close'] as num).toDouble(),
      volume: (map['volume'] as num).toDouble(),
    );
  }

  /// 计算实体方向 (1=涨, -1=跌, 0=平)
  int get direction => close.compareTo(open);

  /// 复制并修改部分字段
  KlineData copyWith({
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return KlineData(
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }
}

/// 带技术指标的数据点
class KlineDataWithIndicators {
  final KlineData data;
  final double? ma5;
  final double? ma10;
  final double? ma20;
  final double? upperBoll;
  final double? lowerBoll;

  KlineDataWithIndicators({
    required this.data,
    this.ma5,
    this.ma10,
    this.ma20,
    this.upperBoll,
    this.lowerBoll,
  });

  /// 便捷访问
  double get close => data.close;
  DateTime get time => data.time;
  double get open => data.open;
  double get high => data.high;
  double get low => data.low;
  double get volume => data.volume;
  int get direction => data.direction;

  /// 复制并修改部分字段
  KlineDataWithIndicators copyWith({
    KlineData? data,
    double? ma5,
    double? ma10,
    double? ma20,
    double? upperBoll,
    double? lowerBoll,
  }) {
    return KlineDataWithIndicators(
      data: data ?? this.data,
      ma5: ma5 ?? this.ma5,
      ma10: ma10 ?? this.ma10,
      ma20: ma20 ?? this.ma20,
      upperBoll: upperBoll ?? this.upperBoll,
      lowerBoll: lowerBoll ?? this.lowerBoll,
    );
  }
}
