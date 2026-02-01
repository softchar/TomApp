import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/funding_rate_provider.dart';
import 'services/theme_provider.dart';
import 'services/popup_alert_service.dart';
import 'services/long_short_provider.dart';
import 'services/binance_api_service.dart';
import 'screens/main_navigation.dart';

late final PopupAlertService popupAlertService;

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

  // 初始化弹窗服务
  popupAlertService = PopupAlertService();
  await popupAlertService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FundingRateProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LongShortProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '币安合约费率',
            debugShowCheckedModeBanner: false,
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
