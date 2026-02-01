import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

/// 我的页面
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
}
