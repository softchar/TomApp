import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 合约自动同步设置服务
class ContractSyncSettings with ChangeNotifier {
  static const String _keyAutoSyncEnabled = 'contract_auto_sync_enabled';

  bool _autoSyncEnabled = false;

  bool get autoSyncEnabled => _autoSyncEnabled;

  /// 加载设置
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSyncEnabled = prefs.getBool(_keyAutoSyncEnabled) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load contract sync settings: $e');
    }
  }

  /// 设置自动同步开关
  Future<void> setAutoSyncEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoSyncEnabled, value);
      _autoSyncEnabled = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save contract sync settings: $e');
    }
  }
}
