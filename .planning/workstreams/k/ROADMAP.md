---
workstream: k
milestone: v1.1
title: K线图表优化
created: 2026-06-27
---

# Roadmap: v1.1 K线图表优化

## Goal

采用 TradingView 组件替换现有 ECharts，优化测试页面的K线图表显示，提升用户体验。

## Phases

- [ ] **Phase 1: TradingView 组件集成与静态显示** - 集成 TradingView 组件，完成数据适配与图表显示配置
- [ ] **Phase 2: 实时数据流与多周期支持** - 接入 WebSocket 实时更新，支持多周期切换

## Phase Details

### Phase 1: TradingView 组件集成与静态显示
**Goal**: 用户可以在 ReboundTestScreen 中看到正确渲染的 TradingView K线图表，蜡烛线显示符合预期
**Depends on**: Nothing
**Requirements**: TV-01, TV-02, TV-03, CHART-01, CHART-02, CHART-03, DATA-01
**Success Criteria** (what must be TRUE):
  1. 用户打开 ReboundTestScreen 时能看到 TradingView K线图表正常渲染
  2. 图表界面为中文显示（按钮、标签、提示均为中文）
  3. 蜡烛线粗细在缩放时保持固定不变
  4. 蜡烛线从左往右按时间顺序排列显示
  5. 图表加载流畅，无明显卡顿或白屏
**Plans**: TBD

### Phase 2: 实时数据流与多周期支持
**Goal**: 图表可以实时更新数据，用户可以在不同时间周期间自由切换
**Depends on**: Phase 1
**Requirements**: DATA-02, DATA-03
**Success Criteria** (what must be TRUE):
  1. 新 K线数据通过 WebSocket 到达时，图表自动更新显示
  2. 用户切换周期（15m/1h/4h/日）时，图表重新加载对应周期数据并正确显示
  3. 实时更新过程中图表无闪烁、无数据丢失
**Plans**: TBD

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. TradingView 组件集成与静态显示 | 0/0 | Not started | - |
| 2. 实时数据流与多周期支持 | 0/0 | Not started | - |
