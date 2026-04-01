import 'package:tomapp/models/pump_model.dart';

class PricePoint {
  final double price;
  final DateTime timestamp;

  PricePoint({required this.price, required this.timestamp});
}

class PumpDetector {
  final double threshold;
  final int cooldownMinutes;

  // 存储每个合约的价格历史 (最多保留 2 分钟的数据)
  final Map<String, List<PricePoint>> _priceHistory = {};

  // 存储每个合约的最后通知时间
  final Map<String, DateTime> _lastNotificationTime = {};

  PumpDetector({required this.threshold, required this.cooldownMinutes});

  /// 添加价格数据点
  void addPricePoint(String symbol, double price, DateTime timestamp) {
    _priceHistory.putIfAbsent(symbol, () => []);

    _priceHistory[symbol]!.add(PricePoint(price: price, timestamp: timestamp));

    // 清理 2 分钟前的旧数据
    _cleanupOldPoints(symbol, timestamp);
  }

  /// 检测是否触发快速上涨
  /// 返回 PumpModel 如果触发，否则返回 null
  PumpModel? check(String symbol, double currentPrice, DateTime timestamp) {
    // 检查冷却期
    if (_isInCooldown(symbol, timestamp)) {
      return null;
    }

    // 添加当前价格点
    addPricePoint(symbol, currentPrice, timestamp);

    // 计算涨幅
    final change = _calculate1MinChange(symbol, timestamp);
    if (change == null || change <= threshold) {
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

  /// 获取价格点数量 (用于测试)
  int getPricePointCount(String symbol) {
    return _priceHistory[symbol]?.length ?? 0;
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
    return elapsed.inMinutes < cooldownMinutes;
  }

  void _cleanupOldPoints(String symbol, DateTime currentTime) {
    final cutoff = currentTime.subtract(const Duration(minutes: 2));
    _priceHistory[symbol]!.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }
}
