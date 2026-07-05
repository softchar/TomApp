// lib/screens/pump_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/widgets/pump_history_item.dart';
import 'package:tomapp/screens/pump_detail_screen.dart';
import 'package:tomapp/services/theme_provider.dart' show AppColors, AppSpacing, AppRadius;

class PumpScreen extends StatefulWidget {
  const PumpScreen({super.key});

  @override
  State<PumpScreen> createState() => _PumpScreenState();
}

class _PumpScreenState extends State<PumpScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 初始加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PumpListProvider>().load();
    });

    // 监听滚动，加载更多
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PumpListProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : null,
      appBar: AppBar(
        title: const Text('快速上涨'),
        actions: [
          Consumer<BinanceWebSocketManager>(
            builder: (context, wsManager, child) {
              final state = wsManager.connectionState;
              Color dotColor;
              String statusText;

              switch (state) {
                case WebSocketConnectionState.connected:
                  dotColor = AppColors.gain;
                  statusText = '已连接';
                  break;
                case WebSocketConnectionState.connecting:
                case WebSocketConnectionState.reconnecting:
                  dotColor = AppColors.warning;
                  statusText = '连接中';
                  break;
                default:
                  dotColor = AppColors.destructive;
                  statusText = '已断开';
              }

              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // 收藏筛选按钮
          Consumer<PumpListProvider>(
            builder: (context, provider, child) {
              final isFilteringFavorites = provider.isFilteringFavorites;
              return IconButton(
                icon: Icon(
                  isFilteringFavorites ? Icons.star : Icons.star_border,
                  color: isFilteringFavorites ? AppColors.primary : null,
                ),
                tooltip: '只看收藏',
                onPressed: () {
                  provider.setFavoriteFilter(!isFilteringFavorites);
                },
              );
            },
          ),
          PopupMenuButton<PumpListSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) {
              context.read<PumpListProvider>().setSortType(sort);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: PumpListSort.timeDesc,
                child: Text('最新优先'),
              ),
              const PopupMenuItem(
                value: PumpListSort.timeAsc,
                child: Text('最早优先'),
              ),
              const PopupMenuItem(
                value: PumpListSort.changeDesc,
                child: Text('涨幅最高'),
              ),
              const PopupMenuItem(
                value: PumpListSort.changeAsc,
                child: Text('涨幅最低'),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
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
                          context.read<PumpListProvider>().setSearchQuery('');
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
                context.read<PumpListProvider>().setSearchQuery(value);
              },
            ),
          ),
        ),
      ),
      body: Consumer<PumpListProvider>(
        builder: (context, provider, child) {
          final state = provider.state;

          switch (state.status) {
            case PumpListStatus.initial:
            case PumpListStatus.loading:
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );

            case PumpListStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppColors.destructive,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.errorMessage ?? '加载失败',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                      ),
                      onPressed: () => provider.load(refresh: true),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );

            case PumpListStatus.empty:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '暂无快速上涨记录',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );

            case PumpListStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => provider.load(refresh: true),
                color: AppColors.primary,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: state.pumps.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.pumps.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }

                    final pump = state.pumps[index];
                    return PumpHistoryItem(
                      pump: pump,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PumpDetailScreen(pump: pump),
                        ),
                      ),
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}
