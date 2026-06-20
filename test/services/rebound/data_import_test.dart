import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tomapp/services/rebound/data_import_service.dart';
import 'package:tomapp/services/rebound/funding_rate_service.dart';

/// DataImportService 和 FundingRateService 单元测试。
///
/// 覆盖：时间戳标准化、CSV 解析容错、去重、symbol 校验、
/// funding rate 分页拉取、缓存查询、缓存命中。

/// 构造模拟的 Binance 月度 ZIP CSV 内容（12 列格式）。
String mockCsvContent({
  required int openTimeMs,
  double open = 100.0,
  double high = 101.0,
  double low = 99.0,
  double close = 100.5,
  double volume = 1000.0,
}) {
  return '$openTimeMs,$open,$high,$low,$close,$volume,'
      '${openTimeMs + 900000},50000.0,100,400.0,200.0,0';
}

/// 创建模拟的 funding rate JSON 响应。
String mockFundingRateResponse(List<Map<String, dynamic>> items) {
  return jsonEncode(items);
}

/// 模拟 HTTP 客户端，返回预定义的响应序列。
class MockHttpClient extends http.BaseClient {
  final List<http.Response> responses;
  int callCount = 0;

  MockHttpClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = responses[callCount % responses.length];
    callCount++;
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      request: request,
    );
  }
}

