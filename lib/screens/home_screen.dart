import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/funding_rate_provider.dart';
import '../widgets/funding_rate_item.dart';

/// 主页面 - 显示资金费率列表
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  SortType _currentSortType = SortType.symbolAsc;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('币安合约费率'),
        elevation: 0,
        actions: [
          // 排序按钮
          PopupMenuButton<SortType>(
            icon: const Icon(Icons.sort),
            onSelected: (SortType sortType) {
              setState(() {
                _currentSortType = sortType;
              });
              context.read<FundingRateProvider>().setSortType(sortType);
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: SortType.symbolAsc,
                child: Text('交易对 A-Z'),
              ),
              const PopupMenuItem(
                value: SortType.symbolDesc,
                child: Text('交易对 Z-A'),
              ),
              const PopupMenuItem(
                value: SortType.rateDesc,
                child: Text('费率 从高到低'),
              ),
              const PopupMenuItem(
                value: SortType.rateAsc,
                child: Text('费率 从低到高'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),
          // 统计信息
          _buildStatsBar(),
          // 费率列表
          Expanded(
            child: Consumer<FundingRateProvider>(
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
                  return const Center(
                    child: Text('暂无数据'),
                  );
                }

                return RefreshIndicator(
                  backgroundColor: Colors.white,
                  color: Colors.blue,
                  strokeWidth: 3,
                  onRefresh: () async {
                    await context.read<FundingRateProvider>().refresh();
                  },
                  child: ListView.builder(
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
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索交易对...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<FundingRateProvider>().setSearchQuery('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) {
          context.read<FundingRateProvider>().setSearchQuery(value);
        },
      ),
    );
  }

  Widget _buildStatsBar() {
    return Consumer<FundingRateProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 ${provider.rateCount} 个合约',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
              const Text(
                '每小时自动更新',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorView(FundingRateProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage ?? '加载失败',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rate.symbol,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
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
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
