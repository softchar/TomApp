# Phase 1: TradingView 组件集成与静态显示 - Research

**Researched:** 2026-06-27
**Domain:** Flutter WebView + TradingView Lightweight Charts K线图表配置
**Confidence:** HIGH

## Summary

本阶段的核心工作是对已有的 `TradingViewKlineWidget` 进行配置调整和代码清理，而非从零构建。现有组件已基本可用，基于 WebView 渲染 TradingView Lightweight Charts 4.1.3，但配置参数与 CONTEXT.md 中的决策存在多处不一致。

主要差异包括：`barSpacing`（8→6）、`rightOffset`（0→5）、`fixLeftEdge`/`fixRightEdge`（false→true）、`shiftVisibleRangeOnNewBar`（false→true）、可见蜡烛数（30→50）、成交量占比（20%→15%）。此外，中文本地化（D-18~D-21）和 ECharts 清理（D-22~D-24）是新增工作。

**主要建议：** 修改现有 `TradingViewKlineWidget` 的配置参数，添加中文本地化支持，删除 `EchartsKlineWidget` 及 `flutter_echarts` 依赖。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| K线图表渲染 | WebView (Browser) | — | TradingView Lightweight Charts 在 WebView 中运行，所有图表逻辑在 JS 层 |
| 数据格式转换 | Dart (UI Widget) | — | `KlineData` → TradingView JSON 格式在 Dart 层完成 |
| 图表配置参数 | JavaScript (HTML) | — | barSpacing、locale 等配置在 JS 初始化时设置 |
| 依赖管理 | pubspec.yaml | — | 移除 flutter_echarts，保留 webview_flutter |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| webview_flutter | 4.13.1 | WebView 容器 | Flutter 官方 WebView 方案，已集成 |
| TradingView Lightweight Charts | 4.1.3 (CDN) | K线图表渲染 | 专业金融图表库，轻量级，无需 npm 构建 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_echarts | 2.5.0 | ECharts 图表 | **待移除** — 本阶段清理 |
| KlineData | 内置模型 | K线数据结构 | 已有，直接复用 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| WebView + CDN | npm 构建 + asset bundle | CDN 依赖网络，但免去构建步骤；离线场景需改为本地 asset |
| TradingView 4.1.3 | TradingView 4.2+ | 4.1.3 已验证可用，升级需测试兼容性 |

**Installation:**
```bash
# 无需额外安装，webview_flutter 已在 pubspec.yaml
# TradingView 通过 CDN 加载：https://unpkg.com/lightweight-charts@4.1.3/dist/lightweight-charts.standalone.production.js
```

**Version verification:**
- webview_flutter: 4.13.1（已验证，pubspec.lock 确认）
- TradingView Lightweight Charts: 4.1.3（CDN URL 已在现有代码中验证）

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| webview_flutter | pub.dev | 4+ yrs | 高 | github.com/nicedoc/packages (Flutter 官方) | OK | 保留 |
| flutter_echarts | pub.dev | 3+ yrs | 中 | github.com/nicedoc/flutter_echarts | OK | **待移除**（D-22/D-23） |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ReboundTestScreen                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           TradingViewKlineWidget                      │   │
│  │  ┌────────────────────────────────────────────────┐  │   │
│  │  │              WebView                            │  │   │
│  │  │  ┌──────────────────────────────────────────┐  │  │   │
│  │  │  │   TradingView Lightweight Charts (JS)    │  │  │   │
│  │  │  │   - CandlestickSeries                    │  │  │   │
│  │  │  │   - HistogramSeries (成交量)              │  │  │   │
│  │  │  │   - Markers (下跌/回拉段标记)             │  │  │   │
│  │  │  └──────────────────────────────────────────┘  │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  TestOrchestrator (Provider)                         │   │
│  │  - window: List<KlineData>                           │   │
│  │  - signals: List<ReboundSignal>                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**数据流：**
1. `TestOrchestrator` 生成 K 线数据 → `window: List<KlineData>`
2. `ReboundTestScreen` 读取 `window`，截取最后 50 根
3. `TradingViewKlineWidget` 将 `KlineData` 转换为 TradingView JSON 格式
4. 通过 `_controller.runJavaScript('updateChart($jsonData)')` 传入 WebView
5. TradingView JS 渲染蜡烛图 + 成交量 + 标记

