---
status: partial
phase: 04-ui-tab-sparkline
source: [04-VERIFICATION.md]
started: 2026-06-19T11:00:00Z
updated: 2026-06-19T20:10:00Z
---

## Current Test

[testing paused — fix plan 04-03 已就绪，待执行后复验]
- Test 1（全市场扫描）：04-03 落地后重新验证核心 gap
- Test 3（高亮标注）、Test 4（warm-up）：04-03 落地后运行 app 一并验证

## Tests

### 1. 反弹看板综合 UI 验证
expected: 4 个周期 Tab 可切换；信号按评分降序排列；每行展示全部字段；sparkline 折线图正确渲染；死猫风险图标颜色正确；warm-up 状态条显示；底部风险提示固定可见
result: issue
reported: "不符合，我要的是你能够从全部的合约中找到反弹的合约，让不是我去添加监控。"
severity: major
note: 功能覆盖面问题（非 UI 渲染）——详见 Gaps #1

### 2. MACD 图表在 fl_chart 1.2 下渲染验证
expected: 进入 KlineScreen（任意合约如 BTCUSDT，任意周期），DIF 蓝线、DEA 橙线、MACD 红绿柱状图均正常显示，无变形、无 overflow
result: pass
note: 沿用 04-01 checkpoint 用户 approved（04-01-SUMMARY：hot reload 肉眼验证 MACD 渲染正常）；与全市场扫描无关，fl_chart 升级零回归独立成立

### 3. KlineScreen 高亮标注验证
expected: 从反弹看板点击某信号行进入 KlineScreen 后，K 线图上应显示绿色半透明矩形高亮标注反弹窗口区域
result: [pending]

### 4. Warming-up 行为验证
expected: 新启动的看板顶部的 warm-up 横幅显示加载中的合约数量，且 warm-up 中的标的不出现信号行
result: [pending]

### 5. MACD 图表零回归验证
expected: 图表与升级前（fl_chart 0.65）完全一致，布局/间距/颜色/图例行均无变化
result: pass
note: 沿用 04-01 checkpoint 用户 approved；macd_chart_widget.dart 零代码改动 + 既有测试全通过

## Summary

total: 5
passed: 2
issues: 1
pending: 2
skipped: 0
blocked: 0

## Gaps

- truth: "反弹看板从全部合约中自动扫描发现反弹候选，而非监控固定/手动添加的少量标的"
  status: failed
  reason: "User reported: 不符合，我要的是你能够从全部的合约中找到反弹的合约，让不是我去添加监控。"
  severity: major
  test: 1
  root_cause: "ReboundDashboardScreen._startAlertService 仅监控固定名单：ExchangeInfoService 返回的 USDT 永续合约经 sublist(0,50) 硬截断为字典序前 50（未按成交量/流动性排序），ExchangeInfo 不可用时 fallback 到硬编码 _defaultSymbols（20 个 BTC/ETH/…）。未实现全市场扫描覆盖。"
  artifacts:
    - path: "lib/screens/rebound_dashboard_screen.dart"
      issue: "L38-43 _defaultSymbols 硬编码 20 个；L71-90 symbols=allSymbols…sublist(0,50) 字典序截断，未按成交量排序"
  missing:
    - "明确扫描范围：全部 USDT 永续（~400+）vs 按成交量 Top N"
    - "选标按 24h 成交量/流动性排序，而非字典序前 50"
    - "WS 订阅容量规划（Phase 3 by-symbol sharding）以支撑全市场"
    - "可选：REST 定时轮询全市场扫描 vs 全量 WS 订阅的成本权衡"
  debug_session: ""
  fix_plan: "04-03-PLAN.md (commit 3676a5a) — 全市场轮询+命中精跟，plan-checker iteration 2 PASSED，3 TDD task / 8 文件"
