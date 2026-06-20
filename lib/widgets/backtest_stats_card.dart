import 'package:flutter/material.dart';
import 'package:tomapp/services/theme_provider.dart';

/// 单张回测统计卡片 Widget。
///
/// 接收 label（如 "胜率"）和 value（如 "65.2%"），
/// 在 Column 中垂直排列显示。
/// 正值用 AppColors.gain（金色），负值用 AppColors.loss（绿色）。
class BacktestStatsCard extends StatelessWidget {
  /// 统计指标名称。
  final String label;

  /// 统计指标值（含 +/- 前缀以保证色盲可读）。
  final String value;

  /// 值是否为正数（用于颜色选择）。
  final bool isPositive;

  const BacktestStatsCard({
    super.key,
    required this.label,
    required this.value,
    this.isPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isPositive ? AppColors.gain : AppColors.loss,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
