import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/pump_analytics_service.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:intl/intl.dart';

class PumpDetailScreen extends StatefulWidget {
  final PumpHistoryModel pump;

  const PumpDetailScreen({super.key, required this.pump});

  @override
  State<PumpDetailScreen> createState() => _PumpDetailScreenState();
}

class _PumpDetailScreenState extends State<PumpDetailScreen> {
  late final PumpRepository _repository;
  late final PumpAnalyticsService _analytics;
  SymbolDetailStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = RepositoryFactory.create();
    _analytics = PumpAnalyticsService(
      repository: _repository,
      config: PumpConfig(),
    );
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _analytics.getSymbolStats(widget.pump.symbol);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final isPositive = widget.pump.priceChange >= 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.pump.symbol),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 检测信息卡片
            _buildInfoCard(isDark),
            const SizedBox(height: 16),

            // 价格走势图占位
            _buildChartPlaceholder(isDark),
            const SizedBox(height: 16),

            // 后续走势
            _buildPullbackSection(isDark),
            const SizedBox(height: 16),

            // 历史统计
            if (!_isLoading) _buildStatsSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '检测信息',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('检测时间', DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.pump.triggerDateTime)),
            const SizedBox(height: 8),
            _buildInfoRow('基准价格', '\$${widget.pump.basePrice.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow('峰值价格', '\$${widget.pump.peakPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildInfoRow(
              '涨幅',
              '${widget.pump.priceChange >= 0 ? '+' : ''}${widget.pump.priceChange.toStringAsFixed(2)}%',
              valueColor: widget.pump.priceChange >= 0 ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('策略', widget.pump.strategyType),
            const SizedBox(height: 8),
            _buildInfoRow('冷却时间', '${widget.pump.cooldownMinutes} 分钟'),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '价格走势',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '图表功能即将推出',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPullbackSection(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '后续走势',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.pump.subsequentLow != null) ...[
              _buildInfoRow('最低价', '\$${widget.pump.subsequentLow!.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _buildInfoRow(
                '回撤',
                '${widget.pump.pullbackPercent!.toStringAsFixed(2)}%',
                valueColor: widget.pump.pullbackPercent! < 0 ? Colors.red : Colors.green,
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(
                  widget.pump.confirmed ? Icons.check_circle : Icons.hourglass_empty,
                  size: 20,
                  color: widget.pump.confirmed ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.pump.confirmed ? '已确认' : '分析中',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    if (_stats == null) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '历史统计 (${widget.pump.symbol})',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('检测次数', '${_stats!.totalDetections} 次'),
            const SizedBox(height: 8),
            _buildInfoRow('平均涨幅', '+${_stats!.avgChange.toStringAsFixed(2)}%'),
            const SizedBox(height: 8),
            _buildInfoRow('最大涨幅', '+${_stats!.maxChange.toStringAsFixed(2)}%'),
            const SizedBox(height: 8),
            _buildInfoRow('确认率', '${(_stats!.successRate * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor ?? (isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }
}
