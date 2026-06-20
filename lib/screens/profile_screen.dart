import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../services/notification_service.dart';
import '../services/binance_api_service.dart';
import '../services/funding_rate_settings.dart';
import '../services/kline_cache_service.dart';
import '../services/pump_config_service.dart';
import '../services/contract_sync_settings.dart';
import '../services/contract_sync_service.dart';
import '../providers/kline_provider.dart';
import '../providers/alert_settings_provider.dart';
import '../services/rebound/rebound_timeframes.dart';

/// 构建时间戳，由 `flutter run --dart-define=BUILD_TIME=...` 注入。
/// 用于在「我的」页确认手机上运行的究竟是哪一次构建（每次部署都不同）。
const String _buildTime = String.fromEnvironment('BUILD_TIME', defaultValue: '');

/// 应用版本号（取自 pubspec.yaml）。
const String _appVersion = 'v1.0.0';

/// 组合显示的版本字符串：无构建时间戳时只显示版本号。
String get _displayVersion =>
    _buildTime.isEmpty ? _appVersion : '$_appVersion · $_buildTime';

/// 构建时间戳，由 `flutter run --dart-define=BUILD_TIME=...` 注入。
/// 用于在「我的」页确认手机上运行的究竟是哪一次构建（每次部署都不同）。
const String _buildTime = String.fromEnvironment('BUILD_TIME', defaultValue: '');

/// 应用版本号（取自 pubspec.yaml）。
const String _appVersion = 'v1.0.0';

/// 组合显示的版本字符串：无构建时间戳时只显示版本号。
String get _displayVersion =>
    _buildTime.isEmpty ? _appVersion : '$_appVersion · $_buildTime';

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
          // 费率自动更新设置
          _buildSectionHeader('费率设置'),
          Consumer<FundingRateSettings>(
            builder: (context, settings, child) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  title: const Text('自动更新费率'),
                  subtitle: Text(settings.autoUpdateEnabled ? '每小时自动更新' : '已关闭'),
                  value: settings.autoUpdateEnabled,
                  onChanged: (value) async {
                    // 只更新设置，FundingRateProvider 会通过监听器自动响应
                    await settings.setAutoUpdateEnabled(value);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // 快速上涨设置
          _buildSectionHeader('快速上涨设置'),
          Consumer<PumpConfig>(
            builder: (context, pumpConfig, child) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('快速上涨检测'),
                      subtitle: Text(pumpConfig.pumpAlertEnabled ? '已开启' : '已关闭'),
                      value: pumpConfig.pumpAlertEnabled,
                      onChanged: (value) {
                        pumpConfig.pumpAlertEnabled = value;
                      },
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '上涨阈值',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${pumpConfig.baseThreshold.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '当合约价格上涨超过此百分比时发送通知',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Slider(
                            value: pumpConfig.baseThreshold,
                            min: 0.5,
                            max: 10.0,
                            divisions: 19,
                            label: '${pumpConfig.baseThreshold.toStringAsFixed(1)}%',
                            onChanged: (value) {
                              pumpConfig.baseThreshold = value;
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '0.5%',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                              Text(
                                '10.0%',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          // 合约信息管理部分
          _buildSectionHeader('合约信息管理'),
          Consumer<ContractSyncSettings>(
            builder: (context, settings, child) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SwitchListTile(
                  title: const Text('自动同步合约信息'),
                  subtitle: Text(
                    settings.autoSyncEnabled
                        ? '每小时自动同步'
                        : '已关闭',
                  ),
                  value: settings.autoSyncEnabled,
                  onChanged: (value) async {
                    await settings.setAutoSyncEnabled(value);
                    if (value) {
                      ContractSyncService.instance.startSync();
                    } else {
                      ContractSyncService.instance.stopSync();
                    }
                  },
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
          // K线缓存管理部分
          _buildSectionHeader('K线缓存管理'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('缓存大小'),
                  trailing: Consumer<KlineProvider>(
                    builder: (context, provider, child) {
                      return FutureBuilder<int>(
                        future: KlineCacheService().getCacheSize(),
                        builder: (context, snapshot) {
                          final size = snapshot.data ?? 0;
                          final sizeMB = (size / (1024 * 1024)).toStringAsFixed(2);
                          return Text('$sizeMB MB');
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: const Text('清除缓存'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await KlineCacheService().clearAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('缓存已清除')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Phase 5：反弹提醒设置
          _buildSectionHeader('反弹提醒'),
          Consumer<AlertSettingsProvider>(
            builder: (context, provider, child) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    // 周期开关列表
                    ...monitoredTimeframes.map((tf) {
                      final isLast = tf == monitoredTimeframes.last;
                      return Column(
                        children: [
                          SwitchListTile(
                            title: Text('$tf 周期提醒'),
                            subtitle: Text(
                              provider.getTimeframeToggle(tf) ? '已开启' : '已关闭',
                            ),
                            value: provider.getTimeframeToggle(tf),
                            onChanged: (v) =>
                                provider.setTimeframeToggle(tf, v),
                          ),
                          if (!isLast) const Divider(height: 1),
                        ],
                      );
                    }),
                    const Divider(height: 1),
                    // 高分阈值 Slider
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '高分提醒阈值',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${provider.highThreshold}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: provider.highThreshold.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '${provider.highThreshold}',
                            onChanged: (v) =>
                                provider.setHighThreshold(v.round()),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                              Text('100',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 中分阈值 Slider
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '中分提醒阈值',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${provider.medThreshold}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: provider.medThreshold.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '${provider.medThreshold}',
                            onChanged: (v) =>
                                provider.setMedThreshold(v.round()),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                              Text('100',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 说明文字
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '评分高于高分阈值且死猫风险低 → 响铃+震动提醒',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '评分高于中分阈值 → 横幅提醒，低分仅看板可见',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
                  trailing: _displayVersion,
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
      applicationVersion: _displayVersion,
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
