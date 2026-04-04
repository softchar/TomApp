import 'package:tomapp/models/pump_model.dart';

/// PumpHistory 数据库实体模型
class PumpHistoryModel {
  final int? id;
  final String symbol;
  final double basePrice;
  final double peakPrice;
  final double priceChange;
  final int triggerTime; // Unix timestamp in milliseconds
  final String detectedAt; // ISO 8601 format
  final int cooldownMinutes;
  final String strategyType;
  final double? subsequentLow;
  final int? subsequentLowTime;
  final double? pullbackPercent;
  final int isConfirmed; // 0 = false, 1 = true

  PumpHistoryModel({
    this.id,
    required this.symbol,
    required this.basePrice,
    required this.peakPrice,
    required this.priceChange,
    required this.triggerTime,
    required this.detectedAt,
    required this.cooldownMinutes,
    required this.strategyType,
    this.subsequentLow,
    this.subsequentLowTime,
    this.pullbackPercent,
    required this.isConfirmed,
  });

  /// 从 PumpModel 转换
  factory PumpHistoryModel.fromPumpModel(PumpModel pump, {
    required String strategyType,
    int cooldownMinutes = 1,
  }) {
    final now = DateTime.now();
    return PumpHistoryModel(
      symbol: pump.symbol,
      basePrice: pump.currentPrice / (1 + pump.priceChange / 100),
      peakPrice: pump.currentPrice,
      priceChange: pump.priceChange,
      triggerTime: pump.triggerTime.millisecondsSinceEpoch,
      detectedAt: now.toIso8601String(),
      cooldownMinutes: cooldownMinutes,
      strategyType: strategyType,
      isConfirmed: 0,
    );
  }

  /// 从数据库 Map 创建
  factory PumpHistoryModel.fromMap(Map<String, dynamic> map) {
    return PumpHistoryModel(
      id: map['id'] as int?,
      symbol: map['symbol'] as String,
      basePrice: (map['basePrice'] as num).toDouble(),
      peakPrice: (map['peakPrice'] as num).toDouble(),
      priceChange: (map['priceChange'] as num).toDouble(),
      triggerTime: map['triggerTime'] as int,
      detectedAt: map['detectedAt'] as String,
      cooldownMinutes: map['cooldownMinutes'] as int,
      strategyType: map['strategyType'] as String,
      subsequentLow: map['subsequentLow'] != null
          ? (map['subsequentLow'] as num).toDouble()
          : null,
      subsequentLowTime: map['subsequentLowTime'] as int?,
      pullbackPercent: map['pullbackPercent'] != null
          ? (map['pullbackPercent'] as num).toDouble()
          : null,
      isConfirmed: map['isConfirmed'] as int,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'symbol': symbol,
      'basePrice': basePrice,
      'peakPrice': peakPrice,
      'priceChange': priceChange,
      'triggerTime': triggerTime,
      'detectedAt': detectedAt,
      'cooldownMinutes': cooldownMinutes,
      'strategyType': strategyType,
      'subsequentLow': subsequentLow,
      'subsequentLowTime': subsequentLowTime,
      'pullbackPercent': pullbackPercent,
      'isConfirmed': isConfirmed,
    };
  }

  /// 转换为 PumpModel (用于兼容)
  PumpModel toPumpModel() {
    return PumpModel(
      symbol: symbol,
      priceChange: priceChange,
      triggerTime: DateTime.fromMillisecondsSinceEpoch(triggerTime),
      currentPrice: peakPrice,
    );
  }

  /// 复制并修改部分字段
  PumpHistoryModel copyWith({
    int? id,
    String? symbol,
    double? basePrice,
    double? peakPrice,
    double? priceChange,
    int? triggerTime,
    String? detectedAt,
    int? cooldownMinutes,
    String? strategyType,
    double? subsequentLow,
    int? subsequentLowTime,
    double? pullbackPercent,
    int? isConfirmed,
  }) {
    return PumpHistoryModel(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      basePrice: basePrice ?? this.basePrice,
      peakPrice: peakPrice ?? this.peakPrice,
      priceChange: priceChange ?? this.priceChange,
      triggerTime: triggerTime ?? this.triggerTime,
      detectedAt: detectedAt ?? this.detectedAt,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      strategyType: strategyType ?? this.strategyType,
      subsequentLow: subsequentLow ?? this.subsequentLow,
      subsequentLowTime: subsequentLowTime ?? this.subsequentLowTime,
      pullbackPercent: pullbackPercent ?? this.pullbackPercent,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }

  /// 获取触发时间作为 DateTime
  DateTime get triggerDateTime =>
      DateTime.fromMillisecondsSinceEpoch(triggerTime);

  /// 是否已确认
  bool get confirmed => isConfirmed == 1;

  /// 是否还在监控期内
  bool isWithinMonitoringPeriod({int minutes = 15}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAge = Duration(minutes: minutes).inMilliseconds;
    return (now - triggerTime) < maxAge;
  }

  /// 计算从检测到现在的时间差
  Duration get age =>
      DateTime.now().difference(triggerDateTime);
}
