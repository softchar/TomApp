import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show popupAlertService;
import '../services/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/binance_api_service.dart';

/// 我的页面
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final NotificationService _notificationService = NotificationService();
  final BinanceApiService _apiService = BinanceApiService();
  int _notificationCount = 0;
  bool _isTestingConnection = false;

  final List<String> _randomMessages = [
    'RIVERUSDT 的资费间隔已变为1小时',
    'ETHUSDT 发现高费率机会！',
    'BTCUSDT 资费间隔更新',
    '新的1小时合约可用',
    '资费提醒：检查您的持仓',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我'),
      ),
      body: ListView(
        children: [
          // 主题设置部分
          _buildSectionHeader('主题设置'),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildThemeOption(
                      context,
                      icon: Icons.light_mode,
                      title: '亮色模式',
                      subtitle: '使用浅色主题',
                      isSelected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () => themeProvider.setLightMode(),
                    ),
                    const Divider(height: 1),
                    _buildThemeOption(
                      context,
                      icon: Icons.dark_mode,
                      title: '暗色模式',
                      subtitle: '使用深色主题',
                      isSelected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () => themeProvider.setDarkMode(),
                    ),
                    const Divider(height: 1),
                    _buildThemeOption(
                      context,
                      icon: Icons.brightness_auto,
                      title: '跟随系统',
                      subtitle: '根据系统设置自动切换',
                      isSelected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () => themeProvider.setSystemMode(),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // 测试部分
          _buildSectionHeader('测试功能'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 测试整点弹窗按钮
                  FilledButton.icon(
                    icon: const Icon(Icons.alarm),
                    label: const Text('测试整点弹窗'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await popupAlertService.testCheck();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('已触发整点检查测试'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 测试通知按钮
                  FilledButton.icon(
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('测试通知'),
                    onPressed: () async {
                      setState(() {
                        _notificationCount++;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      await _notificationService.show(
                        _notificationCount,
                        '测试通知 #$_notificationCount',
                        _randomMessages[_notificationCount % _randomMessages.length],
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('已发送通知 #$_notificationCount'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 清除通知按钮
                  OutlinedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('清除通知'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await _notificationService.cancelAll();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('所有通知已清除')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // 测试 API 连接按钮
                  OutlinedButton.icon(
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_sync, size: 18),
                    label: Text(_isTestingConnection ? '测试中...' : '测试 API 连接'),
                    onPressed: _isTestingConnection
                        ? null
                        : () => _testApiConnection(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // 关于部分
          _buildSectionHeader('关于'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildInfoItem(
                  icon: Icons.info_outline,
                  title: '应用版本',
                  trailing: 'v1.0.0',
                ),
                const Divider(height: 1),
                _buildInfoItem(
                  icon: Icons.description_outlined,
                  title: '关于项目',
                  trailingWidget: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.blue : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    String? trailing,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '币安合约费率',
      applicationVersion: 'v1.0.0',
      applicationIcon: const Icon(
        Icons.show_chart,
        size: 48,
        color: Colors.blue,
      ),
      children: [
        const Text('实时查看币安合约资金费率'),
        const SizedBox(height: 8),
        const Text('支持亮色/暗色主题切换'),
      ],
    );
  }

  /// 测试 API 连接
  Future<void> _testApiConnection(BuildContext context) async {
    setState(() => _isTestingConnection = true);

    try {
      final result = await _apiService.testConnection();

      if (!mounted) return;

      final isConnected = result['isConnected'] as bool;
      final message = result['message'] as String;
      final baseUrl = result['baseUrl'] as String;
      final details = result['details'] as Map<String, bool>;

      // 显示详细结果
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error,
                color: isConnected ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text('API 连接测试'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('服务器: $baseUrl',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              _buildStatusItem('基础 API', details['premiumIndex'] ?? false),
              _buildStatusItem('多空比 API', details['longShortRatio'] ?? false),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.info : Icons.warning,
                      size: 20,
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message)),
                  ],
                ),
              ),
              if (!isConnected) ...[
                const SizedBox(height: 16),
                const Text('提示：请配置代理服务器',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('测试失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  Widget _buildStatusItem(String label, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            isSuccess ? '正常' : '失败',
            style: TextStyle(
              fontSize: 12,
              color: isSuccess ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
