// lib/screens/pump_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/providers/pump_list_provider.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/widgets/pump_history_item.dart';
import 'package:tomapp/screens/pump_detail_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PumpListProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('快速上涨'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          Consumer<BinanceWebSocketManager>(
            builder: (context, wsManager, child) {
              final state = wsManager.connectionState;
              Color dotColor;
              String statusText;

              switch (state) {
                case WebSocketConnectionState.connected:
                  dotColor = Colors.green;
                  statusText = '已连接';
                  break;
                case WebSocketConnectionState.connecting:
                case WebSocketConnectionState.reconnecting:
                  dotColor = Colors.orange;
                  statusText = '连接中';
                  break;
                default:
                  dotColor = Colors.red;
                  statusText = '已断开';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
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
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey[200],
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
              return const Center(
                child: CircularProgressIndicator(),
              );

            case PumpListStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: isDark ? Colors.red[400] : Colors.red[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? '加载失败',
                      style: TextStyle(
                        color: isDark ? Colors.red[400] : Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
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
                      Icons.trending_up,
                      size: 64,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无快速上涨记录',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );

            case PumpListStatus.loaded:
              return RefreshIndicator(
                onRefresh: () => provider.load(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.pumps.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.pumps.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
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
