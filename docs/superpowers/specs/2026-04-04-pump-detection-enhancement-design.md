# 快速上涨检测功能增强 - 设计文档

**日期**: 2026-04-04
**版本**: 1.1
**作者**: Claude
**状态**: 设计阶段

---

## 1. 概述

### 1.1 背景
当前快速上涨检测功能（Pump Detection）已经实现基础功能：WebSocket 实时监控、2% 涨幅检测、通知提醒。本设计旨在增强该功能，添加本地数据库存储、智能监控策略、数据分析和 UI 优化。

### 1.2 目标
- 实现本地数据库存储，保存历史检测记录
- 添加智能监控策略（分时段 + 自适应阈值）
- 提供数据分析功能（统计、回撤分析、图表）
- 优化 UI/UX（列表 + 详情页设计）

### 1.3 设计原则
- **渐进式增强**：在现有代码基础上逐步添加，最小化破坏性变更
- **向后兼容**：保留现有稳定功能
- **风险可控**：可逐步验证，易于回滚

---

## 2. 架构设计

### 2.1 整体架构

```
现有组件 (保留)
├── BinanceWebSocketManager    # WebSocket 连接管理
├── NotificationService        # 通知服务
└── PumpBackgroundService      # 后台服务 (HTTP轮询)

新增/修改组件
├── PumpDetector               # 增强: 添加策略模式
├── PumpStore                  # 增强: 保留作为内存缓存 (最近50条)
├── PumpRepository (新增)      # 数据库仓储
├── PumpAnalyticsService (新增) # 数据分析服务
├── PumpConfigService (新增)   # 配置管理
├── PumpHistoryModel (新增)    # 数据库实体
└── UI 层
    ├── PumpScreen (修改)      # 列表页
    └── PumpDetailScreen (新增) # 详情页
```

### 2.2 数据流

```
WebSocket/HTTP → PumpDetector → PumpStore (内存, 50条) + PumpRepository (数据库, 全量)
                                          ↓
                                    PumpAnalyticsService (异步)
                                          ↓
                                    UI 展示
```

### 2.3 组件职责

| 组件 | 职责 | 数据范围 |
|------|------|----------|
| `PumpDetector` | 价格检测，应用智能策略 | - |
| `PumpStore` | 内存缓存，快速访问 | 最近 50 条 |
| `PumpRepository` | 数据库持久化 | 全量历史 |
| `PumpAnalyticsService` | 数据分析、统计、回撤计算 | - |
| `PumpConfigService` | 配置管理，默认值 | - |
| `PumpScreen` | 列表展示，搜索筛选 | 分页加载 |
| `PumpDetailScreen` | 详情展示，图表可视化 | 单条记录 |

### 2.4 数据同步

```
应用启动
    ↓
PumpRepository → 加载最近50条 → PumpStore (内存)
    ↓
新检测到 Pump
    ↓
同时写入: PumpStore + PumpRepository
    ↓
PumpStore 保持最多50条 (FIFO 淘汰)
```

---

## 3. 数据库设计

### 3.1 PumpHistory 表

| 字段 | 类型 | 描述 | 索引 |
|------|------|------|------|
| id | INTEGER | 主键 (自增) | PK |
| symbol | TEXT | 交易对 | |
| basePrice | REAL | 基准价格 | |
| peakPrice | REAL | 峰值价格 | |
| priceChange | REAL | 涨幅百分比 | |
| triggerTime | INTEGER | 检测时间 (Unix timestamp) | IDX |
| detectedAt | TEXT | 检测日期时间 (ISO 8601) | |
| cooldownMinutes | INTEGER | 使用的冷却时间 | |
| strategyType | TEXT | 策略类型标识 | |
| subsequentLow | REAL | 后续最低价 (回撤分析) | |
| subsequentLowTime | INTEGER | 最低价时间 | |
| pullbackPercent | REAL | 回撤百分比 | |
| isConfirmed | INTEGER | 是否确认 (0=未确认, 1=已确认) | IDX |

### 3.2 索引设计

```sql
CREATE INDEX idx_symbol_time ON PumpHistory(symbol, triggerTime DESC);
CREATE INDEX idx_trigger_time ON PumpHistory(triggerTime DESC);
CREATE INDEX idx_is_confirmed ON PumpHistory(isConfirmed);
```

### 3.3 数据库版本管理

```dart
class DatabaseVersion {
  static const int currentVersion = 1;
  
  static const Map<int, String> migrations = {
    1: 'CREATE TABLE PumpHistory (...)',
    // 未来版本:
    // 2: 'ALTER TABLE PumpHistory ADD COLUMN ...',
  };
}
```

