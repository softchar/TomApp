import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'funding_screen.dart';
import 'long_short_screen.dart';
import 'pump_screen.dart';
import 'profile_screen.dart';
import 'rebound_dashboard_screen.dart';
import '../services/funding_rate_provider.dart';
import '../services/funding_rate_settings.dart';
import '../services/theme_provider.dart' show AppColors;
import '../services/contract_sync_settings.dart';
import '../services/contract_sync_service.dart';

/// 主导航页面 - 带底部导航栏
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // 懒加载：记录哪些页面已经构建过，避免一次性构建6个页面
  final Set<int> _builtPages = {0}; // 首页默认构建

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const FundingScreen();
      case 2:
        return const LongShortScreen();
      case 3:
        return const PumpScreen();
      case 4:
        return const ProfileScreen();
      case 5:
        return const ReboundDashboardScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始化费率设置并启动自动更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFundingRateUpdate();
      _initContractSync();
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

  /// 懒加载页面：只构建访问过的页面，避免启动时一次性创建全部6个页面
  Widget _buildCurrentPage() {
    _builtPages.add(_currentIndex);
    // 只保留当前页面在内存中，之前访问过的页面重建
    return KeyedSubtree(
      key: ValueKey(_currentIndex),
      child: _buildScreen(_currentIndex),
    );
  }

  Future<void> _initContractSync() async {
    final syncSettings = context.read<ContractSyncSettings>();
    if (syncSettings.autoSyncEnabled) {
      await ContractSyncService.instance.startSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.border : Colors.grey.shade300,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: isDark ? AppColors.onSurfaceVariant : Colors.grey.shade500,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              activeIcon: Icon(Icons.show_chart),
              label: '资费',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline),
              activeIcon: Icon(Icons.pie_chart),
              label: '多空',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_fire_department_outlined),
              activeIcon: Icon(Icons.local_fire_department),
              label: '快速',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up),
              activeIcon: Icon(Icons.trending_up),
              label: '反弹',
            ),
          ],
        ),
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
