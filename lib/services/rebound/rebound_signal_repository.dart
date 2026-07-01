import 'package:sqflite/sqflite.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/database_helper.dart';

/// 看板列表信号仓库（sqflite `rebound_signals` 表，v6）。
///
/// 由 [ReboundScoreProvider] 在低频路径（收盘/扫描命中）写库、启动时读回。
/// 与 ReboundNotificationRepository（仅已通知的高分记录）的区别：
/// 本仓库存"进列表(score≥70)"的全部信号，范围更大。
class ReboundSignalRepository {
  static const String _table = 'rebound_signals';

  final DatabaseHelper _helper;

  /// [helper] 可注入便于测试；默认用单例。
  ReboundSignalRepository([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  /// 插入或覆盖一条信号（PK: symbol+timeframe）。
  Future<void> upsert(ReboundSignal signal) async {
    final db = await _helper.database;
    await db.insert(
      _table,
      {
        'symbol': signal.symbol,
        'timeframe': signal.timeframe,
        'score': signal.score,
        'deadCatRiskScore': signal.deadCatRiskScore,
        'dropMagnitude': signal.dropMagnitude,
        'recoveryRatio': signal.recoveryRatio,
        'entryPrice': signal.entryPrice,
        'swingLowPrice': signal.swingLowPrice,
        'swingHighPrice': signal.swingHighPrice,
        'dropStartIndex': signal.dropStartIndex,
        'dropEndIndex': signal.dropEndIndex,
        'recoveryEndIndex': signal.recoveryEndIndex,
        'isLatestBar': signal.isLatestBar ? 1 : 0,
        'klineCloseTime': signal.timestamp.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除指定 (symbol, timeframe)。
  Future<void> delete(String symbol, String timeframe) async {
    final db = await _helper.database;
    await db.delete(
      _table,
      where: 'symbol = ? AND timeframe = ?',
      whereArgs: [symbol, timeframe],
    );
  }

  /// 按 score 降序返回 ≥ [minScore] 的信号（最多 [limit] 条）。
  Future<List<ReboundSignal>> queryListed(int minScore, int limit) async {
    final db = await _helper.database;
    final rows = await db.query(
      _table,
      where: 'score >= ?',
      whereArgs: [minScore],
      orderBy: 'score DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  ReboundSignal _fromRow(Map<String, Object?> row) => ReboundSignal(
        symbol: row['symbol'] as String,
        timeframe: row['timeframe'] as String,
        dropMagnitude: (row['dropMagnitude'] as num).toDouble(),
        recoveryRatio: (row['recoveryRatio'] as num).toDouble(),
        speed: 0, // 不持久化（展示不用），重建默认 0
        confluenceFilters: const {}, // 不持久化
        score: (row['score'] as num).toInt(),
        deadCatRiskScore: (row['deadCatRiskScore'] as num).toInt(),
        entryPrice: (row['entryPrice'] as num).toDouble(),
        swingLowPrice: (row['swingLowPrice'] as num).toDouble(),
        swingHighPrice: (row['swingHighPrice'] as num).toDouble(),
        dropStartIndex: (row['dropStartIndex'] as num).toInt(),
        dropEndIndex: (row['dropEndIndex'] as num).toInt(),
        recoveryEndIndex: (row['recoveryEndIndex'] as num).toInt(),
        isLatestBar: (row['isLatestBar'] as int) == 1,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(row['klineCloseTime'] as int),
      );
}
