import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/funding_rate_provider.dart';
import '../widgets/funding_rate_item.dart';

/// 资费页面 - 显示资金费率列表（紧凑布局）
class FundingScreen extends StatefulWidget {
  const FundingScreen({super.key});

  @override
  State<FundingScreen> createState() => _FundingScreenState();
}

class _FundingScreenState extends State<FundingScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 启动定时更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FundingRateProvider>().startPeriodicUpdate();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('资费'),
        elevation: 0,
        actions: [
          // 排序按钮
          Consumer<FundingRateProvider>(
            builder: (context, provider, child) {
              return PopupMenuButton<SortType>(
                icon: const Icon(Icons.sort),
                tooltip: '排序',
                onSelected: (SortType sortType) {
                  context.read<FundingRateProvider>().setSortType(sortType);
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    value: SortType.intervalAsc,
                    child: Row(
                      children: [
                        Icon(Icons.sort, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        const Text('间隔↑ (1h优先)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortType.intervalDesc,
                    child: Row(
                      children: [
                        Icon(Icons.sort, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        const Text('间隔↓ (8h优先)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortType.rateDesc,
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        const Text('费率↑ (最高优先)'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SortType.rateAsc,
                    child: Row(
                      children: [
                        Icon(Icons.trending_down, size: 18, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        const Text('费率↓ (最低优先)'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索交易对...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          context.read<FundingRateProvider>().setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                isDense: true,
              ),
              onChanged: (value) {
                context.read<FundingRateProvider>().setSearchQuery(value);
              },
            ),
          ),
        ),
      ),
      body: Consumer<FundingRateProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.errorMessage != null) {
            return _buildErrorView(provider);
          }

          if (provider.fundingRates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无数据',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await context.read<FundingRateProvider>().refresh();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: provider.fundingRates.length,
              itemBuilder: (context, index) {
                final rate = provider.fundingRates[index];
                return FundingRateItem(
                  rate: rate,
                  onTap: () => _showRateDetails(context, rate),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(FundingRateProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage ?? '加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              provider.refresh();
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showRateDetails(BuildContext context, dynamic rate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部把手
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                rate.symbol,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _detailRow('资金费率', rate.fundingRatePercent),
              const SizedBox(height: 12),
              _detailRow('标记价格', rate.formattedMarkPrice),
              const SizedBox(height: 12),
              _detailRow('指数价格', rate.indexPrice.toString()),
              const SizedBox(height: 12),
              _detailRow(
                '下次费率时间',
                rate.nextFundingTime.toString().split('.')[0],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
