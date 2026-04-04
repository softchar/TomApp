# K线图页面设计文档

## 1. 概述

### 1.1 目标
在币安合约费率应用中添加专业的K线图功能，允许用户查看交易对的价格走势、技术指标，并支持实时价格更新。

### 1.2 核心功能
- 多时间周期K线图（分时、1分钟、15分钟、1小时、4小时、日K、周K）
- 完整技术指标：蜡烛图、成交量、MA均线、BOLL布林带、MACD
- 实时价格更新（WebSocket推送）
- 数据持久化缓存（SQLite数据库）
- 从资费页面和多空页面便捷跳转

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────┐
│ Presentation│
│    Layer    │  KlineScreen, KlineChartWidget
└──────┬──────┘
       │
┌──────┴──────┐
│  Provider   │  KlineProvider (状态管理)
│    Layer    │  Loading, Error, Realtime states
└──────┬──────┘
       │
┌──────┴─────────────────────┐
│      Service Layer        │
├───────────────────────────┤
│ BinanceApiService         │  KlineApi extension
│ KlineCacheService         │  数据库缓存
│ KlineWebSocketService     │  实时更新(复用WS Manager)
│ TechnicalIndicators       │  指标计算
└──────┬────────────────────┘
       │
┌──────┴──────┐
│   Data Layer│  KlineData, KlineCacheModel
└─────────────┘  SQLite Database
```

### 2.2 导航流程

```
FundingScreen            LongShortScreen
     │                         │
     │ onTap                   │ onTap
     ▼                         ▼
┌─────────────────────────────────────┐
│         KlineScreen                │
│  ┌─────────────────────────────┐  │
│  │ Symbol: BTCUSDT             │  │
│  │ Interval: [分时][1m][15m]... │  │
│  │ Chart Area                  │  │
│  │ MACD Drawer (bottom sheet) │  │
│  └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

## 3. 数据模型

### 3.1 KlineData - K线数据点（原始OHLCV）

```dart
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

  // 从币安API响应创建
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

  // 转换为 Map（用于数据库存储）
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

  // 从 Map 创建
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
}
```

### 3.2 KlineDataWithIndicators - 带指标的数据

```dart
class KlineDataWithIndicators {
  final KlineData data;
  final double ma5;
  final double ma10;
  final double ma20;
  final double upperBoll;
  final double lowerBoll;

  KlineDataWithIndicators({
    required this.data,
    required this.ma5,
    required this.ma10,
    required this.ma20,
    required this.upperBoll,
    required this.lowerBoll,
  });

  // 获取收盘价（便捷访问）
  double get close => data.close;
  DateTime get time => data.time;
}
```

### 3.3 KlineCacheModel - 缓存数据

```dart
import 'dart:convert';

class KlineCacheModel {
  final String symbol;
  final String interval;
  final List<KlineData> data;
  final DateTime cachedAt;
  final int dataSize; // 缓存大小（字节）

  KlineCacheModel({
    required this.symbol,
    required this.interval,
    required this.data,
    required this.cachedAt,
    required this.dataSize,
  });

  // 从数据库Map创建
  factory KlineCacheModel.fromDbMap(Map<String, dynamic> map) {
    final dataList = json.decode(map['data'] as String) as List;
    return KlineCacheModel(
      symbol: map['symbol'] as String,
      interval: map['interval'] as String,
      data: dataList.map((e) => KlineData.fromMap(e as Map<String, dynamic>)).toList(),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(map['cached_at'] as int),
      dataSize: (map['data'] as String).length,
    );
  }

  // 转换为数据库Map
  Map<String, dynamic> toDbMap() {
    return {
      'symbol': symbol,
      'interval': interval,
      'data': json.encode(data.map((e) => e.toMap()).toList()),
      'cached_at': cachedAt.millisecondsSinceEpoch,
    };
  }
}
```

### 3.4 MACDData - MACD指标数据

```dart
class MACDData {
  final List<double> dif;      // DIF线 (快线)
  final List<double> dea;      // DEA线 (慢线)
  final List<double> macd;     // MACD柱状图
  final List<DateTime> time;   // 时间轴
}
```

