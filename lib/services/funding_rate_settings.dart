import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 费率自动更新设置服务
class FundingRateSettings with ChangeNotifier {
  static const String _keyAutoUpdate = 'funding_rate_auto_update';

  bool _autoUpdateEnabled = true; // 默认开启

  bool get autoUpdateEnabled => _autoUpdateEnabled;

  /// 加载设置
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoUpdateEnabled = prefs.getBool(_keyAutoUpdate) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load funding rate settings: $e');
    }
  }

  /// 设置自动更新开关
  Future<void> setAutoUpdateEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoUpdate, value);
      _autoUpdateEnabled = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save funding rate settings: $e');
    }
  }
}
