import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';

void main() {
  group('BinanceWebSocketManager', () {
    late BinanceWebSocketManager manager;

    setUp(() {
      manager = BinanceWebSocketManager();
    });

    tearDown(() {
      manager.disconnect();
    });

    test('should have initial state as disconnected', () {
      expect(manager.connectionState, WebSocketConnectionState.disconnected);
    });

    test('should connect to binance websocket', () async {
      await manager.connect();

      // 等待连接
      await Future.delayed(const Duration(seconds: 3));

      expect(manager.connectionState, WebSocketConnectionState.connected);
    });

    test('should receive ticker data', () async {
      await manager.connect();

      // 等待接收数据
      final ticker = await manager.tickerStream.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('No ticker received'),
      );

      expect(ticker.symbol, isNotEmpty);
      expect(ticker.price, greaterThan(0));
    });

    test('should disconnect properly', () async {
      await manager.connect();
      await Future.delayed(const Duration(seconds: 1));

      await manager.disconnect();

      expect(manager.connectionState, WebSocketConnectionState.disconnected);
    });
  });
}
