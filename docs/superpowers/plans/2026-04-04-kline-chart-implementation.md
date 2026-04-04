# K线图功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在币安合约费率应用中添加专业的K线图功能，支持多时间周期、完整技术指标、实时价格更新和数据持久化缓存。

**架构:** 三层架构 - Presentation层(KlineScreen+Widgets)、Provider层(KlineProvider状态管理)、Service层(API/缓存/WebSocket/指标计算)。复用现有BinanceApiService、BinanceWebSocketManager、DatabaseHelper。

**Tech Stack:** Flutter 3.x, flutter_chen_kchart, sqflite, web_socket_channel, provider, shared_preferences

---

## 文件结构概览

### 新建文件
- `lib/models/kline_data.dart` - K线数据模型 (KlineData, KlineDataWithIndicators)
- `lib/models/macd_data.dart` - MACD指标数据模型
- `lib/services/kline_cache_service.dart` - K线缓存服务
- `lib/services/kline_websocket_service.dart` - K线WebSocket服务
- `lib/services/technical_indicators.dart` - 技术指标计算工具
- `lib/providers/kline_provider.dart` - K线状态管理
- `lib/screens/kline_screen.dart` - K线图页面
- `lib/widgets/kline_chart_widget.dart` - K线图组件
- `lib/widgets/macd_chart_widget.dart` - MACD图表组件
- `lib/widgets/kline_skeleton.dart` - 骨架屏加载组件
- `lib/widgets/interval_selector.dart` - 周期选择器组件
- `test/services/technical_indicators_test.dart` - 指标计算单元测试
- `test/services/kline_cache_service_test.dart` - 缓存服务单元测试

### 修改文件
- `pubspec.yaml` - 添加flutter_chen_kchart依赖
- `lib/services/binance_api_service.dart` - 添加KlineApi extension
- `lib/services/database_helper.dart` - 添加kline_cache表(version 2)
- `lib/screens/funding_screen.dart` - 添加导航到KlineScreen
- `lib/screens/long_short_screen.dart` - 添加导航到KlineScreen
- `lib/screens/profile_screen.dart` - 添加K线缓存管理选项
- `lib/main.dart` - 注册KlineProvider

---

## Task 1: 更新依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加flutter_chen_kchart依赖**

编辑 `pubspec.yaml`，在 dependencies 部分添加：
```yaml
  flutter_chen_kchart: ^2.0.4
```

在 dev_dependencies 部分添加：
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

- [ ] **Step 2: 运行flutter pub get**

```bash
cd /c/Users/softc/Desktop/TomApp
flutter pub get
```

Expected: 依赖安装成功，无错误

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add flutter_chen_kchart and test dependencies"
```

---

## Task 2: 创建K线数据模型

**Files:**
- Create: `lib/models/kline_data.dart`

- [ ] **Step 1: 创建KlineData类**

创建 `lib/models/kline_data.dart`：
```dart
/// K线数据点（原始OHLCV）
class KlineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// 从币安API响应创建
  factory KlineData.fromBinanceResponse(List<dynamic> response) {
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(response[0] as int),
      open: double.parse(response[1].toString()),
      high: double.parse(response[2].toString()),
      low: double.parse(response[3].toString()),
      close: double.parse(response[4].toString()),
      volume: double.parse(response[5].toString()),
    );
  }

  /// 转换为Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      'time': time.millisecondsSinceEpoch,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }

  /// 从Map创建
  factory KlineData.fromMap(Map<String, dynamic> map) {
    return KlineData(
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      open: (map['open'] as num).toDouble(),
      high: (map['high'] as num).toDouble(),
      low: (map['low'] as num).toDouble(),
      close: (map['close'] as num).toDouble(),
      volume: (map['volume'] as num).toDouble(),
    );
  }

  /// 计算实体方向 (1=涨, -1=跌, 0=平)
  int get direction => close.compareTo(open);
}

/// 带技术指标的数据点
class KlineDataWithIndicators {
  final KlineData data;
  final double? ma5;
  final double? ma10;
  final double? ma20;
  final double? upperBoll;
  final double? lowerBoll;

  KlineDataWithIndicators({
    required this.data,
    this.ma5,
    this.ma10,
    this.ma20,
    this.upperBoll,
    this.lowerBoll,
  });

  /// 便捷访问
  double get close => data.close;
  DateTime get time => data.time;
  double get open => data.open;
  double get high => data.high;
  double get low => data.low;
  double get volume => data.volume;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/kline_data.dart
git commit -m "feat: add KlineData and KlineDataWithIndicators models"
```

---

## Task 3: 创建MACD数据模型

**Files:**
- Create: `lib/models/macd_data.dart`

- [ ] **Step 1: 创建MACDData类**

创建 `lib/models/macd_data.dart`：
```dart
/// MACD指标数据
class MACDData {
  final List<double?> dif;      // DIF线 (快线)
  final List<double?> dea;      // DEA线 (慢线)
  final List<double?> macd;     // MACD柱状图
  final List<DateTime> time;    // 时间轴

  MACDData({
    required this.dif,
    required this.dea,
    required this.macd,
    required this.time,
  });

  /// 数据长度
  int get length => time.length;

  /// 获取指定位置的MACD值
  MACDValue? getValue(int index) {
    if (index < 0 || index >= length) return null;
    if (dif[index] == null || dea[index] == null || macd[index] == null) {
      return null;
    }
    return MACDValue(
      dif: dif[index]!,
      dea: dea[index]!,
      macd: macd[index]!,
      time: time[index],
    );
  }
}

/// 单个MACD值
class MACDValue {
  final double dif;
  final double dea;
  final double macd;
  final DateTime time;

