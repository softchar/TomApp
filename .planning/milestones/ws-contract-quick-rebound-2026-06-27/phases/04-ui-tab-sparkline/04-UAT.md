---
status: testing
phase: 04-ui-tab-sparkline
source: [04-03-SUMMARY.md, 04-VERIFICATION.md]
started: 2026-06-20T13:00:00Z
updated: 2026-06-20T13:00:00Z
note: 04-03 范围调整后重写（去周期 Tab 单页 + 全市场扫描 + 最近反弹 + 日志面板 + 行内标签 + 字段说明）。原 04-02 的 4-Tab Gap #1（全市场扫描）已由 04-03 修复。
---

## Current Test
[testing complete — 7/7 passed, 2026-06-20]

## Tests

### 1. 全市场扫描覆盖
expected: 反弹看板从全部 ~400 USDT 永续合约自动扫描发现反弹候选（非固定名单前 50）。日志面板显示「命中 2xx 标的」，信号列表含非 BTC/ETH 的小币。
result: pass

### 2. 15m 单页看板 + 行内字段标签
expected: 看板无周期 Tab，单页 15m 信号列表；每行数值下方有小灰字标签（评分/跌幅/回补/死猫/止损）。
result: pass

### 3. 最近反弹过滤（recentBars=6）
expected: 只显示最近 6 根 K 线（1.5h）内结束的反弹。日志「写入 N 信号」反映最近反弹数（非历史窗口全部 263）。
result: pass

### 4. 调试日志面板
expected: 看板底部日志面板实时显示扫描/精跟事件（「扫描器已启动」「第 N 轮完成 命中 X 写入 Y」「精跟 +N」），右上角可清空。
result: pass

### 5. 字段说明对话框
expected: AppBar 右上角❓按钮 → 弹出字段说明（评分/跌幅×ATR/回补%/死猫风险/止损位的含义与算法）。
result: pass

### 6. KlineScreen 高亮标注
expected: 点击信号行进入 KlineScreen，K 线图显示绿色半透明矩形高亮标注反弹窗口区域。
result: pass

### 7. warm-up 行为
expected: 新启动看板顶部 warm-up 横幅显示加载中合约数，warm-up 中无信号行；完成后合约进入信号列表。
result: pass

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
