import 'package:flutter/material.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/favorite_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = widget.pump.priceChange >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
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
                      widget.pump.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(widget.pump.triggerDateTime),
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
                    '${isPositive ? '+' : ''}${widget.pump.priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? Colors.green : Colors.red,
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
                          size: 14,
                          color: widget.pump.pullbackPercent! < 0
                              ? Colors.red
                              : widget.pump.pullbackPercent! > 0
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.pump.pullbackPercent!.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        widget.pump.confirmed ? Icons.check_circle : Icons.hourglass_empty,
                        size: 16,
                        color: widget.pump.confirmed ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),

              // 收藏按钮
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.star : Icons.star_border,
                  color: _isFavorite ? Colors.amber : (isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
                onPressed: _toggleFavorite,
                tooltip: _isFavorite ? '取消收藏' : '收藏',
                constraints: const BoxConstraints(minWidth: 40),
                padding: EdgeInsets.zero,
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
