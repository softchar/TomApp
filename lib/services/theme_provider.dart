import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题管理Provider
class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    // 这里需要根据实际模式判断，暂时返回false
    return _themeMode == ThemeMode.dark;
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  /// 从本地加载主题设置
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeKey) ?? 2; // 默认跟随系统
    _themeMode = ThemeMode.values[themeModeIndex];
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  /// 切换到亮色模式
  Future<void> setLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  /// 切换到暗色模式
  Future<void> setDarkMode() async {
    await setThemeMode(ThemeMode.dark);
  }

  /// 切换到系统模式
  Future<void> setSystemMode() async {
    await setThemeMode(ThemeMode.system);
  }
}
