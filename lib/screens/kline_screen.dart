import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/providers/kline_provider.dart';
import 'package:tomapp/providers/market_overview_provider.dart';
import 'package:tomapp/services/long_short_provider.dart';
import 'package:tomapp/widgets/interval_selector.dart';
import 'package:tomapp/widgets/kline_chart_widget.dart';
import 'package:tomapp/models/kline_data.dart';

class KlineScreen extends StatefulWidget {
  final String symbol;

  const KlineScreen({
    super.key,
    required this.symbol,
  });

  @override
  State<KlineScreen> createState() => _KlineScreenState();
}

class _KlineScreenState extends State<KlineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<KlineProvider>();
      provider.loadKlines(widget.symbol, '1d');

      // 获取当前合约的多空比数据
      context.read<LongShortProvider>().setPeriod('5m');
      context.read<LongShortProvider>().fetchRatioForSymbol(widget.symbol);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('K线图'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Top10 合约按钮列表（始终显示）
          const _TopSymbolsWidget(),

          // 时间周期选择器 - 只监听 interval 变化
          const _IntervalSelectorWidget(),

          // 价格信息 - 只监听价格相关数据变化
          const _PriceInfoWidget(),

          // K线图表 - 限制高度，只监听图表数据变化
          const _KlineChartWidget(),

          // 5分钟多空比显示（紧挨着K线图下方）
          const _LongShortRatioWidget(),

          // Expanded to push content to bottom
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

// ==================== 拆分的独立Widget ====================

/// 时间周期选择器 - 只监听 interval 变化
class _IntervalSelectorWidget extends StatelessWidget {
  const _IntervalSelectorWidget();

  @override
  Widget build(BuildContext context) {
    return Selector<KlineProvider, String>(
      selector: (context, provider) => provider.currentInterval,
      builder: (context, interval, child) {
        final provider = context.read<KlineProvider>();
        return Container(
          color: Colors.black,
          child: IntervalSelector(
            currentInterval: interval,
            onIntervalChanged: provider.switchInterval,
          ),
        );
      },
    );
  }
}

/// Top10 合约按钮列表（始终显示）
class _TopSymbolsWidget extends StatelessWidget {
  const _TopSymbolsWidget();

  @override
  Widget build(BuildContext context) {
    return Consumer<MarketOverviewProvider>(
      builder: (context, marketProvider, child) {
        final topSymbols = marketProvider.overview?.topGainers.take(10).toList() ?? [];

        if (topSymbols.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.black,
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topSymbols.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final ticker = topSymbols[index];
              final symbol = ticker.symbol.replaceAll('USDT', '');
              final isSelected = context.watch<KlineProvider>().symbol == ticker.symbol;

              return _buildSymbolButton(
                context: context,
                symbol: symbol,
                isSelected: isSelected,
                onTap: () {
                  context.read<KlineProvider>().switchSymbol(ticker.symbol);
                  // 切换合约时获取该合约的多空比数据
                  context.read<LongShortProvider>().fetchRatioForSymbol(ticker.symbol);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSymbolButton({
    required BuildContext context,
    required String symbol,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[700]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 价格信息显示 - 只监听价格相关数据变化
class _PriceInfoWidget extends StatelessWidget {
  const _PriceInfoWidget();

  @override
  Widget build(BuildContext context) {
    return Selector<KlineProvider, ({double price, double? change, bool hasData})>(
      selector: (context, provider) => (
        price: provider.currentPrice ?? 0,
        change: provider.priceChange,
        hasData: provider.currentPrice != null,
      ),
      builder: (context, data, child) {
        if (!data.hasData) {
          return const SizedBox.shrink();
        }

        final change = data.change;
        final isPositive = change != null && change >= 0;
        final color = isPositive ? Colors.red : Colors.green;

        return Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                data.price.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (change != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 14, color: color),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// K线图表 - 添加 RepaintBoundary 隔离重绘，限制高度
class _KlineChartWidget extends StatelessWidget {
  const _KlineChartWidget();

  @override
  Widget build(BuildContext context) {
    return Selector<KlineProvider, ({
      List<KlineDataWithIndicators> klineData,
      bool isRealtime,
      double? currentPrice,
      bool isLoading,
      bool hasData,
      String interval
    })>(
      selector: (context, provider) => (
        klineData: provider.klineWithIndicators,
        isRealtime: provider.isRealtime,
        currentPrice: provider.currentPrice,
        isLoading: provider.isLoading,
        hasData: provider.klineWithIndicators.isNotEmpty,
        interval: provider.currentInterval,
      ),
      builder: (context, data, child) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.25,
          child: Container(
            color: Colors.black,
            child: data.klineData.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : RepaintBoundary(
                    child: KlineChartWidget(
                      data: data.klineData,
                      isRealtime: data.isRealtime,
                      currentPrice: data.currentPrice,
                      interval: data.interval,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// 5分钟多空比显示
class _LongShortRatioWidget extends StatelessWidget {
  const _LongShortRatioWidget();

  @override
  Widget build(BuildContext context) {
    return Consumer<LongShortProvider>(
      builder: (context, provider, child) {
        final currentRatio = provider.currentSymbolRatio;

        if (currentRatio == null) {
          return const SizedBox.shrink();
        }

        final longAccount = currentRatio.longAccount * 100;
        final shortAccount = currentRatio.shortAccount * 100;
        final total = longAccount + shortAccount;

        return Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '5分钟多空比 - ${currentRatio.symbol.replaceAll('USDT', '')}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 多空比条形图
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Container(
                      height: 24,
                      width: longAccount / total * MediaQuery.of(context).size.width,
                      color: Colors.red,
                    ),
                    Container(
                      height: 24,
                      width: shortAccount / total * MediaQuery.of(context).size.width,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '做多 ${longAccount.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                  Text(
                    '做空 ${shortAccount.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
