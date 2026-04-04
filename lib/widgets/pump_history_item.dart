import 'package:flutter/material.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:intl/intl.dart';

class PumpHistoryItem extends StatelessWidget {
  final PumpHistoryModel pump;
  final VoidCallback onTap;

  const PumpHistoryItem({
    super.key,
    required this.pump,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = pump.priceChange >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),

              // 主要信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pump.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(pump.triggerDateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // 涨幅和回撤
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : ''}${pump.priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (pump.pullbackPercent != null) ...[
                        Icon(
                          pump.pullbackPercent! < 0
                              ? Icons.arrow_downward
                              : pump.pullbackPercent! > 0
                                  ? Icons.arrow_upward
                                  : Icons.remove,
                          size: 14,
                          color: pump.pullbackPercent! < 0
                              ? Colors.red
                              : pump.pullbackPercent! > 0
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${pump.pullbackPercent!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        pump.confirmed ? Icons.check_circle : Icons.hourglass_empty,
                        size: 16,
                        color: pump.confirmed ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }
}
