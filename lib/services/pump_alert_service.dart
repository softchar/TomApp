import 'dart:async';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/models/pump_history_model.dart';
import 'package:tomapp/services/binance_websocket_manager.dart';
import 'package:tomapp/services/pump_detector.dart';
import 'package:tomapp/services/pump_store.dart';
import 'package:tomapp/services/notification_service.dart';
import 'package:tomapp/services/pump_repository.dart';
import 'package:tomapp/services/pump_config_service.dart';

class PumpAlertService {
  static final PumpAlertService _instance = PumpAlertService._internal();
  static PumpAlertService get instance => _instance;

  factory PumpAlertService() => _instance;

  PumpAlertService._internal();

  final BinanceWebSocketManager _wsManager = BinanceWebSocketManager();
  PumpDetector? _detector;
  final PumpStore _store = PumpStore();
  final NotificationService _notificationService = NotificationService();

  late PumpRepository _repository;
  final PumpConfig _config = PumpConfig();

  StreamSubscription? _tickerSubscription;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  PumpStore get store => _store;
  WebSocketConnectionState get connectionState => _wsManager.connectionState;

  /// 初始化服务
  Future<void> initialize() async {
    await _config.load();
    _repository = RepositoryFactory.create();

    _detector = PumpDetector(
      config: _config,
      repository: _repository,
    );
  }

  /// 标记服务已销毁，防止 dispose 后被误用
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed) return;
    if (_isRunning) return;

    await initialize();

    try {
      // 连接 WebSocket
      await _wsManager.connect();

      // 订阅 ticker 数据
      _tickerSubscription = _wsManager.tickerStream.listen(_onTicker);

      // 初始化通知服务
      await _notificationService.initialize();

      _isRunning = true;
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;

    _tickerSubscription?.cancel();
    await _wsManager.disconnect();
  }

  void _onTicker(Ticker ticker) {
    // 只处理 USDT 合约
    if (!ticker.symbol.endsWith('USDT')) {
      return;
    }

    // 异步检测快速上涨
    _checkPump(ticker.symbol, ticker.price, ticker.timestamp);
  }

  Future<void> _checkPump(
    String symbol,
    double price,
    DateTime timestamp,
  ) async {
    if (_detector == null) return;

    final pump = await _detector!.check(symbol, price, timestamp);

    if (pump != null) {
      _handlePump(pump);
    }
  }

  void _handlePump(PumpModel pump) {
    // 存入 store (内存缓存)
    _store.addPump(pump);

    // 存入数据库
    final historyModel = PumpHistoryModel.fromPumpModel(
      pump,
      strategyType: _detector?.getStrategyTypeName() ?? 'Unknown',
    );
    _repository.save(historyModel);

    // 发送通知
    _notificationService.showPumpNotification(
      symbol: pump.symbol,
      priceChange: pump.priceChange,
      currentPrice: pump.currentPrice,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    _wsManager.dispose(); // 注意：PumpAlertService是单例，dispose后不可再次使用
  }
}
