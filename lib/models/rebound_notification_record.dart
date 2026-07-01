import 'package:flutter/foundation.dart';

/// 反弹通知历史记录（持久化到 sqflite `rebound_notifications` 表）。
///
/// 由 [ReboundNotificationRepository] 读写，监控页历史区域展示。
/// 与 [ReboundSignal] 的区别：仅保留展示所需字段 + `notifiedAt`（推送时间）。
@immutable
class ReboundNotificationRecord {
  final int? id;
  final String symbol;
  final String timeframe;
  final int score;
  final int deadCatRiskScore;
  final double dropMagnitude;
  final double recoveryRatio;
  final DateTime notifiedAt;

  const ReboundNotificationRecord({
    this.id,
    required this.symbol,
    required this.timeframe,
    required this.score,
    required this.deadCatRiskScore,
    required this.dropMagnitude,
    required this.recoveryRatio,
    required this.notifiedAt,
  });

  /// 从 sqflite 查询行构造。
  factory ReboundNotificationRecord.fromRow(Map<String, Object?> row) {
    return ReboundNotificationRecord(
      id: row['id'] as int?,
      symbol: row['symbol'] as String,
      timeframe: row['timeframe'] as String,
      score: (row['score'] as num).toInt(),
      deadCatRiskScore: (row['deadCatRiskScore'] as num).toInt(),
      dropMagnitude: (row['dropMagnitude'] as num).toDouble(),
      recoveryRatio: (row['recoveryRatio'] as num).toDouble(),
      notifiedAt:
          DateTime.fromMillisecondsSinceEpoch(row['notifiedAt'] as int),
    );
  }
}
