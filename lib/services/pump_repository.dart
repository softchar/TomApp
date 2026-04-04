import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/database_helper.dart';

/// PumpRepository 抽象接口
abstract class PumpRepository {
  Future<void> save(PumpHistoryModel pump);
  Future<void> saveAll(List<PumpHistoryModel> pumps);

  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  });

  Future<List<PumpHistoryModel>> getRecentData(String symbol, {int hours = 24});
  Future<PumpStatistics> getStatistics();
  Future<List<SymbolStats>> getTopSymbols(int limit);

  Future<void> updatePullback(int id, double lowPrice, int lowTime);
  Future<void> markConfirmed(int id);

  Future<void> cleanOldData({int daysToKeep = 90});
  Future<int> getDatabaseSize();
}

/// 统计数据模型
class PumpStatistics {
  final int totalDetections;
  final int uniqueSymbols;
  final double avgPriceChange;
  final double successRate;
  final List<SymbolStats> topSymbols;
  final List<HourlyCount> detectionsByHour;

  PumpStatistics({
    required this.totalDetections,
    required this.uniqueSymbols,
    required this.avgPriceChange,
    required this.successRate,
    required this.topSymbols,
    required this.detectionsByHour,
  });
}

/// 币种统计
class SymbolStats {
  final String symbol;
  final int count;
  final double avgChange;
  final double maxChange;
  final double successRate;

  SymbolStats({
    required this.symbol,
    required this.count,
    required this.avgChange,
    required this.maxChange,
    required this.successRate,
  });
}

/// 小时统计
class HourlyCount {
  final int hour;
  final int count;

  HourlyCount({required this.hour, required this.count});
}

/// RepositoryFactory - 根据规范 Section 3.6
class RepositoryFactory {
  static PumpRepository create() {
    try {
      return SqlitePumpRepository();
    } catch (e) {
      debugPrint('数据库初始化失败，降级到内存模式: $e');
      return MemoryPumpRepository();
    }
  }
}

