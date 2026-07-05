import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      debugPrint('KlineCacheService.getCached 失败: $e');
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
      // 缓存失败不应影响主流程
      debugPrint('KlineCacheService.saveCache 失败: $e');
    }
  }

  /// 检查缓存是否有效（基于 _cacheValidDuration 判断）
  ///
  /// 注意：实际缓存验证在 getCached 方法中执行，此方法提供快速前端判断。
  Future<bool> isCacheValid(String symbol, String interval) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'kline_cache',
        where: 'symbol = ? AND interval = ?',
        whereArgs: [symbol, interval],
        limit: 1,
      );

      if (results.isEmpty) return false;

      final cacheEntry = results.first;
      final cachedAt = cacheEntry['cached_at'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      return (now - cachedAt) <= _cacheValidDuration;
    } catch (e) {
      debugPrint('KlineCacheService.isCacheValid 失败: $e');
      return false;
    }
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
      debugPrint('KlineCacheService.cleanOldData 失败: $e');
    }
  }

  /// 清除所有缓存数据
  Future<void> clearAll() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('kline_cache');
    } catch (e) {
      debugPrint('KlineCacheService.clearAll 失败: $e');
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
        // SUM 返回 num 类型，安全转换
        final size = result.first['total_size'];
        if (size is int) return size;
        if (size is double) return size.toInt();
        return (size as num).toInt();
      }
      return 0;
    } catch (e) {
      debugPrint('KlineCacheService.getCacheSize 失败: $e');
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
      debugPrint('KlineCacheService.savePreferences 失败: $e');
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
      debugPrint('KlineCacheService.getLastSymbol 失败: $e');
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
      debugPrint('KlineCacheService.getLastInterval 失败: $e');
      return '15m';
    }
  }
}
