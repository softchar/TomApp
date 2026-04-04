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
┌──────┴────────────────┐
│    Service Layer     │
├───────────────────────┤
│ KlineService          │  API调用
│ KlineCacheService     │  数据库缓存
│ KlineWebSocketService │  实时更新
│ TechnicalIndicators    │  指标计算
└──────┬────────────────┘
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

### 3.1 KlineData - K线数据点

```dart
class KlineData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double ma5;
  final double ma10;
  final double ma20;
  final double upperBoll;
  final double lowerBoll;

  KlineData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.ma5 = 0,
    this.ma10 = 0,
    this.ma20 = 0,
    this.upperBoll = 0,
    this.lowerBoll = 0,
  });
}
```

### 3.2 KlineCacheModel - 缓存数据

```dart
class KlineCacheModel {
  final String symbol;
  final String interval;
  final List<KlineData> data;
  final DateTime cachedAt;
  final int dataSize; // 缓存大小（字节）
}
```

### 3.3 MACDData - MACD指标数据

```dart
class MACDData {
  final List<double> dif;      // DIF线 (快线)
  final List<double> dea;      // DEA线 (慢线)
  final List<double> macd;     // MACD柱状图
  final List<DateTime> time;   // 时间轴
}
```

## 4. 服务层设计

### 4.1 KlineService - API服务

**职责：**
- 从币安API获取K线数据
- 支持分页请求和拼接
- 处理API限流和错误

**核心方法：**
```dart
class KlineService {
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

### 4.3 KlineWebSocketService - 实时价格服务

**职责：**
- 连接币安WebSocket实时K线流
- 推送最新K线数据更新
- 处理连接状态和重连

**核心方法：**
```dart
class KlineWebSocketService extends ChangeNotifier {
  StreamSubscription? _subscription;

  // 连接WebSocket
  Future<void> connect(String symbol, String interval);

  // 断开连接
  Future<void> disconnect();

  // 获取K线数据流
  Stream<KlineData> get klineStream;

  // 连接状态
  WebSocketConnectionState get connectionState;
}

enum WebSocketConnectionState {
  connecting,
  connected,
  disconnected,
  error,
}
```

**WebSocket端点：**
```
wss://fstream.binance.com/ws/{symbol}@kline_{interval}
返回：实时推送K线数据
```

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
  final List<double> upper;
  final List<double> middle;
  final List<double> lower;
}
```

## 5. 状态管理

### 5.1 KlineProvider

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
}
```

## 6. UI设计

### 6.1 KlineScreen 布局

```
┌─────────────────────────────────────┐
│  ← BTCUSDT        ⚙️        📊MACD │  AppBar
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

## 8. 性能优化

### 8.1 数据分页加载

- 首次加载最近500根K线
- 用户向左滑动时，自动加载更早的数据
- 每次追加500根，最多保留2000根

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
│   ├── kline_service.dart           # 币安API服务
│   ├── kline_cache_service.dart     # 缓存服务
│   ├── kline_websocket_service.dart # WebSocket服务
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
    └── kline_cache_helper.dart      # 数据库帮助类
```

## 10. 依赖项

**新增依赖：**
```yaml
dependencies:
  k_chart: ^0.6.3                  # 专业K线图库
  socket_io_client: ^2.0.0        # Socket.IO客户端（可选）
  shimmer: ^3.0.0                 # 骨架屏效果
  intl: ^0.18.1                   # 国际化（已有）

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.0.0                 # 单元测试（可选）
```

## 11. 测试策略

### 11.1 单元测试

- `KlineService` - API调用测试
- `KlineCacheService` - 缓存逻辑测试
- `TechnicalIndicators` - 指标计算正确性测试
- `KlineProvider` - 状态管理测试

### 11.2 集成测试

- 完整的K线数据加载流程
- 周期切换功能
- 缓存命中/未命中场景
- WebSocket实时更新

### 11.3 端到端测试

- 从资费页面跳转到K线页面
- 多空页面跳转到K线页面
- 横屏/竖屏切换
- 缓存清理功能

## 12. 后续扩展

### 12.1 短期（v1.1）
- 添加画线工具（趋势线、水平线等）
- 支持多个交易对对比显示
- 添加图表截图分享功能

### 12.2 中期（v2.0）
- 添加更多技术指标（RSI、KDJ、OBV）
- 支持自定义指标参数
- 添加价格预警功能

### 12.3 长期（v3.0）
- 支持期货合约K线
- 添加订单流功能
- 提供策略回测工具

## 13. 风险和限制

### 13.1 技术风险

- **API限流**：币安API有请求频率限制，需要合理控制请求频率
- **WebSocket稳定**：网络不稳定时需要重连机制
- **数据准确性**：实时数据可能延迟，需要注明

### 13.2 性能限制

- **内存占用**：K线数据和缓存占用内存，需要限制数据量
- **电量消耗**：实时WebSocket会消耗电量，需要提供关闭选项

### 13.3 缓解措施

- 实现请求去重和限流
- WebSocket断线自动重连
- 提供关闭实时更新的开关
- 定期清理过期缓存

## 14. 版本历史

- v1.0 - 初始版本（本文档）
