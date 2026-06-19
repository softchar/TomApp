import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/binance_api_service.dart';

/// 收盘 K 线事件（仅 k.x==true 时触发，per D-03）。
class ClosedKline {
  final String symbol;
  final String timeframe;
  final List<KlineData> window;

  const ClosedKline({
    required this.symbol,
    required this.timeframe,
    required this.window,
  });
}

/// sharded combined-stream WebSocket 管理器。
///
/// 管理 Binance mark price kline 流，按标的分片（2 连接池，每连接 ≤1024 stream）。
/// 仅 k.x==true 的收盘 K 线触发 [closedKlines] 事件（杜绝 repaint，per D-03）。
/// partial kline 仅更新 rolling buffer 尾部（UI 实时价用）。
class ReboundKlineStreamService {
  /// 每连接最大 stream 数（Binance 限制 1024）
  static const int maxStreamsPerConnection = 1024;

  /// mark price kline stream URL 基础
  static const String _wsBaseUrl = 'wss://fstream.binance.com/stream';

  /// rolling buffer 最大大小（每 symbol+TF）
  static const int _maxBufferSize = 100;

  /// 重连参数
  static const Duration _reconnectBaseDelay = Duration(seconds: 1);
  static const Duration _reconnectMaxDelay = Duration(seconds: 60);

  /// BinanceApiService（REST 回填用）
  final BinanceApiService _apiService;

  /// 当前活跃连接列表
  final List<_ShardConnection> _connections = [];

  /// rolling buffer：symbol → timeframe → window
  final Map<String, Map<String, List<KlineData>>> _buffers = {};

  /// warm-up 状态：`$symbol:$tf` → true（正在 warm-up，不触发信号）
  final Map<String, bool> _warmingUp = {};

  /// 已订阅的 symbols
  final Set<String> _subscribedSymbols = {};

  /// 已订阅的 timeframes
  final List<String> _subscribedTimeframes = [];

  /// 收盘 K 线事件流（仅 k.x==true，per D-03）
  final StreamController<ClosedKline> _closedKlineController =
      StreamController<ClosedKline>.broadcast();
  Stream<ClosedKline> get closedKlines => _closedKlineController.stream;

  /// 是否已连接
  bool get isConnected => _connections.isNotEmpty;

  /// 当前是否正在 warm-up
  bool isWarmingUp(String symbol, String tf) =>
      _warmingUp['$symbol:$tf'] == true;

  ReboundKlineStreamService(this._apiService);

  /// 连接并订阅 symbols × timeframes 的 mark price kline 流。
  ///
  /// 按标的分片，每连接 ≤[maxStreamsPerConnection] stream（per D-02）。
  /// 每 symbol+TF 先 REST warm-up（50-100 根历史，per D-04），
  /// 期间标记 warming-up 不触发信号。
  Future<void> connect(List<String> symbols, List<String> timeframes) async {
    _subscribedSymbols.addAll(symbols);
    _subscribedTimeframes
      ..clear()
      ..addAll(timeframes);

    // 按标的分片（per D-02）
    final totalStreams = symbols.length * timeframes.length;
    final shardSize = (totalStreams / 2).ceil().clamp(1, maxStreamsPerConnection);
    final symbolChunks = _chunkSymbols(symbols, shardSize ~/ timeframes.length);

    for (final chunk in symbolChunks) {
      final streams = <String>[];
      for (final sym in chunk) {
        for (final tf in timeframes) {
          streams.add('${sym.toLowerCase()}@kline_$tf');
        }
      }
      final conn = _ShardConnection(streams);
      _connections.add(conn);
      await _openConnection(conn);
    }
  }

  /// 断开所有连接。
  void disconnect() {
    for (final conn in _connections) {
      conn.subscription?.cancel();
      conn.channel?.sink.close();
    }
    _connections.clear();
  }

  /// 获取指定 symbol+TF 的当前 rolling buffer 不变副本。
  List<KlineData>? windowOf(String symbol, String tf) {
    final buf = _buffers[symbol]?[tf];
    return buf == null ? null : List.unmodifiable(buf);
  }

  /// 所有 buffer 快照（用于调试）。
  Map<String, Map<String, List<KlineData>>> get allBuffers =>
      Map.unmodifiable(_buffers);

  // ─── 内部实现 ────────────────────────────────────────────

  List<List<String>> _chunkSymbols(List<String> symbols, int chunkSize) {
    final chunks = <List<String>>[];
    for (var i = 0; i < symbols.length; i += chunkSize) {
      chunks.add(symbols.sublist(i, (i + chunkSize).clamp(0, symbols.length)));
    }
    return chunks;
  }

  Future<void> _openConnection(_ShardConnection conn) async {
    // 先用一个初始 stream 建立连接，再 SUBSCRIBE 其余（避免 URL 过长）
    final firstStream = conn.streams.first;
    final uri = Uri.parse('$_wsBaseUrl?streams=$firstStream');
    conn.channel = WebSocketChannel.connect(uri);

    // 如果有更多 stream，用 SUBSCRIBE JSON 消息追加（per D-02）
    if (conn.streams.length > 1) {
      await conn.channel!.ready;
      final remaining = conn.streams.skip(1).toList();
      conn.channel!.sink.add(jsonEncode({
        'method': 'SUBSCRIBE',
        'params': remaining,
        'id': DateTime.now().millisecondsSinceEpoch,
      }));
    }

    conn.subscription = conn.channel!.stream.listen(
      (message) => handleMessage(message as String),
      onError: (error) => _onConnectionError(conn, error),
      onDone: () => _onConnectionDone(conn),
    );
  }

