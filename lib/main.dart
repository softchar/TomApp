import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'services/funding_rate_provider.dart';
import 'services/theme_provider.dart';
import 'services/long_short_provider.dart';
import 'services/binance_api_service.dart';
import 'services/pump_background_service.dart';
import 'services/pump_alert_service.dart';
import 'services/binance_websocket_manager.dart';
import 'package:tomapp/services/pump_analytics_service.dart';
import 'package:tomapp/services/pump_config_service.dart';
import 'package:tomapp/services/pump_repository.dart' show RepositoryFactory;
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'services/funding_rate_settings.dart';
import 'services/exchange_info_service.dart';
import 'providers/pump_list_provider.dart';
import 'providers/kline_provider.dart';
import 'providers/market_overview_provider.dart';
import 'screens/main_navigation.dart';
import 'utils/app_navigation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Pump检测器 (简化版用于后台服务)
class _PricePoint {
  final double price;
  final DateTime timestamp;
  _PricePoint({required this.price, required this.timestamp});
}

class _PumpDetector {
  final double threshold;
  final int cooldownMinutes = 1;
  final Map<String, List<_PricePoint>> _priceHistory = {};
  final Map<String, DateTime> _lastNotificationTime = {};

  _PumpDetector({this.threshold = 2.0});

  void addPricePoint(String symbol, double price, DateTime timestamp) {
    _priceHistory.putIfAbsent(symbol, () => []);
    _priceHistory[symbol]!.add(_PricePoint(price: price, timestamp: timestamp));
    _cleanupOldPoints(symbol, timestamp);
  }

  Map<String?, double>? checkAll(Map<String, double> currentPrices, DateTime timestamp) {
    final Map<String?, double> pumps = {};

    for (final entry in currentPrices.entries) {
      final symbol = entry.key;
      final price = entry.value;

      if (_isInCooldown(symbol, timestamp)) {
        continue;
      }

      addPricePoint(symbol, price, timestamp);

      final change = _calculate1MinChange(symbol, timestamp);
      if (change != null && change > threshold) {
        pumps[symbol] = change;
        _lastNotificationTime[symbol] = timestamp;
      }
    }

    return pumps.isEmpty ? null : pumps;
  }

  double? _calculate1MinChange(String symbol, DateTime currentTime) {
    final points = _priceHistory[symbol];
    if (points == null || points.length < 2) return null;

    final oneMinuteAgo = currentTime.subtract(const Duration(minutes: 1));
    _PricePoint? baselinePoint;

    for (final point in points) {
      if (point.timestamp.isBefore(oneMinuteAgo) || point.timestamp.isAtSameMomentAs(oneMinuteAgo)) {
        baselinePoint = point;
      } else {
        break;
      }
    }

    if (baselinePoint == null) return null;

    return ((points.last.price - baselinePoint.price) / baselinePoint.price) * 100;
  }

  bool _isInCooldown(String symbol, DateTime currentTime) {
    final lastNotified = _lastNotificationTime[symbol];
    if (lastNotified == null) return false;
    return currentTime.difference(lastNotified).inMinutes < cooldownMinutes;
  }

  void _cleanupOldPoints(String symbol, DateTime currentTime) {
    final cutoff = currentTime.subtract(const Duration(minutes: 2));
    _priceHistory[symbol]!.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }
}

