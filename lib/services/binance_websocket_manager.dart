import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketConnectionState { disconnected, connecting, connected, reconnecting }

class Ticker {
  final String symbol;
  final double price;
  final double priceChangePercent;
  final DateTime timestamp;

  Ticker({
    required this.symbol,
    required this.price,
    required this.priceChangePercent,
    required this.timestamp,
  });

  factory Ticker.fromJson(Map<String, dynamic> json) {
    return Ticker(
      symbol: json['s'] as String,
      price: double.parse(json['c'] as String),
      priceChangePercent: double.parse(json['P'] as String),
      timestamp: DateTime.now(),
    );
  }
}

class BinanceWebSocketManager {
  static const String _baseUrl = 'wss://fstream.binance.com/ws';
  static const String _tickerStream = '!ticker@arr';

  WebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  final StreamController<Ticker> _tickerController = StreamController.broadcast();
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  Stream<Ticker> get tickerStream => _tickerController.stream;
  WebSocketConnectionState get connectionState => _connectionState;

  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      return;
    }

    _connectionState = WebSocketConnectionState.connecting;

    try {
      final uri = Uri.parse('$_baseUrl/$_tickerStream');
      _channel = WebSocketChannel.connect(uri);

      // Store the stream subscription for proper cleanup
      _streamSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Set connected after stream is successfully established
      _connectionState = WebSocketConnectionState.connected;
      _reconnectAttempts = 0;
    } catch (e) {
      _connectionState = WebSocketConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    await _channel?.sink.close();
    _connectionState = WebSocketConnectionState.disconnected;
  }

  void _onMessage(dynamic message) {
    try {
      final List<dynamic> data = json.decode(message as String);

      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final ticker = Ticker.fromJson(item);
          _tickerController.add(ticker);
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  void _onError(error) {
    _connectionState = WebSocketConnectionState.disconnected;
    _scheduleReconnect();
  }

  void _onDone() {
    _connectionState = WebSocketConnectionState.disconnected;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    final delay = _calculateReconnectDelay();
    _connectionState = WebSocketConnectionState.reconnecting;
    _reconnectAttempts++;  // Increment when scheduling, not in timer callback

    _reconnectTimer = Timer(delay, () {
      connect();  // Don't increment here
    });
  }

  Duration _calculateReconnectDelay() {
    // 指数退避：5s, 10s, 20s, 最多 60s
    const baseDelay = Duration(seconds: 5);
    const maxDelay = Duration(seconds: 60);

    final delay = Duration(
      milliseconds: baseDelay.inMilliseconds * (1 << (_reconnectAttempts.clamp(0, 3))),
    );

    return delay > maxDelay ? maxDelay : delay;
  }

  void dispose() {
    disconnect();
    _streamSubscription?.cancel();
    _tickerController.close();
  }
}
