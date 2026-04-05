# 首页优化设计文档

**日期:** 2026-04-05
**主题:** 首页显示优化 - 价格格式化与非交易合约过滤

## 问题背景

1. **价格显示精度不足**：当前首页价格显示 4 位小数，对于小金额币种（如 0.00000123）显示不准确
2. **首次加载显示非交易合约**：首次进入首页时，`ExchangeInfoService` 可能还未完成初始化，导致无法正确过滤不可交易的合约

## 设计方案

### 1. 智能价格格式化

根据价格大小自动选择合适的小数位数：

| 价格范围 | 小数位数 | 示例 |
|---------|---------|------|
| ≥ 1000 | 2 | `50000.12` |
| ≥ 10 | 3 | `123.456` |
| ≥ 1 | 4 | `5.6789` |
| ≥ 0.01 | 6 | `0.123456` |
| < 0.01 | 8 | `0.00000123` |

**实现位置:** `lib/screens/home_screen.dart`

新增辅助函数：
```dart
String _formatPrice(double price) {
  if (price >= 1000) return price.toStringAsFixed(2);
  if (price >= 10) return price.toStringAsFixed(3);
  if (price >= 1) return price.toStringAsFixed(4);
  if (price >= 0.01) return price.toStringAsFixed(6);
  return price.toStringAsFixed(8);
}
```

### 2. ExchangeInfo 初始化等待机制

确保 `MarketOverviewProvider` 在获取市场数据前，`ExchangeInfoService` 已完成本地缓存加载。

#### 改动点 A: `ExchangeInfoService` 添加初始化状态

**文件:** `lib/services/exchange_info_service.dart`

添加状态标志：
```dart
bool _isInitialized = false;
bool get isInitialized => _isInitialized;
```

在 `_loadFromStorage()` 完成后设置为 `true`。

#### 改动点 B: `MarketOverviewProvider` 等待初始化

**文件:** `lib/providers/market_overview_provider.dart`

修改 `fetchMarketOverview()` 方法，在获取数据前检查 `ExchangeInfoService` 是否已初始化：
```dart
final exchangeInfo = ExchangeInfoService.instance;
if (!exchangeInfo.isInitialized) {
  // 等待初始化完成（最多 2 秒）
  await _waitForInitialization(exchangeInfo);
}
```

## 数据流

```
App 启动
    ↓
ExchangeInfoService._internal()
    ↓
_loadFromStorage() [异步] → isInitialized = true
    ↓
MarketOverviewProvider 构造
    ↓
检查 isInitialized → 若 false 则等待
    ↓
fetchMarketOverview() → 正确过滤非交易合约
```

## 影响范围

- `lib/screens/home_screen.dart` - 添加价格格式化函数，修改显示逻辑
- `lib/services/exchange_info_service.dart` - 添加 isInitialized 状态
- `lib/providers/market_overview_provider.dart` - 添加初始化等待逻辑

## 测试要点

1. 验证不同价格范围的币种显示正确的小数位数
2. 验证首次启动首页不显示非交易合约
3. 验证缓存存在时加载速度正常