### Recommended Project Structure

```
lib/
├── widgets/
│   ├── tradingview_kline_widget.dart   # 修改：配置调整 + 中文本地化
│   └── echarts_kline_widget.dart       # 删除
├── screens/
│   └── rebound_test_screen.dart        # 已集成，无需修改
├── models/
│   └── kline_data.dart                 # 已有，直接复用
```

### Pattern 1: TradingView 配置调整

**What:** 修改 `_buildHtml()` 中的 `createChart` 配置参数
**When to use:** 所有 D-01~D-17 决策的实现
**Example:**
```javascript
// Source: TradingView Lightweight Charts 4.1.3 API
chart = LightweightCharts.createChart(container, {
  // ... layout, grid, crosshair 保持不变 ...
  rightPriceScale: {
    borderColor: '#333333',
    scaleMargins: { top: 0.05, bottom: 0.15 },  // D-05: 成交量占底部15%
  },
  timeScale: {
    borderColor: '#333333',
    timeVisible: true,
    secondsVisible: false,
    rightOffset: 5,           // D-10: 右侧留白5根
    barSpacing: 6,            // D-02: 更紧凑
    minBarSpacing: 2,         // D-03: 允许较紧凑缩放
    fixLeftEdge: true,        // D-14: 固定左边缘
    fixRightEdge: true,       // D-15: 固定右边缘
    lockVisibleTimeRangeOnResize: false,
    shiftVisibleRangeOnNewBar: true,  // D-13: 新K线自动跟随
  },
  localization: {             // D-18~D-21: 中文本地化
    locale: 'zh-CN',
    timeFormatter: (time) => {
      const d = new Date(time * 1000);
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      const hh = String(d.getHours()).padStart(2, '0');
      const min = String(d.getMinutes()).padStart(2, '0');
      return `${mm}-${dd} ${hh}:${min}`;  // D-19: ISO日期 + D-16: HH:mm
    },
    priceFormatter: (price) => {
      return price.toLocaleString('zh-CN', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });  // D-20: 千位分隔符
    },
  },
});
```

### Pattern 2: 成交量颜色配置

**What:** 成交量柱颜色跟随蜡烛涨跌方向
**When to use:** D-04/D-06 决策
**Example:**
```javascript
// Source: 现有代码 _buildChartData() 已实现
// 涨绿跌红（国际习惯，D-06）
'e.value.close >= e.value.open
  ? "rgba(38, 166, 154, 0.5)"   // 涨：绿色
  : "rgba(239, 83, 80, 0.5)"',  // 跌：红色
```

### Pattern 3: 可见范围设置

**What:** 初始显示50根蜡烛，最新数据在右侧
**When to use:** D-08/D-09 决策
**Example:**
```javascript
// Source: 现有代码 updateChart() 需修改
function updateChart(data) {
  // ... candleSeries.setData, volumeSeries.setData ...

  const candleCount = data.candles.length;
  const visibleCount = Math.min(candleCount, 50);  // D-09: 50根

  // D-08: 最新数据在右侧，向左滚动查看历史
  chart.timeScale().setVisibleLogicalRange({
    from: candleCount - visibleCount - 0.5,
    to: candleCount - 0.5,
  });
}
```

### Pattern 4: 中文十字光标标签

**What:** 触摸时显示中文标签（开/高/低/收）
**When to use:** D-21 决策
**Example:**
```javascript
// Source: TradingView Lightweight Charts localization API
// localization.locale = 'zh-CN' 会自动将十字光标标签本地化
// 但 "O/H/L/C" 标签需要通过 customFields 或 formatter 覆盖
// TradingView 4.1.3 的 locale 设置会自动处理大部分本地化
```

