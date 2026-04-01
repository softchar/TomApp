# 快速上涨警报功能设计文档

**日期:** 2026-04-01
**状态:** 设计阶段
**作者:** Claude + softchar

## 概述

为 TomApp 添加快速上涨警报功能，实时监控币安永续合约，当合约在 1 分钟内涨幅超过 2% 时，记录并通过系统通知用户。

## 需求

| 需求项 | 说明 |
|--------|------|
| 触发条件 | 1 分钟内涨幅超过 2% |
| 记录数量 | 保留最近 50 条记录 |
| 通知频率 | 同一合约 1 分钟内最多通知 1 次 |
| 显示信息 | 合约名称、涨幅、触发时间、当前价格 |
| 检测方式 | 实时监控（WebSocket） |
| 页面入口 | 首页 |

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                     App (Main)                          │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Home Screen │  │   Pump      │  │ Settings    │     │
│  │             │  │   Screen    │  │             │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │  PumpAlertService     │
              │  (单例)               │
              └───────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ WebSocket    │  │ Pump         │  │ Notification │
│ Manager      │  │ Store        │  │ Service      │
│ (Binance)    │  │ (50条记录)   │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

## 组件设计

### BinanceWebSocketManager

管理币安期货 WebSocket 连接。

**职责:**
- 连接到 `wss://fstream.binance.com/ws`
- 订阅 `!ticker@arr` 频道（所有 USDT 合约 ticker）
- 处理连接、断线重连、心跳检测
- 流式输出解析后的 Ticker 数据

**关键方法:**
```dart
class BinanceWebSocketManager {
  Stream<Ticker> get tickerStream;
  Future<void> connect();
  Future<void> disconnect();
  ConnectionState get connectionState;
}
```

### PumpDetector

检测快速上涨并管理通知冷却。

**职责:**
- 维护每个合约的价格历史（用于计算 1 分钟涨幅）
- 判断是否满足触发条件（涨幅 > 2%）
- 跟踪通知冷却时间（1 分钟内只通知一次）

**关键方法:**
```dart
class PumpDetector {
  PumpDetectResult? detect(Ticker ticker);
  void resetCoolDown(String symbol);
}
```

**数据结构:**
```dart
class PriceHistory {
  final String symbol;
  final List<PricePoint> points; // 保留最近 2 分钟的数据点

  double calculate1MinChange();
}

class PricePoint {
  final double price;
  final DateTime timestamp;
}
```

### PumpAlertService

协调整个检测流程的核心服务。

**职责:**
- 整合 WebSocket 和 Detector
- 当检测到快速上涨时：
  1. 创建 PumpModel
  2. 存入 PumpStore
  3. 触发系统通知
- 管理服务生命周期（启动/停止）

**关键方法:**
```dart
class PumpAlertService {
  static PumpAlertService get instance;
  Future<void> start();
  Future<void> stop();
  bool get isRunning;
}
```

### PumpModel

快速上涨记录的数据模型。

```dart
class PumpModel {
  final String symbol;        // 合约名称，如 "BTCUSDT"
  final double priceChange;   // 涨幅百分比，如 3.5
  final DateTime triggerTime; // 触发时间
  final double currentPrice;  // 当前价格

  PumpModel({
    required this.symbol,
    required this.priceChange,
    required this.triggerTime,
    required this.currentPrice,
  });
}
```

### PumpStore

存储检测到的快速上涨记录。

**职责:**
- 使用 Provider 管理状态
- 自动维护最多 50 条记录（FIFO）
- 通知 UI 更新

```dart
class PumpStore extends ChangeNotifier {
  final List<PumpModel> _pumps = [];

  List<PumpModel> get pumps => List.unmodifiable(_pumps);

  void addPump(PumpModel pump) {
    _pumps.add(pump);
    if (_pumps.length > 50) {
      _pumps.removeAt(0);
    }
    notifyListeners();
  }

  void clear();
}
```

## 数据流

