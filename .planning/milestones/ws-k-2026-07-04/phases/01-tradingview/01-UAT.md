---
status: testing
phase: 01-tradingview
source: [01-01-VERIFICATION.md]
started: 2026-06-27T08:30:00Z
updated: 2026-06-27T08:30:00Z
---

## Current Test

number: 1
name: 图表渲染验证
expected: |
  TradingView K线图表正常显示，蜡烛图+成交量+下跌/回拉段标记均可见
awaiting: user response

## Tests

### 1. 图表渲染验证
expected: 运行 flutter run → 打开 ReboundTestScreen → 点击开始 → 观察图表区域。TradingView K线图表正常显示，蜡烛图+成交量+下跌/回拉段标记均可见。
result: [pending]

### 2. 中文本地化验证
expected: 触摸图表区域查看十字光标标签，观察时间轴和价格轴格式。十字光标显示中文标签（开/高/低/收），时间格式为 MM-dd HH:mm，价格带千位分隔符（如 1,234.56）。
result: [pending]

### 3. 蜡烛固定粗细验证
expected: 双指缩放图表，观察蜡烛线宽度是否变化。缩放时蜡烛宽度不变（barSpacing=6 固定），仅可见蜡烛数量变化。
result: [pending]

### 4. 数据方向验证
expected: 观察图表初始视图，确认最新K线在右侧，向左滚动查看历史。最新50根K线显示在右侧，可向左滚动查看更早数据。
result: [pending]

### 5. 成交量显示验证
expected: 观察成交量柱状图位置和颜色。成交量占图表底部约15%空间，上涨蜡烛成交量为绿色（rgba(38,166,154)），下跌为红色（rgba(239,83,80)）。
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps

None — all gaps resolved.