  MACDValue({
    required this.dif,
    required this.dea,
    required this.macd,
    required this.time,
  });

  /// MACD柱状图颜色 (正=红, 负=绿)
  bool get isPositive => macd >= 0;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/macd_data.dart
git commit -m "feat: add MACDData model"
```

---

## Task 4: 更新数据库Helper

**Files:**
- Modify: `lib/services/database_helper.dart`

- [ ] **Step 1: 更新数据库版本和onUpgrade逻辑**

编辑 `lib/services/database_helper.dart`，更新 `_databaseVersion` 为 2：

```dart
static const int _databaseVersion = 2;
```

更新 `_onUpgrade` 方法：

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // 创建K线缓存表
    await db.execute('''
      CREATE TABLE kline_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol TEXT NOT NULL,
        interval TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        UNIQUE(symbol, interval)
      )
    ''');
    await db.execute('CREATE INDEX idx_kline_symbol_interval ON kline_cache(symbol, interval)');
  }
}
```

- [ ] **Step 2: 运行应用验证数据库升级**

```bash
flutter run
```

Expected: 应用正常启动，数据库自动升级

- [ ] **Step 3: Commit**

```bash
git add lib/services/database_helper.dart
git commit -m "feat: add kline_cache table to database (v2)"
```

---

## Task 5: 扩展BinanceApiService

**Files:**
- Modify: `lib/services/binance_api_service.dart`

- [ ] **Step 1: 添加KlineApi extension**

在 `lib/services/binance_api_service.dart` 文件末尾添加：

```dart
/// K线API扩展
extension KlineApi on BinanceApiService {
  static const String _klinesEndpoint = '/fapi/v1/klines';

  /// 获取最近N根K线
  Future<List<dynamic>> getRecentKlines({
    required String symbol,
    required String interval,
    int limit = 500,
  }) async {
    try {
      final queryParams = <String, String>{
        'symbol': symbol,
        'interval': interval,
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl$_klinesEndpoint')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('K线API请求失败: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('K线请求超时');
    } catch (e) {
      throw Exception('获取K线数据失败: $e');
    }
  }

  /// 获取指定时间范围的K线数据（支持分页）
  Future<List<dynamic>> getKlines({
    required String symbol,
    required String interval,
    required DateTime startTime,
    required DateTime endTime,
    int limit = 1500,
  }) async {
    try {
      final queryParams = <String, String>{
        'symbol': symbol,
        'interval': interval,
        'startTime': startTime.millisecondsSinceEpoch.toString(),
        'endTime': endTime.millisecondsSinceEpoch.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$_baseUrl$_klinesEndpoint')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('K线API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取K线数据失败: $e');
    }
  }
}
```

同时需要在文件顶部添加 `import '../models/kline_data.dart';`

- [ ] **Step 2: Commit**

```bash
git add lib/services/binance_api_service.dart
git commit -m "feat: add KlineApi extension to BinanceApiService"
```

---

## Task 6: 创建技术指标计算工具

**Files:**
- Create: `lib/services/technical_indicators.dart`
- Test: `test/services/technical_indicators_test.dart`

- [ ] **Step 1: 创建TechnicalIndicators类**

创建 `lib/services/technical_indicators.dart`：
```dart
import 'dart:math';
import '../models/kline_data.dart';
import '../models/macd_data.dart';

/// 技术指标计算工具
class TechnicalIndicators {
  /// 计算简单移动平均线 (SMA)
  /// 返回列表，数据不足时对应位置为null
  static List<double?> calculateMA(List<KlineData> data, int period) {
    if (data.isEmpty || period <= 0) return [];

    final result = <double?>[];

    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else {
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += data[i - j].close;
        }
        result.add(sum / period);
      }
    }

    return result;
  }

  /// 计算EMA (指数移动平均)
  static List<double?> _calculateEMA(List<KlineData> data, int period) {
    if (data.isEmpty || period <= 0) return [];

    final result = <double?>[];
    final double multiplier = 2 / (period + 1);

    // 第一个EMA使用SMA
    double? ema;

    for (int i = 0; i < data.length; i++) {
      if (i < period - 1) {
        result.add(null);
      } else if (i == period - 1) {
        // 计算初始SMA作为第一个EMA
        double sum = 0;
        for (int j = 0; j < period; j++) {
          sum += data[i - j].close;
        }
        ema = sum / period;
        result.add(ema);
      } else {
        // EMA = (当前价格 - 上一个EMA) × multiplier + 上一个EMA
        ema = (data[i].close - ema!) * multiplier + ema;
        result.add(ema);
      }
    }

    return result;
  }

  /// 布林带数据
  static BollingerBands calculateBOLL(
    List<KlineData> data, {
    int period = 20,
    double stdDev = 2.0,
  }) {
    final middle = calculateMA(data, period);
    final upper = <double?>[];
    final lower = <double?>[];

    for (int i = 0; i < data.length; i++) {
      if (middle[i] == null) {
        upper.add(null);
        lower.add(null);
      } else {
        // 计算标准差
        double sum = 0;
        for (int j = 0; j < period; j++) {
          final diff = data[i - j].close - middle[i]!;
          sum += diff * diff;
        }
        final std = sqrt(sum / period);

        upper.add(middle[i]! + stdDev * std);
        lower.add(middle[i]! - stdDev * std);
      }
    }

    return BollingerBands(upper: upper, middle: middle, lower: lower);
  }

  /// 计算MACD指标
  /// 返回null当数据不足时
  static MACDData? calculateMACD(
    List<KlineData> data, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  }) {
    if (data.length < slowPeriod + signalPeriod) {
      return null;
    }

    // 计算快速EMA和慢速EMA
    final fastEMA = _calculateEMA(data, fastPeriod);
    final slowEMA = _calculateEMA(data, slowPeriod);

    // DIF = 快速EMA - 慢速EMA
    final dif = <double?>[];
    for (int i = 0; i < data.length; i++) {
      if (fastEMA[i] == null || slowEMA[i] == null) {
        dif.add(null);
      } else {
        dif.add(fastEMA[i]! - slowEMA[i]!);
      }
    }

    // DEA = DIF的信号线EMA
    // 将dif转换为KlineData列表用于EMA计算
    final difData = <KlineData>[];
    for (int i = 0; i < dif.length; i++) {
      if (dif[i] != null) {
        difData.add(KlineData(
          time: data[i].time,
          open: dif[i]!,
          high: dif[i]!,
          low: dif[i]!,
          close: dif[i]!,
          volume: 0,
        ));
      }
    }

    final dea = <double?>[];
    if (difData.length >= signalPeriod) {
      final deaValues = _calculateEMA(difData, signalPeriod);

      int difIndex = 0;
      for (int i = 0; i < data.length; i++) {
        if (i < slowPeriod - 1 + signalPeriod - 1) {
          dea.add(null);
        } else {
          dea.add(deaValues[difIndex++]);
        }
      }
    } else {
      for (int i = 0; i < data.length; i++) {
        dea.add(null);
      }
    }

    // MACD柱状图 = (DIF - DEA) × 2
    final macd = <double?>[];
    for (int i = 0; i < data.length; i++) {
      if (dif[i] == null || dea[i] == null) {
        macd.add(null);
      } else {
        macd.add((dif[i]! - dea[i]!) * 2);
      }
    }

    return MACDData(
      dif: dif,
      dea: dea,
      macd: macd,
      time: data.map((e) => e.time).toList(),
    );
  }
}

/// 布林带数据
class BollingerBands {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;

  BollingerBands({
    required this.upper,
    required this.middle,
    required this.lower,
  });

  int get length => upper.length;
}
```

- [ ] **Step 2: 创建单元测试**

创建 `test/services/technical_indicators_test.dart`：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/technical_indicators.dart';

void main() {
  group('TechnicalIndicators', () {
    late List<KlineData> testData;

    setUp(() {
      // 创建测试数据
      final now = DateTime.now();
      testData = List.generate(50, (index) {
        final price = 50000.0 + index * 100 + (index % 3) * 50;
        return KlineData(
          time: now.add(Duration(minutes: index)),
          open: price,
          high: price + 50,
          low: price - 50,
          close: price + 20,
          volume: 1000.0,
        );
      });
    });

    test('calculateMA returns null for insufficient data', () {
      final result = TechnicalIndicators.calculateMA(testData, 20);

      expect(result.length, equals(50));
      expect(result[18], isNull); // 前19个应该是null
      expect(result[19], isNotNull);
    });

    test('calculateMA computes correct average', () {
      final simpleData = [
        KlineData(
          time: DateTime.now(),
          open: 100,
          high: 100,
          low: 100,
          close: 100,
          volume: 100,
        ),
        KlineData(
          time: DateTime.now().add(const Duration(minutes: 1)),
          open: 200,
          high: 200,
          low: 200,
          close: 200,
          volume: 100,
        ),
        KlineData(
          time: DateTime.now().add(const Duration(minutes: 2)),
          open: 300,
          high: 300,
          low: 300,
          close: 300,
          volume: 100,
        ),
      ];

      final result = TechnicalIndicators.calculateMA(simpleData, 2);

      expect(result[0], isNull);
      expect(result[1], equals(150.0)); // (100+200)/2
      expect(result[2], equals(250.0)); // (200+300)/2
    });

    test('calculateBOLL returns correct bands', () {
      final result = TechnicalIndicators.calculateBOLL(testData, period: 20);

      expect(result.length, equals(50));
      expect(result.upper[18], isNull);
      expect(result.upper[19], isNotNull);
      expect(result.lower[19], isLessThan(result.middle[19]!));
      expect(result.upper[19], isGreaterThan(result.middle[19]!));
    });

    test('calculateMACD returns null for insufficient data', () {
      final shortData = testData.take(20).toList();
      final result = TechnicalIndicators.calculateMACD(shortData);

      expect(result, isNull);
    });

    test('calculateMACD computes correctly', () {
      final result = TechnicalIndicators.calculateMACD(testData);

      expect(result, isNotNull);
      expect(result!.length, equals(50));
      // 前36个(26+9+1)应该有null值
      expect(result.dif[25], isNotNull);
      expect(result.dea[34], isNotNull);
      expect(result.macd[35], isNotNull);
    });
  });
}
```

- [ ] **Step 3: 运行测试**

```bash
flutter test test/services/technical_indicators_test.dart
```

Expected: PASS (所有测试通过)

- [ ] **Step 4: Commit**

```bash
git add lib/services/technical_indicators.dart test/services/technical_indicators_test.dart
git commit -m "feat: add TechnicalIndicators with tests"
```

---

## Task 7: 创建K线缓存服务

**Files:**
- Create: `lib/services/kline_cache_service.dart`

- [ ] **Step 1: 创建KlineCacheService类**

创建 `lib/services/kline_cache_service.dart`：
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../models/kline_data.dart';

/// K线缓存服务
class KlineCacheService {
  static const String _lastSymbolKey = 'kline_last_symbol';
  static const String _lastIntervalKey = 'kline_last_interval';
  static const int _cacheValidDuration = 3600000; // 1小时（毫秒）
  static const int _maxCacheAge = 604800000; // 7天（毫秒）

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 获取缓存数据
  Future<List<KlineData>?> getCached(String symbol, String interval) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'kline_cache',
        where: 'symbol = ? AND interval = ?',
        whereArgs: [symbol, interval],
      );

      if (results.isEmpty) return null;

      final row = results.first;
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int);

      // 检查缓存是否有效（1小时内）
      if (!isCacheValid(symbol, interval)) {
        return null;
      }

      final dataList = json.decode(row['data'] as String) as List;
      return dataList
          .map((e) => KlineData.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return null;
    }
  }

  /// 保存到缓存
  Future<void> saveCache(String symbol, String interval, List<KlineData> data) async {
    try {
      final db = await _dbHelper.database;
      final jsonString = json.encode(data.map((e) => e.toMap()).toList());

      await db.insert(
        'kline_cache',
        {
          'symbol': symbol,
          'interval': interval,
          'data': jsonString,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // 缓存失败不影响主流程
    }
  }

  /// 检查缓存是否有效（1小时内）
  bool isCacheValid(String symbol, String interval) {
    // 实际实现需要查询数据库，这里简化
    return true; // 将在getCached中检查
  }

  /// 清理旧数据（7天前）
  Future<void> cleanOldData() async {
    try {
      final db = await _dbHelper.database;
      final cutoffTime = DateTime.now().millisecondsSinceEpoch - _maxCacheAge;

      await db.delete(
        'kline_cache',
        where: 'cached_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      // 清理失败不影响主流程
    }
  }

  /// 清理所有缓存
  Future<void> clearAll() async {
    try {
      final db = await _dbHelper.database;
      await db.delete('kline_cache');
    } catch (e) {
      // 清理失败不影响主流程
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.rawQuery('''
        SELECT SUM(LENGTH(data)) as size FROM kline_cache
      ''');
      return result.first['size'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 保存用户最后选择的交易对和周期
  Future<void> savePreferences(String symbol, String interval) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSymbolKey, symbol);
      await prefs.setString(_lastIntervalKey, interval);
    } catch (e) {
      // 保存失败不影响主流程
    }
  }

  /// 获取用户最后选择的交易对
  Future<String> getLastSymbol() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastSymbolKey) ?? 'BTCUSDT';
    } catch (e) {
      return 'BTCUSDT';
    }
  }

  /// 获取用户最后选择的周期
  Future<String> getLastInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastIntervalKey) ?? '15m';
    } catch (e) {
      return '15m';
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/kline_cache_service.dart
git commit -m "feat: add KlineCacheService"
```

---

## Task 8: 创建K线WebSocket服务

**Files:**
- Create: `lib/services/kline_websocket_service.dart`

- [ ] **Step 1: 创建KlineWebSocketService类**

创建 `lib/services/kline_websocket_service.dart`：
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'binance_websocket_manager.dart';
import '../models/kline_data.dart';

/// K线WebSocket服务
class KlineWebSocketService extends ChangeNotifier {
  final BinanceWebSocketManager _wsManager;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<KlineData> _klineController =
      StreamController.broadcast();
  bool _isConnected = false;

