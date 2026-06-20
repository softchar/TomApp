import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tomapp/widgets/equity_curve_chart.dart';

/// EquityCurveChart Widget 测试。
///
/// 验证图表渲染不抛异常、双系列数据正确传递。
void main() {
  group('EquityCurveChart', () {
    testWidgets('图表渲染不抛异常', (tester) async {
      final zeroCost = [
        (tradeIndex: 0, cumulativeR: 0.5),
        (tradeIndex: 1, cumulativeR: 1.2),
        (tradeIndex: 2, cumulativeR: 0.8),
      ];
      final withCost = [
        (tradeIndex: 0, cumulativeR: 0.3),
        (tradeIndex: 1, cumulativeR: 0.9),
        (tradeIndex: 2, cumulativeR: 0.5),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquityCurveChart(
              zeroCostData: zeroCost,
              withCostData: withCost,
            ),
          ),
        ),
      );

      // 图表应渲染成功（不抛异常）
      expect(find.byType(EquityCurveChart), findsOneWidget);
    });

    testWidgets('双系列数据正确传递——图例两曲线标签均可见', (tester) async {
      final zeroCost = [
        (tradeIndex: 0, cumulativeR: 0.5),
        (tradeIndex: 1, cumulativeR: 1.2),
      ];
      final withCost = [
        (tradeIndex: 0, cumulativeR: 0.3),
        (tradeIndex: 1, cumulativeR: 0.9),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquityCurveChart(
              zeroCostData: zeroCost,
              withCostData: withCost,
            ),
          ),
        ),
      );

      // 图例中应显示"零成本"和"含成本"
      expect(find.text('零成本'), findsOneWidget);
      expect(find.text('含成本'), findsOneWidget);
    });

    testWidgets('空数据不抛异常', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EquityCurveChart(
              zeroCostData: const [],
              withCostData: const [],
            ),
          ),
        ),
      );

      expect(find.byType(EquityCurveChart), findsOneWidget);
    });
  });
}
