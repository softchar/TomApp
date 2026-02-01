import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/long_short_ratio.dart';
import '../services/long_short_provider.dart';

/// 大户多空比页面
class LongShortScreen extends StatefulWidget {
  const LongShortScreen({super.key});

  @override
  State<LongShortScreen> createState() => _LongShortScreenState();
}

class _LongShortScreenState extends State<LongShortScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 首次加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LongShortProvider>().fetchRatios();
    });

    // 监听滚动到底部
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        context.read<LongShortProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大户多空比'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildPeriodFilter(),
        ),
      ),
      body: Consumer<LongShortProvider>(
        builder: (context, provider, child) {
          // 统一使用 RefreshIndicator 包裹所有状态
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: _buildContent(provider),
          );
        },
      ),
    );
  }

  Widget _buildContent(LongShortProvider provider) {
    // 如果正在加载且没有数据
    if (provider.isLoading && provider.ratios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果有错误且没有数据
    if (provider.error != null && provider.ratios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => provider.refresh(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 如果没有数据
    if (provider.ratios.isEmpty) {
      return const Center(child: Text('暂无数据，下拉刷新'));
    }

    // 有数据，显示列表
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: provider.ratios.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.ratios.length) {
          // 加载更多指示器
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final ratio = provider.ratios[index];
        return _buildCompactRatioCard(ratio);
      },
    );
  }

  Widget _buildPeriodFilter() {
    return Consumer<LongShortProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _PeriodButton(
                label: '5M',
                isSelected: provider.period == '5m',
                onTap: () => provider.setPeriod('5m'),
              ),
              const SizedBox(width: 4),
              _PeriodButton(
                label: '15M',
                isSelected: provider.period == '15m',
                onTap: () => provider.setPeriod('15m'),
              ),
              const SizedBox(width: 4),
              _PeriodButton(
                label: '1H',
                isSelected: provider.period == '1h',
                onTap: () => provider.setPeriod('1h'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactRatioCard(LongShortRatio ratio) {
    final shortPercent = (ratio.shortAccount * 100).toStringAsFixed(1);
    final longPercent = (ratio.longAccount * 100).toStringAsFixed(1);
    final interval = ratio.fundingIntervalHours == 1 ? '1h' : ratio.fundingIntervalHours == 4 ? '4h' : '${ratio.fundingIntervalHours}h';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 交易对 + 资费间隔
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ratio.symbol.replaceAll('USDT', ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // 资费间隔标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: interval == '1h'
                              ? Colors.orange.withOpacity(0.2)
                              : interval == '4h'
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          interval,
                          style: TextStyle(
                            fontSize: 11,
                            color: interval == '1h'
                                ? Colors.orange
                                : interval == '4h'
                                    ? Colors.blue
                                    : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '空$shortPercent%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 空头进度条（紫色）
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('空', style: TextStyle(fontSize: 11, color: Colors.deepPurple)),
                      const SizedBox(width: 4),
                      Text(
                        shortPercent,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ratio.shortAccount,
                      backgroundColor: Colors.deepPurple.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 多头进度条（蓝色）
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('多', style: TextStyle(fontSize: 11, color: Colors.lightBlue)),
                      const SizedBox(width: 4),
                      Text(
                        longPercent,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ratio.longAccount,
                      backgroundColor: Colors.lightBlue.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: isSelected ? null : Colors.grey.shade300,
          foregroundColor: isSelected ? null : Colors.grey.shade700,
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(0, 32),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