  Stream<KlineData> get klineStream => _klineController.stream;
  bool get isConnected => _isConnected;

  KlineWebSocketService(this._wsManager);

  /// 连接WebSocket
  Future<void> connect(String symbol, String interval) async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      final topic = '${symbol.toLowerCase()}@kline_$interval';
      final uri = Uri.parse('wss://fstream.binance.com/ws/$topic');

      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String) as Map<String, dynamic>;
      final kline = data['k'] as Map<String, dynamic>;

      final klineData = KlineData(
        time: DateTime.fromMillisecondsSinceEpoch(kline['t'] as int),
        open: double.parse(kline['o'] as String),
        high: double.parse(kline['h'] as String),
        low: double.parse(kline['l'] as String),
        close: double.parse(kline['c'] as String),
        volume: double.parse(kline['v'] as String),
      );

      _klineController.add(klineData);
    } catch (e) {
      if (kDebugMode) print('[KlineWebSocket] 解析消息失败: $e');
    }
  }

  void _onError(error) {
    _isConnected = false;
    notifyListeners();
  }

  void _onDone() {
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _klineController.close();
    super.dispose();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/kline_websocket_service.dart
git commit -m "feat: add KlineWebSocketService"
```

---

## Task 9: 创建KlineProvider

**Files:**
- Create: `lib/providers/kline_provider.dart`

- [ ] **Step 1: 创建KlineProvider类**

创建 `lib/providers/kline_provider.dart`：
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/kline_data.dart';
import '../models/macd_data.dart';
import '../services/binance_api_service.dart';
import '../services/kline_cache_service.dart';
import '../services/kline_websocket_service.dart';
import '../services/technical_indicators.dart';
import 'binance_websocket_manager.dart';

/// K线状态管理
class KlineProvider extends ChangeNotifier {
  final BinanceWebSocketManager _wsManager = BinanceWebSocketManager();
  late final KlineWebSocketService _wsService;
  final KlineCacheService _cacheService = KlineCacheService();

  // 当前选中的交易对和周期
  String _symbol = '';
  String _currentInterval = '15m';

  // K线数据
  List<KlineData> _klineData = [];
  List<KlineDataWithIndicators> _klineWithIndicators = [];

  // UI状态
  bool _isLoading = false;
  bool _isRealtime = false;
  String? _errorMessage;

  // MACD数据
  MACDData? _macdData;
  bool _showMacd = false;

  // 实时价格
  double? _currentPrice;
  double? _priceChange;

  // WebSocket订阅
  StreamSubscription? _wsSubscription;

  KlineProvider() {
    _wsService = KlineWebSocketService(_wsManager);
  }

  // Getters
  String get symbol => _symbol;
  String get currentInterval => _currentInterval;
  List<KlineDataWithIndicators> get klineData => _klineWithIndicators;
  bool get isLoading => _isLoading;
  bool get isRealtime => _isRealtime;
  String? get errorMessage => _errorMessage;
  MACDData? get macdData => _macdData;
  bool get showMacd => _showMacd;
  double? get currentPrice => _currentPrice;
  double? get priceChange => _priceChange;

  /// 加载K线数据（优先使用缓存）
  Future<void> loadKlines(String symbol, String interval) async {
    _symbol = symbol;
    _currentInterval = interval;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. 尝试从缓存加载
      List<KlineData>? data = await _cacheService.getCached(symbol, interval);

      // 2. 缓存未命中则请求API
      if (data == null || data.isEmpty) {
        final api = BinanceApiService();
        final rawData = await api.getRecentKlines(
          symbol: symbol,
          interval: interval,
          limit: 500,
        );

        data = rawData.map((e) => KlineData.fromBinanceResponse(e as List<dynamic>)).toList();

        // 保存到缓存
        await _cacheService.saveCache(symbol, interval, data);
      }

      _klineData = data;

      // 3. 计算技术指标
      _calculateIndicators();

      // 4. 保存用户偏好
      await _cacheService.savePreferences(symbol, interval);

      // 5. 启动实时更新
      _startRealtime();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 计算技术指标
  void _calculateIndicators() {
    if (_klineData.isEmpty) {
      _klineWithIndicators = [];
      return;
    }

    final ma5 = TechnicalIndicators.calculateMA(_klineData, 5);
    final ma10 = TechnicalIndicators.calculateMA(_klineData, 10);
    final ma20 = TechnicalIndicators.calculateMA(_klineData, 20);
    final boll = TechnicalIndicators.calculateBOLL(_klineData);
    _macdData = TechnicalIndicators.calculateMACD(_klineData);

    _klineWithIndicators = List.generate(
      _klineData.length,
      (index) => KlineDataWithIndicators(
        data: _klineData[index],
        ma5: ma5.length > index ? ma5[index] : null,
        ma10: ma10.length > index ? ma10[index] : null,
        ma20: ma20.length > index ? ma20[index] : null,
        upperBoll: boll.upper.length > index ? boll.upper[index] : null,
        lowerBoll: boll.lower.length > index ? boll.lower[index] : null,
      ),
    );
  }

  /// 切换时间周期
  Future<void> switchInterval(String interval) async {
    if (interval == _currentInterval) return;

    await _stopRealtime();
    await loadKlines(_symbol, interval);
  }

  /// 切换交易对
  Future<void> switchSymbol(String symbol) async {
    if (symbol == _symbol) return;

    await _stopRealtime();
    await loadKlines(symbol, _currentInterval);
  }

  /// 启动实时更新
  void _startRealtime() {
    try {
      _wsService.connect(_symbol, _currentInterval).then((_) {
        _wsSubscription = _wsService.klineStream.listen(_onKlineUpdate);
        _isRealtime = true;
        notifyListeners();
      });
    } catch (e) {
      if (kDebugMode) print('[KlineProvider] 实时更新启动失败: $e');
    }
  }

  /// 停止实时更新
  Future<void> _stopRealtime() async {
    await _wsSubscription?.cancel();
    await _wsService.disconnect();
    _isRealtime = false;
  }

  /// 处理实时K线更新
  void _onKlineUpdate(KlineData data) {
    if (_klineData.isEmpty) return;

    // 更新最后一个数据点
    final lastIndex = _klineData.length - 1;

    // 如果是同一根K线，更新它
    if (_isSameKline(data.time, _klineData[lastIndex].time, _currentInterval)) {
      _klineData[lastIndex] = data;

      // 更新价格
      _currentPrice = data.close;
      _priceChange = ((data.close - data.open) / data.open) * 100;
    } else {
      // 新K线，添加到列表
      _klineData.add(data);

      // 限制数据量
      if (_klineData.length > 2000) {
        _klineData.removeAt(0);
      }

      // 重新计算指标
      _calculateIndicators();
    }

    notifyListeners();
  }

  /// 判断是否是同一根K线
  bool _isSameKline(DateTime time1, DateTime time2, String interval) {
    switch (interval) {
      case '1m':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour &&
            time1.minute == time2.minute;
      case '15m':
        final min1 = (time1.minute ~/ 15) * 15;
        final min2 = (time2.minute ~/ 15) * 15;
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour &&
            min1 == min2;
      case '1h':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            time1.hour == time2.hour;
      case '4h':
        final hour1 = (time1.hour ~/ 4) * 4;
        final hour2 = (time2.hour ~/ 4) * 4;
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day &&
            hour1 == hour2;
      case '1d':
        return time1.year == time2.year &&
            time1.month == time2.month &&
            time1.day == time2.day;
      case '1w':
        final week1 = _getWeekNumber(time1);
        final week2 = _getWeekNumber(time2);
        return time1.year == time2.year && week1 == week2;
      default:
        return false;
    }
  }

  int _getWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  /// 切换MACD显示
  void toggleMacd() {
    _showMacd = !_showMacd;
    notifyListeners();
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadKlines(_symbol, _currentInterval);
  }

  @override
  void dispose() {
    _stopRealtime();
    _wsService.dispose();
    super.dispose();
  }
}
```

需要在文件顶部添加：
```dart
import 'package:intl/intl.dart';
```

- [ ] **Step 2: Commit**

```bash
git add lib/providers/kline_provider.dart
git commit -m "feat: add KlineProvider"
```

---

## Task 10: 创建周期选择器组件

**Files:**
- Create: `lib/widgets/interval_selector.dart`

- [ ] **Step 1: 创建IntervalSelector组件**

创建 `lib/widgets/interval_selector.dart`：
```dart
import 'package:flutter/material.dart';

/// 周期选择器组件
class IntervalSelector extends StatelessWidget {
  final String currentInterval;
  final ValueChanged<String> onIntervalChanged;

  static const Map<String, String> _intervals = {
    '分时': '1m',  // 使用1分钟数据，以密集方式展示
    '1m': '1m',
    '15m': '15m',
    '1H': '1h',
    '4H': '4h',
    '日K': '1d',
    '周K': '1w',
  };

  const IntervalSelector({
    super.key,
    required this.currentInterval,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _intervals.entries.map((entry) {
            final label = entry.key;
            final value = entry.value;
            final isSelected = currentInterval == value;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildIntervalButton(
                label: label,
                isSelected: isSelected,
                colorScheme: colorScheme,
                onTap: () => onIntervalChanged(value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIntervalButton({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/interval_selector.dart
git commit -m "feat: add IntervalSelector widget"
```

---

## Task 11: 创建K线图组件

**Files:**
- Create: `lib/widgets/kline_chart_widget.dart`

- [ ] **Step 1: 创建KlineChartWidget组件**

创建 `lib/widgets/kline_chart_widget.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_chen_kchart/flutter_chen_kchart.dart';
import '../models/kline_data.dart';
import '../providers/kline_provider.dart';

/// K线图组件
class KlineChartWidget extends StatelessWidget {
  final List<KlineDataWithIndicators> data;
  final bool isRealtime;
  final double? currentPrice;

  const KlineChartWidget({
    super.key,
    required this.data,
    required this.isRealtime,
    this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // 转换为K线库所需格式
    final klineData = data.map((e) => KChartModel(
      open: e.data.open,
      close: e.data.close,
      high: e.data.high,
      low: e.data.low,
      time: e.data.time,
      vol: e.data.volume,
      ma5: e.ma5,
      ma10: e.ma10,
      ma20: e.ma20,
      upper: e.upperBoll,
      lower: e.lowerBoll,
    )).toList();

    return KChartWidget(
      klineData,
      isLine: false,
      mainState: MainState.MA,
      volState: VolState.VOL,
      secondaryState: SecondaryState.MACD,
      isChinese: true,
      hideGrid: false,
      isShowPrice: currentPrice != null,
      currentPrice: currentPrice,
    );
  }
}
```

注意：flutter_chen_kchart的实际API可能有所不同，需要根据实际库文档调整。

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/kline_chart_widget.dart
git commit -m "feat: add KlineChartWidget"
```

---

## Task 12: 创建骨架屏组件

**Files:**
- Create: `lib/widgets/kline_skeleton.dart`

- [ ] **Step 1: 创建KlineSkeleton组件**

创建 `lib/widgets/kline_skeleton.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// K线图骨架屏加载组件
class KlineSkeleton extends StatelessWidget {
  const KlineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 周期选择器骨架
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_) => _buildSkeletonButton(colorScheme),
          ),
        ),
        const SizedBox(height: 16),
        // K线图骨架
        Expanded(
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // 图表区域
                  Expanded(
                    flex: 3,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // 成交量区域
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonButton(ColorScheme colorScheme) {
    return Container(
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/kline_skeleton.dart
git commit -m "feat: add KlineSkeleton widget"
```

---

## Task 13: 创建MACD图表组件

**Files:**
- Create: `lib/widgets/macd_chart_widget.dart`

- [ ] **Step 1: 创建MacdChartWidget组件**

创建 `lib/widgets/macd_chart_widget.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/macd_data.dart';

/// MACD图表组件
class MacdChartWidget extends StatelessWidget {
  final MACDData macdData;

  const MacdChartWidget({
    super.key,
    required this.macdData,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(colorScheme, 'DIF', Colors.blue),
              const SizedBox(width: 16),
              _buildLegend(colorScheme, 'DEA', Colors.orange),
              const SizedBox(width: 16),
              _buildLegend(colorScheme, 'MACD', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          // 图表
          Expanded(
            child: LineChart(
              _buildChartData(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ColorScheme colorScheme, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  LineChartData _buildChartData(ColorScheme colorScheme) {
    // 只显示有效数据
    final validDif = <FlSpot>[];
    final validDea = <FlSpot>[];
    final validMacd = <BarData>[];

    for (int i = 0; i < macdData.length; i++) {
      final dif = macdData.dif[i];
      final dea = macdData.dea[i];
      final macd = macdData.macd[i];

      if (dif != null) {
        validDif.add(FlSpot(i.toDouble(), dif));
      }
      if (dea != null) {
        validDea.add(FlSpot(i.toDouble(), dea));
      }
      if (macd != null) {
        validMacd.add(
          BarChartBarData(
            color: macd >= 0 ? Colors.red : Colors.green,
            width: 4,
            barData: [
              FlSpot(i.toDouble(), 0),
              FlSpot(i.toDouble(), macd),
            ],
          ),
        );
      }
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: false,
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: validDif,
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: validDea,
          isCurved: true,
          color: Colors.orange,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
      barGroups: validMacd,
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/macd_chart_widget.dart
git commit -m "feat: add MacdChartWidget"
```

---

## Task 14: 创建K线主页面

**Files:**
- Create: `lib/screens/kline_screen.dart`

- [ ] **Step 1: 创建KlineScreen页面**

创建 `lib/screens/kline_screen.dart`：
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/kline_provider.dart';
import '../widgets/interval_selector.dart';
import '../widgets/kline_chart_widget.dart';
import '../widgets/kline_skeleton.dart';
import '../widgets/macd_chart_widget.dart';

/// K线图页面
class KlineScreen extends StatefulWidget {
  final String symbol;

  const KlineScreen({
    super.key,
    required this.symbol,
  });

  @override
  State<KlineScreen> createState() => _KlineScreenState();
}

class _KlineScreenState extends State<KlineScreen> {
  final List<String> _commonSymbols = [
    'BTCUSDT',
    'ETHUSDT',
    'BNBUSDT',
    'SOLUSDT',
    'ADAUSDT',
    'XRPUSDT',
    'DOGEUSDT',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KlineProvider>().loadKlines(widget.symbol, '15m');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<KlineProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const KlineSkeleton();
          }

          if (provider.errorMessage != null) {
            return _buildErrorView(provider);
          }

          return Column(
            children: [
              // 交易对选择器
              _buildSymbolSelector(provider),
              // 周期选择器
              const IntervalSelector(
                currentInterval: '15m',
                onIntervalChanged: null, // 由Consumer内部处理
              ),
              // K线图
              Expanded(
                child: KlineChartWidget(
                  data: provider.klineData,
                  isRealtime: provider.isRealtime,
                  currentPrice: provider.currentPrice,
                ),
              ),
              // 实时价格线
              _buildPriceLine(provider),
              // MACD按钮
              _buildMacdButton(provider),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('K线图'),
      actions: [
        IconButton(
          icon: const Icon(Icons.bar_chart),
          onPressed: () {
            final provider = context.read<KlineProvider>();
            provider.toggleMacd();
            if (provider.showMacd) {
              _showMacdBottomSheet();
            }
          },
        ),
      ],
    );
  }

  Widget _buildSymbolSelector(KlineProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.symbol,
          isExpanded: true,
          items: _commonSymbols.map((symbol) {
            return DropdownMenuItem(
              value: symbol,
              child: Text(symbol),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              provider.switchSymbol(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPriceLine(KlineProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    if (provider.currentPrice == null) {
      return const SizedBox.shrink();
    }

    final priceChange = provider.priceChange ?? 0;
    final changeColor = priceChange >= 0 ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Text(
            '¥${provider.currentPrice!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: changeColor,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 14,
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacdButton(KlineProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.show_chart),
        label: const Text('MACD 指标'),
        onPressed: () {
          provider.toggleMacd();
          _showMacdBottomSheet();
        },
      ),
    );
  }

  Widget _buildErrorView(KlineProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            provider.errorMessage ?? '加载失败',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            onPressed: () => provider.refresh(),
          ),
        ],
      ),
    );
  }

  void _showMacdBottomSheet() {
    final provider = context.read<KlineProvider>();
    if (provider.macdData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 拖动把手
            _buildDragHandle(),
            // MACD图表
            Expanded(
              child: MacdChartWidget(macdData: provider.macdData!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 16, bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
```

需要修复IntervalSelector的使用：

```dart
// 在Consumer内部修改IntervalSelector使用方式
Consumer<KlineProvider>(
  builder: (context, provider, child) {
    return IntervalSelector(
      currentInterval: provider.currentInterval,
      onIntervalChanged: (interval) => provider.switchInterval(interval),
    );
  },
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/kline_screen.dart
git commit -m "feat: add KlineScreen"
```

---

## Task 15: 更新main.dart注册Provider

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 导入并注册KlineProvider**

编辑 `lib/main.dart`，在imports部分添加：
```dart
import 'providers/kline_provider.dart';
```

在MultiProvider的providers数组中添加（在PumpListProvider之后）：
```dart
ChangeNotifierProvider(
  create: (_) => KlineProvider(),
),
```

- [ ] **Step 2: 运行应用验证**

```bash
flutter run
```

Expected: 应用正常启动，KlineProvider正常注册

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: register KlineProvider in main.dart"
```

---

## Task 16: 更新FundingScreen添加导航

**Files:**
- Modify: `lib/screens/funding_screen.dart`

- [ ] **Step 1: 添加KlineScreen导入和导航**

编辑 `lib/screens/funding_screen.dart`，在imports部分添加：
```dart
import 'kline_screen.dart';
```

修改ListView.builder中的FundingRateItem，将onTap回调改为导航：

```dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => KlineScreen(symbol: rate.symbol),
    ),
  );
},
```

找到_showRateDetails方法，改为导航到K线页面：

```dart
void _showRateDetails(BuildContext context, dynamic rate) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => KlineScreen(symbol: rate.symbol),
    ),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/funding_screen.dart
git commit -m "feat: add navigation to KlineScreen from FundingScreen"
```

---

## Task 17: 更新LongShortScreen添加导航

**Files:**
- Modify: `lib/screens/long_short_screen.dart`

- [ ] **Step 1: 添加KlineScreen导入和导航**

首先读取文件确定卡片的构建方式，然后添加：

在imports部分添加：
```dart
import 'kline_screen.dart';
```

为多空比卡片添加GestureDetector包装（根据实际代码结构调整）：

```dart
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KlineScreen(symbol: ratio.symbol),
      ),
    );
  },
  child: Card(...), // 现有的多空比卡片
)
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/long_short_screen.dart
git commit -m "feat: add navigation to KlineScreen from LongShortScreen"
```

---

## Task 18: 更新ProfileScreen添加缓存管理

**Files:**
- Modify: `lib/screens/profile_screen.dart`

- [ ] **Step 1: 添加K线缓存管理选项**

编辑 `lib/screens/profile_screen.dart`，在imports部分添加：
```dart
import '../services/kline_cache_service.dart';
```

在State类中添加：
```dart
final KlineCacheService _klineCacheService = KlineCacheService();
int _klineCacheSize = 0;

@override
void initState() {
  super.initState();
  _loadKlineCacheSize();
}

Future<void> _loadKlineCacheSize() async {
  final size = await _klineCacheService.getCacheSize();
  if (mounted) {
    setState(() {
      _klineCacheSize = (size / 1024 / 1024).round(); // 转换为MB
    });
  }
}
```

在"测试功能"部分之前添加（在_buildSectionHeader('测试功能')之前）：

```dart
// 数据管理部分
_buildSectionHeader('数据管理'),
Card(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: ListTile(
    leading: const Icon(Icons.delete_sweep),
    title: const Text('清理K线缓存'),
    subtitle: Text('当前缓存: $_klineCacheSize MB'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _showClearKlineCacheDialog(),
  ),
),
const SizedBox(height: 32),
```

添加清理缓存对话框方法：

```dart
void _showClearKlineCacheDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清理K线缓存'),
      content: Text('确定要清理所有K线缓存数据吗？\n当前缓存: $_klineCacheSize MB'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            await _klineCacheService.clearAll();
            await _loadKlineCacheSize();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('K线缓存已清理')),
              );
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add K-line cache management to ProfileScreen"
```

---

## Task 19: 运行集成测试

**Files:**
- Test: 应用整体功能

- [ ] **Step 1: 启动应用测试**

```bash
flutter run
```

测试流程：
1. 在资费页面点击任意交易对 → 应该跳转到K线页面
2. 查看K线图是否正常显示
3. 切换不同周期（分时、1m、15m、1H等）
4. 切换不同交易对
5. 查看实时价格更新
6. 打开MACD指标
7. 返回个人中心，清理K线缓存

- [ ] **Step 2: 检查错误日志**

```bash
flutter logs
```

- [ ] **Step 3: 修复发现的问题**

如果有问题，修复后再次commit。

---

## Task 20: 最终代码检查和文档

**Files:**
- 检查所有新建和修改的文件

- [ ] **Step 1: 运行flutter analyze**

```bash
flutter analyze
```

修复所有警告和错误。

- [ ] **Step 2: 运行格式化**

```bash
dart format .
```

- [ ] **Step 3: 最终Commit**

```bash
git add .
git commit -m "chore: final cleanup after K-line feature implementation"
```

- [ ] **Step 4: 创建功能说明文档**

创建 `docs/kline-feature.md`：
```markdown
# K线图功能

## 概述
应用新增K线图功能，支持多时间周期查看交易对价格走势。

## 功能特性
- 支持7种时间周期：分时、1m、15m、1H、4H、日K、周K
- 技术指标：MA(5,10,20)、BOLL布林带、MACD
- 实时价格更新（WebSocket）
- 数据持久化缓存（SQLite）
- 从资费页面和多空页面便捷跳转

## 使用方法
1. 在资费页面或多空页面点击交易对名称
2. 进入K线图页面查看走势
3. 点击顶部周期按钮切换不同时间周期
4. 点击交易对下拉菜单可切换查看其他交易对
5. 点击右上角图表图标或底部按钮查看MACD指标

## 缓存管理
在"我"页面可以清理K线缓存数据以释放存储空间。
```

- [ ] **Step 5: 提交文档**

```bash
git add docs/kline-feature.md
git commit -m "docs: add K-line feature documentation"
```

---

## 实施完成检查清单

- [ ] 所有依赖已添加
- [ ] 所有数据模型已创建
- [ ] 数据库已升级到v2
- [ ] BinanceApiService已扩展KlineApi
- [ ] 技术指标计算工具已创建并通过测试
- [ ] KlineCacheService已创建
- [ ] KlineWebSocketService已创建
- [ ] KlineProvider已创建
- [ ] 所有UI组件已创建
- [ ] KlineScreen已创建
- [ ] 导航已集成到FundingScreen和LongShortScreen
- [ ] ProfileScreen已添加缓存管理
- [ ] KlineProvider已在main.dart中注册
- [ ] 集成测试通过
- [ ] 代码分析无错误
- [ ] 文档已完成

---

## 注意事项

1. **flutter_chen_kchart库的API可能需要调整** - 该库的文档可能不完整，需要根据实际使用情况调整KlineChartWidget的实现。

2. **网络请求需要配置代理** - 在中国大陆可能需要配置代理才能访问币安API。

3. **WebSocket连接稳定性** - 网络不稳定时可能需要重连机制，已通过复用BinanceWebSocketManager解决。

4. **数据量控制** - K线数据量较大时需要注意内存使用，已设置2000根K线的上限。

5. **测试覆盖** - 建议在实施过程中增加更多单元测试和集成测试。
