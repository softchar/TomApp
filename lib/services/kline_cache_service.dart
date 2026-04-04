import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/kline_data.dart';

/// K线数据缓存服务
///
/// 提供K线数据的本地缓存功能，减少API调用并提供即时加载
class KlineCacheService {
  // SharedPreferences keys
  static const String _lastSymbolKey = 'kline_last_symbol';
  static const String _lastIntervalKey = 'kline_last_interval';

  // Cache duration constants
  static const int _cacheValidDuration = 3600000; // 1 hour in milliseconds
  static const int _maxCacheAge = 604800000; // 7 days in milliseconds

  /// 获取缓存的K线数据
  ///
  /// [symbol] 交易对符号，如 'BTCUSDT'
  /// [interval] 时间间隔，如 '15m'
  ///
  /// 返回缓存的K线数据列表，如果缓存不存在或已过期则返回null
  Future<List<KlineData>?> getCached(String symbol, String interval) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'kline_cache',
        where: 'symbol = ? AND interval = ?',
        whereArgs: [symbol, interval],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      final cacheEntry = results.first;
      final cachedAt = cacheEntry['cached_at'] as int;
      final dataJson = cacheEntry['data'] as String;

      // 检查缓存是否有效（1小时内）
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cachedAt > _cacheValidDuration) {
        // 缓存已过期
        return null;
      }

      // 解析JSON数据
      final List<dynamic> decoded = jsonDecode(dataJson);
      return decoded.map((item) => KlineData.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      // 任何错误都返回null，缓存失败不应影响主流程
      return null;
    }
  }

  /// 保存K线数据到缓存
  ///
  /// [symbol] 交易对符号
  /// [interval] 时间间隔
  /// [data] K线数据列表
  Future<void> saveCache(String symbol, String interval, List<KlineData> data) async {
    try {
      // 序列化数据为JSON
      final dataJson = jsonEncode(data.map((item) => item.toMap()).toList());

      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 插入或替换缓存数据
      await db.insert(
        'kline_cache',
        {
          'symbol': symbol,
          'interval': interval,
          'data': dataJson,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // 静默捕获错误，缓存失败不应影响主流程
    }
  }

  /// 检查缓存是否有效
  ///
  /// 注意：实际的缓存验证在getCached方法中进行
  /// 这是一个辅助方法，用于快速检查缓存是否存在
  bool isCacheValid(String symbol, String interval) {
    // 实际的验证逻辑在getCached中实现
    // 这里返回true作为占位符
    return true;
  }

  /// 清理过期的缓存数据
  ///
  /// 删除7天前的缓存条目
  Future<void> cleanOldData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final expireTime = now - _maxCacheAge;

      await db.delete(
        'kline_cache',
        where: 'cached_at < ?',
        whereArgs: [expireTime],
      );
    } catch (e) {
      // 静默捕获错误
    }
  }

  /// 清除所有缓存数据
  Future<void> clearAll() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('kline_cache');
    } catch (e) {
      // 静默捕获错误
    }
  }

  /// 获取缓存大小
  ///
  /// 返回缓存数据的总大小（字符数）
  Future<int> getCacheSize() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        'SELECT SUM(LENGTH(data)) as total_size FROM kline_cache',
      );

      if (result.isNotEmpty && result.first['total_size'] != null) {
        return result.first['total_size'] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// 保存用户偏好设置
  ///
  /// [symbol] 最后查看的交易对
  /// [interval] 最后使用的时间间隔
  Future<void> savePreferences(String symbol, String interval) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSymbolKey, symbol);
      await prefs.setString(_lastIntervalKey, interval);
    } catch (e) {
      // 静默捕获错误
    }
  }

  /// 获取最后查看的交易对
  ///
  /// 如果没有保存的偏好，返回默认值 'BTCUSDT'
  Future<String> getLastSymbol() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastSymbolKey) ?? 'BTCUSDT';
    } catch (e) {
      return 'BTCUSDT';
    }
  }

  /// 获取最后使用的时间间隔
  ///
  /// 如果没有保存的偏好，返回默认值 '15m'
  Future<String> getLastInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastIntervalKey) ?? '15m';
    } catch (e) {
      return '15m';
    }
  }
}
