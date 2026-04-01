# 快速上涨警报功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现实时监控币安永续合约，1 分钟内涨幅超过 2% 时记录并通过系统通知用户

**Architecture:** 使用 WebSocket 连接币安期货 API 实时获取 ticker 数据，通过 PumpDetector 计算涨幅并检测快速上涨，使用 Provider 管理状态并通知 UI 更新

**Tech Stack:** Flutter, web_socket_channel, Provider, flutter_local_notifications

---

## 文件结构

**新建文件：**
| 文件 | 职责 |
|------|------|
| `lib/models/pump_model.dart` | 快速上涨数据模型 |
| `lib/services/pump_detector.dart` | 涨幅检测和冷却管理 |
| `lib/services/binance_websocket_manager.dart` | WebSocket 连接管理 |
| `lib/services/pump_store.dart` | 快速上涨状态管理 (Provider) |
| `lib/services/pump_alert_service.dart` | 主服务，整合所有组件 |
| `lib/screens/pump_screen.dart` | 快速上涨列表页面 |
| `lib/widgets/pump_item.dart` | 快速上涨列表项组件 |
| `test/services/pump_detector_test.dart` | 检测器单元测试 |

**修改文件：**
| 文件 | 变更 |
|------|------|
| `lib/screens/home_screen.dart` | 添加快速上涨入口和摘要卡片 |
| `pubspec.yaml` | 添加 web_socket_channel 依赖 |

---

## Task 1: 添加依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加 web_socket_channel 依赖**

在 `dependencies:` 部分添加：

```yaml
  web_socket_channel: ^2.4.0
```

- [ ] **Step 2: 运行 flutter pub get**

```bash
cd "c:\Users\softc\Desktop\TomApp"
flutter pub get
```

预期输出：`Got dependencies!`

- [ ] **Step 3: 提交**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: 添加 web_socket_channel 依赖"
```

---

## Task 2: 创建 PumpModel 数据模型

**Files:**
- Create: `lib/models/pump_model.dart`
- Test: `test/models/pump_model_test.dart`

- [ ] **Step 1: 创建测试文件**

```dart
// test/models/pump_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_model.dart';

