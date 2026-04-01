import 'dart:async';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/services/pump_detector.dart';
import 'package:tomapp/services/pump_store.dart';
import 'package:tomapp/services/notification_service.dart';

class PumpAlertService {
  static final PumpAlertService _instance = PumpAlertService._internal();
  static PumpAlertService get instance => _instance;

  factory PumpAlertService() => _instance;

  PumpAlertService._internal();

  final BinanceWebSocketManager _wsManager = BinanceWebSocketManager();
  final PumpDetector _detector = PumpDetector(threshold: 2.0, cooldownMinutes: 1);
  final PumpStore _store = PumpStore();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _tickerSubscription;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  PumpStore get store => _store;
  WebSocketConnectionState get connectionState => _wsManager.connectionState;

  Future<void> start() async {
    if (_isRunning) return;

    try {
      // 连接 WebSocket
      await _wsManager.connect();

      // 订阅 ticker 数据
      _tickerSubscription = _wsManager.tickerStream.listen(_onTicker);

      // 初始化通知服务
      await _notificationService.initialize();

      // Only set running after successful initialization
      _isRunning = true;
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;

    await _tickerSubscription?.cancel();
    await _wsManager.disconnect();
  }

  void _onTicker(Ticker ticker) {
    // 只处理 USDT 合约
    if (!ticker.symbol.endsWith('USDT')) {
      return;
    }

    // 检测快速上涨
    final pump = _detector.check(
      ticker.symbol,
      ticker.price,
      ticker.timestamp,
    );

    if (pump != null) {
      _handlePump(pump);
    }
  }

  void _handlePump(PumpModel pump) {
    // 存入 store
    _store.addPump(pump);

    // 发送通知
    _notificationService.showPumpNotification(
      symbol: pump.symbol,
      priceChange: pump.priceChange,
      currentPrice: pump.currentPrice,
    );
  }

  Future<void> dispose() async {
    await stop();
    _wsManager.dispose();
  }
}
