# K线图代码深度审查报告

**项目**: TomApp (Flutter 加密货币交易应用)  
**审查范围**: 8 个 K 线相关文件  
**审查日期**: 2026-07-04  
**审查类型**: 深度审查（Bug/Security/Code Quality/Cross-file）+ 自动修复

---

## 概述

| 文件 | 行数 | 严重问题 | 警告 | 已修复 |
|------|------|---------|------|--------|
| `lib/models/kline_data.dart` | 126 | 1 | 1 | ✅ |
| `lib/screens/kline_screen.dart` | 386 | 1 | 1 | ✅ |
| `lib/widgets/flchart_kline_widget.dart` | 631 | 0 | 2 | ✅ |
| `lib/widgets/kline_chart_widget.dart` | 207 | 0 | 1 | ✅ |
| `lib/widgets/kline_skeleton.dart` | 79 | 0 | 1 | ✅ |
| `lib/providers/kline_provider.dart` | 406 | 1 | 2 | ✅ |
| `lib/services/kline_cache_service.dart` | 198 | 1 | 1 | ✅ |
| `lib/services/kline_websocket_service.dart` | 157 | 0 | 0 | — |

---

## 🚨 Critical 问题（已全部自动修复）

### C1. [kline_provider.dart] `_onKlineUpdate` 涨跌幅计算永远为 0%  
**严重性**: Critical — 实时 K 线更新时价格涨跌幅不更新  
**根因**: 更新同一根 K 线时，`_priceChange` 使用 `_klineData[lastIndex].close`，但该元素已被 `updatedKline` 覆盖，导致 `prevClose == data.close`，涨跌幅恒为 0%。  
**修复**: 在修改 `_klineData[lastIndex]` 之前保存 `prevClose`，并在后续计算中使用保存的值。同时增加 `prevClose != 0` 防除零保护。

```diff
+    // 保存更新前的收盘价
+    final prevClose = lastKline.close;
     ...
-    final prevClose = _klineData[lastIndex].close;
+    if (_klineData.length >= 2 && prevClose != 0) {
       _priceChange = ((data.close - prevClose) / prevClose) * 100;
     }
```

### C2. [kline_screen.dart] `_LongShortRatioWidget` 除零崩溃  
**严重性**: Critical — 当 `longAccount + shortAccount == 0` 时直接除零崩溃  
**根因**: `longAccount / total * MediaQuery.of(context).size.width` 未检查 `total == 0`。  
**修复**: 引入 `totalSafe = total > 0 ? total : 1.0`。

### C3. [kline_cache_service.dart] `getCacheSize` SQLite `SUM` 返回类型不兼容  
**严重性**: Critical — `SUM(LENGTH(data))` 返回 `num`，强制 `as int` 在特定 sqflite 版本可能崩溃  
**修复**: 分步检查 `int` / `double` / `num` 后进行安全转换。

---

## ⚠️ Warning 问题（已全部自动修复）

### W1. [kline_data.dart] `fromBinanceResponse` 类型不严格  
**根因**: `response[0] as int` — 币安 API 可能返回 double 或 string 类型的时间戳。  
**修复**: 使用 `(response[0] as num).toInt()`。

### W2. [kline_data.dart] `fromMap` 类型不严格  
**根因**: `map['time'] as int` — 数据库可能存储为 double 类型的时间戳。  
**修复**: 使用 `(map['time'] as num).toInt()`。

### W3. [kline_provider.dart] `_isSameKline` 缺少常见间隔  
**根因**: `switch` 只处理了 `1m`/`15m`/`1h`/`4h`/`1d`/`1w`，缺少 `5m`/`30m`/`2h`/`8h`/`12h`。这些间隔落在 `default` 分支（按分钟比较）可能导致同一根 K 线被误判为新 K 线。  
**修复**: 添加 5m、30m、2h、8h、12h 五个间隔的精确匹配。

### W4. [kline_provider.dart] `_startRealtime` 使用遗留 `catchError`  
**根因**: `.catchError((error) { ... })` 不接收 stackTrace，且连接失败后 `_isRealtime` 仍为 true。  
**修复**: 改用 `.onError((error, stackTrace) { ... })`，在连接失败时回退 `_isRealtime = false`。

### W5. [kline_skeleton.dart] Shimmer 颜色与深色主题不匹配  
**根因**: 使用 `Colors.grey[300]`（浅灰）和 `Colors.white` 容器，而页面背景为 `Colors.black`，加载时出现白色闪烁。  
**修复**: 改为 `Colors.grey[800]` / `Colors.grey[600]` 渐变色，容器背景 `Colors.grey[900]`。

