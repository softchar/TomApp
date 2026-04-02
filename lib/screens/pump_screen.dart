// lib/screens/pump_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/services/pump_store.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/widgets/pump_item.dart';

class PumpScreen extends StatefulWidget {
  const PumpScreen({super.key});

  @override
  State<PumpScreen> createState() => _PumpScreenState();
}

class _PumpScreenState extends State<PumpScreen> {
  @override
  void initState() {
    super.initState();
    // 在应用启动时已经在 main.dart 中启动了服务
  }

  @override
  void dispose() {
    super.dispose();
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
        ],
      ),
      body: Consumer<PumpStore>(
        builder: (context, store, child) {
          final pumps = store.pumps;

          if (pumps.isEmpty) {
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
          }

          return ListView.builder(
            itemCount: pumps.length,
            itemBuilder: (context, index) {
              final pump = pumps[pumps.length - 1 - index];
              return PumpItem(pump: pump);
            },
          );
        },
      ),
    );
  }
}
