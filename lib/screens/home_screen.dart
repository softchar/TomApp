import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/providers/market_overview_provider.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/favorite_service.dart';
import 'package:tomapp/screens/kline_screen.dart';
import 'package:tomapp/services/theme_provider.dart' show AppColors, AppSpacing, AppRadius;

/// 首页
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _filterFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    // 确保数据已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketOverviewProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          // 收藏筛选按钮
          IconButton(
            icon: Icon(
              _filterFavoritesOnly ? Icons.star : Icons.star_border,
              color: _filterFavoritesOnly ? AppColors.primary : null,
            ),
            tooltip: '只看收藏',
            onPressed: () {
              setState(() {
                _filterFavoritesOnly = !_filterFavoritesOnly;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MarketOverviewProvider>().refresh();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索币种...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                filled: true,
                fillColor: isDark
                    ? AppColors.surfaceVariant
                    : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toUpperCase();
                });
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<MarketOverviewProvider>().refresh(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // 今日涨幅排行榜 Top20
            _TopGainersWidget(
              searchQuery: _searchQuery,
              filterFavoritesOnly: _filterFavoritesOnly,
            ),
            const SizedBox(height: AppSpacing.md),

            // 最近检测到快速上涨
            const _RecentPumpsWidget(),
          ],
        ),
      ),
    );
  }
}

// ==================== 拆分的独立Widget ====================

/// 今日涨幅排行榜
class _TopGainersWidget extends StatelessWidget {
  final String searchQuery;
  final bool filterFavoritesOnly;

  const _TopGainersWidget({
    required this.searchQuery,
    this.filterFavoritesOnly = false,
  });

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

        // 应用搜索和收藏过滤
        var filteredGainers = gainers;
        if (searchQuery.isNotEmpty) {
          filteredGainers = gainers.where((ticker) =>
            ticker.symbol.toUpperCase().contains(searchQuery)).toList();
        }
        if (filterFavoritesOnly) {
          final favorites = FavoriteService().favorites;
          filteredGainers = filteredGainers.where((ticker) =>
            favorites.contains(ticker.symbol)).toList();
        }

        if (filteredGainers.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '未找到匹配的币种',
                    style: TextStyle(color: Colors.grey.shade600),
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
                    const Icon(Icons.trending_up, size: 20, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '今日涨幅排行榜 Top20${searchQuery.isNotEmpty || filterFavoritesOnly ? ' (已筛选)' : ''}',
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
                itemCount: filteredGainers.take(20).length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ticker = filteredGainers[index];
                  final rank = index + 1;
                  final change = ticker.priceChangePercent;
                  final symbol = ticker.symbol.replaceAll('USDT', '');
                  final originalSymbol = ticker.symbol;

                  return _GainerListTile(
                    rank: rank,
                    symbol: symbol,
                    originalSymbol: originalSymbol,
                    change: change,
                    price: ticker.lastPrice,
                    formatPrice: _formatPrice,
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

/// 涨幅列表项（带收藏按钮）
class _GainerListTile extends StatefulWidget {
  final int rank;
  final String symbol;
  final String originalSymbol;
  final double change;
  final double price;
  final String Function(double) formatPrice;

  const _GainerListTile({
    required this.rank,
    required this.symbol,
    required this.originalSymbol,
    required this.change,
    required this.price,
    required this.formatPrice,
  });

  @override
  State<_GainerListTile> createState() => _GainerListTileState();
}

class _GainerListTileState extends State<_GainerListTile> {
  final FavoriteService _favoriteService = FavoriteService();
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = _favoriteService.isFavorite(widget.originalSymbol);
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
        _isFavorite = _favoriteService.isFavorite(widget.originalSymbol);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    await _favoriteService.toggleFavorite(widget.originalSymbol);
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.primary; // Gold for #1
      case 2:
        return AppColors.surfaceVariant; // Silver
      case 3:
        return const Color(0xFFB45309); // Bronze
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        // 跳转到K线页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => KlineScreen(symbol: widget.originalSymbol),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  widget.rank.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _getRankColor(widget.rank),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Symbol
            Expanded(
              child: Text(
                widget.symbol,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Price and change column
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+${widget.change.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: AppColors.gain,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '\$${widget.formatPrice(widget.price)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),

            // Favorite button
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
