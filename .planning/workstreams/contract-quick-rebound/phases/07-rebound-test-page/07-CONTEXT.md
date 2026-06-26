# Phase 07: rebound-test-page - Context

**Gathered:** 2026-06-27
**Status:** Ready for planning

<domain>
## Phase Boundary

创建一个独立的测试调试页面，用于验证反弹检测逻辑——每 5 秒自动生成模拟分时数据，实时运行 ReboundDetector，并在页面上半部分展示 K 线图、下半部分展示高评分通知。

本阶段依赖 Phase 2 的 ReboundDetector 纯函数，不涉及网络 I/O 或外部服务。所有数据为本地模拟生成，检测逻辑复用现有 `ReboundDetector.evaluate`。

</domain>

<decisions>
## Implementation Decisions

### 数据生成模式
- 默认数据模式为 `vRebound`（V 型反弹）——最能展示检测器能力
- 模式切换时清空窗口——清空历史数据重新开始
- 不支持自动循环模式——手动切换更可控

### 参数调整 UI
- 暴露 3 个关键参数：`dropAtrMultiplier`、`recoveryMinRatio`、`volumeMultiplier`
- 使用 Slider 控件——直观、实时反馈
- 参数调整后立即重新检测——拖动 Slider 时实时更新

### 信号展示与高亮
- 信号列表展示完整字段：评分徽章 + ATR 倍数 + 回补% + 死猫风险 + 共振标签 + 时间戳
- 评分徽章颜色分级：≥70 绿色、60-69 黄色、<60 红色
- K 线高亮方式：下跌段红色、拉回段绿色、正常灰色

### Claude's Discretion
- 文件路径使用 `lib/services/test/` 而非 `lib/services/rebound/`——测试工具与生产逻辑分离
- 控制栏布局为两行：第一行播放/暂停+模式+刷新，第二行参数 Slider
- 入口从 ProfileScreen 进入——与 BacktestScreen 保持一致

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ReboundDetector.evaluate` — Phase 2 纯函数，直接复用
- `ReboundParams` — 参数数据类，含 `looseForTesting` 预设
- `ReboundSignal` — 信号输出模型
- `KlineData` — K 线数据模型
- fl_chart 1.2.0 `CandlestickChart` — 已在 Phase 4 升级

### Established Patterns
- 4 层架构：UI (screens/) → Service (services/) → Data (models/)
- Provider 模式用于状态管理（ChangeNotifier）
- Navigator.push 用于页面跳转（ProfileScreen → 子页面）
- TDD 模式：先写测试再实现

### Integration Points
- `lib/screens/profile_screen.dart` — 添加入口按钮
- `lib/services/rebound/rebound_detector.dart` — 调用 evaluate
- `lib/models/rebound_params.dart` — 参数调整

</code_context>

<specifics>
## Specific Ideas

- 测试页面应支持 4 种数据模式：V 型反弹、死猫反弹、随机游走、持续下跌
- K 线图显示最近 50 根 K 线，使用 fl_chart CandlestickChart
- 信号列表仅显示 score ≥ 60 的信号，最多保留 20 条
- 控制栏支持开始/暂停、模式切换、参数调整

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
