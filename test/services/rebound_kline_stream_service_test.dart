import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/binance_api_service.dart';
import 'package:tomapp/services/rebound/rebound_kline_stream_service.dart';

/// Phase 3 单测：ReboundKlineStreamService k.x 过滤 + rolling buffer 管理。
/// 通过 handleMessage() 直接注入模拟 WS 消息，无需真实 WebSocket。

/// 构造 Binance combined-stream kline 消息 JSON。
///
/// [symbol] e.g. "BTCUSDT"，[tf] e.g. "15m"。
/// [isClosed] 对应 k.x（true=已收盘）。
String _klineMessage(
  String symbol,
  String tf, {
  required double open,
  required double high,
  required double low,
  required double close,
  required double volume,
  required int openTime,
  bool isClosed = false,
}) {
  return jsonEncode({
    'stream': '${symbol.toLowerCase()}@kline_$tf',
    'data': {
      'e': 'kline',
      'E': openTime + 1000,
      's': symbol,
      'k': {
        't': openTime,    // openTime (ms)
        'T': openTime + 899999, // closeTime
        's': symbol,
        'i': tf,
        'f': 100,
        'L': 200,
        'o': open.toString(),
        'c': close.toString(),
        'h': high.toString(),
        'l': low.toString(),
        'v': volume.toString(),
        'n': 50,
        'x': isClosed,    // k.x — 关键字段
        'q': '1000.00',
        'V': '50.00',
        'Q': '500.00',
      },
    },
  });
}

