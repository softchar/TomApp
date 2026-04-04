import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PumpConfig with ChangeNotifier {
  // 配置键
  static const String _keyBaseThreshold = 'pump_base_threshold';
  static const String _keyMinThreshold = 'pump_min_threshold';
  static const String _keyMaxThreshold = 'pump_max_threshold';
  static const String _keyActiveDataDays = 'pump_active_data_days';
  static const String _keyArchiveDataDays = 'pump_archive_data_days';
  static const String _keyMemoryCacheSize = 'pump_memory_cache_size';
  static const String _keyListPageSize = 'pump_list_page_size';
  static const String _keyPullbackMonitorMinutes = 'pump_pullback_monitor_minutes';

  // 默认值
  double _baseThreshold = 2.0;
  double _minThreshold = 1.0;
  double _maxThreshold = 4.0;
  int _activeDataDays = 30;
  int _archiveDataDays = 90;
  int _memoryCacheSize = 50;
  int _listPageSize = 50;
  int _pullbackMonitorMinutes = 15;

  // Getters
  double get baseThreshold => _baseThreshold;
  double get minThreshold => _minThreshold;
  double get maxThreshold => _maxThreshold;
  int get activeDataDays => _activeDataDays;
  int get archiveDataDays => _archiveDataDays;
  int get memoryCacheSize => _memoryCacheSize;
  int get listPageSize => _listPageSize;
  int get pullbackMonitorMinutes => _pullbackMonitorMinutes;

  // Singleton
  static final PumpConfig _instance = PumpConfig._internal();
  static PumpConfig get instance => _instance;
  factory PumpConfig() => _instance;

  PumpConfig._internal();

  /// 从 SharedPreferences 加载配置
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _baseThreshold = prefs.getDouble(_keyBaseThreshold) ?? _baseThreshold;
      _minThreshold = prefs.getDouble(_keyMinThreshold) ?? _minThreshold;
      _maxThreshold = prefs.getDouble(_keyMaxThreshold) ?? _maxThreshold;
      _activeDataDays = prefs.getInt(_keyActiveDataDays) ?? _activeDataDays;
      _archiveDataDays = prefs.getInt(_keyArchiveDataDays) ?? _archiveDataDays;
      _memoryCacheSize = prefs.getInt(_keyMemoryCacheSize) ?? _memoryCacheSize;
      _listPageSize = prefs.getInt(_keyListPageSize) ?? _listPageSize;
      _pullbackMonitorMinutes = prefs.getInt(_keyPullbackMonitorMinutes) ?? _pullbackMonitorMinutes;

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load pump config: $e');
    }
  }

  /// 保存配置到 SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setDouble(_keyBaseThreshold, _baseThreshold);
      await prefs.setDouble(_keyMinThreshold, _minThreshold);
      await prefs.setDouble(_keyMaxThreshold, _maxThreshold);
      await prefs.setInt(_keyActiveDataDays, _activeDataDays);
      await prefs.setInt(_keyArchiveDataDays, _archiveDataDays);
      await prefs.setInt(_keyMemoryCacheSize, _memoryCacheSize);
      await prefs.setInt(_keyListPageSize, _listPageSize);
      await prefs.setInt(_keyPullbackMonitorMinutes, _pullbackMonitorMinutes);
    } catch (e) {
      debugPrint('Failed to save pump config: $e');
    }
  }

  /// Setters with auto-save
  set baseThreshold(double value) {
    _baseThreshold = value.clamp(0.5, 10.0);
    notifyListeners();
    save();
  }

  set minThreshold(double value) {
    _minThreshold = value.clamp(0.1, _baseThreshold);
    notifyListeners();
    save();
  }

  set maxThreshold(double value) {
    _maxThreshold = value.clamp(_baseThreshold, 20.0);
    notifyListeners();
    save();
  }

  set activeDataDays(int value) {
    _activeDataDays = value.clamp(7, 365);
    notifyListeners();
    save();
  }

  set archiveDataDays(int value) {
    _archiveDataDays = value.clamp(30, 365);
    notifyListeners();
    save();
  }

  set memoryCacheSize(int value) {
    _memoryCacheSize = value.clamp(10, 500);
    notifyListeners();
    save();
  }

  set listPageSize(int value) {
    _listPageSize = value.clamp(10, 200);
    notifyListeners();
    save();
  }

  set pullbackMonitorMinutes(int value) {
    _pullbackMonitorMinutes = value.clamp(5, 60);
    notifyListeners();
    save();
  }

  /// 重置为默认值
  Future<void> reset() async {
    _baseThreshold = 2.0;
    _minThreshold = 1.0;
    _maxThreshold = 4.0;
    _activeDataDays = 30;
    _archiveDataDays = 90;
    _memoryCacheSize = 50;
    _listPageSize = 50;
    _pullbackMonitorMinutes = 15;

    notifyListeners();
    await save();
  }
}
