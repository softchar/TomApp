import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/technical_indicators.dart';

/// Phase 1 / INDIC 单测：ATR(Wilders)、warm-up、纯函数幂等、RSI 超卖拐头、Bollinger、swing。

/// 构造一根 K 线（open/close 居中、给定 high/low），close 默认 100。
KlineData _bar(double high, double low, {double close = 100, int t = 0}) {
  return KlineData(
    time: DateTime(2024, 1, 1, 0, t),
    open: close,
    high: high,
    low: low,
    close: close,
    volume: 1,
  );
}

/// TR=2 的标准 bar（high=101, low=99, close=100）。
KlineData _tr2(int t) => _bar(101, 99, t: t);

void main() {
  final ti = TechnicalIndicators();

  group('ATR (Wilders/RMA, period=14)', () {
    test('warm-up: 头 14 根返回 null（长度不足）', () {
      final k14 = List.generate(14, _tr2);
      expect(ti.atr(k14), isNull, reason: '长度 <= period 应返回 null');
      final series14 = ti.atrSeries(k14);
      expect(series14.length, 14);
      expect(series14.every((e) => e == null), isTrue, reason: '前 period 个全为 null');
    });

    test('刚好 15 根：种子 = 头 14 根 TR 均值（恒定 TR=2 → ATR=2）', () {
      final k15 = List.generate(15, _tr2);
      expect(ti.atr(k15), closeTo(2.0, 1e-9));
      final s = ti.atrSeries(k15);
      expect(s[14], closeTo(2.0, 1e-9));
    });

    test('Wilders 平滑：第 15 根 TR=4 后 ATR = (2*13+4)/14 = 30/14', () {
      // bars 0..13: TR=2；bar 14: TR=4；bar 15: TR=2（共 16 根）
      final k = <KlineData>[
        for (int i = 0; i < 14; i++) _tr2(i),
        _bar(102, 98, t: 14), // TR=4
        _tr2(15),
      ];
      expect(ti.atr(k), closeTo(30.0 / 14.0, 1e-9));
      final s = ti.atrSeries(k);
      expect(s[14], closeTo(2.0, 1e-9), reason: '种子');
      expect(s[15], closeTo(30.0 / 14.0, 1e-9), reason: 'Wilders 第一步');
    });

    test('纯函数幂等冒烟（key_links）：同输入两次调用逐位相等、无副作用', () {
      final k = <KlineData>[
        for (int i = 0; i < 14; i++) _tr2(i),
        _bar(102, 98, t: 14),
        _tr2(15),
      ];
      final snapshot = k.map((b) => b.toMap()).toList();
      final a1 = ti.atr(k);
      final a2 = ti.atr(k);
      final s1 = ti.atrSeries(k);
      final s2 = ti.atrSeries(k);
      expect(a1, equals(a2));
      // 逐位相等
      for (int i = 0; i < s1.length; i++) {
        expect(s1[i], equals(s2[i]));
      }
      // 无副作用：输入对象未被篡改
      final after = k.map((b) => b.toMap()).toList();
      expect(after, equals(snapshot));
    });
  });

  group('RSI (14)', () {
    test('单调上涨序列 → RSI 接近 100（avgLoss=0 → 100）', () {
      final k = <KlineData>[
        for (int i = 0; i < 25; i++)
          KlineData(
            time: DateTime(2024, 1, 1, 0, i),
            open: 100 + i.toDouble(),
            high: 101 + i.toDouble(),
            low: 99 + i.toDouble(),
            close: 100 + i.toDouble(),
            volume: 1,
          ),
      ];
      final r = ti.rsi(k);
      expect(r, isNotNull);
      expect(r!, closeTo(100.0, 1e-9));
    });

    test('rsiTurningUp：超卖后向上拐头 → oversoldTurningUp=true', () {
      // 25 根急跌（每根 -3），然后 3 根回升（每根 +4）
      final closes = <double>[];
      double p = 100;
      for (int i = 0; i < 25; i++) {
        p -= 3;
        closes.add(p);
      }
      for (int i = 0; i < 3; i++) {
        p += 4;
        closes.add(p);
      }
      final k = <KlineData>[
        for (int i = 0; i < closes.length; i++)
          KlineData(
            time: DateTime(2024, 1, 1, 0, i),
            open: closes[i],
            high: closes[i] + 1,
            low: closes[i] - 1,
            close: closes[i],
            volume: 1,
          ),
      ];
      final r = ti.rsiTurningUp(k);
      expect(r.oversoldTurningUp, isTrue,
          reason: '急跌至 RSI<30 后回升应判定为超卖拐头');
    });

    test('长度不足返回 null/false', () {
      final k = List.generate(10, _tr2);
      expect(ti.rsi(k), isNull);
      final r = ti.rsiTurningUp(k);
      expect(r.rsi, isNull);
      expect(r.oversoldTurningUp, isFalse);
    });
  });

  group('Bollinger（复用既有 calculateBOLL）', () {
    test('三轨齐备：upper >= middle >= lower（在 period 之后）', () {
      final k = <KlineData>[
        for (int i = 0; i < 30; i++)
          KlineData(
            time: DateTime(2024, 1, 1, 0, i),
            open: 100 + (i % 5).toDouble(),
            high: 105 + (i % 5).toDouble(),
            low: 95 + (i % 5).toDouble(),
            close: 100 + (i % 5).toDouble(),
            volume: 1,
          ),
      ];
      final b = ti.calculateBOLL(k, period: 20);
      final i = 25; // 远超 warm-up
      expect(b.upper[i], isNotNull);
      expect(b.middle[i], isNotNull);
      expect(b.lower[i], isNotNull);
      expect(b.upper[i]! >= b.middle[i]!, isTrue);
      expect(b.middle[i]! >= b.lower[i]!, isTrue);
    });
  });

  group('swing high/low', () {
    test('swingHigh：返回最近一个左右各 lookback 根更小的峰索引', () {
      // highs: 1 1 1 3 1 1 5 1 1（索引 3 和 6 是峰，6 最近）
      final highs = <double>[1, 1, 1, 3, 1, 1, 5, 1, 1];
      final k = <KlineData>[
        for (int i = 0; i < highs.length; i++)
          KlineData(
            time: DateTime(2024, 1, 1, 0, i),
            open: 0,
            high: highs[i],
            low: 0,
            close: 0,
            volume: 1,
          ),
      ];
      expect(ti.swingHigh(k, lookback: 2), 6);
    });

    test('swingLow：返回最近一个左右各 lookback 根更大的谷索引', () {
      final lows = <double>[9, 9, 9, 5, 9, 9, 1, 9, 9];
      final k = <KlineData>[
        for (int i = 0; i < lows.length; i++)
          KlineData(
            time: DateTime(2024, 1, 1, 0, i),
            open: 10,
            high: 10,
            low: lows[i],
            close: 10,
            volume: 1,
          ),
      ];
      expect(ti.swingLow(k, lookback: 2), 6);
    });

    test('无明显 swing 时返回 null', () {
      // 单调递增 high：无峰
      final k = <KlineData>[
        for (int i = 0; i < 8; i++)
          KlineData(
            time: DateTime(2024, 1, 1, 0, i),
            open: 0,
            high: i.toDouble(),
            low: 0,
            close: 0,
            volume: 1,
          ),
      ];
      expect(ti.swingHigh(k, lookback: 2), isNull);
    });
  });
}