### 3.4 数据保留策略

- **活跃数据**：最近 30 天，完整保留
- **归档数据**：30-90 天，仅保留汇总统计
- **清理任务**：应用启动时执行，删除 90 天以上数据

### 3.5 PumpRepository 接口

```dart
abstract class PumpRepository {
  // 基础 CRUD
  Future<void> save(PumpHistoryModel pump);
  Future<void> saveAll(List<PumpHistoryModel> pumps);
  
  // 查询
  Future<List<PumpHistoryModel>> findAll({
    int? limit = 50,
    int? offset = 0,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
    bool? isConfirmed,
  });
  
  // 统计
  Future<PumpStatistics> getStatistics();
  Future<List<SymbolStats>> getTopSymbols(int limit);
  
  // 回撤分析
  Future<void> updatePullback(int id, double lowPrice, int lowTime);
  Future<void> markConfirmed(int id);
  
  // 维护
  Future<void> cleanOldData({int daysToKeep = 90});
  Future<int> getDatabaseSize();
}
```

### 3.6 错误降级策略

```dart
class RepositoryFactory {
  static PumpRepository create() {
    try {
      return SqlitePumpRepository();
    } catch (e) {
      log('数据库初始化失败，降级到内存模式: $e');
      return MemoryPumpRepository(); // 降级方案
    }
  }
}
```

---

## 4. 智能监控策略

### 4.1 策略架构

```
PumpDetectionStrategy (接口)
├── TimeBasedStrategy     # 分时段策略
└── AdaptiveStrategy      # 自适应策略
```

### 4.2 TimeBasedStrategy（分时段策略）

| 时段 (UTC) | 阈值调整 | 说明 |
|-----------|----------|------|
| 00:00-08:00 | +0.3% | 亚洲时段，波动较小 |
| 08:00-16:00 | -0.2% | 欧洲时段，波动增加 |
| 16:00-24:00 | -0.5% | 美洲时段，波动最大 |
| 整点前后5分钟 | -0.3% | 资金费率结算时波动大 |

### 4.3 AdaptiveStrategy（自适应策略）

**活跃度计算**：基于最近 24 小时数据

```dart
class AdaptiveStrategy {
  double calculateActivityScore(String symbol) {
    // 从数据库获取该币种最近24小时的数据
    final recent = _repository.getRecentData(symbol, hours: 24);
    
    if (recent.isEmpty) return 0.5; // 新币种默认值
    
    // 计算评分 (0.0 - 1.0)
    final detectionCount = recent.length;
    final avgChange = recent.map((e) => e.priceChange).reduce((a,b) => a+b) / detectionCount;
    final volatility = _calculateVolatility(recent);
    
    // 检测次数多 + 涨幅大 + 波动大 = 高活跃度
    final score = (
      (detectionCount / 10).clamp(0, 0.4) +
      (avgChange / 5).clamp(0, 0.3) +
      volatility.clamp(0, 0.3)
    );
    
    return score.clamp(0, 1);
  }
  
  double adjustThreshold(double baseThreshold, double activityScore) {
    // 活跃度越高，阈值越低 (更敏感)
    // 调整范围: ±0.3%
    final adjustment = (activityScore - 0.5) * 0.6;
    return baseThreshold - adjustment;
  }
}
```

### 4.4 策略组合

```dart
class PumpDetector {
  double calculateEffectiveThreshold(String symbol) {
    double threshold = _config.baseThreshold; // 默认 2.0%
    
    // 1. 分时段调整 (优先级 1)
    threshold += _timeStrategy.adjust(threshold);
    
    // 2. 自适应调整 (优先级 2)
    final activity = _adaptiveStrategy.calculateActivityScore(symbol);
    threshold = _adaptiveStrategy.adjust(threshold, activity);
    
    // 3. 确保在合理范围内
    return threshold.clamp(_config.minThreshold, _config.maxThreshold);
  }
}
```

### 4.5 配置管理

```dart
class PumpConfig {
  // 可配置参数
  double baseThreshold = 2.0;
  double minThreshold = 1.0;
  double maxThreshold = 4.0;
  
  // 数据保留
  int activeDataDays = 30;
  int archiveDataDays = 90;
  
  // 性能
  int memoryCacheSize = 50;
  int listPageSize = 50;
  
  // 回撤分析
  int pullbackMonitorMinutes = 15;
  
  // 加载/保存
  Future<void> load() async { /* 从 SharedPreferences 加载 */ }
  Future<void> save() async { /* 保存到 SharedPreferences */ }
}
```

