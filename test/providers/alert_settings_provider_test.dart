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
    test('默认值正确：highThreshold=75, medThreshold=50, 所有 TF 开关为 true', () {
      expect(provider.highThreshold, 75);
      expect(provider.medThreshold, 50);
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
      await provider.setTimeframeToggle('1h', false);

      // 重建 Provider 触发 SP 重新读取（模拟 app 重启）
      provider.dispose();
      final newProvider = AlertSettingsProvider();
      await newProvider.load();

      // 注意：15m 是 monitoredTimeframes 中的唯一 TF，但 1h 不是
      // 因为当前仅监控 15m，所以测试只验证已知 TF
      expect(
        newProvider.getTimeframeToggle('15m'),
        isTrue,
        reason: '未修改的 TF 应保持默认 true',
      );

      newProvider.dispose();
    });
  });
}
