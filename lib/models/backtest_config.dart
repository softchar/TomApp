/// 回测运行配置，不可变数据类。
///
/// 包含起止日期、标的列表、成本开关等回测参数。
/// 提供 JSON 序列化用于 UI 日期选择器持久化。
class BacktestConfig {
  /// 回测起始日期（含）
  final DateTime startDate;

  /// 回测结束日期（含）
  final DateTime endDate;

  /// 待回测的交易对列表（如 ["BTCUSDT", "ETHUSDT"]）
  final List<String> symbols;

  /// 是否启用成本计算（手续费、滑点、资金费率）
  final bool costsEnabled;

  /// 最大持仓 K 线数（超过则时间退出）
  final int maxHoldBars;

  const BacktestConfig({
    required this.startDate,
    required this.endDate,
    required this.symbols,
    this.costsEnabled = true,
    this.maxHoldBars = 20,
  });

  /// 默认配置：最近 6 个月，空标的列表（由数据导入管线填充 Top-100）。
  factory BacktestConfig.defaults() {
    final now = DateTime.now();
    return BacktestConfig(
      startDate: DateTime(now.year, now.month - 6, now.day),
      endDate: now,
      symbols: const [],
    );
  }

  /// 从 JSON 反序列化，日期字段为 ISO 8601 字符串。
  ///
  /// 校验规则（对齐 CONTEXT.md D-09 + threat T-06-03）：
  /// - startDate 不早于 2020-01-01
  /// - endDate 不晚于 today
  /// - startDate < endDate
  /// - 日期范围不超过 365 天
  /// - symbols 数量不超过 100
  factory BacktestConfig.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.parse(json['startDate'] as String);
    final endDate = DateTime.parse(json['endDate'] as String);
    final symbols = (json['symbols'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        [];
    final costsEnabled = json['costsEnabled'] as bool? ?? true;
    final maxHoldBars = json['maxHoldBars'] as int? ?? 20;

    // 校验日期范围
    if (startDate.isBefore(DateTime(2020, 1, 1))) {
      throw ArgumentError('startDate 不得早于 2020-01-01');
    }
    final today = DateTime.now();
    final todayEnd = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));
    if (endDate.isAfter(todayEnd)) {
      throw ArgumentError('endDate 不得晚于今天');
    }
    if (!startDate.isBefore(endDate)) {
      throw ArgumentError('startDate 必须早于 endDate');
    }
    if (endDate.difference(startDate).inDays > 365) {
      throw ArgumentError('日期范围不得超过 365 天');
    }
    if (symbols.length > 100) {
      throw ArgumentError('标的数量不得超过 100 个');
    }

    return BacktestConfig(
      startDate: startDate,
      endDate: endDate,
      symbols: symbols,
      costsEnabled: costsEnabled,
      maxHoldBars: maxHoldBars,
    );
  }

  /// 序列化为 JSON，日期字段存为 ISO 8601 字符串。
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'symbols': symbols,
      'costsEnabled': costsEnabled,
      'maxHoldBars': maxHoldBars,
    };
  }

  /// 不可变副本，支持覆盖任意字段。
  BacktestConfig copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? symbols,
    bool? costsEnabled,
    int? maxHoldBars,
  }) {
    return BacktestConfig(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      symbols: symbols ?? this.symbols,
      costsEnabled: costsEnabled ?? this.costsEnabled,
      maxHoldBars: maxHoldBars ?? this.maxHoldBars,
    );
  }

  @override
  String toString() =>
      'BacktestConfig(${startDate.toIso8601String()} → ${endDate.toIso8601String()}, '
      '${symbols.length} symbols, costs=$costsEnabled, maxHold=$maxHoldBars)';
}
