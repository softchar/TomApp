import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/providers/market_overview_provider.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/screens/kline_screen.dart';

/// 首页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 确保数据已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketOverviewProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MarketOverviewProvider>().refresh();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MarketOverviewProvider>().refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            // 今日涨幅排行榜 Top20
            _TopGainersWidget(),
            SizedBox(height: 16),

            // 最近检测到快速上涨
            _RecentPumpsWidget(),
          ],
        ),
      ),
    );
  }
}

// ==================== 拆分的独立Widget ====================

/// 今日涨幅排行榜
class _TopGainersWidget extends StatelessWidget {
  const _TopGainersWidget();

  /// 智能价格格式化 - 根据价格大小选择合适的小数位数
  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(2);
    if (price >= 10) return price.toStringAsFixed(3);
    if (price >= 1) return price.toStringAsFixed(4);
    if (price >= 0.01) return price.toStringAsFixed(6);
    return price.toStringAsFixed(8);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MarketOverviewProvider, List<dynamic>>(
      selector: (context, provider) => provider.overview?.topGainers ?? [],
      builder: (context, gainers, child) {
        if (gainers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '今日涨幅排行榜 Top20',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gainers.take(20).length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ticker = gainers[index];
                  final rank = index + 1;
                  final change = ticker.priceChangePercent;
                  final symbol = ticker.symbol.replaceAll('USDT', '');
                  final originalSymbol = ticker.symbol;

                  return ListTile(
                    dense: true,
                    onTap: () {
                      // 跳转到K线页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KlineScreen(symbol: originalSymbol),
                        ),
                      );
                    },
                    leading: SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(
                          rank.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: rank <= 3 ? Colors.orange : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      symbol,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${change.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_formatPrice(ticker.lastPrice)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 最近检测到快速上涨
class _RecentPumpsWidget extends StatelessWidget {
  const _RecentPumpsWidget();

  @override
  Widget build(BuildContext context) {
    return Consumer<PumpListProvider>(
      builder: (context, pumpProvider, child) {
        final recentPumps = pumpProvider.state.pumps.take(5).toList();

        if (recentPumps.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.bolt, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '暂无快速上涨记录',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当检测到币种快速上涨时会显示在这里',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      '最近检测到快速上涨',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...recentPumps.asMap().entries.map((entry) {
                final index = entry.key;
                final pump = entry.value;
                final minutesAgo = pump.age.inMinutes;
                final symbol = pump.symbol.replaceAll('USDT', '');
                final originalSymbol = pump.symbol;

                return ListTile(
                  dense: true,
                  onTap: () {
                    // 跳转到K线页面
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KlineScreen(symbol: originalSymbol),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: _getPumpColor(pump.priceChange),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    symbol,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '$minutesAgo分钟前',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    '+${pump.priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: _getPumpColor(pump.priceChange),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Color _getPumpColor(double percent) {
    if (percent >= 5) return Colors.red;
    if (percent >= 3) return Colors.orange;
    return Colors.yellow.shade700;
  }
}