// 后台服务回调 - 必须是顶层函数
@pragma('vm:entry-point')
Future<void> callbackDispatcher(ServiceInstance service) async {
  debugPrint('🔧 callbackDispatcher: 后台服务回调已启动');

  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await notifications.initialize(initializationSettings);

  debugPrint('🔧 callbackDispatcher: 通知插件已初始化');

  if (service is AndroidServiceInstance) {
    // 立即设置为前台服务，确保在后台继续运行
    service.setAsForegroundService();
    debugPrint('🔧 callbackDispatcher: 已设置为前台服务');

    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stop').listen((event) {
    debugPrint('🔧 callbackDispatcher: 收到停止信号');
    service.stopSelf();
  });

  // 加载 PumpConfig 获取阈值配置
  final pumpConfig = PumpConfig();
  await pumpConfig.load();
  final pumpDetector = _PumpDetector(threshold: pumpConfig.baseThreshold);
  debugPrint('🔧 callbackDispatcher: PumpDetector 已创建，阈值: ${pumpConfig.baseThreshold}%');

  Timer.periodic(const Duration(seconds: 2), (timer) async {
    debugPrint('🔧 callbackDispatcher: 定时器触发 #${timer.tick}');

    // 只在第一次更新通知，之后不再更新以避免通知重复弹出
    if (timer.tick == 1 && service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'TomApp',
        content: '后台监控运行中',
      );
    }

    // 每 5 个周期（约 2.5 分钟）执行一次回撤分析
    if (timer.tick % 5 == 0) {
      try {
        final analytics = PumpAnalyticsService(
          repository: RepositoryFactory.create(),
          config: PumpConfig(),
        );
        await analytics.analyzePullbacks();
      } catch (e) {
        debugPrint('回撤分析失败: $e');
      }
    }

    // HTTP 轮询获取所有合约价格
    try {
      final response = await http.get(
        Uri.parse('${BinanceApiService.currentBaseUrl}/fapi/v1/ticker/price'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, double> prices = {};

        for (final item in data) {
          final symbol = item['symbol'] as String?;
          final priceStr = item['price'] as String?;
          if (symbol != null && priceStr != null && symbol.endsWith('USDT')) {
            prices[symbol] = double.tryParse(priceStr) ?? 0.0;
          }
        }

        debugPrint('🔧 callbackDispatcher: 获取到 ${prices.length} 个合约价格');

        // 检测快速上涨
        final pumps = pumpDetector.checkAll(prices, DateTime.now());
        if (pumps != null) {
          debugPrint('🔧 callbackDispatcher: 检测到 ${pumps.length} 个快速上涨');
          final repository = RepositoryFactory.create();

          for (final entry in pumps.entries) {
            final symbol = entry.key;
            final change = entry.value;
            if (symbol != null) {
              debugPrint('🚀 检测到快速上涨: $symbol +${change.toStringAsFixed(2)}%');

              // 保存到数据库
              try {
                final price = prices[symbol] ?? 0.0;
                final pumpModel = PumpModel(
                  symbol: symbol,
                  priceChange: change,
                  triggerTime: DateTime.now(),
                  currentPrice: price,
                );
                final historyModel = PumpHistoryModel.fromPumpModel(
                  pumpModel,
                  strategyType: 'BackgroundService',
                  cooldownMinutes: 1,
                );
                await repository.save(historyModel);
                debugPrint('💾 已保存快速上涨记录: $symbol');
              } catch (e) {
                debugPrint('❌ 保存快速上涨记录失败: $e');
              }

              await notifications.show(
                symbol.hashCode,
                '',
                '$symbol 快速上涨 ${change.toStringAsFixed(2)}%',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'pump_alerts',
                    '快速上涨提醒',
                    channelDescription: '检测到币种快速上涨',
                    importance: Importance.high,
                    priority: Priority.high,
                  ),
                ),
              );
            }
          }
        }
      } else {
        debugPrint('🔧 callbackDispatcher: API 请求失败，状态码 ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('🔧 callbackDispatcher: 获取价格失败: $e');
    }
  });
}

// ============================================
// API 配置区域
// ============================================
void configureApi() {
  // 如果在中国大陆无法直接访问 Binance API，请设置代理服务器地址
  // 部署代理服务器请参考: proxy_server/README.md

  // 示例代理地址（替换为你自己的代理服务器地址）：
  // BinanceApiService.setCustomBaseUrl('https://your-proxy.com/api');

  // Cloudflare Workers 示例：
  // BinanceApiService.setCustomBaseUrl('https://your-worker.workers.dev/api');

  // 默认使用官方 API（需要能访问 fapi.binance.com）
  BinanceApiService.resetBaseUrl();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置 API
  configureApi();

  // 初始化并启动后台快速上涨检测服务
  final backgroundService = PumpBackgroundService.instance;
  await backgroundService.initialize(onStart: callbackDispatcher);

  // 启动后台服务
  await backgroundService.start();

  // 验证服务是否正在运行
  final isRunning = await backgroundService.isRunning;
  debugPrint('PumpBackgroundService 启动状态: $isRunning');

  if (!isRunning) {
    debugPrint('警告: 后台服务启动失败，请检查权限配置');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FundingRateSettings()),
        ChangeNotifierProxyProvider<FundingRateSettings, FundingRateProvider>(
          create: (context) => FundingRateProvider(
            settings: context.read<FundingRateSettings>(),
          ),
          update: (_, settings, previous) =>
              previous ?? FundingRateProvider(settings: settings),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LongShortProvider()),
        ChangeNotifierProvider(create: (_) => PumpAlertService.instance.store),
        ChangeNotifierProvider(create: (_) => BinanceWebSocketManager()),
        ChangeNotifierProvider(create: (_) => PumpConfig()..load()),
        ChangeNotifierProvider(
          create: (_) => PumpListProvider(
            repository: RepositoryFactory.create(),
            config: PumpConfig(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => KlineProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MarketOverviewProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExchangeInfoService.instance,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '币安合约费率',
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNavigation.navigatorKey,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            home: const MainNavigation(),
          );
        },
      ),
    );
  }

  /// 构建亮色主题
  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  /// 构建暗色主题
  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1E1E1E),
      ),
    );
  }
}
