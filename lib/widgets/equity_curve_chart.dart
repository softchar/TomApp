import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tomapp/services/theme_provider.dart';

/// 双权益曲线折线图封装（fl_chart LineChart）。
///
/// 渲染零成本（橙色实线）和含成本（紫色虚线）两条权益曲线。
/// 两条曲线按交易序号（tradeIndex）在 X 轴展开。
class EquityCurveChart extends StatelessWidget {
  /// 零成本权益曲线数据：每笔交易后的累计 R 倍数。
  final List<({int tradeIndex, double cumulativeR})> zeroCostData;

  /// 含成本权益曲线数据：每笔交易后的累计 R 倍数（含成本）。
  final List<({int tradeIndex, double cumulativeR})> withCostData;

  const EquityCurveChart({
    super.key,
    required this.zeroCostData,
    required this.withCostData,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                right: AppSpacing.md,
                bottom: AppSpacing.xs,
                left: AppSpacing.sm,
              ),
              child: LineChart(
                _buildLineChartData(),
                duration: const Duration(milliseconds: 250),
              ),
            ),
          ),
          // 图例
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  color: AppColors.primary,
                  label: '零成本',
                  isDashed: false,
                ),
                const SizedBox(width: AppSpacing.lg),
                _buildLegendItem(
                  color: AppColors.accent,
                  label: '含成本',
                  isDashed: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required bool isDashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            border: isDashed
                ? Border(
                    top: BorderSide(
                      color: color,
                      width: 2,
                    ),
                  )
                : null,
          ),
          child: isDashed
              ? CustomPaint(
                  painter: _DashPainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  LineChartData _buildLineChartData() {
    // 计算 Y 轴范围（含正负值）
    double minY = 0;
    double maxY = 0;
    for (final d in zeroCostData) {
      if (d.cumulativeR < minY) minY = d.cumulativeR;
      if (d.cumulativeR > maxY) maxY = d.cumulativeR;
    }
    for (final d in withCostData) {
      if (d.cumulativeR < minY) minY = d.cumulativeR;
      if (d.cumulativeR > maxY) maxY = d.cumulativeR;
    }

    // 留出 10% 边距
    final yRange = (maxY - minY).abs();
    final yPadding = yRange > 0 ? yRange * 0.1 : 1.0;
    minY -= yPadding;
    maxY += yPadding;

    return LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: _calcGridInterval(minY, maxY),
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: AppColors.border,
            strokeWidth: 0.5,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: _calcBottomInterval(),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '交易 ${spot.x.toInt()}\n${spot.y.toStringAsFixed(3)} R',
                AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        // 零成本曲线（橙色实线）
        _buildLineBarData(
          spots: zeroCostData
              .map((d) => FlSpot(
                    d.tradeIndex.toDouble(),
                    d.cumulativeR,
                  ))
              .toList(),
          color: AppColors.primary,
          dashArray: null,
        ),
        // 含成本曲线（紫色虚线）
        _buildLineBarData(
          spots: withCostData
              .map((d) => FlSpot(
                    d.tradeIndex.toDouble(),
                    d.cumulativeR,
                  ))
              .toList(),
          color: AppColors.accent,
          dashArray: [8, 4],
        ),
      ],
      // 零线（y=0 水平参考线）
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (minY <= 0 && maxY >= 0)
            HorizontalLine(
              y: 0,
              color: AppColors.border,
              strokeWidth: 1,
              label: HorizontalLineLabel(
                show: true,
                labelResolver: (line) => '0',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineBarData({
    required List<FlSpot> spots,
    required Color color,
    List<int>? dashArray,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      dashArray: dashArray,
    );
  }

  double _calcGridInterval(double minY, double maxY) {
    final range = (maxY - minY).abs();
    if (range <= 0) return 1;
    if (range <= 5) return 1;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    return (range / 5).ceilToDouble();
  }

  double _calcBottomInterval() {
    final count = zeroCostData.length;
    if (count <= 10) return 1;
    if (count <= 50) return 5;
    if (count <= 100) return 10;
    return (count / 10).ceilToDouble();
  }
}

/// 虚线绘制器（用于图例中的虚线色块）。
class _DashPainter extends CustomPainter {
  final Color color;

  _DashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashGap = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset((startX + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
