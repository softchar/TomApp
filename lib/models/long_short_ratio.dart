/// 大户多空账号人数比模型
class LongShortRatio {
  final String symbol;
  final double longShortRatio; // 多空比
  final double longAccount; // 多头账号比例
  final double shortAccount; // 空头账号比例
  final int timestamp;
  final DateTime? updateTime;
  int fundingIntervalHours; // 资费间隔（小时）- 改为可变

  LongShortRatio({
    required this.symbol,
    required this.longShortRatio,
    required this.longAccount,
    required this.shortAccount,
    required this.timestamp,
    this.updateTime,
    this.fundingIntervalHours = 8, // 默认8小时
  });

  factory LongShortRatio.fromJson(Map<String, dynamic> json) {
    return LongShortRatio(
      symbol: json['symbol'] ?? '',
      longShortRatio: double.tryParse(json['longShortRatio']?.toString() ?? '0') ?? 0.0,
      longAccount: double.tryParse(json['longAccount']?.toString() ?? '0') ?? 0.0,
      shortAccount: double.tryParse(json['shortAccount']?.toString() ?? '0') ?? 0.0,
      timestamp: json['timestamp'] ?? 0,
      updateTime: DateTime.now(),
    );
  }

  /// 设置资费间隔
  void setFundingIntervalHours(int hours) {
    fundingIntervalHours = hours;
  }

  /// 格式化多空比
  String get formattedRatio => longShortRatio.toStringAsFixed(4);

  /// 格式化多头比例
  String get formattedLongAccount => '${(longAccount * 100).toStringAsFixed(2)}%';

  /// 格式化空头比例
  String get formattedShortAccount => '${(shortAccount * 100).toStringAsFixed(2)}%';

  /// 更新时间
  DateTime get updateDateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// 是否多头占优（多空比 > 1）
  bool get isLongDominant => longShortRatio > 1.0;

  /// 是否空头占优（多空比 < 1）
  bool get isShortDominant => longShortRatio < 1.0;

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'longShortRatio': longShortRatio,
      'longAccount': longAccount,
      'shortAccount': shortAccount,
      'timestamp': timestamp,
      'updateTime': updateTime?.toIso8601String(),
    };
  }
}