## 4. 服务层设计

### 4.1 KlineService - 扩展BinanceApiService

**设计：** 扩展现有的 `BinanceApiService` 类，添加K线数据获取方法，而不是创建独立的服务。

**职责：**
- 从币安API获取K线数据
- 支持分页请求和拼接
- 处理API限流和错误
- 复用现有的baseUrl配置和错误处理逻辑

**核心方法（添加到BinanceApiService）：**
```dart
extension KlineApi on BinanceApiService {
  // 获取K线数据（自动分页拼接）
  Future<List<KlineData>> getKlines({
    required String symbol,
    required String interval,
    required DateTime startTime,
    required DateTime endTime,
    int limit = 1500,
  });

  // 获取最近N根K线
  Future<List<KlineData>> getRecentKlines({
    required String symbol,
    required String interval,
    int count = 500,
  });
}
```

**API端点：**
```
GET /fapi/v1/klines
参数：symbol, interval, startTime, endTime, limit
返回：[[time, open, high, low, close, volume, ...], ...]
```

### 4.2 KlineCacheService - 缓存服务

**职责：**
- 管理SQLite数据库缓存
- 自动清理过期数据
- 提供缓存查询和更新

**核心方法：**
```dart
class KlineCacheService {
  // 获取缓存数据
  Future<List<KlineData>?> getCached(String symbol, String interval);

  // 保存到缓存
  Future<void> saveCache(String symbol, String interval, List<KlineData> data);

  // 检查缓存是否有效（< 1小时）
  bool isCacheValid(String symbol, String interval);

  // 清理旧数据（> 7天）
  Future<void> cleanOldData();

  // 清理所有缓存
  Future<void> clearAll();

  // 获取缓存大小
  Future<int> getCacheSize();
}
```

**数据库表：**
```sql
CREATE TABLE kline_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  symbol TEXT NOT NULL,
  interval TEXT NOT NULL,
  data TEXT NOT NULL,           -- JSON序列化的List<KlineData>
  cached_at INTEGER NOT NULL,
  UNIQUE(symbol, interval)
);

CREATE INDEX idx_symbol_interval ON kline_cache(symbol, interval);
```

**数据库迁移策略：**
- 当前 `DatabaseHelper` 版本为 1
- K线缓存功能将版本升级为 2
- 迁移逻辑在 `onUpgrade()` 中执行：
  ```dart
  if (oldVersion < 2) {
    // 创建kline_cache表
    db.execute('''
      CREATE TABLE kline_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        symbol TEXT NOT NULL,
        interval TEXT NOT NULL,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL,
        UNIQUE(symbol, interval)
      )
    ''');
    db.execute('CREATE INDEX idx_symbol_interval ON kline_cache(symbol, interval)');
  }
  ```

### 4.3 KlineWebSocketService - 实时价格服务

**设计：** 复用现有的 `BinanceWebSocketManager` 进行WebSocket连接管理。

**职责：**
- 连接币安WebSocket实时K线流
- 推送最新K线数据更新
- 处理连接状态和重连（委托给BinanceWebSocketManager）
- 复用现有的 `WebSocketConnectionState` 枚举

**核心方法：**
```dart
class KlineWebSocketService extends ChangeNotifier {
  final BinanceWebSocketManager _wsManager;
  StreamSubscription? _subscription;

  KlineWebSocketService(this._wsManager);

  // 连接WebSocket
  Future<void> connect(String symbol, String interval);

  // 断开连接
  Future<void> disconnect();

  // 获取K线数据流
  Stream<KlineData> get klineStream;

  // 连接状态（委托给BinanceWebSocketManager）
  WebSocketConnectionState get connectionState =>
      _wsManager.connectionState;
}
```

**WebSocket端点：**
```
wss://fstream.binance.com/ws/{symbol}@kline_{interval}
返回：实时推送K线数据
```

**与现有服务集成：**
- 使用 `BinanceWebSocketManager` 的单例实例
- 复用现有的连接池和重连逻辑
- 连接状态通过 `BinanceWebSocketManager.connectionState` 获取