/// SQLite 实现
class SqlitePumpRepository implements PumpRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<void> save(PumpHistoryModel pump) async {
    final db = await _dbHelper.database;
    await db.insert('PumpHistory', pump.toMap());
  }

  @override
  Future<void> saveAll(List<PumpHistoryModel> pumps) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    for (final pump in pumps) {
      batch.insert('PumpHistory', pump.toMap());
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  }) async {
    final db = await _dbHelper.database;

    String query = 'SELECT * FROM PumpHistory WHERE 1=1';
    final args = <dynamic>[];

    if (symbol != null) {
      query += ' AND symbol = ?';
      args.add(symbol);
    }

    if (startTime != null) {
      query += ' AND triggerTime >= ?';
      args.add(startTime.millisecondsSinceEpoch);
    }

    if (endTime != null) {
      query += ' AND triggerTime <= ?';
      args.add(endTime.millisecondsSinceEpoch);
    }

    if (isConfirmed != null) {
      query += ' AND isConfirmed = ?';
      args.add(isConfirmed ? 1 : 0);
    }

    query += ' ORDER BY triggerTime DESC';

    if (limit != null) {
      query += ' LIMIT ?';
      args.add(limit);
    }

    if (offset != null) {
      query += ' OFFSET ?';
      args.add(offset);
    }

    final maps = await db.rawQuery(query, args);
    return maps.map((map) => PumpHistoryModel.fromMap(map)).toList();
  }

  @override
  Future<List<PumpHistoryModel>> getRecentData(String symbol, {int hours = 24}) async {
    final startTime = DateTime.now().subtract(Duration(hours: hours));
    return findAll(
      symbol: symbol,
      startTime: startTime,
    );
  }

  @override
  Future<PumpStatistics> getStatistics() async {
    final db = await _dbHelper.database;

    // 总检测次数
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM PumpHistory'
    );
    final totalDetections = totalResult.first['count'] as int? ?? 0;

    // 唯一币种数
    final symbolsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT symbol) as count FROM PumpHistory'
    );
    final uniqueSymbols = symbolsResult.first['count'] as int? ?? 0;

    // 平均涨幅
    final avgResult = await db.rawQuery(
      'SELECT AVG(priceChange) as avg FROM PumpHistory'
    );
    final avgPriceChange =
      (avgResult.first['avg'] as num?)?.toDouble() ?? 0.0;

    // 确认率
    final confirmedResult = await db.rawQuery('''
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN isConfirmed = 1 AND (pullbackPercent IS NULL OR pullbackPercent > -0.5) THEN 1 ELSE 0 END) as confirmed
      FROM PumpHistory
    ''');
    final total = confirmedResult.first['total'] as int? ?? 1;
    final confirmed = confirmedResult.first['confirmed'] as int? ?? 0;
    final successRate = total > 0 ? (confirmed / total) : 0.0;

    // 热门币种 TOP 10
    final topSymbolsResult = await db.rawQuery('''
      SELECT
        symbol,
        COUNT(*) as count,
        AVG(priceChange) as avgChange,
        MAX(priceChange) as maxChange,
        SUM(CASE WHEN isConfirmed = 1 AND (pullbackPercent IS NULL OR pullbackPercent > -0.5) THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as successRate
      FROM PumpHistory
      GROUP BY symbol
      ORDER BY count DESC
      LIMIT 10
    ''');

    final topSymbols = topSymbolsResult.map((row) => SymbolStats(
      symbol: row['symbol'] as String,
      count: row['count'] as int,
      avgChange: (row['avgChange'] as num).toDouble(),
      maxChange: (row['maxChange'] as num).toDouble(),
      successRate: (row['successRate'] as num).toDouble(),
    )).toList();

    // 按小时统计
    final hourlyResult = await db.rawQuery('''
      SELECT
        CAST(strftime('%H', datetime(triggerTime/1000, 'unixepoch')) AS INTEGER) as hour,
        COUNT(*) as count
      FROM PumpHistory
      GROUP BY hour
      ORDER BY hour
    ''');

    final detectionsByHour = hourlyResult.map((row) => HourlyCount(
      hour: row['hour'] as int,
      count: row['count'] as int,
    )).toList();

    return PumpStatistics(
      totalDetections: totalDetections,
      uniqueSymbols: uniqueSymbols,
      avgPriceChange: avgPriceChange,
      successRate: successRate,
      topSymbols: topSymbols,
      detectionsByHour: detectionsByHour,
    );
  }

  @override
  Future<List<SymbolStats>> getTopSymbols(int limit) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT
        symbol,
        COUNT(*) as count,
        AVG(priceChange) as avgChange,
        MAX(priceChange) as maxChange,
        SUM(CASE WHEN isConfirmed = 1 AND (pullbackPercent IS NULL OR pullbackPercent > -0.5) THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as successRate
      FROM PumpHistory
      GROUP BY symbol
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);

    return result.map((row) => SymbolStats(
      symbol: row['symbol'] as String,
      count: row['count'] as int,
      avgChange: (row['avgChange'] as num).toDouble(),
      maxChange: (row['maxChange'] as num).toDouble(),
      successRate: (row['successRate'] as num).toDouble(),
    )).toList();
  }

  @override
  Future<void> updatePullback(int id, double lowPrice, int lowTime) async {
    final db = await _dbHelper.database;

    final pumpResult = await db.query(
      'PumpHistory',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (pumpResult.isEmpty) return;

    final pump = PumpHistoryModel.fromMap(pumpResult.first);
    final pullbackPercent = ((lowPrice - pump.peakPrice) / pump.peakPrice) * 100;

    await db.update(
      'PumpHistory',
      {
        'subsequentLow': lowPrice,
        'subsequentLowTime': lowTime,
        'pullbackPercent': pullbackPercent,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> markConfirmed(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'PumpHistory',
      {'isConfirmed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final db = await _dbHelper.database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .millisecondsSinceEpoch;

    await db.delete(
      'PumpHistory',
      where: 'triggerTime < ?',
      whereArgs: [cutoffTime],
    );
  }

  @override
  Future<int> getDatabaseSize() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM PumpHistory
    ''');
    return result.first['count'] as int? ?? 0;
  }
}

/// 内存实现 (降级方案)
class MemoryPumpRepository implements PumpRepository {
  final List<PumpHistoryModel> _pumps = [];

  @override
  Future<void> save(PumpHistoryModel pump) async {
    _pumps.add(pump);
  }

  @override
  Future<void> saveAll(List<PumpHistoryModel> pumps) async {
    _pumps.addAll(pumps);
  }

  @override
  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  }) async {
    var result = _pumps.toList();

    if (symbol != null) {
      result = result.where((p) => p.symbol == symbol).toList();
    }

    if (startTime != null) {
      result = result.where((p) => p.triggerTime >= startTime.millisecondsSinceEpoch).toList();
    }

    if (endTime != null) {
      result = result.where((p) => p.triggerTime <= endTime.millisecondsSinceEpoch).toList();
    }

    if (isConfirmed != null) {
      result = result.where((p) => p.confirmed == isConfirmed).toList();
    }

    result.sort((a, b) => b.triggerTime.compareTo(a.triggerTime));

    if (offset != null && offset > 0) {
      result = result.skip(offset).toList();
    }

    if (limit != null && limit > 0) {
      result = result.take(limit).toList();
    }

    return result;
  }

  @override
  Future<List<PumpHistoryModel>> getRecentData(String symbol, {int hours = 24}) async {
    final startTime = DateTime.now().subtract(Duration(hours: hours));
    return findAll(
      symbol: symbol,
      startTime: startTime,
    );
  }

  @override
  Future<PumpStatistics> getStatistics() async {
    return PumpStatistics(
      totalDetections: _pumps.length,
      uniqueSymbols: _pumps.map((p) => p.symbol).toSet().length,
      avgPriceChange: _pumps.isEmpty ? 0 :
      _pumps.map((p) => p.priceChange).reduce((a,b) => a+b) / _pumps.length,
      successRate: 0.0,
      topSymbols: [],
      detectionsByHour: [],
    );
  }

  @override
  Future<List<SymbolStats>> getTopSymbols(int limit) async {
    return [];
  }

  @override
  Future<void> updatePullback(int id, double lowPrice, int lowTime) async {
    final index = _pumps.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final pump = _pumps[index];
      final pullbackPercent = ((lowPrice - pump.peakPrice) / pump.peakPrice) * 100;
      _pumps[index] = pump.copyWith(
        subsequentLow: lowPrice,
        subsequentLowTime: lowTime,
        pullbackPercent: pullbackPercent,
      );
    }
  }

  @override
  Future<void> markConfirmed(int id) async {
    final index = _pumps.indexWhere((p) => p.id == id);
    if (index >= 0) {
      _pumps[index] = _pumps[index].copyWith(isConfirmed: 1);
    }
  }

  @override
  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .millisecondsSinceEpoch;
    _pumps.removeWhere((p) => p.triggerTime < cutoffTime);
  }

  @override
  Future<int> getDatabaseSize() async {
    return _pumps.length;
  }
}
