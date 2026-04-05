import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'funding_screen.dart';
import 'long_short_screen.dart';
import 'pump_screen.dart';
import 'profile_screen.dart';
import '../services/funding_rate_provider.dart';
import '../services/funding_rate_settings.dart';

/// 主导航页面 - 带底部导航栏
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FundingScreen(),
    const LongShortScreen(),
    const PumpScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 初始化费率设置并启动自动更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFundingRateUpdate();
    });
  }

  Future<void> _initFundingRateUpdate() async {
    final settings = context.read<FundingRateSettings>();
    await settings.load();
    if (!mounted) return;
    if (settings.autoUpdateEnabled) {
      context.read<FundingRateProvider>().startPeriodicUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_outlined),
            activeIcon: Icon(Icons.attach_money),
            label: '资费',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps_outlined),
            activeIcon: Icon(Icons.apps),
            label: '多空',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up_outlined),
            activeIcon: Icon(Icons.trending_up),
            label: '快速',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 停止费率自动更新
    try {
      context.read<FundingRateProvider>().stopPeriodicUpdate();
    } catch (_) {
      // Provider 可能未初始化，忽略错误
    }
    super.dispose();
  }
}