### 4.4 TechnicalIndicators - 技术指标工具

**职责：**
- 计算MA移动平均线
- 计算BOLL布林带
- 计算MACD指标

**核心方法：**
```dart
class TechnicalIndicators {
  // 计算MA均线
  static List<double> calculateMA(List<KlineData> data, int period);

  // 计算BOLL布林带
  static BollingerBands calculateBOLL(
    List<KlineData> data,
    int period = 20,
    double stdDev = 2.0,
  );

  // 计算MACD
  static MACDData calculateMACD(
    List<KlineData> data, {
    int fastPeriod = 12,
    int slowPeriod = 26,
    int signalPeriod = 9,
  );
}

class BollingerBands {
  final List<double?> upper;    // 上轨（数据不足时为null）
  final List<double?> middle;   // 中轨（MA，数据不足时为null）
  final List<double?> lower;    // 下轨（数据不足时为null）
}
```

## 5. 状态管理

### 5.1 KlineProvider

**Provider注册（在main.dart中）：**
```dart
// 在MultiProvider的providers数组中添加
ChangeNotifierProvider(
  create: (_) => KlineProvider(),
),
```

**状态：**
```dart
class KlineProvider extends ChangeNotifier {
  // 当前选中的交易对和周期
  String _symbol = '';
  String _currentInterval = '1m';

  // K线数据
  List<KlineData> _klineData = [];

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
}
```

**核心方法：**
```dart
class KlineProvider extends ChangeNotifier {
  // 加载K线数据（优先使用缓存）
  Future<void> loadKlines(String symbol, String interval);

  // 切换时间周期
  Future<void> switchInterval(String interval);

  // 切换交易对
  Future<void> switchSymbol(String symbol);

  // 启动实时更新
  void startRealtime();

  // 停止实时更新
  void stopRealtime();

  // 切换MACD显示
  void toggleMacd();

  // 刷新数据
  Future<void> refresh();

  // 保存用户偏好（交易对、周期）
  Future<void> savePreferences();

  // 加载用户偏好
  Future<void> loadPreferences();
}
```

**状态持久化：**
- 使用`shared_preferences`保存用户最后选择的交易对和周期
- 下次打开K线页面时自动恢复上次的视图
- 在`loadKlines`成功后调用`savePreferences`

## 6. UI设计

### 6.0 时间周期映射

币安API支持的interval值与UI显示的映射关系：

| UI显示 | API值 | 说明 |
|--------|-------|------|
| 分时 | 1m | 使用1分钟K线聚合显示 |
| 1m | 1m | 1分钟 |
| 15m | 15m | 15分钟 |
| 1H | 1h | 1小时 |
| 4H | 4h | 4小时 |
| 日K | 1d | 1天 |
| 周K | 1w | 1周 |

**注意：** "分时"不是币安原生支持的周期，实现方式为使用1分钟K线数据，在图表上以更密集的方式展示，不显示具体日期标签。

### 6.1 KlineScreen 布局

```
┌─────────────────────────────────────┐
│  ← K线图        ⚙️        📊MACD   │  AppBar
├─────────────────────────────────────┤
│  ▼ BTCUSDT                          │  交易对选择器
├─────────────────────────────────────┤
│  [分时] [1m] [15m] [1H] [4H] [日K]  │  周期选择器
├─────────────────────────────────────┤
│                                     │
│   ┌─────────────────────────────┐   │
│   │  ╔═╦═╗                      │   │
│   │ ╔═╩═╗ ║  MA(5,10,20)     │   │
│   │ ║  ║ ║  ████ BOLL ████   │   │  K线图
│   │ ╚═╦═╝ ║                  │   │
│   │  ╚═╩═╝                      │   │
│   ├─────────────────────────────┤   │
│   │  ▃ ▃ ▂ ▂ ▃ ▃ ▂ ▂ ▃ ▃ ▃ ▃    │   │  成交量
│   └─────────────────────────────┘   │
│                                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │  实时价格线
│  ┃ $67,234.50  +1.23% (+$823.00)   │
│                                     │
├─────────────────────────────────────┤
│  [📊 MACD 指标]  ▲                  │  底部按钮
└─────────────────────────────────────┘
```

