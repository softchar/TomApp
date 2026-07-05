# Phase 1: TradingView 组件集成与静态显示 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-27
**Phase:** 1-TradingView 组件集成与静态显示
**Areas discussed:** 蜡烛线固定粗细, 从左往右显示, 中文本地化, ECharts 清理策略

---

## 蜡烛线固定粗细

### 缩放时蜡烛线的粗细应该如何表现？

| Option | Description | Selected |
|--------|-------------|----------|
| 固定像素宽度 (Recommended) | 保持当前 barSpacing=8，缩放时蜡烛宽度不变（当前实现） | ✓ |
| 缩放联动但有边界 | 允许用户双指缩放时蜡烛粗细跟着变化，但有最小/最大限制 | |
| 你来决定 | — | |

**User's choice:** 固定像素宽度 (Recommended)
**Notes:** 保持固定像素宽度，不随缩放变化

### 固定宽度下，蜡烛之间的间距应该是多少像素？

| Option | Description | Selected |
|--------|-------------|----------|
| barSpacing=8（当前值） | 当前默认值，蜡烛之间有一定间距，视觉清晰 | |
| barSpacing=6（更紧凑） | 更紧凑，同屏显示更多蜡烛 | ✓ |
| barSpacing=10（更宽松） | 更宽松，每根蜡烛更清晰 | |
| 你来决定 | — | |

**User's choice:** barSpacing=6（更紧凑）
**Notes:** 选择更紧凑的布局，同屏显示更多蜡烛

### 用户手动缩放时，最小蜡烛间距应该是多少？

| Option | Description | Selected |
|--------|-------------|----------|
| minBarSpacing=2（当前值） | 当前默认值，允许用户缩放到很紧凑的程度 | ✓ |
| minBarSpacing=4（更保守） | 防止过度缩放，保持最低可读性 | |
| 你来决定 | — | |

**User's choice:** minBarSpacing=2（当前值）
**Notes:** 保持当前值，允许较紧凑的缩放

### 是否允许用户通过双指缩放改变蜡烛宽度？

| Option | Description | Selected |
|--------|-------------|----------|
| 禁用缩放改变蜡烛宽度 (Recommended) | 双指缩放时蜡烛宽度不变，只是可见范围改变 | ✓ |
| 允许缩放但有边界 | 允许缩放改变蜡烛宽度，但限制在 minBarSpacing 到 maxBarSpacing 之间 | |
| 你来决定 | — | |

**User's choice:** 禁用缩放改变蜡烛宽度 (Recommended)
**Notes:** 完全固定蜡烛宽度，缩放只影响可见范围

### 成交量柱的宽度是否跟随蜡烛图的 barSpacing 设置？

| Option | Description | Selected |
|--------|-------------|----------|
| 跟随蜡烛图设置 (Recommended) | 成交量柱宽度跟随蜡烛图的 barSpacing 设置 | ✓ |
| 独立宽度设置 | 成交量柱有自己独立的宽度设置 | |
| 你来决定 | — | |

**User's choice:** 跟随蜡烛图设置 (Recommended)
**Notes:** 成交量柱与蜡烛图保持一致的宽度

### 成交量柱应该显示在什么位置，占多大比例？

| Option | Description | Selected |
|--------|-------------|----------|
| 底部 20%（当前值）(Recommended) | 成交量在蜡烛图下方，占图表高度的 20% | |
| 底部 15%（更小） | 成交量在蜡烛图下方，占图表高度的 15% | ✓ |
| 隐藏成交量 | 不显示成交量，只显示蜡烛图 | |
| 你来决定 | — | |

**User's choice:** 底部 15%（更小）
**Notes:** 缩小成交量区域，给蜡烛图更多空间

### 成交量柱的颜色应该跟随什么规则？

| Option | Description | Selected |
|--------|-------------|----------|
| 涨红跌绿 (Recommended) | 涨红跌绿（与蜡烛颜色一致，中国习惯） | |
| 涨绿跌红 | 涨绿跌红（国际习惯，TradingView 默认） | ✓ |
| 你来决定 | — | |

**User's choice:** 涨绿跌红
**Notes:** 选择国际习惯，与蜡烛颜色（涨红跌绿）不一致

---

## 从左往右显示

### 蜡烛线的时间顺序应该如何排列？

| Option | Description | Selected |
|--------|-------------|----------|
| 从左到右（旧→新）(Recommended) | 最早的时间在左边，最新的时间在右边（符合时间顺序，ROADMAP 要求） | ✓ |
| 从右到左（新→旧） | 最新的时间在左边，最早的时间在右边（类似某些交易软件） | |
| 你来决定 | — | |