---

## 5. 数据分析功能

### 5.1 PumpAnalyticsService

```dart
class PumpAnalyticsService {
  // 统计汇总
  Future<PumpStatistics> getStatistics();
  
  // 回撤分析 (使用 PumpBackgroundService)
  Future<void> analyzePullbacks();
  
  // 图表数据准备
  Future<ChartSeriesData> prepareChartData(String symbol);
  
  // 币种详情
  Future<SymbolDetailStats> getSymbolStats(String symbol);
}
```

### 5.2 回撤分析实现

**使用现有 PumpBackgroundService** 进行持续监控：

```dart
class PumpAnalyticsService {
  Future<void> analyzePullbacks() async {
    // 获取所有未确认的记录
    final unconfirmed = await _repository.findAll(isConfirmed: false);
    
    for (final pump in unconfirmed) {
      final age = DateTime.now().millisecondsSinceEpoch - pump.triggerTime;
      final maxAge = Duration(minutes: _config.pullbackMonitorMinutes);
      
      if (age < maxAge.inMilliseconds) {
        // 还在监控期内，获取当前价格
        final currentPrice = await _binanceApi.getCurrentPrice(pump.symbol);
        
        if (currentPrice != null) {
          final pullback = (currentPrice - pump.peakPrice) / pump.peakPrice * 100;
          
          if (pullback < (pump.pullbackPercent ?? double.infinity)) {
            // 更新最低价
            await _repository.updatePullback(
              pump.id,
              currentPrice,
              DateTime.now().millisecondsSinceEpoch,
            );
          }
        }
      } else {
        // 监控期结束，标记确认
        await _repository.markConfirmed(pump.id);
      }
    }
  }
}
```

### 5.3 定期分析任务

在 `PumpBackgroundService` 的回调中添加：

```dart
Timer.periodic(Duration(minutes: 5), (timer) async {
  await _analyticsService.analyzePullbacks();
});
```

### 5.4 统计数据结构

```dart
class PumpStatistics {
  int totalDetections;              // 总检测次数
  int uniqueSymbols;                // 涉及币种数
  double avgPriceChange;            // 平均涨幅
  double successRate;               // 确认率 (未回撤)
  List<SymbolStats> topSymbols;     // 热门币种 TOP 10
  List<HourlyCount> detectionsByHour; // 按小时统计
}

class SymbolStats {
  String symbol;
  int count;
  double avgChange;
  double maxChange;
  double successRate;               // 该币种的确认率
}

class SymbolDetailStats {
  String symbol;
  int totalDetections;
  double avgChange;
  double maxChange;
  double minChange;
  double successRate;
  List<PumpHistoryModel> recentDetections; // 最近10次
}
```

---

## 6. UI/UX 设计

### 6.1 PumpScreen（列表页）

**状态管理**：
```dart
enum PumpListStatus { initial, loading, loaded, error, empty }

class PumpListState {
  PumpListStatus status;
  List<PumpHistoryModel> pumps;
  String? errorMessage;
  bool hasMore;
  int currentPage;
}
```

**列表项展示**：
- 币种名称
- 检测时间
- 涨幅百分比（颜色：绿涨红跌）
- 回撤标记：↘下跌 | ↗上涨 | →持平
- 持续时间：从检测到现在
- 确认状态：✓已确认 | ○分析中

**功能**：
- 搜索币种
- 筛选（全部/已确认/分析中）
- 排序（时间/涨幅/回撤）
- 下拉刷新
- 上拉加载更多
- 点击进入详情

### 6.2 PumpDetailScreen（详情页）

**内容区域**：

1. **价格走势图** (使用 fl_chart)
   - 价格曲线 (检测前5分钟到检测后15分钟)
   - 检测点标记 (垂直虚线)
   - 回撤点标记 (最低点)

2. **检测信息**
   - 检测时间
   - 基准价格、峰值价格
   - 涨幅
   - 使用的策略

3. **后续走势**
   - 最低价
   - 回撤百分比
   - 当前价
   - 确认状态

4. **历史统计**（该币种）
   - 检测次数
   - 平均涨幅
   - 最大涨幅
   - 确认率

**状态处理**：
- 加载中：显示骨架屏
- 加载失败：显示错误提示和重试按钮
- 空数据：显示占位图

### 6.3 统计页面

**内容**：
- 总览卡片（总数、币种数、平均涨幅、确认率）
- 热门币种 TOP 10
- 时段分布柱状图

