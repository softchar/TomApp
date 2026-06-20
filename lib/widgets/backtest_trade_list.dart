import 'package:flutter/material.dart';
import 'package:tomapp/models/backtest_trade.dart';
import 'package:tomapp/services/theme_provider.dart';

/// 排序列枚举。
enum _SortColumn {
  symbol,
  entryTime,
  exitTime,
  pnl,
  rMultiple,
}

/// 排序方向。
enum _SortDirection { asc, desc }

/// 可排序交易列表 Widget。
///
/// 5 列：币种 / 进场时间-价格 / 出场时间-价格 / PnL / R 倍数。
/// 每列标题可点击排序，活跃排序列显示箭头指示器。
/// 行点击触发 onTradeTap 导航回调。
class BacktestTradeList extends StatefulWidget {
  /// 交易记录列表。
  final List<BacktestTrade> trades;

  /// 行点击回调（传入被点击的 BacktestTrade）。
  final void Function(BacktestTrade)? onTradeTap;

  const BacktestTradeList({
    super.key,
    required this.trades,
    this.onTradeTap,
  });

  @override
  State<BacktestTradeList> createState() => _BacktestTradeListState();
}

class _BacktestTradeListState extends State<BacktestTradeList> {
  _SortColumn _sortColumn = _SortColumn.entryTime;
  _SortDirection _sortDirection = _SortDirection.asc;

  List<BacktestTrade> get _sortedTrades {
    final sorted = List<BacktestTrade>.from(widget.trades);
    sorted.sort((a, b) {
      int result;
      switch (_sortColumn) {
        case _SortColumn.symbol:
          result = a.symbol.compareTo(b.symbol);
          break;
        case _SortColumn.entryTime:
          result = a.entryTime.compareTo(b.entryTime);
          break;
        case _SortColumn.exitTime:
          final aTime = a.exitTime ?? DateTime(2099);
          final bTime = b.exitTime ?? DateTime(2099);
          result = aTime.compareTo(bTime);
          break;
        case _SortColumn.pnl:
          result = a.pnl.compareTo(b.pnl);
          break;
        case _SortColumn.rMultiple:
          result = a.rMultiple.compareTo(b.rMultiple);
          break;
      }
      return _sortDirection == _SortDirection.asc ? result : -result;
    });
    return sorted;
  }

  void _toggleSort(_SortColumn column) {
    if (_sortColumn == column) {
      _sortDirection = _sortDirection == _SortDirection.asc
          ? _SortDirection.desc
          : _SortDirection.asc;
    } else {
      _sortColumn = column;
      _sortDirection = _SortDirection.asc;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            '无符合条件的交易记录',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final sorted = _sortedTrades;

    return Column(
      children: [
        // 列标题行
        _buildHeaderRow(),
        const Divider(height: 1, color: AppColors.border),
        // 数据行列表
        ...sorted.map((trade) => _buildDataRow(trade)),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          _buildHeaderCell('币种', _SortColumn.symbol, flex: 2),
          _buildHeaderCell('进场', _SortColumn.entryTime, flex: 3),
          _buildHeaderCell('出场', _SortColumn.exitTime, flex: 3),
          _buildHeaderCell('PnL', _SortColumn.pnl, flex: 2),
          _buildHeaderCell('R倍数', _SortColumn.rMultiple, flex: 2),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label,
    _SortColumn column, {
    int flex = 1,
  }) {
    final isActive = _sortColumn == column;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () => _toggleSort(column),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Icon(
                _sortDirection == _SortDirection.asc
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 12,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(BacktestTrade trade) {
    final timeFormat = _TimeFormatter();

    return InkWell(
      onTap: () => widget.onTradeTap?.call(trade),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // 币种
            Expanded(
              flex: 2,
              child: Text(
                trade.symbol.replaceAll('USDT', ''),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 进场时间-价格
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeFormat.format(trade.entryTime),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    trade.entryPrice.toStringAsFixed(2),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // 出场时间-价格
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trade.exitTime != null
                        ? timeFormat.format(trade.exitTime!)
                        : '持仓中',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    trade.exitPrice != null
                        ? trade.exitPrice!.toStringAsFixed(2)
                        : '—',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // PnL
            Expanded(
              flex: 2,
              child: Text(
                '${trade.pnl >= 0 ? '+' : ''}${trade.pnl.toStringAsFixed(2)}R',
                style: AppTextStyles.bodySmall.copyWith(
                  color: trade.pnl >= 0 ? AppColors.gain : AppColors.loss,
                ),
              ),
            ),
            // R 倍数
            Expanded(
              flex: 2,
              child: Text(
                '${trade.rMultiple >= 0 ? '+' : ''}${trade.rMultiple.toStringAsFixed(2)}R',
                style: AppTextStyles.bodySmall.copyWith(
                  color: trade.rMultiple >= 0 ? AppColors.gain : AppColors.loss,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 时间格式化器：输出 "MM-dd HH:mm" 格式。
class _TimeFormatter {
  String format(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