**User's choice:** 从左到右（旧→新）(Recommended)
**Notes:** 符合 ROADMAP 要求，时间顺序排列

### 初始加载时，图表应该显示哪部分数据？

| Option | Description | Selected |
|--------|-------------|----------|
| 显示最旧数据在左侧 | 打开时显示最早的数据，用户需要滚动查看最新数据 | |
| 显示最新数据在右侧 (Recommended) | 打开时显示最新的数据，用户可以向左滚动查看历史（当前行为） | ✓ |
| 你来决定 | — | |

**User's choice:** 显示最新数据在右侧 (Recommended)
**Notes:** 保留当前行为，最新数据在右侧

### 初始可见范围应该显示多少根蜡烛？

| Option | Description | Selected |
|--------|-------------|----------|
| 30 根（当前值）(Recommended) | 当前设置，显示最近 30 根蜡烛 | |
| 50 根 | 显示更多蜡烛，减少滚动 | ✓ |
| 20 根 | 显示更少蜡烛，每根更清晰 | |
| 你来决定 | — | |

**User's choice:** 50 根
**Notes:** 增加可见数量，减少滚动需求

### 图表右侧是否需要留白空间？

| Option | Description | Selected |
|--------|-------------|----------|
| 无留白（rightOffset=0）(Recommended) | 最新蜡烛紧贴右边缘，无留白 | |
| 留白 5 根蜡烛 | 右侧留几根蜡烛的空白，方便查看最新蜡烛 | ✓ |
| 你来决定 | — | |

**User's choice:** 留白 5 根蜡烛
**Notes:** 右侧留白，方便查看最新蜡烛

### 用户是否可以手动滚动查看历史数据？

| Option | Description | Selected |
|--------|-------------|----------|
| 自由滚动 (Recommended) | 用户可以自由左右滚动查看历史数据 | ✓ |
| 锁定视图 | 锁定视图，不支持滚动，只显示固定范围 | |
| 你来决定 | — | |

**User's choice:** 自由滚动 (Recommended)
**Notes:** 允许自由滚动查看历史

### 触摸图表时是否显示十字光标？

| Option | Description | Selected |
|--------|-------------|----------|
| Normal 模式 (Recommended) | 触摸时显示十字光标，方便查看具体价格和时间 | ✓ |
| 仅水平线 | 触摸时只显示水平线（价格），不显示垂直线（时间） | |
| 禁用 | 禁用十字光标 | |
| 你来决定 | — | |

**User's choice:** Normal 模式 (Recommended)
**Notes:** 显示完整的十字光标

### 当新 K 线数据到达时，视图应该如何表现？

| Option | Description | Selected |
|--------|-------------|----------|
| 自动跟随最新数据 | 新 K 线到达时，视图自动跟随最新数据（适合实时监控） | ✓ |
| 视图不动 (Recommended) | 新 K 线到达时，视图不动，用户手动滚动查看 | |
| 你来决定 | — | |

**User's choice:** 自动跟随最新数据
**Notes:** 适合实时监控场景（Phase 2 会用到）

### 用户滚动到最早数据时，左边缘应该如何处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 允许滚动到空白 | 用户可以滚动到最早数据之前，看到空白区域 | |
| 固定左边缘 (Recommended) | 最早的数据固定在左边缘，用户无法滚动超过它 | ✓ |
| 你来决定 | — | |

**User's choice:** 固定左边缘 (Recommended)
**Notes:** 固定左边缘，防止滚动到空白区域

### 用户滚动到最新数据时，右边缘应该如何处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 固定右边缘 (Recommended) | 最新数据固定在右边缘（加上 rightOffset 留白），用户无法滚动超过它 | ✓ |
| 允许滚动到空白 | 用户可以滚动到最新数据之后，看到空白区域 | |
| 你来决定 | — | |

**User's choice:** 固定右边缘 (Recommended)
**Notes:** 固定右边缘，防止滚动到空白区域

### 当窗口大小变化时，可见范围应该如何处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 锁定可见范围 (Recommended) | 窗口大小变化时，保持当前可见范围不变 | ✓ |
| 自动调整范围 | 窗口大小变化时，自动调整可见范围以显示更多数据 | |
| 你来决定 | — | |

**User's choice:** 锁定可见范围 (Recommended)
**Notes:** 保持可见范围稳定

### 时间轴上应该显示什么格式的时间？

