import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TomApp Design System Colors
class AppColors {
  // Primary - Gold for brand/trust
  static const Color primary = Color(0xFFF59E0B);
  static const Color onPrimary = Color(0xFF0F172A);
  static const Color primaryContainer = Color(0xFFFEF3C7);
  static const Color onPrimaryContainer = Color(0xFF92400E);

  // Secondary - Lighter gold
  static const Color secondary = Color(0xFFFBBF24);
  static const Color onSecondary = Color(0xFF0F172A);

  // Accent/CTA - Purple for tech/actions
  static const Color accent = Color(0xFF8B5CF6);
  static const Color onAccent = Color(0xFFFFFFFF);

  // Background - Deep dark blue
  static const Color background = Color(0xFF0F172A);
  static const Color onBackground = Color(0xFFF8FAFC);

  // Surface variants
  static const Color surface = Color(0xFF1E293B);
  static const Color onSurface = Color(0xFFF8FAFC);
  static const Color surfaceVariant = Color(0xFF272F42);
  static const Color onSurfaceVariant = Color(0xFFCBD5E1);

  // Borders and dividers
  static const Color border = Color(0xFF334155);
  static const Color divider = Color(0xFF334155);

  // Semantic colors
  static const Color success = Color(0xFFF59E0B); // Gold for gains
  static const Color successLight = Color(0xFFFEF3C7);
  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF97316);
  static const Color info = Color(0xFF3B82F6);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Special colors for crypto
  static const Color gain = Color(0xFFF59E0B); // Gold for gains (Chinese red = up)
  static const Color loss = Color(0xFF22C55E); // Green for losses (Chinese green = down)
  static const Color gainBg = Color(0x1AF59E0B);
  static const Color lossBg = Color(0x1A22C55E);
}

/// TomApp Text Styles
class AppTextStyles {
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}

/// TomApp Spacing
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// TomApp Border Radius
class AppRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 9999;
}

/// 主题管理Provider
class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.dark; // 默认暗色模式更适合交易应用

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    // 默认返回 true，因为交易应用通常使用暗色主题
    return _themeMode == ThemeMode.dark || _themeMode == ThemeMode.system;
  }

  ThemeProvider() {
    _loadThemeMode();
  }

  /// 从本地加载主题设置
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeKey) ?? 0; // 默认暗色模式
    _themeMode = ThemeMode.values[themeModeIndex.clamp(0, ThemeMode.values.length - 1)];
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
