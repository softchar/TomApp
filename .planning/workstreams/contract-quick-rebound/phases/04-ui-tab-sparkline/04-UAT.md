---
status: testing
phase: 04-ui-tab-sparkline
source: [04-VERIFICATION.md]
started: 2026-06-19T11:00:00Z
updated: 2026-06-19T11:00:00Z
---

## Current Test

number: 1
name: 反弹看板综合 UI 验证
expected: |
  4 个周期 Tab 可切换；信号按评分降序排列；每行展示全部字段（币种/评分/跌幅/回补%/sparkline/死猫风险/止损位）；sparkline 折线图正确渲染（无轴/无网格/无边框，涨绿跌红）；死猫风险图标颜色正确；warm-up 状态条显示；底部风险提示固定可见
awaiting: user response

## Tests

### 1. 反弹看板综合 UI 验证
expected: 4 个周期 Tab 可切换；信号按评分降序排列；每行展示全部字段；sparkline 折线图正确渲染；死猫风险图标颜色正确；warm-up 状态条显示；底部风险提示固定可见
result: [pending]

### 2. MACD 图表在 fl_chart 1.2 下渲染验证
expected: 进入 KlineScreen（任意合约如 BTCUSDT，任意周期），DIF 蓝线、DEA 橙线、MACD 红绿柱状图均正常显示，无变形、无 overflow
result: [pending]
note: 用户在 04-01 checkpoint 已确认渲染正常（approved），此项已实质通过

### 3. KlineScreen 高亮标注验证
expected: 从反弹看板点击某信号行进入 KlineScreen 后，K 线图上应显示绿色半透明矩形高亮标注反弹窗口区域
result: [pending]

### 4. Warming-up 行为验证
expected: 新启动的看板顶部的 warm-up 横幅显示加载中的合约数量，且 warm-up 中的标的不出现信号行
result: [pending]

### 5. MACD 图表零回归验证
expected: 图表与升级前（fl_chart 0.65）完全一致，布局/间距/颜色/图例行均无变化
result: [pending]
note: 用户在 04-01 checkpoint 已确认渲染正常，此项已实质通过

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
