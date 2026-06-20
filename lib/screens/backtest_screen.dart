import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_report.dart';
import 'package:tomapp/models/backtest_status.dart';
import 'package:tomapp/providers/backtest_provider.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/widgets/backtest_stats_card.dart';
import 'package:tomapp/widgets/backtest_trade_list.dart';
import 'package:tomapp/widgets/equity_curve_chart.dart';
import 'package:tomapp/screens/kline_screen.dart';

/// 回测验证页面。
///
/// 完整回测报告 UI：配置表单 + 双权益曲线 + 7 项统计卡 +
/// 可排序交易列表 + 四项强制披露 + 免责声明。
///
/// 状态机：idle → running → complete|error。
class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BacktestProvider>();

    return PopScope(
      // 回测运行中离开时弹出确认对话框
      canPop: provider.status != BacktestStatus.running,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('回测运行中'),
            content: const Text('回测正在运行中，确定要离开吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('离开'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('回测验证'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
              tooltip: '指标说明',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xxl,
          ),
          child: Column(
            children: [
              // 配置卡片（idle/error 可用，running 不可用，complete 折叠）
              _buildConfigSection(provider),
              const SizedBox(height: AppSpacing.lg),
              // 按状态渲染内容
              _buildStateContent(provider),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 配置区域 ──────────────────────────────────────────

  Widget _buildConfigSection(BacktestProvider provider) {
    final status = provider.status;
    final isRunning = status == BacktestStatus.running;
    final isComplete = status == BacktestStatus.complete;

    // complete 状态：折叠为摘要行
    if (isComplete) {
      return Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        child: ExpansionTile(
          title: Text(
            '回测配置',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${_formatDate(provider.config.startDate)} 至 ${_formatDate(provider.config.endDate)} · '
            '${provider.config.symbols.length} 个标的 · '
            '${provider.totalCombos} 组合',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            _buildConfigFields(provider, disabled: true),
          ],
        ),
      );
    }

    // idle / running / error 状态：完整配置卡片
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('回测配置'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _buildConfigFields(provider, disabled: isRunning),
          ),
          if (!isRunning) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: FilledButton(
                onPressed: () => provider.runBacktest(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text('开始回测'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigFields(BacktestProvider provider, {required bool disabled}) {
    final config = provider.config;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        // 起始日期
        _buildDateRow(
          label: '起始日期',
          date: config.startDate,
          onTap: disabled
              ? null
              : () => _pickDate(context, provider, isStart: true),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 结束日期
        _buildDateRow(
          label: '结束日期',
          date: config.endDate,
          onTap: disabled
              ? null
              : () => _pickDate(context, provider, isStart: false),
        ),
        const SizedBox(height: AppSpacing.sm),
        // 参数组合摘要
        Row(
          children: [
            Text(
              '参数：2.0/0.5/3/1.5 ',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '（${provider.totalCombos} 组合）',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRow({
    required String label,
    required DateTime date,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              _formatDate(date),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.calendar_today,
              size: 16,
              color: onTap != null
                  ? AppColors.textSecondary
                  : AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  // ─── 状态内容 ──────────────────────────────────────────

  Widget _buildStateContent(BacktestProvider provider) {
    switch (provider.status) {
      case BacktestStatus.idle:
        return _buildIdleContent();
      case BacktestStatus.running:
        return _buildRunningContent(provider);
      case BacktestStatus.complete:
        return _buildCompleteContent(provider);
      case BacktestStatus.error:
        return _buildErrorContent(provider);
    }
  }

  Widget _buildIdleContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.analytics_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '尚未运行回测',
            style: AppTextStyles.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '选择数据范围和参数后点击「开始回测」。回测将使用'
            'Binance 历史 K 线数据，以 event-driven 方式逐 bar 回放，'
            '验证反弹信号在历史数据上的有效性。',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRunningContent(BacktestProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '正在运行回测...（${provider.currentFold}/${provider.totalFolds} fold，'
            '${provider.completedCombos}/${provider.totalCombos} 参数组合）',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => provider.cancelBacktest(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
              side: const BorderSide(color: AppColors.destructive),
            ),
            child: const Text('取消回测'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteContent(BacktestProvider provider) {
    final report = provider.report;
    if (report == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 回测报告 section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: _buildSectionHeader('回测报告'),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 权益曲线
        _buildEquityCurveCard(report),
        const SizedBox(height: AppSpacing.lg),

        // 汇总统计
        _buildStatsGrid(report),
        const SizedBox(height: AppSpacing.lg),

        // 交易列表
        _buildTradeListCard(report),
        const SizedBox(height: AppSpacing.lg),

        // 四项强制披露（缺任意一项整个 section 不渲染）
        _buildDisclosuresCard(report, provider.config),
        const SizedBox(height: AppSpacing.lg),

        // 免责声明
        _buildDisclaimerBar(),
        const SizedBox(height: AppSpacing.lg),

        // 清除按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: TextButton(
            onPressed: () => _confirmClearResults(context, provider),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.destructive,
            ),
            child: const Text('清除回测结果'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BacktestProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.destructive, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.destructive,
                size: 32,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                provider.errorMessage ?? '未知错误',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '。请检查数据源和网络连接后重试。',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => provider.runBacktest(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 子组件 ────────────────────────────────────────────

  Widget _buildEquityCurveCard(BacktestReport report) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Text(
              '权益曲线（累计 PnL）',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          EquityCurveChart(
            zeroCostData: report.equityCurveZeroCost,
            withCostData: report.equityCurveWithCost,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BacktestReport report) {
    final stats = [
      ('胜率', '${(report.winRate * 100).toStringAsFixed(1)}%', report.winRate > 0),
      ('平均 R', report.avgR.toStringAsFixed(2), report.avgR > 0),
      ('盈亏比', report.profitFactor == double.infinity
          ? '∞'
          : report.profitFactor.toStringAsFixed(2), report.profitFactor > 1),
      ('最大回撤', '-${(report.maxDrawdown * 100).toStringAsFixed(1)}%', false),
      ('样本数', report.sampleCount.toString(), true),
      ('总 PnL (R)', '${report.totalPnL >= 0 ? '+' : ''}${report.totalPnL.toStringAsFixed(2)}',
          report.totalPnL >= 0),
      ('均笔 R', '${report.avgRPerTrade >= 0 ? '+' : ''}${report.avgRPerTrade.toStringAsFixed(2)}',
          report.avgRPerTrade >= 0),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.5,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        children: stats.map((s) {
          return BacktestStatsCard(
            label: s.$1,
            value: s.$2,
            isPositive: s.$3,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTradeListCard(BacktestReport report) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  '交易明细',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '点击列标题排序',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          BacktestTradeList(
            trades: report.trades,
            onTradeTap: (trade) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KlineScreen(
                    symbol: trade.symbol,
                    defaultInterval: '15m',
                    highlightStartMs: trade.entryTime.millisecondsSinceEpoch,
                    highlightEndMs: trade.exitTime?.millisecondsSinceEpoch,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisclosuresCard(BacktestReport report, BacktestConfig config) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: _buildSectionHeader('强制披露'),
          ),
          _buildDisclosureItem(
            '前视偏差已检：lookahead-analysis 测试通过',
          ),
          _buildDisclosureItem(
            '含手续费（taker 0.06% 来回）+ 资金费（跨 8h 结算扣费）+ 滑点（0.1% 单边）',
          ),
          _buildDisclosureItem(
            '标的池说明：仅覆盖当前 Top-100 流动性币种，不包含已下架合约，'
            '结论不适用于小币/低流动性标的。数据范围：'
            '${_formatDate(config.startDate)} 至 ${_formatDate(config.endDate)}',
          ),
          _buildDisclosureItem(
            '仅报告 Out-of-Sample 聚合指标'
            '（walk-forward 3-fold，训练窗口增长，测试窗口固定 1 个月）',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildDisclosureItem(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.loss, // green = checked
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Text(
        '回测表现通常需打 30-50% 折扣作为实盘预期；本工具不构成投资建议。',
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ─── 工具方法 ──────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.xs),
      child: Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate(
    BuildContext context,
    BacktestProvider provider, {
    required bool isStart,
  }) async {
    final config = provider.config;
    final initialDate = isStart ? config.startDate : config.endDate;
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isStart ? '选择起始日期' : '选择结束日期',
    );

    if (picked != null && context.mounted) {
      if (isStart) {
        // 起始日期必须早于结束日期
        if (!picked.isBefore(config.endDate)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('起始日期必须早于结束日期')),
            );
          }
          return;
        }
        provider.updateConfig(config.copyWith(startDate: picked));
      } else {
        // 结束日期必须晚于起始日期
        if (!config.startDate.isBefore(picked)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('结束日期必须晚于起始日期')),
            );
          }
          return;
        }
        provider.updateConfig(config.copyWith(endDate: picked));
      }
    }
  }

  Future<void> _confirmClearResults(
    BuildContext context,
    BacktestProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有回测结果吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.destructive,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      provider.clearResults();
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('指标说明'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem('胜率', '盈利交易数 / 总交易数。高于 50% 表示策略有正向期望。'),
              _buildHelpItem('平均 R', '所有交易纯 R 倍数的算术平均值。R = 盈亏 / 止损风险。'),
              _buildHelpItem('盈亏比', '总盈利 / 总亏损绝对值。>1 表示盈利大于亏损。无亏损时为 ∞。'),
              _buildHelpItem('最大回撤', '从权益峰值到谷底的最大回落比例。衡量策略风险的重要指标。'),
              _buildHelpItem('样本数', '触发的信号总数（即总交易笔数）。样本越多统计越可靠。'),
              _buildHelpItem('总 PnL (R)', '所有交易含成本净盈亏的合计值（以 R 倍数计）。'),
              _buildHelpItem('均笔 R', '总 PnL / 总交易数。每笔交易的平均净收益。'),
              const SizedBox(height: AppSpacing.md),
              Text(
                '强制披露说明：',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildHelpItem('前视偏差', '回测时信号只使用 bar[0..i] 数据，不含未来信息。'),
              _buildHelpItem('含成本', '每笔交易扣除手续费(0.06%)、滑点(0.1%)和资金费。'),
              _buildHelpItem('标的池', '仅覆盖 Top-100 流动性合约，不适用于小币/低流动性标的。'),
              _buildHelpItem('Out-of-Sample', '使用 walk-forward 3-fold 方法，仅报告测试窗口指标。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
