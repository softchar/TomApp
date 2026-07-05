# Phase 1: TradingView 组件集成与静态显示 - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

在 ReboundTestScreen 中集成 TradingView K线图表组件，完成数据适配与图表显示配置。确保蜡烛线粗细固定（不随缩放变化）、从左往右按时间顺序排列、界面中文显示。

本阶段聚焦静态图表显示，不涉及实时数据流（Phase 2 范围）。现有 `TradingViewKlineWidget` 已基本可用，需要调整配置参数和清理冗余代码。

</domain>

<decisions>
## Implementation Decisions

### 蜡烛线固定粗细
- **D-01:** 固定像素宽度，禁用缩放改变蜡烛宽度（`barSpacing` 固定）
- **D-02:** `barSpacing=6`（更紧凑，同屏显示更多蜡烛）
- **D-03:** `minBarSpacing=2`（当前值，允许用户缩放到较紧凑程度）
- **D-04:** 成交量柱宽度跟随蜡烛图 `barSpacing` 设置
- **D-05:** 成交量占底部 15%（从 20% 缩小）
- **D-06:** 成交量颜色：涨绿跌红（国际习惯，非中国习惯）

### 从左往右显示
- **D-07:** 时间顺序从左到右（旧→新），符合 ROADMAP 要求
- **D-08:** 初始视图显示最新数据在右侧（用户可向左滚动查看历史）
- **D-09:** 初始可见 50 根蜡烛（从 30 根增加）
- **D-10:** 右侧留白 5 根蜡烛空间（`rightOffset=5`）
- **D-11:** 用户可自由左右滚动查看历史数据
- **D-12:** 十字光标使用 Normal 模式（触摸时显示十字线）
- **D-13:** 新 K 线到达时，视图自动跟随最新数据（`shiftVisibleRangeOnNewBar=true`）
- **D-14:** 固定左边缘（`fixLeftEdge=true`），用户无法滚动到最早数据之前
- **D-15:** 固定右边缘（`fixRightEdge=true`），用户无法滚动到最新数据之后
- **D-16:** 时间格式 HH:mm（如 14:30）
- **D-17:** 显示浅灰色网格线

### 中文本地化
- **D-18:** 全面本地化所有 UI 元素
- **D-19:** ISO 日期格式（06-27），非中文格式（6月27日）
- **D-20:** 价格使用千位分隔符（如 1,234.56）
- **D-21:** 触摸提示使用中文标签（开/高/低/收）

### ECharts 清理策略
- **D-22:** 完全移除 `EchartsKlineWidget` 组件文件
- **D-23:** 从 `pubspec.yaml` 移除 `flutter_echarts` 依赖
- **D-24:** 保留 `webview_flutter` 依赖（TradingView 组件需要）

### Claude's Discretion
- 图表背景色、蜡烛颜色等视觉细节可由 Claude 根据现有代码风格决定
- 错误处理和加载状态的具体实现方式由 Claude 决定

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 项目文档
- `.planning/workstreams/k/ROADMAP.md` — Phase 1 目标和成功标准
- `.planning/PROJECT.md` — 项目概述、技术栈、约束条件

### 现有代码
- `lib/widgets/tradingview_kline_widget.dart` — 当前 TradingView 组件实现（需修改）
- `lib/widgets/echarts_kline_widget.dart` — 当前 ECharts 组件（需删除）
- `lib/screens/rebound_test_screen.dart` — 测试页面（使用 TradingView 组件）
- `lib/models/kline_data.dart` — K 线数据模型

### 代码库分析
- `.planning/codebase/CONVENTIONS.md` — 编码规范
- `.planning/codebase/STRUCTURE.md` — 目录结构
- `.planning/codebase/STACK.md` — 技术栈

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TradingViewKlineWidget` — 已存在的 TradingView Lightweight Charts 组件，基于 WebView
- `KlineData` — K 线数据模型，包含 time/open/high/low/close/volume
- `ReboundTestScreen` — 测试页面，已集成 TradingView 组件
- `TestOrchestrator` — 测试数据编排器，提供 window 和 signals 数据

### Established Patterns
- 4 层架构：UI (screens/) → Service (services/) → Data (models/)
- Provider 模式用于状态管理（ChangeNotifier）
- WebView 渲染 TradingView Lightweight Charts 4.1.3
- 深色主题（黑色背景，灰色网格）

### Integration Points
- `ReboundTestScreen._buildCandlestickChart()` — 图表渲染入口
- `TradingViewKlineWidget._buildHtml()` — HTML/JS 构建
- `TradingViewKlineWidget._updateChart()` — 数据更新方法
- `pubspec.yaml` — 依赖管理

</code_context>

<specifics>
## Specific Ideas

- TradingView Lightweight Charts 版本 4.1.3（当前使用）
- 蜡烛颜色：涨红跌绿（中国习惯）— 注意：成交量颜色选择涨绿跌红（国际习惯），两者不一致需确认
- 图表黑色背景，与应用整体深色主题一致
- 保留现有的下跌段/拉回段高亮标记功能

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1-TradingView 组件集成与静态显示*
*Context gathered: 2026-06-27*