void main() {
  group('PumpModel', () {
    test('should create model with all required fields', () {
      final model = PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
        currentPrice: 67234.50,
      );

      expect(model.symbol, 'BTCUSDT');
      expect(model.priceChange, 3.5);
      expect(model.triggerTime, DateTime(2026, 4, 1, 10, 23, 45));
      expect(model.currentPrice, 67234.50);
    });

    test('should serialize to map correctly', () {
      final model = PumpModel(
        symbol: 'ETHUSDT',
        priceChange: 2.3,
        triggerTime: DateTime(2026, 4, 1, 10, 22, 10),
        currentPrice: 3456.78,
      );

      final map = model.toMap();

      expect(map['symbol'], 'ETHUSDT');
      expect(map['priceChange'], 2.3);
      expect(map['triggerTime'], DateTime(2026, 4, 1, 10, 22, 10).toIso8601String());
      expect(map['currentPrice'], 3456.78);
    });

    test('should deserialize from map correctly', () {
      final map = {
        'symbol': 'BTCUSDT',
        'priceChange': 3.5,
        'triggerTime': DateTime(2026, 4, 1, 10, 23, 45).toIso8601String(),
        'currentPrice': 67234.50,
      };

      final model = PumpModel.fromMap(map);

      expect(model.symbol, 'BTCUSDT');
      expect(model.priceChange, 3.5);
      expect(model.triggerTime, DateTime(2026, 4, 1, 10, 23, 45));
      expect(model.currentPrice, 67234.50);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/models/pump_model_test.dart
```

预期：FAIL - `PumpModel` 类不存在

- [ ] **Step 3: 实现 PumpModel**

```dart
// lib/models/pump_model.dart
class PumpModel {
  final String symbol;
  final double priceChange;
  final DateTime triggerTime;
  final double currentPrice;

  PumpModel({
    required this.symbol,
    required this.priceChange,
    required this.triggerTime,
    required this.currentPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'priceChange': priceChange,
      'triggerTime': triggerTime.toIso8601String(),
      'currentPrice': currentPrice,
    };
  }

  factory PumpModel.fromMap(Map<String, dynamic> map) {
    return PumpModel(
      symbol: map['symbol'] as String,
      priceChange: map['priceChange'] as double,
      triggerTime: DateTime.parse(map['triggerTime'] as String),
      currentPrice: map['currentPrice'] as double,
    );
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/models/pump_model_test.dart
```

预期：PASS

- [ ] **Step 5: 提交**

```bash
git add lib/models/pump_model.dart test/models/pump_model_test.dart
git commit -m "feat: 添加 PumpModel 数据模型"
```

---

## Task 3: 实现 PumpDetector 检测器

**Files:**
- Create: `lib/services/pump_detector.dart`
- Test: `test/services/pump_detector_test.dart`

- [ ] **Step 1: 创建测试文件**

```dart
// test/services/pump_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/pump_detector.dart';

void main() {
  group('PumpDetector', () {
    late PumpDetector detector;

    setUp(() {
      detector = PumpDetector(threshold: 2.0, cooldownMinutes: 1);
    });

    test('should return null when price change is below threshold', () {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      // 添加基准价格
      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 1 分钟后，上涨 1% (低于阈值)
      final result = detector.check(
        'BTCUSDT',
        65650.0, // 1% 涨幅
        baseTime.add(const Duration(minutes: 1)),
      );

      expect(result, isNull);
    });

    test('should detect pump when price change exceeds threshold', () {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 1 分钟后，上涨 3% (超过阈值)
      final result = detector.check(
        'BTCUSDT',
        66950.0, // 3% 涨幅
        baseTime.add(const Duration(minutes: 1)),
      );

      expect(result, isNotNull);
      expect(result!.symbol, 'BTCUSDT');
      expect(result.priceChange, closeTo(3.0, 0.1));
      expect(result.currentPrice, 66950.0);
    });

    test('should enforce cooldown period', () {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 第一次触发
      detector.check(
        'BTCUSDT',
        66950.0,
        baseTime.add(const Duration(minutes: 1)),
      );

      // 30 秒后再次触发 (在冷却期内)
      final result2 = detector.check(
        'BTCUSDT',
        67500.0,
        baseTime.add(const Duration(minutes: 1, seconds: 30)),
      );

      expect(result2, isNull); // 冷却中，返回 null
    });

    test('should allow detection after cooldown expires', () {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

      // 第一次触发
      detector.check(
        'BTCUSDT',
        66950.0,
        baseTime.add(const Duration(minutes: 1)),
      );

      // 2 分钟后再次触发 (冷却期已过)
      final result2 = detector.check(
        'BTCUSDT',
        68000.0,
        baseTime.add(const Duration(minutes: 2)),
      );

      expect(result2, isNotNull);
    });

    test('should clean up old price points', () {
      final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

      // 添加 3 分钟前的旧数据点
      detector.addPricePoint('BTCUSDT', 65000.0, baseTime);
      // 添加当前价格点
      detector.addPricePoint('BTCUSDT', 66000.0, baseTime.add(const Duration(minutes: 3)));

      // 旧数据点应该被清理
      expect(detector.getPricePointCount('BTCUSDT'), lessThanOrEqualTo(2));
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/pump_detector_test.dart
```

预期：FAIL

- [ ] **Step 3: 实现 PumpDetector**

```dart
// lib/services/pump_detector.dart
import 'package:tomapp/models/pump_model.dart';

class PricePoint {
  final double price;
  final DateTime timestamp;

  PricePoint({required this.price, required this.timestamp});
}

class PumpDetector {
  final double threshold;
  final int cooldownMinutes;

  // 存储每个合约的价格历史 (最多保留 2 分钟的数据)
  final Map<String, List<PricePoint>> _priceHistory = {};

  // 存储每个合约的最后通知时间
  final Map<String, DateTime> _lastNotificationTime = {};

  PumpDetector({required this.threshold, required this.cooldownMinutes});

  /// 添加价格数据点
  void addPricePoint(String symbol, double price, DateTime timestamp) {
    _priceHistory.putIfAbsent(symbol, () => []);

    _priceHistory[symbol]!.add(PricePoint(price: price, timestamp: timestamp));

    // 清理 2 分钟前的旧数据
    _cleanupOldPoints(symbol, timestamp);
  }

  /// 检测是否触发快速上涨
  /// 返回 PumpModel 如果触发，否则返回 null
  PumpModel? check(String symbol, double currentPrice, DateTime timestamp) {
    // 检查冷却期
    if (_isInCooldown(symbol, timestamp)) {
      return null;
    }

    // 添加当前价格点
    addPricePoint(symbol, currentPrice, timestamp);

    // 计算涨幅
    final change = _calculate1MinChange(symbol, timestamp);
    if (change == null || change <= threshold) {
      return null;
    }

    // 记录通知时间
    _lastNotificationTime[symbol] = timestamp;

    return PumpModel(
      symbol: symbol,
      priceChange: change,
      triggerTime: timestamp,
      currentPrice: currentPrice,
    );
  }

  /// 重置冷却时间 (用于测试)
  void resetCooldown(String symbol) {
    _lastNotificationTime.remove(symbol);
  }

  /// 获取价格点数量 (用于测试)
  int getPricePointCount(String symbol) {
    return _priceHistory[symbol]?.length ?? 0;
  }

  double? _calculate1MinChange(String symbol, DateTime currentTime) {
    final points = _priceHistory[symbol];
    if (points == null || points.length < 2) {
      return null;
    }

    // 找到 1 分钟前的价格
    final oneMinuteAgo = currentTime.subtract(const Duration(minutes: 1));
    PricePoint? baselinePoint;

    for (final point in points) {
      if (point.timestamp.isBefore(oneMinuteAgo) ||
          point.timestamp.isAtSameMomentAs(oneMinuteAgo)) {
        baselinePoint = point;
      } else {
        break;
      }
    }

    if (baselinePoint == null) {
      return null;
    }

    final currentPrice = points.last.price;
    final baselinePrice = baselinePoint.price;

    return ((currentPrice - baselinePrice) / baselinePrice) * 100;
  }

  bool _isInCooldown(String symbol, DateTime currentTime) {
    final lastNotified = _lastNotificationTime[symbol];
    if (lastNotified == null) {
      return false;
    }

    final elapsed = currentTime.difference(lastNotified);
    return elapsed.inMinutes < cooldownMinutes;
  }

  void _cleanupOldPoints(String symbol, DateTime currentTime) {
    final cutoff = currentTime.subtract(const Duration(minutes: 2));
    _priceHistory[symbol]!.removeWhere((p) => p.timestamp.isBefore(cutoff));
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/services/pump_detector_test.dart
```

预期：PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/pump_detector.dart test/services/pump_detector_test.dart
git commit -m "feat: 添加 PumpDetector 检测器"
```

---

## Task 4: 实现 BinanceWebSocketManager

**Files:**
- Create: `lib/services/binance_websocket_manager.dart`

- [ ] **Step 1: 创建测试文件**

```dart
// test/services/binance_websocket_manager_test.dart
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
      final stream = manager.tickerStream;

      await manager.connect();

      // 等待接收数据
      final ticker = await stream.timeout(
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
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/binance_websocket_manager_test.dart
```

预期：FAIL

- [ ] **Step 3: 实现 BinanceWebSocketManager**

```dart
// lib/services/binance_websocket_manager.dart
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

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _connectionState = WebSocketConnectionState.connected;
      _reconnectAttempts = 0;
    } catch (e) {
      _connectionState = WebSocketConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
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

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
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
    _tickerController.close();
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/services/binance_websocket_manager_test.dart
```

预期：PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/binance_websocket_manager.dart test/services/binance_websocket_manager_test.dart
git commit -m "feat: 添加 BinanceWebSocketManager"
```

---

## Task 5: 实现 PumpStore

**Files:**
- Create: `lib/services/pump_store.dart`

- [ ] **Step 1: 创建测试文件**

```dart
// test/services/pump_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_store.dart';

void main() {
  group('PumpStore', () {
    late PumpStore store;

    setUp(() {
      store = PumpStore();
    });

    test('should start with empty list', () {
      expect(store.pumps, isEmpty);
    });

    test('should add pump and notify listeners', () async {
      PumpModel? receivedPump;

      store.addListener(() {
        receivedPump = store.pumps.lastOrNull;
      });

      final pump = PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
        currentPrice: 67234.50,
      );

      store.addPump(pump);

      expect(store.pumps.length, 1);
      expect(store.pumps.first, pump);
      expect(receivedPump, pump);
    });

    test('should maintain max 50 pumps (FIFO)', () {
      // 添加 55 个 pump
      for (int i = 0; i < 55; i++) {
        store.addPump(PumpModel(
          symbol: 'TEST$i',
          priceChange: 2.0,
          triggerTime: DateTime(2026, 4, 1, 10, 0, 0).add(Duration(seconds: i)),
          currentPrice: 100.0,
        ));
      }

      expect(store.pumps.length, 50);
      expect(store.pumps.first.symbol, 'TEST5'); // 前 5 个被移除
      expect(store.pumps.last.symbol, 'TEST54');
    });

    test('should clear all pumps', () {
      store.addPump(PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
        currentPrice: 67234.50,
      ));

      store.clear();

      expect(store.pumps, isEmpty);
    });

    test('should get today pump count', () {
      final today = DateTime(2026, 4, 1, 12, 0, 0);
      final yesterday = DateTime(2026, 3, 31, 12, 0, 0);

      store.addPump(PumpModel(
        symbol: 'BTCUSDT',
        priceChange: 3.5,
        triggerTime: today,
        currentPrice: 67234.50,
      ));

      store.addPump(PumpModel(
        symbol: 'ETHUSDT',
        priceChange: 2.5,
        triggerTime: yesterday,
        currentPrice: 3456.78,
      ));

      expect(store.todayPumpCount(today), 1);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/pump_store_test.dart
```

预期：FAIL

- [ ] **Step 3: 实现 PumpStore**

```dart
// lib/services/pump_store.dart
import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_model.dart';

class PumpStore extends ChangeNotifier {
  final List<PumpModel> _pumps = [];
  static const int _maxPumps = 50;

  List<PumpModel> get pumps => List.unmodifiable(_pumps);

  void addPump(PumpModel pump) {
    _pumps.add(pump);

    if (_pumps.length > _maxPumps) {
      _pumps.removeAt(0);
    }

    notifyListeners();
  }

  void clear() {
    _pumps.clear();
    notifyListeners();
  }

  int todayPumpCount(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _pumps.where((p) {
      return p.triggerTime.isAfter(startOfDay) && p.triggerTime.isBefore(endOfDay);
    }).length;
  }
}
```

- [ ] **Step 4: 运行测试验证通过**

```bash
flutter test test/services/pump_store_test.dart
```

预期：PASS

- [ ] **Step 5: 提交**

```bash
git add lib/services/pump_store.dart test/services/pump_store_test.dart
git commit -m "feat: 添加 PumpStore 状态管理"
```

---

## Task 6: 实现 PumpAlertService 主服务

**Files:**
- Create: `lib/services/pump_alert_service.dart`

- [ ] **Step 1: 创建测试文件**

```dart
// test/services/pump_alert_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_alert_service.dart';
import 'package:tomapp/services/pump_store.dart';

void main() {
  group('PumpAlertService', () {
    late PumpAlertService service;
    late PumpStore store;

    setUp(() {
      service = PumpAlertService();
      store = PumpStore();
    });

    tearDown(() {
      service.stop();
    });

    test('should be singleton', () {
      final instance1 = PumpAlertService.instance;
      final instance2 = PumpAlertService.instance;

      expect(identical(instance1, instance2), true);
    });

    test('should start in stopped state', () {
      expect(service.isRunning, false);
    });

    test('should start service', () async {
      await service.start();

      expect(service.isRunning, true);
    });

    test('should stop service', () async {
      await service.start();
      await service.stop();

      expect(service.isRunning, false);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
flutter test test/services/pump_alert_service_test.dart
```

预期：FAIL

- [ ] **Step 3: 实现 PumpAlertService**

```dart
// lib/services/pump_alert_service.dart
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

    _isRunning = true;

    // 连接 WebSocket
    await _wsManager.connect();

    // 订阅 ticker 数据
    _tickerSubscription = _wsManager.tickerStream.listen(_onTicker);

    // 初始化通知服务
    await _notificationService.initialize();
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

  void dispose() {
    stop();
    _wsManager.dispose();
  }
}
```

- [ ] **Step 4: 更新 NotificationService 添加 pump 通知方法**

在 `lib/services/notification_service.dart` 中添加：

```dart
void showPumpNotification({
  required String symbol,
  required double priceChange,
  required double currentPrice,
}) {
  const androidDetails = AndroidNotificationDetails(
    'pump_alerts',
    '快速上涨警报',
    channelDescription: '合约快速上涨通知',
    importance: Importance.high,
    priority: Priority.high,
  );

  const iosDetails = DarwinNotificationDetails();

  const details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  flutterLocalNotificationsPlugin.show(
    symbol.hashCode,
    '🚀 $symbol 快速上涨',
    '+${priceChange.toStringAsFixed(2)}% • 当前价格 \$${currentPrice.toStringAsFixed(2)}',
    details,
  );
}
```

- [ ] **Step 5: 运行测试验证通过**

```bash
flutter test test/services/pump_alert_service_test.dart
```

预期：PASS

- [ ] **Step 6: 提交**

```bash
git add lib/services/pump_alert_service.dart lib/services/notification_service.dart test/services/pump_alert_service_test.dart
git commit -m "feat: 添加 PumpAlertService 主服务"
```

---

## Task 7: 创建 PumpItem 组件

**Files:**
- Create: `lib/widgets/pump_item.dart`

- [ ] **Step 1: 创建组件**

```dart
// lib/widgets/pump_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/theme_provider.dart';

class PumpItem extends StatelessWidget {
  final PumpModel pump;

  const PumpItem({super.key, required this.pump});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                pump.symbol,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${pump.priceChange.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('HH:mm:ss').format(pump.triggerTime),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '当前价格: \$${pump.currentPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/widgets/pump_item.dart
git commit -m "feat: 添加 PumpItem 组件"
```

---

## Task 8: 创建 PumpScreen 页面

**Files:**
- Create: `lib/screens/pump_screen.dart`

- [ ] **Step 1: 创建页面**

```dart
// lib/screens/pump_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_alert_service.dart';
import 'package:tomapp/services/pump_store.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/widgets/pump_item.dart';

class PumpScreen extends StatefulWidget {
  const PumpScreen({super.key});

  @override
  State<PumpScreen> createState() => _PumpScreenState();
}

class _PumpScreenState extends State<PumpScreen> {
  final PumpAlertService _service = PumpAlertService.instance;

  @override
  void initState() {
    super.initState();
    _startService();
  }

  Future<void> _startService() async {
    await _service.start();
  }

  @override
  void dispose() {
    // 不在这里停止服务，让服务持续运行
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('快速上涨'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 连接状态指示器
          Consumer<PumpAlertService>(
            builder: (context, service, child) {
              final state = service.connectionState;
              Color dotColor;
              String statusText;

              switch (state) {
                case WebSocketConnectionState.connected:
                  dotColor = Colors.green;
                  statusText = '已连接';
                  break;
                case WebSocketConnectionState.connecting:
                case WebSocketConnectionState.reconnecting:
                  dotColor = Colors.orange;
                  statusText = '连接中';
                  break;
                default:
                  dotColor = Colors.red;
                  statusText = '已断开';
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<PumpStore>(
        builder: (context, store, child) {
          final pumps = store.pumps;

          if (pumps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无快速上涨记录',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: pumps.length,
            itemBuilder: (context, index) {
              // 反转顺序，最新的在前面
              final pump = pumps[pumps.length - 1 - index];
              return PumpItem(pump: pump);
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/pump_screen.dart
git commit -m "feat: 添加 PumpScreen 页面"
```

---

## Task 9: 更新首页添加入口

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: 添加快速上涨摘要卡片**

在 `home_screen.dart` 中添加：

```dart
// 在 HomePage 的 build 方法中，添加快速上涨卡片
Widget _buildPumpCard(BuildContext context) {
  final isDark = context.watch<ThemeProvider>().isDarkMode;
  final store = context.watch<PumpStore>();
  final todayCount = store.todayPumpCount(DateTime.now());

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PumpScreen()),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.8),
            Colors.deepOrange.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.rocket_launch,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '快速上涨',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '今日检测到 $todayCount 个',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: 在首页布局中添加卡片**

在 `home_screen.dart` 的 body 中添加此卡片：

```dart
// 在现有卡片之后添加
_buildPumpCard(context),
```

- [ ] **Step 3: 确保导入 PumpScreen**

```dart
import 'package:tomapp/screens/pump_screen.dart';
import 'package:tomapp/services/pump_store.dart';
```

- [ ] **Step 4: 提交**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: 首页添加快速上涨入口"
```

---

## Task 10: 应用启动时自动启动服务

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 main 函数中初始化服务**

```dart
// 在 main() 函数中添加
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  final notificationService = NotificationService();
  await notificationService.initialize();

  // 启动快速上涨检测服务
  final pumpService = PumpAlertService.instance;
  await pumpService.start();

  runApp(const MyApp());
}
```

- [ ] **Step 2: 确保 Provider 包含 PumpStore**

在 `MultiProvider` 中添加：

```dart
ChangeNotifierProvider(
  create: (_) => PumpAlertService.instance.store,
),
```

- [ ] **Step 3: 提交**

```bash
git add lib/main.dart
git commit -m "feat: 应用启动时自动启动快速上涨检测服务"
```

---

## Task 11: 集成测试

**Files:**
- Test: `integration_test/app_test.dart`

- [ ] **Step 1: 创建集成测试**

```dart
// integration_test/pump_alert_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tomapp/main.dart' as app;
import 'package:tomapp/screens/pump_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pump Alert Integration Tests', () {
    testWidgets('should navigate to pump screen', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 点击快速上涨卡片
      await tester.tap(find.text('快速上涨'));
      await tester.pumpAndSettle();

      // 验证导航成功
      expect(find.byType(PumpScreen), findsOneWidget);
      expect(find.text('快速上涨'), findsWidgets);
    });

    testWidgets('should show connection status', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 导航到快速上涨页面
      await tester.tap(find.text('快速上涨'));
      await tester.pumpAndSettle();

      // 等待服务连接
      await tester.pump(const Duration(seconds: 5));

      // 验证连接状态显示
      expect(find.text('已连接'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行集成测试**

```bash
flutter test integration_test/pump_alert_test.dart
```

预期：PASS

- [ ] **Step 3: 提交**

```bash
git add integration_test/pump_alert_test.dart
git commit -m "test: 添加快速上涨集成测试"
```

---

## Task 12: 最终验证

- [ ] **Step 1: 运行所有测试**

```bash
flutter test
```

预期：全部 PASS

- [ ] **Step 2: 构建验证**

```bash
flutter build apk --release
```

预期：构建成功

- [ ] **Step 3: 手动测试**

1. 启动应用，验证首页显示快速上涨卡片
2. 点击进入快速上涨页面
3. 验证连接状态显示正常
4. 等待或模拟快速上涨，验证通知发送
5. 验证记录显示在列表中

- [ ] **Step 4: 最终提交**

```bash
git add .
git commit -m "chore: 完成快速上涨警报功能"
```

---

## 验收标准

- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] APK 构建成功
- [ ] 手动测试验证功能正常
- [ ] 代码已提交

## 参考资料

- 设计文档: [docs/superpowers/specs/2026-04-01-pump-alert-design.md](docs/superpowers/specs/2026-04-01-pump-alert-design.md)
- 币安期货 WebSocket API: https://binance-docs.github.io/apidocs/futures/cn/#websocket