| Option | Description | Selected |
|--------|-------------|----------|
| HH:mm（当前设置）(Recommended) | 显示 HH:mm 格式（如 14:30） | ✓ |
| MM/dd HH:mm | 显示 MM/dd HH:mm 格式（如 06/27 14:30） | |
| 完整日期时间 | 显示完整日期时间（如 2026-06-27 14:30:00） | |
| 你来决定 | — | |

**User's choice:** HH:mm（当前设置）(Recommended)
**Notes:** 保持简洁的时间格式

### 是否显示网格线？

| Option | Description | Selected |
|--------|-------------|----------|
| 显示网格线 (Recommended) | 显示浅灰色网格线，帮助对齐价格和时间 | ✓ |
| 隐藏网格线 | 不显示网格线，更简洁 | |
| 你来决定 | — | |

**User's choice:** 显示网格线 (Recommended)
**Notes:** 保留网格线，帮助对齐

---

## 中文本地化

### TradingView 图表的本地化范围应该是什么？

| Option | Description | Selected |
|--------|-------------|----------|
| 仅轴标签格式 | 只翻译时间轴和价格轴的标签格式（如日期格式） | |
| 全面本地化 (Recommended) | 翻译所有 UI 元素：按钮、提示、标签等（如果有的话） | ✓ |
| 你来决定 | — | |
| 保持英文 | 保持英文原样，不做本地化 | |

**User's choice:** 全面本地化 (Recommended)
**Notes:** 全面本地化所有 UI 元素

### 日期在图表上应该显示什么格式？

| Option | Description | Selected |
|--------|-------------|----------|
| 中文格式（6月27日）(Recommended) | 使用中文日期格式（如 6月27日 14:30） | |
| ISO 格式（06-27） | 使用 ISO 格式（如 06-27 14:30） | ✓ |
| 你来决定 | — | |

**User's choice:** ISO 格式（06-27）
**Notes:** 选择 ISO 格式，更简洁

### 价格在图表上应该显示什么格式？

| Option | Description | Selected |
|--------|-------------|----------|
| 千位分隔符 (Recommended) | 使用千位分隔符（如 1,234.56） | ✓ |
| 无分隔符 | 不使用分隔符（如 1234.56） | |
| 你来决定 | — | |

**User's choice:** 千位分隔符 (Recommended)
**Notes:** 使用千位分隔符，提高可读性

### 触摸蜡烛时显示的提示信息应该使用什么语言？

| Option | Description | Selected |
|--------|-------------|----------|
| 中文标签 (Recommended) | 显示中文标签（开: 1234.56, 高: 1240.00, 低: 1230.00, 收: 1238.00） | ✓ |
| 英文标签 | 显示英文标签（O: 1234.56, H: 1240.00, L: 1230.00, C: 1238.00） | |
| 无提示 | 不显示提示信息 | |
| 你来决定 | — | |

**User's choice:** 中文标签 (Recommended)
**Notes:** 使用中文标签，符合项目中文优先原则

---

## ECharts 清理策略

### EchartsKlineWidget 应该如何处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 完全移除 ECharts (Recommended) | 完全移除 EchartsKlineWidget 和 flutter_echarts 依赖，统一使用 TradingView | ✓ |
| 保留但不使用 | 保留 EchartsKlineWidget 作为备用，但不再使用 | |
| 保留并可切换 | 保留 EchartsKlineWidget，在某些场景下可以切换使用 | |
| 你来决定 | — | |

**User's choice:** 完全移除 ECharts (Recommended)
**Notes:** 统一使用 TradingView，移除冗余代码

### 是否从 pubspec.yaml 中移除 flutter_echarts 依赖？

| Option | Description | Selected |
|--------|-------------|----------|
| 移除依赖 (Recommended) | 从 pubspec.yaml 中移除 flutter_echarts 依赖 | ✓ |
| 保留依赖 | 保留依赖，以防将来需要 | |
| 你来决定 | — | |

**User's choice:** 移除依赖 (Recommended)
**Notes:** 清理不再使用的依赖

### webview_flutter 依赖应该如何处理？

| Option | Description | Selected |
|--------|-------------|----------|
| 保留 (Recommended) | 保留 webview_flutter，TradingView 组件需要它 | ✓ |
| 移除 WebView | 考虑使用其他方式渲染 TradingView，移除 WebView | |
| 你来决定 | — | |

**User's choice:** 保留 (Recommended)
**Notes:** TradingView 组件依赖 WebView，必须保留

---

## Claude's Discretion

- 图表背景色、蜡烛颜色等视觉细节可由 Claude 根据现有代码风格决定
- 错误处理和加载状态的具体实现方式由 Claude 决定

## Deferred Ideas

None — discussion stayed within phase scope