### W6. [kline_chart_widget.dart] `_HighlightPainter.shouldRepaint` 未跟踪 klineData  
**根因**: `shouldRepaint` 只检查 `startMs` 和 `endMs`，数据变化时不会重绘。  
**修复**: 增加 `klineData.length` 和首元素 time 的对比。

### W7. [flchart_kline_widget.dart] 成交量颜色一致性风险  
**根因**: 成交量颜色使用 `k.close >= k.open ? _upColor : _downColor`，但闭市价等于开盘价时标为红色。通常平盘用灰色更合适。  
**修复**: 改为当 `close == open` 时使用灰色。

---

## 📋 未修复的问题（仅供记录）

| # | 文件 | 问题 | 建议 |
|---|------|------|------|
| 💡 | `kline_chart_widget.dart` | 整个文件是死代码 | `KlineChartWidget` 使用 `flutter_chen_kchart`，但实际渲染使用的是 `FlChartKlineWidget`。该文件未被任何源码引用，可考虑移除。 |
| 💡 | `kline_chart_widget.dart` | `_HighlightPainter` 使用硬编码 60px 左侧偏移 | `chartLeft = 60.0` 基于估算，若 `flutter_chen_kchart` 库布局变化会导致高亮偏移。当此文件为死代码时风险较低。 |
| 💡 | `kline_cache_service.dart` | 全局静默捕获所有异常 | 所有方法用 `catch (e) { }` 吞掉异常，生产环境调试困难。建议至少 debug 模式打印。 |
| 💡 | `flchart_kline_widget.dart` | Build 方法过长（~250 行） | 建议将蜡烛渲染、MA 绘制、刻度绘制拆分为独立方法。 |
| 💡 | `flchart_kline_widget.dart` | `_MaPainter.shouldRepaint` 比较列表引用 | 每次 build 新建 `ma5Vis` 列表，即使数据未变也会触发重绘。可使用 `listEquals` 深比较或缓存机制。 |
| 💡 | `kline_provider.dart` | `_calculateIndicators()` 每次实时更新都全量重算 | 500 根 K 线每 1 秒全量计算 MA/MACD/BOLL 可能成为性能瓶颈。建议增量更新或 Throttle。 |
| 💡 | `kline_provider.dart` | `switchInterval` 中 WebSocket 先连再加载数据 | 网络延迟可能导致短暂状态不一致。建议在数据加载完成后再订阅 WS。 |

---

## 📊 跨文件调用链追踪

```
KlineScreen
 ├── _TopSymbolsWidget (Consumer<MarketOverviewProvider>)
 ├── _IntervalSelectorWidget (Selector<KlineProvider, String>)
 │    └── provider.switchInterval(interval)
 │         ├── _wsService.disconnect()
 │         ├── _wsService.connect()    → KlineWebSocketService
 │         ├── _wsService.klineStream.listen(_onKlineUpdate)
 │         │    └── KlineProvider._onKlineUpdate()
 │         │         ├── _isSameKline()
 │         │         ├── _calculateIndicators() → TechnicalIndicators
 │         │         └── notifyListeners()
 │         └── _cacheService.getCached() → KlineCacheService (SQLite)
 │
 ├── _PriceInfoWidget (Selector<KlineProvider, ...>)
 │
 ├── _KlineChartWidget (Selector<KlineProvider, ...>)
 │    └── FlChartKlineWidget
 │         ├── CandlestickChart (fl_chart)
 │         ├── _MaPainter (CustomPaint)
 │         ├── _HDashPainter (CustomPaint)
 │         └── _VolumePainter (CustomPaint)
 │
 └── _LongShortRatioWidget (Consumer<LongShortProvider>)
```

## 互斥的 K 线组件

代码库中存在两套 K 线实现：

| 组件 | 位置 | 库 | 状态 |
|------|------|----|------|
| `FlChartKlineWidget`（私有包装为 `_KlineChartWidget`） | `lib/widgets/flchart_kline_widget.dart` | fl_chart | ✅ 活跃使用 |
| `KlineChartWidget` | `lib/widgets/kline_chart_widget.dart` | flutter_chen_kchart | ❌ 死代码（未导入） |

---

## 验证

修复后运行 `flutter analyze`：

```
# 针对 8 个被审查文件的诊断结果
# ❌ Errors:       0（仅在 integration_test/pump_alert_test.dart 有 2 个预存错误，非本文件范围）
# ⚠️ Warnings:     0（所有相关文件零警告）
# ℹ️ Info lints:   1（kline_provider.dart:289 字符串插值花括号样式，预存问题）
```

**结果**: ✅ 修复后所有 8 个文件通过静态分析，未引入新问题。
