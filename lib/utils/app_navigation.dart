import 'package:flutter/material.dart';
import '../screens/kline_screen.dart';

/// 全局导航管理器
/// 用于处理从通知点击等外部来源的导航
class AppNavigation {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 跳转到K线页面
  /// symbol: 合约符号
  /// interval: 时间间隔，默认 '1m'（分时）
  static void navigateToKline(String symbol, {String interval = '1m'}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KlineScreen(
            symbol: symbol,
            defaultInterval: interval,
          ),
        ),
      );
    }
  }

  /// 获取当前导航上下文
  static BuildContext? get currentContext => navigatorKey.currentContext;
}
