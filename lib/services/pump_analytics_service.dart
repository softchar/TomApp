import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/binance_api_service.dart';

class PumpAnalyticsService {
  final PumpRepository _repository;
  final PumpConfig _config;
  final BinanceApiService _apiService = BinanceApiService();

  PumpAnalyticsService({
    required PumpRepository repository,
    required PumpConfig config,
  })  : _repository = repository,
        _config = config;

  /// 获取统计数据
  Future<PumpStatistics> getStatistics() async {
    return await _repository.getStatistics();
  }

  /// 获取热门币种
  Future<List<SymbolStats>> getTopSymbols(int limit) async {
    return await _repository.getTopSymbols(limit);
  }

  /// 执行回撤分析
  Future<void> analyzePullbacks() async {
    try {
      final unconfirmed = await _repository.findAll(isConfirmed: false);

      for (final pump in unconfirmed) {
        final age = DateTime.now().millisecondsSinceEpoch - pump.triggerTime;
        final maxAge = Duration(minutes: _config.pullbackMonitorMinutes).inMilliseconds;

        if (age < maxAge) {
          // 还在监控期内，获取当前价格
          try {
            final currentPrice = await _getCurrentPrice(pump.symbol);

            if (currentPrice != null) {
              final pullback = (currentPrice - pump.peakPrice) / pump.peakPrice * 100;

              if (pump.pullbackPercent == null || pullback < pump.pullbackPercent!) {
                await _repository.updatePullback(
                  pump.id!,
                  currentPrice,
                  DateTime.now().millisecondsSinceEpoch,
                );
              }
            }
          } catch (e) {
            debugPrint('获取 ${pump.symbol} 价格失败: $e');
          }
        } else {
          // 监控期结束，标记确认
          await _repository.markConfirmed(pump.id!);
        }
      }
    } catch (e) {
      debugPrint('回撤分析失败: $e');
    }
  }

  /// 获取币种详情统计
  Future<SymbolDetailStats> getSymbolStats(String symbol) async {
    final recent = await _repository.findAll(
      symbol: symbol,
      limit: 100,
    );

    if (recent.isEmpty) {
      return SymbolDetailStats(
        symbol: symbol,
        totalDetections: 0,
        avgChange: 0,
        maxChange: 0,
        minChange: 0,
        successRate: 0,
        recentDetections: [],
      );
    }

    final changes = recent.map((e) => e.priceChange).toList();
    final avgChange = changes.reduce((a, b) => a + b) / changes.length;
    final maxChange = changes.reduce((a, b) => a > b ? a : b);
    final minChange = changes.reduce((a, b) => a < b ? a : b);

    final confirmedCount = recent.where((p) =>
      p.confirmed && (p.pullbackPercent == null || p.pullbackPercent! > -0.5)
    ).length;
    final successRate = confirmedCount / recent.length;

    return SymbolDetailStats(
      symbol: symbol,
      totalDetections: recent.length,
      avgChange: avgChange,
      maxChange: maxChange,
      minChange: minChange,
      successRate: successRate,
      recentDetections: recent.take(10).toList(),
    );
  }

  /// 清理旧数据
  Future<void> cleanOldData() async {
    await _repository.cleanOldData(daysToKeep: _config.archiveDataDays);
  }

  Future<double?> _getCurrentPrice(String symbol) async {
    try {
      final rates = await _apiService.getUSDTFuturesRates();
      final symbolRate = rates.firstWhere(
        (r) => r.symbol == symbol,
        orElse: () => throw Exception('Symbol not found'),
      );
      return symbolRate.markPrice;
    } catch (e) {
      debugPrint('获取 $symbol 价格失败: $e');
      return null;
    }
  }
}

/// 币种详情统计
class SymbolDetailStats {
  final String symbol;
  final int totalDetections;
  final double avgChange;
  final double maxChange;
  final double minChange;
  final double successRate;
  final List<PumpHistoryModel> recentDetections;

  SymbolDetailStats({
    required this.symbol,
    required this.totalDetections,
    required this.avgChange,
    required this.maxChange,
    required this.minChange,
    required this.successRate,
    required this.recentDetections,
  });
}
