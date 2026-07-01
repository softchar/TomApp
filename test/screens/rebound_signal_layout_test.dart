import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/screens/rebound_dashboard_screen.dart';

/// ReboundSignalLayout.resolve 纯函数断点单测。
///
/// 验证信号行在不同可用宽度下的列裁剪策略，保证 360px 窄屏不溢出。
/// 宽度预算（卡内可用宽，已扣除 card margin + padding）：
///   core(非止损固定列+间隔)=256  止损块=48  sparkline 舒适=90/下限=56/极限=40
///   全列档 ≥394｜裁止损宽裕档 ≥312｜裁止损极限档 ≥296｜隐藏 sparkline <296
void main() {
  group('ReboundSignalLayout.resolve', () {
    test('宽屏（≥394 可用）：全列 + 舒适 sparkline', () {
      final l = ReboundSignalLayout.resolve(440);
      expect(l.showStoploss, isTrue);
      expect(l.showSparkline, isTrue);
      expect(l.sparklineMin, 90.0);
    });

    test('394 刚好触发全列档（边界含等号）', () {
      final l = ReboundSignalLayout.resolve(394);
      expect(l.showStoploss, isTrue);
      expect(l.sparklineMin, 90.0);
    });

    test('400 仍在全列档（足够放下止损 + 舒适 sparkline）', () {
      final l = ReboundSignalLayout.resolve(400);
      expect(l.showStoploss, isTrue);
      expect(l.showSparkline, isTrue);
    });

    test('裁止损宽裕档（312–394，多数大屏 iPhone）：止损隐藏，sparkline 56', () {
      final l = ReboundSignalLayout.resolve(350);
      expect(l.showStoploss, isFalse);
      expect(l.showSparkline, isTrue);
      expect(l.sparklineMin, 56.0);
    });

    test('312 边界落宽裕档', () {
      final l = ReboundSignalLayout.resolve(312);
      expect(l.showStoploss, isFalse);
      expect(l.showSparkline, isTrue);
      expect(l.sparklineMin, 56.0);
    });

    test('裁止损极限档（296–312）：sparkline 压到 40', () {
      final l = ReboundSignalLayout.resolve(300);
      expect(l.showStoploss, isFalse);
      expect(l.showSparkline, isTrue);
      expect(l.sparklineMin, 40.0);
    });

    test('360px 屏典型可用宽（≈320）：永不溢出，止损裁、sparkline 在', () {
      // 360px 屏 - card margin 16 - padding 24 = 320 可用
      final l = ReboundSignalLayout.resolve(320);
      expect(l.showSparkline, isTrue, reason: '360px 屏必须保留 sparkline');
      expect(l.showStoploss, isFalse, reason: '360px 屏裁止损列防溢出');
    });

    test('296 边界仍保留 sparkline（极限 40）', () {
      final l = ReboundSignalLayout.resolve(296);
      expect(l.showSparkline, isTrue);
      expect(l.sparklineMin, 40.0);
    });

    test('极窄（<296，分屏/极小屏）：sparkline 彻底隐藏，仅留 core', () {
      final l = ReboundSignalLayout.resolve(280);
      expect(l.showStoploss, isFalse);
      expect(l.showSparkline, isFalse);
      expect(l.sparklineMin, 0);
    });
  });
}