### 6.4 可访问性

- 图表数据点提供语音描述
- 颜色指示器配合图标 (↑↓)
- 支持大字体模式
- 高对比度模式支持

---

## 7. 性能与资源管理

### 7.1 内存管理

**PumpDetector 内存限制**：
- 每个币种最多保留 2 分钟价格历史
- 超过 200 个币种时，清理不活跃币种数据
- 使用 WeakReference 缓存活跃币种数据

**PumpStore 内存限制**：
- 最多保留 50 条记录 (FIFO)
- 使用固定容量队列

### 7.2 性能目标

| 指标 | 目标 |
|------|------|
| 检测延迟 | < 100ms |
| 列表渲染 | 60fps |
| 数据库查询 | < 200ms |
| 图表渲染 | < 500ms |
| 电池消耗 | < 2%/小时 (后台运行) |

### 7.3 电池优化

- 回撤分析仅在应用前台或充电时执行
- 后台仅保留检测功能，不执行分析
- 使用 WorkScheduler 而非 Timer 进行定期任务

---

## 8. 测试策略

### 8.1 单元测试

```dart
// 策略测试
test('TimeBasedStrategy adjusts threshold correctly', () { ... });
test('AdaptiveStrategy calculates activity score', () { ... });

// 回撤分析测试
test('Pullback calculation is accurate', () { ... });

// 数据库测试
test('Repository saves and retrieves pump', () { ... });
test('Repository cleans old data', () { ... });
```

### 8.2 集成测试

```dart
testWidgets('PumpScreen displays pumps correctly', (tester) async { ... });
test('PumpDetector detects pump correctly', () { ... });
```

### 8.3 性能测试

- 检测 100 个币种的 CPU 占用
- 1000 条数据库记录的查询性能
- 图表渲染 100 个数据点的性能

---

## 9. 实施计划

### 阶段 1：基础设施
- 创建 PumpHistory 实体和 PumpRepository
- 实现数据库初始化和迁移
- 实现 PumpConfigService

### 阶段 2：监控策略
- 实现 Strategy 模式接口
- 实现 TimeBasedStrategy
- 实现 AdaptiveStrategy
- 更新 PumpDetector

### 阶段 3：数据分析
- 实现 PumpAnalyticsService
- 实现回撤分析逻辑
- 实现统计汇总

### 阶段 4：UI/UX
- 更新 PumpScreen
- 创建 PumpDetailScreen
- 添加图表组件

### 阶段 5：测试和优化
- 单元测试
- 性能优化
- Bug 修复

---

## 附录

### A. 文件结构

```
lib/
├── models/
│   ├── pump_model.dart              # 现有
│   └── pump_history_model.dart      # 新增
├── services/
│   ├── pump_alert_service.dart      # 修改
│   ├── pump_detector.dart           # 修改
│   ├── pump_store.dart              # 修改
│   ├── pump_repository.dart         # 新增
│   ├── pump_analytics_service.dart  # 新增
│   ├── pump_config_service.dart     # 新增
│   └── strategies/
│       ├── pump_detection_strategy.dart   # 新增
│       ├── time_based_strategy.dart       # 新增
│       └── adaptive_strategy.dart        # 新增
├── providers/
│   └── pump_list_provider.dart      # 新增
└── screens/
    ├── pump_screen.dart             # 修改
    ├── pump_detail_screen.dart      # 新增
    └── pump_statistics_screen.dart  # 新增
```

### B. 数据库 SQL

```sql
-- 版本 1
CREATE TABLE PumpHistory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  symbol TEXT NOT NULL,
  basePrice REAL NOT NULL,
  peakPrice REAL NOT NULL,
  priceChange REAL NOT NULL,
  triggerTime INTEGER NOT NULL,
  detectedAt TEXT NOT NULL,
  cooldownMinutes INTEGER NOT NULL,
  strategyType TEXT NOT NULL,
  subsequentLow REAL,
  subsequentLowTime INTEGER,
  pullbackPercent REAL,
  isConfirmed INTEGER DEFAULT 0
);

CREATE INDEX idx_symbol_time ON PumpHistory(symbol, triggerTime DESC);
CREATE INDEX idx_trigger_time ON PumpHistory(triggerTime DESC);
CREATE INDEX idx_is_confirmed ON PumpHistory(isConfirmed);
```

### C. 依赖更新

```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.0
  fl_chart: ^0.65.0  # 验证支持 iOS/Android
  shared_preferences: ^2.2.0  # 配置存储
```