```
┌─────────────────────────────────────────────────────────────────────┐
│                           WebSocket 数据流                           │
└─────────────────────────────────────────────────────────────────────┘

币安 WebSocket → BinanceWebSocketManager
                      │
                      ▼
              解析 Ticker 数据
                      │
                      ▼
              PumpDetector.detect()
                      │
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
    涨幅 <= 2%            涨幅 > 2% 且未冷却
          │                       │
          │                       ▼
          │              ┌─────────────────┐
          │              │ 创建 PumpModel  │
          │              └─────────────────┘
          │                       │
          └───────────────────────┼────────────┐
                                  ▼            ▼
                          PumpStore.add()  发送通知
                                  │
                                  ▼
                          UI 自动更新
```

## 错误处理

### WebSocket 断线

```
断线检测 → 等待 5 秒 → 重连 → 重新订阅
     │
     ▼
  失败？
     │
     ▼
  指数退避（5s, 10s, 20s, 最多 60s）
```

### 数据异常处理

| 异常类型 | 处理方式 |
|----------|----------|
| ticker 数据缺失字段 | 忽略该条数据 |
| 价格为 0 或负数 | 忽略 |
| 涨幅计算异常 | 记录日志，继续处理下一个 |

### 通知发送失败

| 异常类型 | 处理方式 |
|----------|----------|
| 权限被拒绝 | 记录日志，下次启动时重新请求权限 |
| 系统限制 | 静默失败，不影响数据记录 |

### 用户可见状态

- 连接状态显示在快速上涨页面顶部（已连接/已断开/重连中）
- 断线期间停止检测，重连成功后恢复

## UI 设计

### 首页变更

在首页添加快速上涨入口和摘要卡片：

```
┌─────────────────────────────────────┐
│         TomApp 首页                 │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 资金费率监控                  │   │
│  │ ...                          │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🚀 快速上涨                   │   │
│  │ 今日检测到 3 个               │   │
│  │ [查看详情 →]                 │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

### 快速上涨页面

```
┌─────────────────────────────────────┐
│  ← 快速上涨              ● 已连接   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ BTCUSDT                      │   │
│  │ +3.5%  •  10:23:45          │   │
│  │ 当前价格: $67,234.50         │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ ETHUSDT                      │   │
│  │ +2.3%  •  10:22:10          │   │
│  │ 当前价格: $3,456.78          │   │
│  └─────────────────────────────┘   │
│                                     │
│  ... (最多 50 条)                   │
│                                     │
└─────────────────────────────────────┘
```

## 测试策略

### 单元测试

| 组件 | 测试内容 |
|------|----------|
| `PumpDetector` | 涨幅计算、冷却时间判断、边界条件 |
| `PumpModel` | 序列化/反序列化 |
| `BinanceWebSocketManager` | 连接、订阅、重连逻辑 |
| `PumpStore` | 添加记录、自动清理、通知 |

### 集成测试

- WebSocket 接收真实币安数据
- 检测 → 存储 → 通知 完整流程
- UI 列表正确显示数据

### 手动测试场景

| 场景 | 预期结果 |
|------|----------|
| 正常触发快速上涨 | 收到通知，记录出现在列表 |
| 同一合约连续触发 | 1 分钟内只通知 1 次 |
| WebSocket 断线重连 | 显示重连状态，恢复后继续检测 |
| 通知权限被拒绝 | 记录正常保存，通知失败 |
| 50 条记录后 | 自动清理最旧的记录 |

## 依赖

需要添加的包：

```yaml
dependencies:
  web_socket_channel: ^2.4.0  # WebSocket 支持
```

现有的 `flutter_local_notifications` 包已支持系统通知。

## 实施步骤

1. 添加 `web_socket_channel` 依赖
2. 实现 `BinanceWebSocketManager`
3. 实现 `PumpDetector`
4. 实现 `PumpModel` 和 `PumpStore`
5. 实现 `PumpAlertService`
6. 创建快速上涨页面 UI
7. 更新首页添加入口
8. 编写单元测试
9. 集成测试
10. 手动测试验证
