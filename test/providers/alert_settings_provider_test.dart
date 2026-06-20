import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapp/providers/alert_settings_provider.dart';
import 'package:tomapp/services/rebound/rebound_timeframes.dart';

/// Phase 5 / Task 2：AlertSettingsProvider 测试。
///
/// 验证 TF 开关 + 阈值 + SharedPreferences 持久化逻辑。

void main() {
  late AlertSettingsProvider provider;

  setUp(() async {
    // 设置 mock SharedPreferences 初始值
    SharedPreferences.setMockInitialValues({});
    provider = AlertSettingsProvider();
    await provider.load();
  });

  tearDown(() {
    provider.dispose();
  });

  group('AlertSettingsProvider', () {
    test('test_default_values: 默认 highThreshold=75, medThreshold=50', () {
      expect(provider.highThreshold, 75);
      expect(provider.medThreshold, 50);
    });

    test('test_all_tfs_default_true: 所有 monitoredTimeframes 默认开关为 true',
        () {
      for (final tf in monitoredTimeframes) {
        expect(
          provider.getTimeframeToggle(tf),
          isTrue,
          reason: '$tf 默认应为 true',
        );
      }
    });

    test('setTimeframeToggle 后 bool 开关生效并触发 notifyListeners', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setTimeframeToggle('15m', false);
      expect(provider.getTimeframeToggle('15m'), isFalse);
      expect(notifyCount, 1);
    });

    test('setHighThreshold clamp 到 0-100 范围', () async {
      await provider.setHighThreshold(120);
      expect(provider.highThreshold, 100);

      await provider.setHighThreshold(-5);
      expect(provider.highThreshold, 0);
    });

    test('setMedThreshold clamp 到 0-100 范围', () async {
      await provider.setMedThreshold(120);
      expect(provider.medThreshold, 100);

      await provider.setMedThreshold(-5);
      expect(provider.medThreshold, 0);
    });

    test('TF 开关持久化到 SharedPreferences', () async {
      // 修改 15m 开关为 false（当前 monitoredTimeframes 唯一 TF）
      await provider.setTimeframeToggle('15m', false);
      expect(provider.getTimeframeToggle('15m'), isFalse);

      // 重建 Provider 触发 SP 重新读取（模拟 app 重启）
      final newProvider = AlertSettingsProvider();
      await newProvider.load();

      // 从 SP 读取应保持 false
      expect(
        newProvider.getTimeframeToggle('15m'),
        isFalse,
        reason: 'SharedPreferences 持久化的 false 值应在重新加载后保持',
      );

      newProvider.dispose();
    });
  });
}
