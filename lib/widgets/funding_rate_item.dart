import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/funding_rate.dart';

/// 单个资金费率列表项 - Material 3 风格
class FundingRateItem extends StatelessWidget {
  final FundingRate rate;
  final VoidCallback? onTap;

  const FundingRateItem({
    super.key,
    required this.rate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM/dd HH:mm');
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：交易对名称 + 间隔标签
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rate.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  _buildIntervalBadge(colorScheme),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 第二行：详细信息
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem('价格', rate.formattedMarkPrice, colorScheme),
                  ),
                  _buildDivider(colorScheme),
                  Expanded(
                    child: _buildInfoItem('费率', rate.fundingRatePercent, colorScheme),
                  ),
                  _buildDivider(colorScheme),
                  Expanded(
                    child: _buildInfoItem('下次', dateFormat.format(rate.nextFundingTime), colorScheme),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: colorScheme.outlineVariant,
    );
  }

  Widget _buildIntervalBadge(ColorScheme colorScheme) {
    final intervalText = '${rate.fundingIntervalHours}h';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: rate.fundingIntervalHours == 1
            ? colorScheme.tertiaryContainer
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        intervalText,
        style: TextStyle(
          color: rate.fundingIntervalHours == 1
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSecondaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