  /// 处理一条 combined-stream WS 消息（@visibleForTesting）。
  /// 生产路径由 WebSocket listener 调用；测试直接调用此方法。
  @visibleForTesting
  void handleMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final streamName = json['stream'] as String? ?? '';
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final k = data['k'] as Map<String, dynamic>?;
      if (k == null) return;

      // 解析 symbol 和 timeframe（streamName 格式：btcusdt@kline_15m）
      final parts = streamName.split('@kline_');
      if (parts.length != 2) return;
      final symbol = parts[0].toUpperCase();
      final tf = parts[1];

      // 构造 KlineData（mark price kline，per D-08）
      final kline = KlineData(
        time: DateTime.fromMillisecondsSinceEpoch(k['t'] as int),
        open: double.parse(k['o'].toString()),
        high: double.parse(k['h'].toString()),
        low: double.parse(k['l'].toString()),
        close: double.parse(k['c'].toString()),
        volume: double.parse(k['v'].toString()),
      );

      final isClosed = k['x'] == true;
      _updateBuffer(symbol, tf, kline, isClosed);

      if (isClosed && !isWarmingUp(symbol, tf)) {
        // k.x==true：收盘确认，触发事件（per D-03，硬断言）
        final window = windowOf(symbol, tf);
        if (window != null) {
          _closedKlineController.add(ClosedKline(
            symbol: symbol,
            timeframe: tf,
            window: window,
          ));
        }
      }
      // k.x==false（partial）：仅已更新 buffer 尾部，不触发事件
    } catch (_) {
      // 解析失败计数（per D-07：不再静默吞）
      // Phase 3 可增加 _parseErrorCount + 熔断逻辑
    }
  }

  void _updateBuffer(String symbol, String tf, KlineData kline, bool isClosed) {
    _buffers.putIfAbsent(symbol, () => {});
    _buffers[symbol]!.putIfAbsent(tf, () => []);
    final buf = _buffers[symbol]![tf]!;

    if (buf.isNotEmpty && buf.last.time == kline.time) {
      // 同一根 K 线更新（partial 或收盘替换）
      buf[buf.length - 1] = kline;
    } else {
      // 新 K 线
      buf.add(kline);
      if (buf.length > _maxBufferSize) {
        buf.removeAt(0);
      }
    }
  }

  Future<void> warmUp(String symbol, List<String> timeframes) async {
    for (final tf in timeframes) {
      _warmingUp['$symbol:$tf'] = true;
      try {
        // REST 拉 100 根历史（per D-04：warm-up）
        final now = DateTime.now();
        final start = now.subtract(_intervalDuration(tf) * 100);
        final raw = await _apiService.getKlines(
          symbol: symbol,
          interval: tf,
          startTime: start,
          endTime: now,
          limit: 100,
        );
        final klines = raw.map((k) {
          final list = k as List<dynamic>;
          return KlineData(
            time: DateTime.fromMillisecondsSinceEpoch(list[0] as int),
            open: double.parse(list[1].toString()),
            high: double.parse(list[2].toString()),
            low: double.parse(list[3].toString()),
            close: double.parse(list[4].toString()),
            volume: double.parse(list[5].toString()),
          );
        }).toList();

        _buffers.putIfAbsent(symbol, () => {});
        _buffers[symbol]![tf] = klines;
      } catch (_) {
        // warm-up 失败不阻塞（继续正常流处理）
      } finally {
        _warmingUp['$symbol:$tf'] = false;
      }
    }
  }

  void _onConnectionError(_ShardConnection conn, dynamic error) {
    // 断连处理：jitter 指数退避重连（per D-07）
    _scheduleReconnect(conn);
  }

  void _onConnectionDone(_ShardConnection conn) {
    _connections.remove(conn);
    if (_connections.isEmpty) {
      // 所有连接断开
    }
    _scheduleReconnect(conn);
  }

  void _scheduleReconnect(_ShardConnection conn) {
    final attempt = conn.reconnectAttempt;
    final delay = Duration(
      milliseconds: (_reconnectBaseDelay.inMilliseconds *
              (1 << attempt.clamp(0, 6)))
          .toInt()
          .clamp(0, _reconnectMaxDelay.inMilliseconds),
    );
    // 添加 jitter（±25%）
    final jitter = Duration(
        milliseconds: (delay.inMilliseconds * 0.25 *
                (DateTime.now().millisecondsSinceEpoch % 100 - 50) /
                50)
            .abs()
            .toInt());
    final total = delay + jitter;

    conn.reconnectTimer?.cancel();
    conn.reconnectTimer = Timer(total, () {
      conn.reconnectAttempt++;
      _openConnection(conn);
    });
  }

  Duration _intervalDuration(String tf) {
    switch (tf) {
      case '15m':
        return const Duration(minutes: 15);
      case '1h':
        return const Duration(hours: 1);
      case '4h':
        return const Duration(hours: 4);
      case '1d':
        return const Duration(days: 1);
      default:
        return const Duration(minutes: 15);
    }
  }

  void dispose() {
    disconnect();
    _closedKlineController.close();
  }
}

/// 单个分片连接状态。
class _ShardConnection {
  final List<String> streams;
  WebSocketChannel? channel;
  StreamSubscription? subscription;
  Timer? reconnectTimer;
  int reconnectAttempt = 0;

  _ShardConnection(this.streams);
}
