# 快速上涨检测功能增强 - 设计文档

**日期**: 2025-04-04
**版本**: 1.0
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
├── PumpStore                  # 增强: 保留作为内存缓存
├── PumpRepository (新增)      # 数据库仓储
├── PumpAnalyticsService (新增) # 数据分析服务
├── PumpHistoryModel (新增)    # 数据库实体
└── UI 层
    ├── PumpScreen (修改)      # 列表页
    └── PumpDetailScreen (新增) # 详情页
```

### 2.2 数据流

```
WebSocket/HTTP → PumpDetector → PumpStore (内存) + PumpRepository (数据库)
                                          ↓
                                    PumpAnalyticsService
                                          ↓
                                    UI 展示
```

### 2.3 组件职责

| 组件 | 职责 |
|------|------|
| `PumpDetector` | 价格检测，应用智能策略 |
| `PumpStore` | 内存缓存，快速访问 |
| `PumpRepository` | 数据库持久化 |
| `PumpAnalyticsService` | 数据分析、统计、回撤计算 |
| `PumpScreen` | 列表展示，搜索筛选 |
| `PumpDetailScreen` | 详情展示，图表可视化 |

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

### 3.3 PumpRepository 接口

```dart
abstract class PumpRepository {
  Future<void> save(PumpHistoryModel pump);
  Future<void> saveAll(List<PumpHistoryModel> pumps);

  Future<List<PumpHistoryModel>> findAll({
    int? limit,
    int? offset,
    String? symbol,
    DateTime? startTime,
    DateTime? endTime,
  });

  Future<PumpStatistics> getStatistics();
  Future<void> updatePullback(int id, double lowPrice, int lowTime);
  Future<void> markConfirmed(int id);
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

根据币种历史波动率动态调整阈值：

```dart
class AdaptiveStrategy {
  // 计算币种活跃度评分
  double calculateActivityScore(String symbol);

  // 根据活跃度调整阈值
  double adjustThreshold(double baseThreshold, double activityScore);
}
```

### 4.4 策略组合

```dart
class PumpDetector {
  double calculateEffectiveThreshold(String symbol) {
    double threshold = 2.0; // 基础阈值
    threshold += _timeStrategy.adjust(threshold);
    final activity = _adaptiveStrategy.getActivity(symbol);
    threshold = _adaptiveStrategy.adjust(threshold, activity);
    return threshold;
  }
}
```

---

## 5. 数据分析功能

### 5.1 PumpAnalyticsService

```dart
class PumpAnalyticsService {
  // 统计汇总
  Future<PumpStatistics> getStatistics();

  // 回撤分析
  Future<void> analyzePullbacks();

  // 图表数据准备
  Future<ChartSeriesData> prepareChartData(String symbol);
}
```

### 5.2 统计数据结构

```dart
class PumpStatistics {
  int totalDetections;              // 总检测次数
  int uniqueSymbols;                // 涉及币种数
  double avgPriceChange;            // 平均涨幅
  List<SymbolStats> topSymbols;     // 热门币种 TOP 10
  List<HourlyCount> detectionsByHour; // 按小时统计
}
```

### 5.3 回撤分析流程

```
检测到 Pump → 记录峰值价格
             ↓
      持续监控价格 (15分钟)
             ↓
      记录最低价和回撤百分比
             ↓
      更新数据库 (subsequentLow, pullbackPercent)
```

---

## 6. UI/UX 设计

### 6.1 PumpScreen（列表页）

列表项展示：
- 币种名称
- 检测时间
- 涨幅百分比（颜色：绿涨红跌）
- 回撤标记：↘下跌 | ↗上涨 | →持平
- 持续时间：从检测到现在
- 确认状态：✓已确认 | ○分析中

功能：
- 搜索币种
- 筛选（已确认/分析中）
- 排序（时间/涨幅/回撤）
- 下拉刷新
- 点击进入详情

### 6.2 PumpDetailScreen（详情页）

内容区域：
1. **价格走势图**
   - 价格曲线
   - 检测点标记
   - 回撤点标记

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

### 6.3 统计页面

内容：
- 总览卡片（总数、币种数、平均涨幅、确认率）
- 热门币种 TOP 10
- 时段分布柱状图

---

## 7. 实现注意事项

### 7.1 性能优化

- 列表分页加载（每页 50 条）
- 图表数据缓存（5 分钟）
- 回撤分析异步执行

### 7.2 错误处理

- 网络失败不影响本地数据展示
- 数据库错误降级到内存模式

### 7.3 依赖更新

```yaml
dependencies:
  sqflite: ^2.3.0
  path: ^1.8.0
  fl_chart: ^0.66.0
```

---

## 8. 实施计划

### 阶段 1：基础设施
- 创建 PumpHistory 实体和 PumpRepository
- 实现数据库初始化和迁移

### 阶段 2：监控策略
- 实现 Strategy 模式
- 添加 TimeBasedStrategy 和 AdaptiveStrategy
- 更新 PumpDetector

### 阶段 3：数据分析
- 实现 PumpAnalyticsService
- 实现回撤分析逻辑
- 实现统计汇总

### 阶段 4：UI/UX
- 更新 PumpScreen（添加回撤显示、筛选）
- 创建 PumpDetailScreen（详情页）
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
│   └── strategies/
│       ├── pump_detection_strategy.dart   # 新增
│       ├── time_based_strategy.dart       # 新增
│       └── adaptive_strategy.dart        # 新增
└── screens/
    ├── pump_screen.dart             # 修改
    ├── pump_detail_screen.dart      # 新增
    └── pump_statistics_screen.dart  # 新增
```

### B. 数据库 SQL

```sql
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