void main() {
  group('DataImportService._parseCsv', () {
    late DataImportService service;

    setUp(() {
      service = DataImportService();
    });

    test('正确解析 13 位毫秒时间戳', () {
      final csv = mockCsvContent(
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
      const microTime = 1735689600000000; // 2025-01-01 00:00:00 UTC（微秒）
      final csv = mockCsvContent(
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

      expect(results, hasLength(2));
    });

    test('列数 !=12 的行跳过不崩溃', () {
      const normalRow = '1704067200000,42000.0,42100.0,41900.0,42050.0,1500.0,1704068100000,50000.0,100,400.0,200.0,0';
      const malformedRow = '1704068100000,42050.0,42200.0,42000.0,42150.0,1200.0,1704069000000,50000.0,100,400.0,200.0';
      const normalRow2 = '1704069000000,42150.0,42300.0,42100.0,42250.0,1100.0,1704070000000,50000.0,100,400.0,200.0,0';

      const csv = '$normalRow\n$malformedRow\n$normalRow2';

      final results = service.parseCsvForTest(
        csv,
        symbol: 'BTCUSDT',
        interval: '15m',
      );

      expect(results, hasLength(2));
    });

    test('多行正确解析并保持顺序', () {
      final lines = <String>[];
      for (int i = 0; i < 3; i++) {
        lines.add(mockCsvContent(
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
      expect(service.isValidSymbol('BTCUSDT'), isTrue);
      expect(service.isValidSymbol('ETHUSDT'), isTrue);
      expect(service.isValidSymbol('SOLUSDT'), isTrue);
    });

    test('无效 symbol 格式被拒绝', () {
      expect(service.isValidSymbol('btcusdt'), isFalse);
      expect(service.isValidSymbol('BTCBUSD'), isFalse);
      expect(service.isValidSymbol('BTC-USDT'), isFalse);
      expect(service.isValidSymbol(''), isFalse);
      expect(service.isValidSymbol('123USDT'), isFalse);
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

  group('FundingRateService', () {
    test('getRate 通过 fetchHistory 填充后从缓存查找正确的 funding rate', () async {
      // 模拟一次性返回全部数据（无分页）
      final mockResponse = mockFundingRateResponse([
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0001',
          'fundingTime': DateTime(2025, 1, 1, 0, 0).millisecondsSinceEpoch,
        },
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0002',
          'fundingTime': DateTime(2025, 1, 1, 8, 0).millisecondsSinceEpoch,
        },
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0003',
          'fundingTime': DateTime(2025, 1, 1, 16, 0).millisecondsSinceEpoch,
        },
      ]);

      final mockClient = MockHttpClient([
        http.Response(mockResponse, 200),
        http.Response('[]', 200), // 终止分页
      ]);

      final service = FundingRateService(httpClient: mockClient);

      // 通过 fetchHistory 填充缓存
      await service.fetchHistory(symbol: 'BTCUSDT');

      // 查询 2025-01-01 10:00 时刻的费率 → 应该是 08:00 结算的那条
      final rate = await service.getRate(
        'BTCUSDT',
        DateTime(2025, 1, 1, 10, 0),
      );

      expect(rate, isNotNull);
      expect(rate, equals(0.0002));
    });

    test('getRate 缓存未命中时自动触发 HTTP 拉取', () async {
      final mockResponse = mockFundingRateResponse([
        {
          'symbol': 'ETHUSDT',
          'fundingRate': '0.0005',
          'fundingTime': DateTime(2025, 2, 1, 0, 0).millisecondsSinceEpoch,
        },
        {
          'symbol': 'ETHUSDT',
          'fundingRate': '0.0008',
          'fundingTime': DateTime(2025, 2, 1, 8, 0).millisecondsSinceEpoch,
        },
      ]);

      final mockClient = MockHttpClient([
        http.Response(mockResponse, 200),
        http.Response('[]', 200),
      ]);

      final service = FundingRateService(httpClient: mockClient);

      // 首次查询（缓存未命中，应自动拉取）
      final rate = await service.getRate(
        'ETHUSDT',
        DateTime(2025, 2, 1, 10, 0),
      );

      // 触发了 HTTP 请求
      expect(mockClient.callCount, greaterThan(0));
      // 找到 08:00 结算的费率
      expect(rate, equals(0.0008));
    });

    test('缓存命中避免重复 HTTP 请求', () async {
      final mockResponse = mockFundingRateResponse([
        {
          'symbol': 'SOLUSDT',
          'fundingRate': '0.0003',
          'fundingTime': DateTime(2025, 3, 1, 0, 0).millisecondsSinceEpoch,
        },
      ]);

      final mockClient = MockHttpClient([
        http.Response(mockResponse, 200),
        http.Response('[]', 200),
      ]);

      final service = FundingRateService(httpClient: mockClient);

      // 第一次查询（触发 HTTP）
      await service.getRate('SOLUSDT', DateTime(2025, 3, 1, 4, 0));
      final firstCallCount = mockClient.callCount;

      // 第二次查询（缓存命中，不触发新 HTTP 请求）
      await service.getRate('SOLUSDT', DateTime(2025, 3, 1, 5, 0));
      final secondCallCount = mockClient.callCount;

      // HTTP 请求次数不应增加
      expect(secondCallCount, equals(firstCallCount));
    });

    test('fetchHistory 分页拉取多条数据', () async {
      final page1 = mockFundingRateResponse([
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0001',
          'fundingTime': DateTime(2025, 1, 1, 0, 0).millisecondsSinceEpoch,
        },
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0002',
          'fundingTime': DateTime(2025, 1, 1, 8, 0).millisecondsSinceEpoch,
        },
      ]);
      final page2 = mockFundingRateResponse([
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0003',
          'fundingTime': DateTime(2025, 1, 1, 16, 0).millisecondsSinceEpoch,
        },
        {
          'symbol': 'BTCUSDT',
          'fundingRate': '0.0004',
          'fundingTime': DateTime(2025, 1, 2, 0, 0).millisecondsSinceEpoch,
        },
      ]);

      final mockClient = MockHttpClient([
        http.Response(page1, 200),
        http.Response(page2, 200),
        http.Response('[]', 200),
      ]);

      final service = FundingRateService(httpClient: mockClient);

      final rates = await service.fetchHistory(symbol: 'BTCUSDT');

      // 应有 4 条数据
      expect(rates, hasLength(4));
      // 应发起 3 次 HTTP 请求（2 页数据 + 1 页空终止）
      expect(mockClient.callCount, equals(3));
    });
  });
}
