import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/kline_data.dart';
import 'binance_websocket_manager.dart';

/// K线WebSocket服务 - 用于接收实时K线数据
/// 使用独立的WebSocket连接，因为Binance的K线流topic与ticker流不同
class KlineWebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<KlineData> _klineController =
      StreamController<KlineData>.broadcast();
  WebSocketConnectionState _connectionState =
      WebSocketConnectionState.disconnected;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  /// 保存当前连接参数用于重连
  String? _currentSymbol;
  String? _currentInterval;

  Stream<KlineData> get klineStream => _klineController.stream;
  WebSocketConnectionState get connectionState => _connectionState;

  void _setConnectionState(WebSocketConnectionState state) {
    if (_disposed) return;
    if (_connectionState != state) {
      _connectionState = state;
      notifyListeners();
    }
  }

  /// 连接到指定交易对的K线流
  /// [symbol] 交易对符号，如 'BTCUSDT'
  /// [interval] K线间隔，如 '1m', '5m', '1h', '1d' 等
  Future<void> connect(String symbol, String interval) async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      return;
    }

    // 保存连接参数用于重连
    _currentSymbol = symbol;
    _currentInterval = interval;

    _setConnectionState(WebSocketConnectionState.connecting);

    try {
      final topic = '${symbol.toLowerCase()}@kline_$interval';
      final uri = Uri.parse('wss://fstream.binance.com/ws/$topic');

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _setConnectionState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
    } catch (e) {
      _setConnectionState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    await _channel?.sink.close();
    _setConnectionState(WebSocketConnectionState.disconnected);

    // 清除保存的连接参数
    _currentSymbol = null;
    _currentInterval = null;
  }

  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String) as Map<String, dynamic>;

      // Binance K线流格式: {"e":"kline",...,"k":{"t":...,"o":...,"h":...,"l":...,"c":...,"v":...}}
      if (data.containsKey('k')) {
        final klineData = data['k'] as Map<String, dynamic>;

        final kline = KlineData(
          time: DateTime.fromMillisecondsSinceEpoch(
            klineData['t'] as int,
          ),
          open: double.parse(klineData['o'] as String),
          high: double.parse(klineData['h'] as String),
          low: double.parse(klineData['l'] as String),
          close: double.parse(klineData['c'] as String),
          volume: double.parse(klineData['v'] as String),
        );

        _klineController.add(kline);

        if (kDebugMode) {
          print('[KlineWebSocketService] 收到K线数据: ${kline.time.toIso8601String()} '
                'O=${kline.open} H=${kline.high} L=${kline.low} C=${kline.close}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('KlineWebSocketService: 解析消息失败 - $e');
      }
    }
  }

  void _onError(error) {
    _setConnectionState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _onDone() {
    _setConnectionState(WebSocketConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // 3次重连后放弃
    if (_reconnectAttempts >= 3) {
      if (kDebugMode) {
        print('KlineWebSocketService: 重连次数已达上限，放弃重连');
      }
      return;
    }

    // 指数退避：5s, 10s, 20s
    final delay = Duration(
      seconds: 5 * (1 << _reconnectAttempts.clamp(0, 2)),
    );

    _setConnectionState(WebSocketConnectionState.reconnecting);
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (_currentSymbol != null && _currentInterval != null) {
        connect(_currentSymbol!, _currentInterval!);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _klineController.close();
    super.dispose();
  }
}
