import 'backtest_config.dart';
import 'backtest_trade.dart';

/// 回测报告输出模型（不可变数据类）。
///
/// 包含汇总统计、交易列表、双权益曲线数据。
/// 对齐 CONTEXT.md D-19（报告内容）+ D-06（双曲线必出）。
class BacktestReport {
  /// 回测运行配置
  final BacktestConfig config;

  /// 回测开始时间
  final DateTime startedAt;

  /// 回测完成时间
  final DateTime completedAt;

  /// 总交易笔数
  final int totalTrades;

  /// 胜率（0.0-1.0），trades 为空时返回 0.0 而非 NaN
  final double winRate;

  /// 平均 R 倍数（所有交易）
  final double avgR;

  /// 盈亏比：总盈利 / 总亏损，无亏损时返回 double.infinity
  final double profitFactor;

  /// 最大回撤比例（0.0-1.0）：从峰值到谷底的最大回撤
  final double maxDrawdown;

  /// 样本数量（触发的信号总数）
  final int sampleCount;

  /// 总 PnL（R 倍数合计）
  final double totalPnL;

  /// 每笔交易平均 R 倍数
  final double avgRPerTrade;

  /// 交易列表
  final List<BacktestTrade> trades;

  /// 零成本权益曲线：每笔交易后的累计 R 倍数
  /// 每个元素为 (tradeIndex, cumulativeR) 记录
  final List<({int tradeIndex, double cumulativeR})> equityCurveZeroCost;

  /// 含成本权益曲线：每笔交易后的累计 R 倍数（含手续费+滑点+资金费）
  final List<({int tradeIndex, double cumulativeR})> equityCurveWithCost;

  const BacktestReport({
    required this.config,
    required this.startedAt,
    required this.completedAt,
    required this.totalTrades,
    required this.winRate,
    required this.avgR,
    required this.profitFactor,
    required this.maxDrawdown,
    required this.sampleCount,
    required this.totalPnL,
    required this.avgRPerTrade,
    required this.trades,
    required this.equityCurveZeroCost,
    required this.equityCurveWithCost,
  });

  /// 空报告工厂——用于 0 笔交易或无数据场景。
  ///
  /// 所有统计指标为 0，权益曲线为空列表。
  /// winRate=0.0（非 NaN），profitFactor=0.0（非 infinity，因为没有交易意味着没有可评估的盈亏比）。
  factory BacktestReport.empty(BacktestConfig config) {
    final now = DateTime.now();
    return BacktestReport(
      config: config,
      startedAt: now,
      completedAt: now,
      totalTrades: 0,
      winRate: 0.0,
      avgR: 0.0,
      profitFactor: 0.0,
      maxDrawdown: 0.0,
      sampleCount: 0,
      totalPnL: 0.0,
      avgRPerTrade: 0.0,
      trades: const [],
      equityCurveZeroCost: const [],
      equityCurveWithCost: const [],
    );
  }

