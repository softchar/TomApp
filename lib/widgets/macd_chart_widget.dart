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
            child: LineChart(
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
  LineChartData _buildChartData(ColorScheme colorScheme) {
    // Prepare data lists for DIF, DEA lines and MACD bars
    final validDif = <FlSpot>[];
    final validDea = <FlSpot>[];
    final validMacd = <FlSpot>[];

    for (int i = 0; i < macdData.length; i++) {
      // Add DIF points
      if (macdData.dif[i] != null) {
        validDif.add(FlSpot(i.toDouble(), macdData.dif[i]!));
      }
      // Add DEA points
      if (macdData.dea[i] != null) {
        validDea.add(FlSpot(i.toDouble(), macdData.dea[i]!));
      }
      // Add MACD bars (displayed as a line for simplicity in LineChart)
      if (macdData.macd[i] != null) {
        validMacd.add(FlSpot(i.toDouble(), macdData.macd[i]!));
      }
    }

    return LineChartData(
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
      // DIF line
      lineBarsData: [
        LineChartBarData(
          spots: validDif,
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // DEA line
        LineChartBarData(
          spots: validDea,
          isCurved: true,
          color: Colors.orange,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // MACD histogram (shown as line for now)
        LineChartBarData(
          spots: validMacd,
          isCurved: false,
          color: Colors.red,
          barWidth: 1,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    );
  }
}
