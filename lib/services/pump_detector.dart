import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/strategies/pump_detection_strategy.dart';
import 'package:tomapp/services/strategies/time_based_strategy.dart';
import 'package:tomapp/services/strategies/adaptive_strategy.dart';

class PricePoint {
  final double price;
  final DateTime timestamp;

  PricePoint({required this.price, required this.timestamp});
}

class PumpDetector {
  final PumpConfig _config;
  final PumpRepository _repository;
  final List<PumpDetectionStrategy> _strategies;

  // 存储每个合约的价格历史 (最多保留 2 分钟的数据)
  final Map<String, List<PricePoint>> _priceHistory = {};

  // 存储每个合约的最后通知时间
  final Map<String, DateTime> _lastNotificationTime = {};

  PumpDetector({
    PumpConfig? config,
    required PumpRepository repository,
  })  : _config = config ?? PumpConfig(),
        _repository = repository,
        _strategies = [
          TimeBasedStrategy(),
          AdaptiveStrategy(repository),
        ];

  /// 计算有效阈值（应用所有策略）
  Future<double> calculateEffectiveThreshold(String symbol) async {
    double threshold = _config.baseThreshold;

    for (final strategy in _strategies) {
      if (strategy is AdaptiveStrategy) {
        final activityScore = await strategy.calculateActivityScore(symbol);
        threshold = strategy.adjustWithActivity(threshold, activityScore);
      } else {
        threshold += strategy.adjust(threshold);
      }
    }

    // 确保在合理范围内
    return threshold.clamp(_config.minThreshold, _config.maxThreshold);
  }

  /// 获取使用的策略类型名称（用于记录）
  String getStrategyTypeName() {
    return _strategies.map((s) => s.name).join('+');
  }

  /// 获取价格点数量 (用于测试)
  int getPricePointCount(String symbol) {
    return _priceHistory[symbol]?.length ?? 0;
  }

  /// 添加价格数据点
  void addPricePoint(String symbol, double price, DateTime timestamp) {
    _priceHistory.putIfAbsent(symbol, () => []);

    _priceHistory[symbol]!.add(PricePoint(price: price, timestamp: timestamp));

    // 清理 2 分钟前的旧数据
    _cleanupOldPoints(symbol, timestamp);

    // 内存管理：超过 200 个币种时清理不活跃数据
    if (_priceHistory.length > 200) {
      _cleanupInactiveSymbols();
    }
  }

  /// 检测是否触发快速上涨
  /// 返回 PumpModel 如果触发，否则返回 null
  Future<PumpModel?> check(String symbol, double currentPrice, DateTime timestamp) async {
    // 检查冷却期
    if (_isInCooldown(symbol, timestamp)) {
      return null;
    }

    // 添加当前价格点
    addPricePoint(symbol, currentPrice, timestamp);

    // 计算有效阈值
    final effectiveThreshold = await calculateEffectiveThreshold(symbol);

    // 计算涨幅
    final change = _calculate1MinChange(symbol, timestamp);
    if (change == null || change <= effectiveThreshold) {
      return null;
    }

    // 记录通知时间
    _lastNotificationTime[symbol] = timestamp;

    return PumpModel(
      symbol: symbol,
      priceChange: change,
      triggerTime: timestamp,
      currentPrice: currentPrice,
    );
  }

  /// 重置冷却时间 (用于测试)
  void resetCooldown(String symbol) {
    _lastNotificationTime.remove(symbol);
  }

  double? _calculate1MinChange(String symbol, DateTime currentTime) {
    final points = _priceHistory[symbol];
    if (points == null || points.length < 2) {
      return null;
    }

    // 找到 1 分钟前的价格
    final oneMinuteAgo = currentTime.subtract(const Duration(minutes: 1));
    PricePoint? baselinePoint;

    for (final point in points) {
      if (point.timestamp.isBefore(oneMinuteAgo) ||
          point.timestamp.isAtSameMomentAs(oneMinuteAgo)) {
        baselinePoint = point;
      } else {
        break;
      }
    }

    if (baselinePoint == null) {
      return null;
    }

    final currentPrice = points.last.price;
    final baselinePrice = baselinePoint.price;

    return ((currentPrice - baselinePrice) / baselinePrice) * 100;
  }

  bool _isInCooldown(String symbol, DateTime currentTime) {
    final lastNotified = _lastNotificationTime[symbol];
    if (lastNotified == null) {
      return false;
    }

    final elapsed = currentTime.difference(lastNotified);
    return elapsed.inMinutes < 1; // 默认 1 分钟冷却
  }

  void _cleanupOldPoints(String symbol, DateTime currentTime) {
    final cutoff = currentTime.subtract(const Duration(minutes: 2));
    _priceHistory[symbol]!.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }

  void _cleanupInactiveSymbols() {
    // 清理超过 5 分钟没有更新的币种数据
    final cutoff = DateTime.now().subtract(Duration(minutes: 5));
    _priceHistory.removeWhere((symbol, points) {
      if (points.isEmpty) return true;
      return points.last.timestamp.isBefore(cutoff);
    });
  }
}
