import 'package:flutter/material.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/favorite_service.dart';
import 'package:tomapp/services/theme_provider.dart' show AppColors, AppSpacing, AppRadius;
import 'package:intl/intl.dart';

class PumpHistoryItem extends StatefulWidget {
  final PumpHistoryModel pump;
  final VoidCallback onTap;

  const PumpHistoryItem({
    super.key,
    required this.pump,
    required this.onTap,
  });

  @override
  State<PumpHistoryItem> createState() => _PumpHistoryItemState();
}

class _PumpHistoryItemState extends State<PumpHistoryItem> {
  final FavoriteService _favoriteService = FavoriteService();
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = _favoriteService.isFavorite(widget.pump.symbol);
    _favoriteService.addListener(_onFavoriteChanged);
  }

  @override
  void dispose() {
    _favoriteService.removeListener(_onFavoriteChanged);
    super.dispose();
  }

  void _onFavoriteChanged() {
    if (mounted) {
      setState(() {
        _isFavorite = _favoriteService.isFavorite(widget.pump.symbol);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    await _favoriteService.toggleFavorite(widget.pump.symbol);
  }

  Color _getPumpColor(double percent) {
    if (percent >= 5) return AppColors.primary; // Gold for big gains
    if (percent >= 3) return const Color(0xFFFB923C); // Orange
    return const Color(0xFFFACC15); // Yellow
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final isPositive = widget.pump.priceChange >= 0;
    final pumpColor = _getPumpColor(widget.pump.priceChange.abs());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // 图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pumpColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.local_fire_department,
                  color: pumpColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // 主要信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pump.symbol.replaceAll('USDT', ''),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(widget.pump.triggerDateTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                    '${isPositive ? '+' : ''}${widget.pump.priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: pumpColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.pump.pullbackPercent != null) ...[
                        Icon(
                          widget.pump.pullbackPercent! < 0
                              ? Icons.arrow_downward
                              : widget.pump.pullbackPercent! > 0
                                  ? Icons.arrow_upward
                                  : Icons.remove,
                          size: 12,
                          color: widget.pump.pullbackPercent! < 0
                              ? AppColors.gain
                              : widget.pump.pullbackPercent! > 0
                                  ? AppColors.loss
                                  : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.pump.pullbackPercent!.toStringAsFixed(2)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      Icon(
                        widget.pump.confirmed
                            ? Icons.check_circle
                            : Icons.pending_outlined,
                        size: 14,
                        color: widget.pump.confirmed
                            ? AppColors.loss
                            : AppColors.warning,
                      ),
                    ],
                  ),
                ],
              ),

              // 收藏按钮
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: _toggleFavorite,
                tooltip: _isFavorite ? '取消收藏' : '收藏',
                constraints: const BoxConstraints(minWidth: 40),
                padding: EdgeInsets.zero,
                splashRadius: 20,
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