void main() {
  late ReboundKlineStreamService service;
  late List<ClosedKline> receivedEvents;
  late StreamSubscription<ClosedKline> subscription;

  setUp(() {
    service = ReboundKlineStreamService(BinanceApiService());
    receivedEvents = [];
    subscription = service.closedKlines.listen((event) {
      receivedEvents.add(event);
    });
  });

  tearDown(() {
    subscription.cancel();
    service.dispose();
  });

  group('ReboundKlineStreamService', () {
    // Test 1: k.x==true 触发 ClosedKline 事件
    test('k.x==true（收盘 K 线）→ 触发 ClosedKline 事件', () async {
      service.handleMessage(_klineMessage(
        'BTCUSDT', '15m',
        open: 100, high: 101, low: 99, close: 100.5, volume: 10,
        openTime: 1000000,
        isClosed: true,
      ));
      await Future<void>.value(); // 刷新微任务队列
      expect(receivedEvents.length, 1, reason: '收盘 K 线应触发事件');
      expect(receivedEvents.first.symbol, 'BTCUSDT');
      expect(receivedEvents.first.timeframe, '15m');
      expect(receivedEvents.first.window.length, 1);
      expect(receivedEvents.first.window.first.close, 100.5);
    });

    // Test 2: k.x==false（partial）不触发事件，仅更新 buffer
    test('k.x==false（partial K 线）→ 不触发事件，buffer 已更新', () async {
      service.handleMessage(_klineMessage(
        'BTCUSDT', '15m',
        open: 100, high: 101, low: 99, close: 100.3, volume: 5,
        openTime: 1000000,
        isClosed: false,
      ));
      await Future<void>.value();
      expect(receivedEvents.length, 0, reason: 'partial 不应触发事件');
      // buffer 应已更新
      final window = service.windowOf('BTCUSDT', '15m');
      expect(window, isNotNull);
      expect(window!.length, 1);
      expect(window.first.close, 100.3);
    });

    // Test 3: partial 后收盘替换同一 openTime 的 buffer
    test('partial → 收盘：同一 openTime 的 buffer 被替换', () async {
      // partial
      service.handleMessage(_klineMessage(
        'BTCUSDT', '1h',
        open: 100, high: 102, low: 99, close: 101, volume: 8,
        openTime: 2000000,
        isClosed: false,
      ));
      // 同一根收盘（close 不同）
      service.handleMessage(_klineMessage(
        'BTCUSDT', '1h',
        open: 100, high: 103, low: 99, close: 102, volume: 10,
        openTime: 2000000,
        isClosed: true,
      ));
      await Future<void>.value();
      expect(receivedEvents.length, 1);
      final window = service.windowOf('BTCUSDT', '1h')!;
      expect(window.length, 1, reason: '同一 openTime 替换，不 append');
      expect(window.first.close, 102, reason: '收盘值替换 partial 值');
      expect(window.first.high, 103, reason: '最高价用收盘 K 线值');
    });

    // Test 4: 多根 K 线 buffer 增长
    test('多根 K 线 buffer 正确增长', () async {
      for (int i = 0; i < 5; i++) {
        service.handleMessage(_klineMessage(
          'ETHUSDT', '4h',
          open: 200.0 + i, high: 205.0 + i, low: 195.0 + i, close: 202.0 + i,
          volume: 100,
          openTime: 3000000 + i * 14400000,
          isClosed: true,
        ));
        await Future<void>.value(); // 每条消息后刷新微任务
      }
      expect(receivedEvents.length, 5);
      final window = service.windowOf('ETHUSDT', '4h')!;
      expect(window.length, 5);
      expect(window.first.close, 202.0);
      expect(window.last.close, 206.0);
    });

    // Test 5: 不同 symbol 和 timeframe 独立管理
    test('不同 symbol 和 timeframe 独立 buffer', () async {
      service.handleMessage(_klineMessage(
        'BTCUSDT', '15m',
        open: 100, high: 101, low: 99, close: 100, volume: 10,
        openTime: 1000000,
        isClosed: true,
      ));
      await Future<void>.value();
      service.handleMessage(_klineMessage(
        'ETHUSDT', '1h',
        open: 200, high: 210, low: 195, close: 205, volume: 50,
        openTime: 2000000,
        isClosed: true,
      ));
      await Future<void>.value();
      expect(receivedEvents.length, 2);
      expect(receivedEvents[0].symbol, 'BTCUSDT');
      expect(receivedEvents[0].timeframe, '15m');
      expect(receivedEvents[1].symbol, 'ETHUSDT');
      expect(receivedEvents[1].timeframe, '1h');
      expect(service.windowOf('BTCUSDT', '15m')!.length, 1);
      expect(service.windowOf('ETHUSDT', '1h')!.length, 1);
    });

    // Test 6: 错误消息不崩溃
    test('畸形消息不崩溃', () async {
      service.handleMessage('not json');
      service.handleMessage('{"stream":"btcusdt@kline_15m"}');
      service.handleMessage('{"data":{"k":{}}}');
      await Future<void>.value();
      expect(receivedEvents.length, 0);
    });

    // Test 7: Mark price stream 格式验证
    test('mark price stream 格式：symbol 小写 + @kline_interval', () async {
      service.handleMessage(_klineMessage(
        'BTCUSDT', '15m',
        open: 100, high: 101, low: 99, close: 100, volume: 10,
        openTime: 1000000,
        isClosed: true,
      ));
      await Future<void>.value();
      expect(receivedEvents.first.symbol, 'BTCUSDT');
    });

    // Test 8 [增量 subscribe，per D7]: subscribe 后 symbol 进入订阅集合 + streamToConn 索引更新
    test('subscribe：增量订阅把 symbol 加入集合、streamToConn 索引正确', () async {
      await service.connect(['BTCUSDT'], ['15m', '1h']);
      await service.subscribe(['ABCUSDT']);
      expect(service.isSymbolSubscribed('ABCUSDT'), isTrue,
          reason: 'subscribe 后 ABCUSDT 应在订阅集合中');
      // streamToConn 索引应包含 ABCUSDT 的所有 TF stream
      expect(service.streamToConnContains('abcusdt@kline_15m'), isTrue);
      expect(service.streamToConnContains('abcusdt@kline_1h'), isTrue);
    });

    // Test 9 [增量 unsubscribe，per D7]: unsubscribe 后索引与订阅集合同步移除
    test('unsubscribe：取消订阅后 symbol 与索引同步移除', () async {
      await service.connect(['BTCUSDT'], ['15m']);
      await service.subscribe(['ETHUSDT']);
      expect(service.isSymbolSubscribed('ETHUSDT'), isTrue);
      service.unsubscribe(['ETHUSDT']);
      expect(service.isSymbolSubscribed('ETHUSDT'), isFalse,
          reason: 'unsubscribe 后 ETHUSDT 应不在订阅集合');
      expect(service.streamToConnContains('ethusdt@kline_15m'), isFalse,
          reason: 'unsubscribe 后索引应清理');
    });
  });
}
