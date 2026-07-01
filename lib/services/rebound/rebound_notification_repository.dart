import 'package:tomapp/models/rebound_notification_record.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/database_helper.dart';

/// 反弹通知历史仓库（sqflite `rebound_notifications` 表）。
///
/// 由 [ReboundAlertService] 在推送后写入，监控页历史区域读取展示。
/// 表由 [DatabaseHelper] v5 migration 创建。
class ReboundNotificationRepository {
  static const String _table = 'rebound_notifications';

  final DatabaseHelper _helper;

  /// [helper] 可注入便于测试；默认用单例。
  ReboundNotificationRepository([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  /// 记录一条已推送的通知。[notifiedAt] 可注入便于与内存记录保持同一时间戳。
  Future<void> insert(ReboundSignal signal, {DateTime? notifiedAt}) async {
    final t = (notifiedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final db = await _helper.database;
    await db.insert(_table, {
      'symbol': signal.symbol,
      'timeframe': signal.timeframe,
      'score': signal.score,
      'deadCatRiskScore': signal.deadCatRiskScore,
      'dropMagnitude': signal.dropMagnitude,
      'recoveryRatio': signal.recoveryRatio,
      'notifiedAt': t,
    });
  }

  /// 按推送时间倒序返回最近 [limit] 条通知。
  Future<List<ReboundNotificationRecord>> queryRecent(int limit) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      orderBy: 'notifiedAt DESC',
      limit: limit,
    );
    return rows.map(ReboundNotificationRecord.fromRow).toList();
  }
}