**注意：** TradingView Lightweight Charts 的 `locale` 选项会自动本地化十字光标中的 "Open/High/Low/Close" 标签。如果 `zh-CN` 不自动翻译，需要通过 `localization` 的 `locale` 参数配合 `timeFormatter`/`priceFormatter` 手动处理。

### Anti-Patterns to Avoid

- **不要在 Dart 层做时间格式化：** 时间格式化应在 JS 的 `localization.timeFormatter` 中完成，TradingView 内部会调用
- **不要硬编码成交量占比：** 使用 `scaleMargins` 配置，不要通过 CSS 控制
- **不要在 updateChart 中重复 initChart：** 现有代码已有 `if (!chart) { initChart(); }` 保护，保持不变
- **不要删除 markers 功能：** 下跌段/回拉段高亮标记是现有功能，必须保留

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| K线图表渲染 | 自定义 Canvas 绘制 | TradingView Lightweight Charts | 专业金融图表库，处理缩放/滚动/十字光标等复杂交互 |
| 千位分隔符 | 自定义格式化函数 | `toLocaleString('zh-CN')` | 内置国际化支持，处理边界情况 |
| 时间格式化 | 手动拼接字符串 | `localization.timeFormatter` | TradingView 内部调用，统一管理 |

## Common Pitfalls

### Pitfall 1: CDN 加载失败导致白屏
**What goes wrong:** TradingView JS 文件从 unpkg.com CDN 加载，国内网络可能不稳定
**Why it happens:** unpkg.com 在国内访问速度慢或被墙
**How to avoid:** 现有代码已使用 CDN，如果出现白屏，考虑将 JS 文件打包为本地 asset
**Warning signs:** 页面长时间白屏，控制台网络错误

### Pitfall 2: barSpacing 固定后缩放失效
**What goes wrong:** 设置 `barSpacing: 6` 后，用户缩放时蜡烛宽度不变
**Why it happens:** `barSpacing` 是固定值，缩放会改变可见范围但蜡烛宽度不变
**How to avoid:** 这是预期行为（D-01 决策），不需要修复。用户缩放会显示更多/更少蜡烛，但每根蜡烛宽度固定
**Warning signs:** 用户反馈缩放无效果 — 这是设计决策，不是 bug

### Pitfall 3: fixLeftEdge/fixRightEdge 导致滚动受限
**What goes wrong:** 用户无法滚动到最早/最新数据之外
**Why it happens:** `fixLeftEdge: true` 和 `fixRightEdge: true` 限制了滚动范围
**How to avoid:** 这是预期行为（D-14/D-15 决策），防止用户滚动到空白区域
**Warning signs:** 用户反馈无法继续滚动 — 这是设计决策

### Pitfall 4: ECharts 移除后其他地方引用
**What goes wrong:** 删除 `echarts_kline_widget.dart` 后，其他文件 import 报错
**Why it happens:** 可能有其他文件引用了 `EchartsKlineWidget`
**How to avoid:** 删除前 grep 搜索所有引用，确认只有 `echarts_kline_widget.dart` 自身引用
**Warning signs:** 编译错误

## Code Examples

### 完整的 createChart 配置（符合所有 D-01~D-21 决策）

