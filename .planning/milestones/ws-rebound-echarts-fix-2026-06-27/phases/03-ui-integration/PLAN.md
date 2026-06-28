# Phase 03: 测试页面 UI 整合

## 目标
将 ECharts K 线图和修复后的检测逻辑整合到反弹检测测试页面，优化 UI 体验。

## 执行计划

### Step 1: 替换 K 线图组件
- 将 `_buildCandlestickChart()` 中的 `fl_chart` CandlestickChart 替换为 ECharts 版本
- 保留涨跌幅标签、数据计数标签等 overlay

### Step 2: 添加下跌/回拉段高亮
- 在 ECharts K 线图上用半透明矩形标注下跌段（红色）和回拉段（绿色）
- 与 `KlineChartWidget` 的 `_HighlightPainter` 逻辑一致

### Step 3: 增加参数控制
- 添加 dropMaxCandles Slider（默认 5）
- 添加 RSI 周期 Slider（默认 14，可调 7-21）
- 添加 recoveryMaxCandles Slider（默认 2）

### Step 4: 信号列表优化
- 点击信号时，K 线图自动滚动到对应位置并高亮
- 显示检测到的下跌段和回拉段范围

### Step 5: 调试信息面板
- 添加可折叠的调试面板，显示：
  - 当前 swingLow 索引和价格
  - 当前 ATR 值
  - RSI 值（标准 + 快速）
  - 各共振过滤器的判定结果

## 验收标准
- [ ] ECharts K 线图正常渲染
- [ ] 下跌/回拉段高亮标注正确
- [ ] 所有参数 Slider 正常工作
- [ ] 信号点击跳转到对应 K 线位置
- [ ] 调试面板显示正确信息