**交易对选择器说明：**
- 使用DropdownButton显示当前交易对
- 点击展开常用交易对列表（BTCUSDT, ETHUSDT等）
- 从资费/多空页面跳转时自动设置对应symbol
- 也可手动切换查看其他交易对

### 6.2 加载状态 - 骨架屏

```dart
Widget _buildSkeleton() {
  return Column(
    children: [
      // 周期选择器骨架
      Row(children: _buildPeriodSkeletons()),
      SizedBox(height: 16),
      // K线图骨架
      Expanded(
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: _buildChartSkeleton(),
        ),
      ),
    ],
  );
}
```

### 6.3 错误状态

```dart
Widget _buildError(String message) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red),
        SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        SizedBox(height: 16),
        FilledButton.icon(
          icon: Icon(Icons.refresh),
          label: Text('重试'),
          onPressed: () => provider.refresh(),
        ),
      ],
    ),
  );
}
```

### 6.4 MACD指标底部抽屉

```dart
void _showMacdBottomSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动把手
          _buildDragHandle(),
          // MACD图表
          Expanded(
            child: MacdChartWidget(macdData: provider.macdData),
          ),
        ],
      ),
    ),
  );
}
```

## 7. 交互流程

### 7.1 首次进入K线页面

```
1. 用户在资费页面点击 "BTCUSDT"
2. Navigator.push → KlineScreen(symbol: "BTCUSDT")
3. KlineProvider.loadKlines()
   ├─ 检查数据库缓存
   ├─ 缓存未命中 → 请求币安API
   ├─ 计算技术指标 (MA, BOLL, MACD)
   └─ 更新UI显示K线图
4. 自动启动实时更新 WebSocket
```

**导航代码实现（FundingScreen）：**
```dart
// 在 funding_screen.dart 中修改 FundingRateItem 的 onTap
Widget build(BuildContext context) {
  return FundingRateItem(
    rate: rate,
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KlineScreen(symbol: rate.symbol),
        ),
      );
    },
  );
}
```

**导航代码实现（LongShortScreen）：**
```dart
// 在 long_short_screen.dart 中添加卡片点击事件
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KlineScreen(symbol: ratio.symbol),
      ),
    );
  },
  child: Card(...), // 长空比卡片
)
```

### 7.2 切换时间周期

```
1. 用户点击 "15m" 按钮
2. KlineProvider.switchInterval("15m")
   ├─ 停止当前实时更新
   ├─ 检查 "15m" 缓存
   ├─ 缓存命中 → 直接显示
   └─ 缓存未命中 → 请求API
3. 重新启动 "15m" 实时更新
```

### 7.3 实时价格更新

```
1. WebSocket 推送新K线数据
2. KlineWebSocketService 更新最后一个数据点
3. KlineProvider 更新 _currentPrice 和 _priceChange
4. UI刷新实时价格线
```

### 7.4 WebSocket生命周期管理

**连接时机：**
- K线页面加载完成且K线数据获取成功后自动连接
- 切换交易对时：断开旧连接 → 连接新交易对
- 切换周期时：断开旧连接 → 连接新周期
- 页面销毁时：在`dispose()`中断开连接

**断开时机：**
- 用户离开K线页面
- 切换交易对或周期前（先断开再重连）
- 发生连续错误（3次连接失败后停止重试）

**重连策略：**
- 复用`BinanceWebSocketManager`的自动重连机制
- 手动重连：提供"重新连接"按钮在错误状态时显示

### 7.5 错误处理策略

**API错误处理：**
```dart
try {
  final data = await BinanceApiService().getRecentKlines(...);
  // 更新UI
} on SocketException catch (_) {
  // 网络错误
  errorMessage = '网络连接失败，请检查网络设置';
} on HttpException catch (e) {
  // HTTP错误
  errorMessage = '服务器错误: ${e.message}';
} catch (e) {
  // 其他错误
  errorMessage = '加载失败: $e';
}
```