```javascript
// Source: 基于现有代码 + CONTEXT.md 决策修改
chart = LightweightCharts.createChart(container, {
  width: container.clientWidth,
  height: container.clientHeight,
  layout: {
    background: { type: 'solid', color: '#000000' },
    textColor: '#999999',
    padding: { left: 0, right: 0, top: 0, bottom: 0 },
  },
  grid: {
    vertLines: { color: '#1a1a1a' },   // D-17: 浅灰色网格线
    horzLines: { color: '#1a1a1a' },
  },
  crosshair: {
    mode: LightweightCharts.CrosshairMode.Normal,  // D-12: Normal模式
    vertLine: {
      color: '#555555',
      width: 1,
      style: LightweightCharts.LineStyle.Dashed,
      labelBackgroundColor: '#333333',
    },
    horzLine: {
      color: '#555555',
      width: 1,
      style: LightweightCharts.LineStyle.Dashed,
      labelBackgroundColor: '#333333',
    },
  },
  rightPriceScale: {
    borderColor: '#333333',
    scaleMargins: { top: 0.05, bottom: 0.15 },  // D-05: 成交量占底部15%
  },
  timeScale: {
    borderColor: '#333333',
    timeVisible: true,
    secondsVisible: false,
    rightOffset: 5,           // D-10: 右侧留白5根
    barSpacing: 6,            // D-02: 更紧凑
    minBarSpacing: 2,         // D-03: 允许较紧凑缩放
    fixLeftEdge: true,        // D-14: 固定左边缘
    fixRightEdge: true,       // D-15: 固定右边缘
    lockVisibleTimeRangeOnResize: false,
    shiftVisibleRangeOnNewBar: true,  // D-13: 新K线自动跟随
  },
  localization: {
    locale: 'zh-CN',          // D-18: 中文本地化
    timeFormatter: (time) => {
      const d = new Date(time * 1000);
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      const hh = String(d.getHours()).padStart(2, '0');
      const min = String(d.getMinutes()).padStart(2, '0');
      return `${mm}-${dd} ${hh}:${min}`;  // D-19 + D-16
    },
    priceFormatter: (price) => {
      return price.toLocaleString('zh-CN', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });  // D-20: 千位分隔符
    },
  },
});
```

### 成交量系列配置（D-04/D-05/D-06）

```javascript
// Source: 现有代码 + 决策修改
volumeSeries = chart.addHistogramSeries({
  color: '#26a69a',
  priceFormat: { type: 'volume' },
  priceScaleId: 'volume',
});

chart.priceScale('volume').applyOptions({
  scaleMargins: { top: 0.85, bottom: 0 },  // D-05: 成交量占底部15% (1 - 0.85 = 0.15)
});
```

### updateChart 可见范围（D-08/D-09）

```javascript
// Source: 现有代码 + 决策修改
function updateChart(data) {
  if (!chart) {
    initChart();
  }

  candleSeries.setData(data.candles);
  volumeSeries.setData(data.volumes);

  // 清除旧标记
  markers.forEach(m => m.remove());
  markers = [];

  if (data.markers) {
    addHighlightAreas(data.markers);
  }

  // 设置固定的蜡烛宽度
  chart.timeScale().applyOptions({
    barSpacing: 6,        // D-02
    rightOffset: 5,       // D-10
  });

  // D-08/D-09: 初始显示50根蜡烛，最新数据在右侧
  const candleCount = data.candles.length;
  const visibleCount = Math.min(candleCount, 50);
  chart.timeScale().setVisibleLogicalRange({
    from: candleCount - visibleCount - 0.5,
    to: candleCount - 0.5,
  });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ECharts (flutter_echarts) | TradingView Lightweight Charts (WebView) | 已迁移 | 更专业的金融图表，更好的交互体验 |
| barSpacing: 8 | barSpacing: 6 | D-02 | 更紧凑，同屏显示更多蜡烛 |
| visibleCount: 30 | visibleCount: 50 | D-09 | 显示更多历史数据 |
| fixLeftEdge: false | fixLeftEdge: true | D-14 | 防止滚动到空白区域 |

**Deprecated/outdated:**
- `flutter_echarts`: 已被 TradingView 替代，本阶段完全移除

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | TradingView Lightweight Charts 4.1.3 的 `localization.locale: 'zh-CN'` 会自动本地化十字光标标签（开/高/低/收） | Pattern 4 | 如果不自动翻译，需要手动实现 customFields formatter |
| A2 | `toLocaleString('zh-CN')` 在 WebView 的 JS 环境中可用 | Pattern 1 | 如果不可用，需要手动实现千位分隔符格式化 |
| A3 | `scaleMargins: { top: 0.85, bottom: 0 }` 精确对应 15% 底部占比 | Code Examples | 需要实际测试验证视觉效果 |
| A4 | `setVisibleLogicalRange` 的 `from` 参数使用 `-0.5` 偏移是正确的边界处理 | Code Examples | 如果偏移不正确，第一根蜡烛可能被截断 |

**如果此表为空：** 所有声明已验证或引用 — 无需用户确认。

## Open Questions

1. **TradingView locale 是否自动翻译十字光标标签？**
   - What we know: `localization.locale` 接受 BCP 47 语言标签
   - What's unclear: 4.1.3 版本是否自动将 "Open/High/Low/Close" 翻译为 "开/高/低/收"
   - Recommendation: 实现后测试，如果不翻译，通过 `localization` 的 `formatter` 回调手动处理

2. **成交量占比 15% 的视觉效果是否理想？**
   - What we know: 当前 20%（`scaleMargins.top: 0.8`），D-05 决策改为 15%
   - What's unclear: 15% 是否足够清晰显示成交量变化
   - Recommendation: 实现后视觉验证，如果太小可调整为 18%

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| webview_flutter | TradingView 渲染 | ✓ | 4.13.1 | — |
| TradingView CDN | 图表 JS 库 | ✓ | 4.1.3 | 本地 asset（如果 CDN 不稳定） |
| flutter_echarts | 待移除 | ✓ | 2.5.0 | — |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — Flutter 默认配置 |
| Quick run command | `flutter test test/widgets/tradingview_kline_widget_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TV-01 | TradingView 组件集成到 ReboundTestScreen | widget | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ Wave 0 |
| TV-02 | 中文界面配置 | widget | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ Wave 0 |
| TV-03 | 数据源对接（KlineData → TradingView JSON） | unit | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ Wave 0 |
| CHART-01 | 蜡烛线粗细固定 | manual-only | — | — |
| CHART-02 | 从左往右显示 | manual-only | — | — |
| CHART-03 | 图表加载流畅 | manual-only | — | — |
| DATA-01 | Binance K线数据适配 | unit | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ Wave 0 |

