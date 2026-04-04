import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/macd_data.dart';

/// MACD指标图表组件
///
/// 使用fl_chart库显示MACD指标，包含DIF线、DEA线和MACD柱状图
class MacdChartWidget extends StatelessWidget {
  /// MACD数据
  final MACDData macdData;

  const MacdChartWidget({
    super.key,
    required this.macdData,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(colorScheme, 'DIF', Colors.blue),
              const SizedBox(width: 16),
              _buildLegend(colorScheme, 'DEA', Colors.orange),
              const SizedBox(width: 16),
              _buildLegend(colorScheme, 'MACD', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          Expanded(
            child: BarChart(
              _buildChartData(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  /// Build legend item
  Widget _buildLegend(ColorScheme colorScheme, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Build chart data
  BarChartData _buildChartData(ColorScheme colorScheme) {
    // Prepare data for MACD bar chart
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < macdData.length; i++) {
      if (macdData.macd[i] != null) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: macdData.macd[i]!.abs(),
                color: macdData.macd[i]! >= 0 ? Colors.red : Colors.green,
                width: 4,
              ),
            ],
          ),
        );
      }
    }

    // Prepare line indicator data for DIF and DEA
    // Note: BarChart doesn't support line overlays directly in fl_chart
    // We'll use the last values as horizontal reference lines
    double? lastDif, lastDea;
    for (int i = macdData.length - 1; i >= 0; i--) {
      if (macdData.dif[i] != null && lastDif == null) {
        lastDif = macdData.dif[i];
      }
      if (macdData.dea[i] != null && lastDea == null) {
        lastDea = macdData.dea[i];
      }
      if (lastDif != null && lastDea != null) break;
    }

    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: const FlTitlesData(
        show: false,
      ),
      borderData: FlBorderData(
        show: false,
      ),
      barGroups: barGroups,
      // Add horizontal reference lines for current DIF and DEA values
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (lastDif != null)
            HorizontalLine(
              y: lastDif,
              color: Colors.blue.withValues(alpha: 0.8),
              strokeWidth: 2,
              dashArray: [5, 5],
            ),
          if (lastDea != null)
            HorizontalLine(
              y: lastDea,
              color: Colors.orange.withValues(alpha: 0.8),
              strokeWidth: 2,
              dashArray: [5, 5],
            ),
        ],
      ),
    );
  }
}
