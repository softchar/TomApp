import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/rebound/rebound_timeframes.dart';

/// 反弹提示设置 Provider（ChangeNotifier）。
///
/// 管理 per-TF 周期开关、高/中阈值，通过 [SharedPreferences] 持久化。
/// 由 AlertThrottler 在 evaluate() 中消费，UI 在设置页编辑。
///
/// ## 安全性
/// - 阈值 setter 强制 `clamp(0, 100)`（per ASVS V5 输入校验，T-05-03）
/// - SharedPreferences 为 Android `MODE_PRIVATE`，非 root 不可外部写入
/// - 日上限计数器不在此 Provider 中——由 AlertThrottler 内存维护
///   （per RESEARCH.md Pitfall 2 规避策略：内存 + 跨日重置）
class AlertSettingsProvider extends ChangeNotifier {
  // ── SharedPreferences 键名常量 ─────────────────────────
  static const String _tfTogglePrefix = 'alert_tf_toggle_';
  static const String _highThresholdKey = 'alert_high_threshold';
  static const String _medThresholdKey = 'alert_med_threshold';

  // ── 默认值 ────────────────────────────────────────────
  static const int _defaultHighThreshold = 75;
  static const int _defaultMedThreshold = 70;

  // ── 内部状态 ──────────────────────────────────────────
  Map<String, bool> _timeframeToggles = {};
  int _highThreshold = _defaultHighThreshold;
  int _medThreshold = _defaultMedThreshold;
  SharedPreferences? _prefs;

  // ── 公开 getter ──────────────────────────────────────

  /// per-TF 开关只读视图（不可变）。
  Map<String, bool> get timeframeToggles =>
      Map.unmodifiable(_timeframeToggles);

  /// 高分阈值（0-100）。
  int get highThreshold => _highThreshold;

  /// 中分阈值（0-100）。
  int get medThreshold => _medThreshold;

  /// 查询单 TF 的开关状态。未注册的 TF 默认返回 `false`。
  bool getTimeframeToggle(String tf) => _timeframeToggles[tf] ?? false;

  // ── 配置读写 ─────────────────────────────────────────

  /// 从 [SharedPreferences] 加载持久化配置。
  ///
  /// 应在 Provider 构造后立即调用（在 UI 中通过
  /// `ChangeNotifierProvider` + `create` 异步处理或手动 await）。
  /// 读取后触发一次 [notifyListeners]。
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    // 初始化 TF 开关：默认全部为 true
    _timeframeToggles = {};
    for (final tf in monitoredTimeframes) {
      final key = '$_tfTogglePrefix$tf';
      _timeframeToggles[tf] = _prefs?.getBool(key) ?? true;
    }

    // 初始化阈值
    _highThreshold =
        _prefs?.getInt(_highThresholdKey) ?? _defaultHighThreshold;
    _medThreshold =
        _prefs?.getInt(_medThresholdKey) ?? _defaultMedThreshold;

    notifyListeners();
  }

  /// 设置指定 TF 的开关状态。
  ///
  /// 写入 [SharedPreferences] 并触发 [notifyListeners]。
  Future<void> setTimeframeToggle(String tf, bool enabled) async {
    _timeframeToggles[tf] = enabled;
    await _prefs?.setBool('$_tfTogglePrefix$tf', enabled);
    notifyListeners();
  }

  /// 设置高分阈值（自动 clamp 到 0-100 范围，per T-05-03）。
  ///
  /// 写入 [SharedPreferences] 并触发 [notifyListeners]。
  Future<void> setHighThreshold(int value) async {
    _highThreshold = value.clamp(0, 100);
    await _prefs?.setInt(_highThresholdKey, _highThreshold);
    notifyListeners();
  }

  /// 设置中分阈值（自动 clamp 到 0-100 范围，per T-05-03）。
  ///
  /// 写入 [SharedPreferences] 并触发 [notifyListeners]。
  Future<void> setMedThreshold(int value) async {
    _medThreshold = value.clamp(0, 100);
    await _prefs?.setInt(_medThresholdKey, _medThreshold);
    notifyListeners();
  }
}