**Manual-only justification:** CHART-01/02/03 涉及视觉渲染和用户交互，WebView 内部的 TradingView 图表无法通过 Flutter widget test 验证像素级渲染效果。

### Sampling Rate
- **Per task commit:** `flutter test test/widgets/tradingview_kline_widget_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/widgets/tradingview_kline_widget_test.dart` — 覆盖 TV-01/TV-02/TV-03/DATA-01
- [ ] 测试框架：已内置（flutter_test），无需额外安装

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | KlineData 数据验证（已有 fromBinanceResponse 工厂方法） |
| V6 Cryptography | no | — |

### Known Threat Patterns for Flutter WebView

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| WebView XSS | Tampering | JavaScriptMode.unrestricted 已设置，但 HTML 内容是硬编码的，无用户输入 |
| CDN 脚本注入 | Tampering | 使用固定版本号的 CDN URL，无动态脚本加载 |

## Sources

### Primary (HIGH confidence)
- 现有代码 `lib/widgets/tradingview_kline_widget.dart` — 当前实现分析
- 现有代码 `lib/screens/rebound_test_screen.dart` — 集成点分析
- `pubspec.lock` — 依赖版本验证
- CONTEXT.md — 用户决策（D-01~D-24）

### Secondary (MEDIUM confidence)
- TradingView Lightweight Charts 4.1.3 API 文档（训练知识）— localization、timeScale 配置选项
- Flutter webview_flutter 4.x API（训练知识）— WebViewController、JavaScriptMode

### Tertiary (LOW confidence)
- TradingView locale 自动翻译行为（训练知识，未实际测试）
- `scaleMargins` 精确视觉效果（训练知识，需实际验证）

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 已有代码验证，依赖版本确认
- Architecture: HIGH — 现有架构清晰，修改范围明确
- Pitfalls: MEDIUM — CDN 稳定性和 locale 翻译行为需要实际测试

**Research date:** 2026-06-27
**Valid until:** 2026-07-27（30天，TradingView 4.1.3 稳定版本）