**WebSocket错误处理：**
- 连接失败：显示重试按钮，停止自动重连
- 数据格式错误：忽略该条数据，记录日志
- 连接超时：复用`BinanceWebSocketManager`的超时处理

**缓存错误处理：**
- 数据库读取失败：降级为直接请求API
- JSON解析失败：清除损坏的缓存，重新请求

**UI错误展示：**
- 首次加载失败：全屏错误页面
- 实时更新失败：顶部Toast提示，不影响已显示数据
- 分页加载失败：底部错误提示，可重试

## 8. 性能优化

### 8.1 数据分页加载

- 首次加载最近500根K线
- 用户向左滑动到图表最左侧（查看历史数据）时，触发加载更早的数据
- 触发条件：`visibleData.first.time - oldestData.time < threshold`（留出30根K线的缓冲）
- 每次追加500根，最多保留2000根（超过后删除最旧数据）
- 加载时显示底部加载指示器

### 8.2 内存管理

- 切换交易对时，清空旧数据
- 切换周期时，保留当前交易对各周期缓存
- 页面销毁时，关闭WebSocket连接

### 8.3 缓存策略

- 缓存有效期：1小时
- 自动清理：7天前的数据
- 用户可手动清理：设置页面提供"清理K线缓存"按钮

## 9. 文件结构

```
lib/
├── models/
│   ├── kline_data.dart              # K线数据模型
│   ├── kline_cache_model.dart       # 缓存数据模型
│   └── macd_data.dart               # MACD指标模型
├── services/
│   ├── binance_api_service.dart     # 扩展：添加KlineApi extension
│   ├── kline_cache_service.dart     # 缓存服务
│   ├── kline_websocket_service.dart # WebSocket服务（复用BinanceWebSocketManager）
│   └── technical_indicators.dart    # 技术指标计算
├── providers/
│   └── kline_provider.dart          # 状态管理
├── screens/
│   └── kline_screen.dart            # K线图页面
├── widgets/
│   ├── kline_chart_widget.dart      # K线图组件
│   ├── macd_chart_widget.dart       # MACD图表组件
│   ├── kline_skeleton.dart         # 加载骨架屏
│   └── interval_selector.dart       # 周期选择器
└── database/
    └── database_helper.dart         # 扩展：添加kline_cache表（v2）
```

## 10. 依赖项

**新增依赖：**
```yaml
dependencies:
  flutter_chen_kchart: ^2.0.4     # K线图库（维护中的k_chart替代）

# 以下依赖已在项目中存在，无需新增：
# - web_socket_channel: ^2.4.0   # WebSocket（已有）
# - shimmer: ^3.0.0              # 骨架屏效果（已有）
# - sqflite: ^2.3.0             # SQLite数据库（已有）
# - provider: ^6.1.1            # 状态管理（已有）
# - intl: ^0.18.1               # 国际化（已有）
# - shared_preferences: ^2.0.0  # 状态持久化（已有）

dev_dependencies:
  mockito: ^5.4.0                # 单元测试mock
  build_runner: ^2.4.0           # mockito代码生成
```

## 11. 测试策略

### 11.1 单元测试

使用Flutter内置的 `flutter_test` 和 `mockito` 进行单元测试：

- `TechnicalIndicators` - 指标计算正确性测试
  - MA计算验证（使用已知数据集验证结果）
  - BOLL带计算验证
  - MACD计算验证

- `KlineCacheService` - 缓存逻辑测试
  - 缓存读写操作
  - 过期检测逻辑
  - 数据清理逻辑

- `KlineProvider` - 状态管理测试
  - loadKlines状态转换
  - 周期切换逻辑
  - 错误处理

### 11.2 集成测试

- 完整的K线数据加载流程
- 周期切换功能
- 缓存命中/未命中场景
- WebSocket实时更新（使用mock WebSocket）

### 11.3 端到端测试

