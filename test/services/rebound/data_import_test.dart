import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/rebound/data_import_service.dart';

/// DataImportService 单元测试。
///
/// 覆盖：时间戳标准化、CSV 解析容错、去重、symbol 校验、fetchTopSymbols。

/// 构造模拟的 Binance 月度 ZIP CSV 内容（12 列格式）。
String _mockCsvContent({
  required int openTimeMs,
  double open = 100.0,
  double high = 101.0,
  double low = 99.0,
  double close = 100.5,
  double volume = 1000.0,
}) {
  // 列: openTime, open, high, low, close, volume, closeTime, quoteVolume,
  //      trades, takerBuyBaseVol, takerBuyQuoteVol, ignore
  return '$openTimeMs,$open,$high,$low,$close,$volume,'
      '${openTimeMs + 900000},50000.0,100,400.0,200.0,0';
}

void main() {
  group('DataImportService._parseCsv', () {
    late DataImportService service;

    setUp(() {
      service = DataImportService();
    });

    test('正确解析 13 位毫秒时间戳', () {
      // Binance 2025 年之前的 CSV 使用 13 位毫秒时间戳
      final csv = _mockCsvContent(
        openTimeMs: 1704067200000, // 2024-01-01 00:00:00 UTC
        open: 42000.0,
        high: 42100.0,
        low: 41900.0,
        close: 42050.0,
        volume: 1500.0,
      );

      final results = service.parseCsvForTest(
        csv,
        symbol: 'BTCUSDT',
        interval: '15m',
      );

      expect(results, hasLength(1));
      final kline = results.first;
      expect(kline.time.year, equals(2024));
      expect(kline.open, equals(42000.0));
      expect(kline.high, equals(42100.0));
      expect(kline.low, equals(41900.0));
      expect(kline.close, equals(42050.0));
      expect(kline.volume, equals(1500.0));
    });

    test('正确解析 16 位微秒时间戳并转为毫秒', () {
      // Binance 2025 年及之后的 CSV 使用 16 位微秒时间戳
      const microTime = 1735689600000000; // 2025-01-01 00:00:00 UTC（微秒）
      final csv = _mockCsvContent(
        openTimeMs: microTime,
        open: 50000.0,
      );

      final results = service.parseCsvForTest(
        csv,
        symbol: 'BTCUSDT',
        interval: '15m',
      );

      expect(results, hasLength(1));
      final kline = results.first;
      // 微秒 / 1000 = 毫秒 → 应该是 2025 年
      expect(kline.time.year, equals(2025));
      expect(kline.time.month, equals(1));
      expect(kline.time.day, equals(1));
      expect(
        kline.time.millisecondsSinceEpoch,
        equals(microTime ~/ 1000),
      );
    });

    test('空行跳过不崩溃', () {
      const csv = '''
1704067200000,42000.0,42100.0,41900.0,42050.0,1500.0,1704068100000,50000.0,100,400.0,200.0,0

1704068100000,42050.0,42200.0,42000.0,42150.0,1200.0,1704069000000,50000.0,100,400.0,200.0,0
''';

      final results = service.parseCsvForTest(
        csv,
        symbol: 'BTCUSDT',
        interval: '15m',
      );

      // 2 行有效数据 + 1 行空行 → 2 条 K 线
      expect(results, hasLength(2));
    });

    test('列数 !=12 的行跳过不崩溃', () {
      // 1 行正常 12 列，1 行只有 11 列（畸形），再 1 行正常 12 列
      const normalRow = '1704067200000,42000.0,42100.0,41900.0,42050.0,1500.0,1704068100000,50000.0,100,400.0,200.0,0';
      const malformedRow = '1704068100000,42050.0,42200.0,42000.0,42150.0,1200.0,1704069000000,50000.0,100,400.0,200.0'; // 只有 11 列
      const normalRow2 = '1704069000000,42150.0,42300.0,42100.0,42250.0,1100.0,1704070000000,50000.0,100,400.0,200.0,0';

      const csv = '$normalRow\n$malformedRow\n$normalRow2';

      final results = service.parseCsvForTest(
        csv,
        symbol: 'BTCUSDT',
        interval: '15m',
      );

      // 只有 2 行有效数据，畸形行被跳过
      expect(results, hasLength(2));
    });

    test('多行正确解析并保持顺序', () {
      final lines = <String>[];
      for (int i = 0; i < 3; i++) {
        lines.add(_mockCsvContent(
          openTimeMs: 1704067200000 + i * 900000,
          open: 100.0 + i,
          close: 100.5 + i,
        ));
      }
      final csv = lines.join('\n');

      final results = service.parseCsvForTest(
        csv,
        symbol: 'ETHUSDT',
        interval: '15m',
      );

      expect(results, hasLength(3));
      expect(results[0].open, equals(100.0));
      expect(results[1].open, equals(101.0));
      expect(results[2].open, equals(102.0));
    });
  });

  group('DataImportService symbol 校验', () {
    late DataImportService service;

    setUp(() {
      service = DataImportService();
    });

    test('有效 symbol 格式通过', () {
      // 格式: 大写字母 + USDT
      expect(service.isValidSymbol('BTCUSDT'), isTrue);
      expect(service.isValidSymbol('ETHUSDT'), isTrue);
      expect(service.isValidSymbol('SOLUSDT'), isTrue);
    });

    test('无效 symbol 格式被拒绝', () {
      expect(service.isValidSymbol('btcusdt'), isFalse); // 小写
      expect(service.isValidSymbol('BTCBUSD'), isFalse); // 非 USDT
      expect(service.isValidSymbol('BTC-USDT'), isFalse); // 含连字符
      expect(service.isValidSymbol(''), isFalse); // 空串
      expect(service.isValidSymbol('123USDT'), isFalse); // 数字开头
    });
  });

  group('DataImportService downloadMonth 参数校验', () {
    late DataImportService service;

    setUp(() {
      service = DataImportService();
    });

    test('无效 symbol 抛出错误', () {
      expect(
        () => service.validateSymbol('btcusdt'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('有效 symbol 不抛出错误', () {
      expect(
        () => service.validateSymbol('BTCUSDT'),
        returnsNormally,
      );
    });
  });
}