  /// 从 JSON 反序列化。
  factory BacktestReport.fromJson(Map<String, dynamic> json) {
    return BacktestReport(
      config: BacktestConfig.fromJson(json['config'] as Map<String, dynamic>),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      totalTrades: json['totalTrades'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
      avgR: (json['avgR'] as num?)?.toDouble() ?? 0.0,
      profitFactor: (json['profitFactor'] as num?)?.toDouble() ?? 0.0,
      maxDrawdown: (json['maxDrawdown'] as num?)?.toDouble() ?? 0.0,
      sampleCount: json['sampleCount'] as int? ?? 0,
      totalPnL: (json['totalPnL'] as num?)?.toDouble() ?? 0.0,
      avgRPerTrade: (json['avgRPerTrade'] as num?)?.toDouble() ?? 0.0,
      trades: (json['trades'] as List<dynamic>?)
              ?.map((t) =>
                  BacktestTrade.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      equityCurveZeroCost: _parseEquityCurve(json['equityCurveZeroCost']),
      equityCurveWithCost: _parseEquityCurve(json['equityCurveWithCost']),
    );
  }

  /// 序列化为 JSON。
  Map<String, dynamic> toJson() {
    return {
      'config': config.toJson(),
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'totalTrades': totalTrades,
      'winRate': winRate,
      'avgR': avgR,
      'profitFactor': profitFactor,
      'maxDrawdown': maxDrawdown,
      'sampleCount': sampleCount,
      'totalPnL': totalPnL,
      'avgRPerTrade': avgRPerTrade,
      'trades': trades.map((t) => t.toJson()).toList(),
      'equityCurveZeroCost':
          equityCurveZeroCost.map((e) => {'tradeIndex': e.tradeIndex, 'cumulativeR': e.cumulativeR}).toList(),
      'equityCurveWithCost':
          equityCurveWithCost.map((e) => {'tradeIndex': e.tradeIndex, 'cumulativeR': e.cumulativeR}).toList(),
    };
  }

  /// 不可变副本，支持覆盖任意字段。
  BacktestReport copyWith({
    BacktestConfig? config,
    DateTime? startedAt,
    DateTime? completedAt,
    int? totalTrades,
    double? winRate,
    double? avgR,
    double? profitFactor,
    double? maxDrawdown,
    int? sampleCount,
    double? totalPnL,
    double? avgRPerTrade,
    List<BacktestTrade>? trades,
    List<({int tradeIndex, double cumulativeR})>? equityCurveZeroCost,
    List<({int tradeIndex, double cumulativeR})>? equityCurveWithCost,
  }) {
    return BacktestReport(
      config: config ?? this.config,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      totalTrades: totalTrades ?? this.totalTrades,
      winRate: winRate ?? this.winRate,
      avgR: avgR ?? this.avgR,
      profitFactor: profitFactor ?? this.profitFactor,
      maxDrawdown: maxDrawdown ?? this.maxDrawdown,
      sampleCount: sampleCount ?? this.sampleCount,
      totalPnL: totalPnL ?? this.totalPnL,
      avgRPerTrade: avgRPerTrade ?? this.avgRPerTrade,
      trades: trades ?? this.trades,
      equityCurveZeroCost: equityCurveZeroCost ?? this.equityCurveZeroCost,
      equityCurveWithCost: equityCurveWithCost ?? this.equityCurveWithCost,
    );
  }

  /// 计算权益曲线的最大回撤。
  ///
  /// 从曲线数据中计算从峰值到谷底的最大回撤比例（0.0-1.0）。
  /// 空曲线返回 0.0。
  static double calculateMaxDrawdown(
      List<({int tradeIndex, double cumulativeR})> equityCurve) {
    if (equityCurve.isEmpty) return 0.0;
    double peak = equityCurve.first.cumulativeR;
    double maxDd = 0.0;
    for (final point in equityCurve) {
      if (point.cumulativeR > peak) {
        peak = point.cumulativeR;
      }
      final drawdown = (peak - point.cumulativeR) / peak.abs().clamp(0.01, double.infinity);
      if (drawdown > maxDd) {
        maxDd = drawdown;
      }
    }
    return maxDd;
  }

  @override
  String toString() =>
      'BacktestReport(trades=$totalTrades winRate=${(winRate * 100).toStringAsFixed(1)}% '
      'avgR=${avgR.toStringAsFixed(3)} pf=${profitFactor.toStringAsFixed(2)} '
      'maxDD=${(maxDrawdown * 100).toStringAsFixed(1)}% N=$sampleCount '
      'totalPnL=${totalPnL.toStringAsFixed(2)}R)';

  /// 解析 JSON 中的权益曲线数据。
  static List<({int tradeIndex, double cumulativeR})> _parseEquityCurve(
      dynamic json) {
    if (json == null) return [];
    final list = json as List<dynamic>;
    return list
        .map((e) {
          final map = e as Map<String, dynamic>;
          return (
            tradeIndex: map['tradeIndex'] as int,
            cumulativeR: (map['cumulativeR'] as num).toDouble(),
          );
        })
        .toList();
  }
}