- 从资费页面跳转到K线页面
- 多空页面跳转到K线页面
- 横屏/竖屏切换
- 缓存清理功能（在ProfileScreen中添加清理按钮）

## 12. 与现有服务集成

### 12.1 避免冲突的模块隔离

K线功能与现有服务的关系：

| 现有服务 | K线功能使用方式 | 注意事项 |
|---------|----------------|---------|
| `FundingRateProvider` | 独立，不共享 | 各自管理各自状态 |
| `LongShortProvider` | 独立，不共享 | 各自管理各自状态 |
| `BinanceWebSocketManager` | 复用连接管理 | K线订阅不同topic |
| `BinanceApiService` | 通过extension扩展 | 添加getKlines方法 |
| `DatabaseHelper` | 版本升级到v2 | 添加kline_cache表 |
| `NotificationService` | 不使用 | K线功能不发送通知 |
| `PumpBackgroundService` | 不使用 | 独立的后台服务 |

### 12.2 WebSocket连接管理

- K线WebSocket订阅topic格式：`{symbol}@kline_{interval}`
- 现有WebSocket可能已订阅其他topic（如价格ticker）
- `BinanceWebSocketManager` 需支持多topic订阅：
  ```dart
  // 在KlineWebSocketService中
  void connect(String symbol, String interval) {
    final topic = '${symbol.toLowerCase()}@kline_$interval';
    _wsManager.subscribe(topic);
    // ...
  }
  ```

### 12.3 设置页面集成

在 `ProfileScreen` 中添加K线缓存管理选项：

```dart
// 在"测试功能"部分之前添加
_buildSectionHeader('数据管理'),
Card(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: ListTile(
    leading: const Icon(Icons.delete_sweep),
    title: const Text('清理K线缓存'),
    subtitle: Text('当前缓存: ${_klineCacheSize} MB'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _showClearKlineCacheDialog(),
  ),
),
```

## 13. 后续扩展

### 13.1 短期（v1.1）
- 添加画线工具（趋势线、水平线等）
- 支持多个交易对对比显示
- 添加图表截图分享功能

### 13.2 中期（v2.0）
- 添加更多技术指标（RSI、KDJ、OBV）
- 支持自定义指标参数
- 添加价格预警功能

### 13.3 长期（v3.0）
- 支持期货合约K线
- 添加订单流功能
- 提供策略回测工具

## 14. 风险和限制

### 14.1 技术风险

- **API限流**：币安API有请求频率限制，需要合理控制请求频率
- **WebSocket稳定**：网络不稳定时需要重连机制
- **数据准确性**：实时数据可能延迟，需要注明

### 14.2 性能限制

- **内存占用**：K线数据和缓存占用内存，需要限制数据量
- **电量消耗**：实时WebSocket会消耗电量，需要提供关闭选项

### 14.3 缓解措施

- 实现请求去重和限流
- WebSocket断线自动重连
- 提供关闭实时更新的开关
- 定期清理过期缓存

## 15. 版本历史

- v1.2 - 完善版：补充实现细节和错误处理
  - 修复架构图与实际设计不一致问题
  - 完善KlineCacheModel实现（添加fromDbMap/toDbMap）
  - 添加时间周期映射说明（"分时"实现方式）
  - 添加Provider注册说明
  - 添加状态持久化（shared_preferences）
  - 添加WebSocket生命周期管理章节
  - 添加错误处理策略章节
  - 更新TechnicalIndicators返回可空类型处理数据不足
  - 添加mockito和build_runner到开发依赖
- v1.1 - 修订版：修复spec reviewer反馈的问题
  - 更新依赖：使用flutter_chen_kchart替代k_chart
  - 移除不必要的socket_io_client依赖
  - 扩展BinanceApiService而非创建独立KlineService
  - 复用BinanceWebSocketManager进行WebSocket管理
  - 添加数据库迁移策略（v1→v2）
  - 添加交易对选择器到UI设计
  - 添加明确的导航代码示例
  - 添加与现有服务集成章节
  - 修复分页触发模型说明
  - 解耦KlineData与KlineDataWithIndicators
- v1.0 - 初始版本
