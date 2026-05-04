import 'package:shared_preferences/shared_preferences.dart';

class ContractSyncSettings {
  static const String _keyAutoSyncEnabled = 'contract_auto_sync_enabled';

  bool _autoSyncEnabled = false;
  bool get autoSyncEnabled => _autoSyncEnabled;

  static ContractSyncSettings? _instance;
  static ContractSyncSettings get instance => _instance ??= ContractSyncSettings._internal();

  factory ContractSyncSettings() => instance;

  ContractSyncSettings._internal() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoSyncEnabled = prefs.getBool(_keyAutoSyncEnabled) ?? false;
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSyncEnabled, value);
    _autoSyncEnabled = value;
  }

  Future<void> init() async {
    await _loadSettings();
  }
}
