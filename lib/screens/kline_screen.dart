import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kline_provider.dart';
import '../widgets/interval_selector.dart';
import '../widgets/kline_chart_widget.dart';
import '../widgets/kline_skeleton.dart';
import '../widgets/macd_chart_widget.dart';

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
  static const List<String> _commonSymbols = [
    'BTCUSDT',
    'ETHUSDT',
    'BNBUSDT',
    'SOLUSDT',
    'ADAUSDT',
    'XRPUSDT',
    'DOGEUSDT',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KlineProvider>().loadKlines(widget.symbol, '15m');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<KlineProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const KlineSkeleton();
          }

          if (provider.errorMessage != null) {
            return _buildErrorView(provider);
          }

          return Column(
            children: [
              _buildSymbolSelector(provider),
              Consumer<KlineProvider>(
                builder: (context, provider, child) {
                  return IntervalSelector(
                    currentInterval: provider.currentInterval,
                    onIntervalChanged: (interval) =>
                        provider.switchInterval(interval),
                  );
                },
              ),
              Expanded(
                child: KlineChartWidget(
                  data: provider.klineWithIndicators,
                  isRealtime: provider.isRealtime,
                  currentPrice: provider.currentPrice,
                ),
              ),
              _buildPriceLine(provider),
              _buildMacdButton(provider),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('K线图'),
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart),
          onPressed: () {
            context.read<KlineProvider>().toggleMacd();
            _showMacdBottomSheet(context);
          },
        ),
      ],
    );
  }

  Widget _buildSymbolSelector(KlineProvider provider) {
    // 确保当前交易对在下拉列表中
    final symbols = [..._commonSymbols];
    if (!symbols.contains(provider.symbol)) {
      symbols.add(provider.symbol);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButton<String>(
        value: provider.symbol,
        items: symbols.map((symbol) {
          return DropdownMenuItem(
            value: symbol,
            child: Text(symbol),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            provider.switchSymbol(value);
          }
        },
      ),
    );
  }

  Widget _buildPriceLine(KlineProvider provider) {
    final currentPrice = provider.currentPrice;
    final priceChange = provider.priceChange;

    if (currentPrice == null) {
      return const SizedBox.shrink();
    }

    final isPositive = priceChange != null && priceChange >= 0;
    final color = isPositive ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            currentPrice.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (priceChange != null) ...[
            const SizedBox(width: 8),
            Text(
              '${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
              style: TextStyle(
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacdButton(KlineProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: FilledButton.tonalIcon(
        onPressed: () {
          provider.toggleMacd();
          _showMacdBottomSheet(context);
        },
        icon: const Icon(Icons.show_chart),
        label: const Text('MACD'),
      ),
    );
  }

  Widget _buildErrorView(KlineProvider provider) {
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
            provider.errorMessage!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              provider.loadKlines(
                provider.symbol,
                provider.currentInterval,
              );
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showMacdBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: Consumer<KlineProvider>(
                  builder: (context, provider, child) {
                    final macdData = provider.macdData;
                    if (macdData == null) {
                      return const Center(
                        child: Text('暂无MACD数据'),
                      );
                    }
                    return MacdChartWidget(
                      macdData: macdData,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
