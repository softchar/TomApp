# Milestone v1.1 Requirements: K线图表优化

## Overview

采用 TradingView 组件替换现有 ECharts，优化测试页面的K线图表显示，提升用户体验。

## Requirements

### TradingView 集成

- [ ] **TV-01**: 集成 TradingView K线图表组件到 ReboundTestScreen
- [ ] **TV-02**: 配置 TradingView 组件支持中文界面
- [ ] **TV-03**: 实现 TradingView 组件与现有数据源的对接

### 图表显示优化

- [ ] **CHART-01**: 蜡烛线粗细固定，不随缩放动态调整
- [ ] **CHART-02**: 从左往右显示蜡烛（符合时间顺序）
- [ ] **CHART-03**: 优化图表加载性能，确保流畅显示

### 数据集成

- [ ] **DATA-01**: 将现有 Binance K线数据适配到 TradingView 格式
- [ ] **DATA-02**: 实现实时数据更新（WebSocket 集成）
- [ ] **DATA-03**: 支持多周期数据切换（15m/1h/4h/日）

## Future Requirements

- 技术指标（MA、MACD等）
- 图表交互优化（缩放、拖拽）
- 成交量显示

## Out of Scope

- **自动下单/策略执行** — 本里程碑仅优化显示
- **非 Binance 交易所** — 仅支持现有数据源
- **移动端原生 TradingView SDK** — 使用 Web 版本集成

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TV-01 | Phase 1 | Pending |
| TV-02 | Phase 1 | Pending |
| TV-03 | Phase 1 | Pending |
| CHART-01 | Phase 1 | Pending |
| CHART-02 | Phase 1 | Pending |
| CHART-03 | Phase 1 | Pending |
| DATA-01 | Phase 1 | Pending |
| DATA-02 | Phase 2 | Pending |
| DATA-03 | Phase 2 | Pending |
