# Phase 06: 回测验证 — Discussion Log

**Date:** 2026-06-20
**Mode:** Claude 自主决策（用户授权 AI 基于大数据分析自主选择所有灰度区域）

## Discussion Summary

Phase 6 回测验证阶段的讨论采用自主决策模式——基于 PITFALLS.md（13 条深度风险分析）、ROADMAP.md 成功标准、REQUIREMENTS.md 的 BACKTEST-01 至 BACKTEST-07，以及 Freqtrade 等行业最佳实践，对全部实现灰度区域做出决策。

## Decisions by Area

### 进场时点（Entry Timing）

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 回测进场时点 | signal-close vs next-open | **next-open** | PITFALLS.md Pitfall 1 强烈建议；Freqtrade 等行业标准；ROADMAP 开放问题 #3 倾向 |

**决策内容 (D-01):** 信号在 bar[t].close 收盘后触发，模拟交易在 bar[t+1].open 进场。禁止 signal-close 同根进场（会产生 lookahead bias）。

### 出场规则（Exit Rules）

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 止损方式 | 固定 vs 移动 | **固定止损** swing-low−0.3×ATR | BACKTEST-03 已定义；v1 反弹短线策略，移动止损复杂度收益比不高 |
| 止盈方式 | 单目标 vs 双目标 | **双止盈** 61.8%+100% Fib | BACKTEST-03 已定义；Fib 回撤是反弹策略自然止盈位 |
| 超时退出 | 是 vs 否 | **是** 20 bars (15m=5h) | 避免持仓无限期挂起 |
| 资金费率 | 扣 vs 不扣 | **扣** 历史实际 funding rate | PITFALLS.md Pitfall 4 明确要求 |
| 成本模型 | 零成本 vs 含成本 | **双曲线同屏** | PITFALLS.md Pitfall 4 最低底线 |

### 数据导入与标的池（Data Import & Universe）

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 数据源 | data.binance.vision | **月度 ZIP + REST gap-fill** | BACKTEST-01 已定义 |
| 标的池 | 全市场 vs Top-100 | **Top-100 流动性币种** | PITFALLS.md Pitfall 2 务实折中 |
| Point-in-time universe | 做 vs 不做 | **v1 不做**，声明限制 | v1 成本过高，v2 再做 |
| 历史数据范围 | 可变 | **默认 6 个月** | 用户可调起止日期 |

### Walk-Forward 切片

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 折叠策略 | anchored vs rolling | **3-fold anchored** | PITFALLS.md Pitfall 3 要求 walk-forward |
| 报告内容 | in-sample + out-of-sample | **仅 out-of-sample** | PITFALLS.md Pitfall 3 明确禁止报 in-sample |

### 参数扫描范围

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 扫描参数 | 权重 vs 阈值 vs 全扫 | **仅 4 个阈值** | ROADMAP + PITFALLS.md Pitfall 10（权重不进扫描） |
| 网格大小 | 细 vs 粗 | **320 组合 (4×5×4×4)** | v1 数据量下可行 |

### 回测引擎架构

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 引擎模式 | event-driven vs 向量化 | **Event-driven 逐 bar** | PITFALLS.md 技术债表标向量化为"永不可接受" |
| 数据读取 | 文件 vs drift DB | **drift Klines 表** | Phase 1 已建表，D-16 |
| Lookahead 检测 | 做 vs 不做 | **必须做** close→next open | PITFALLS.md Pitfall 1 "最强检测手段" |

### 回测报告 UI

| 问题 | 选项 | 选择 | 依据 |
|------|------|------|------|
| 展示位置 | 新页面 vs 嵌入看板 | **独立 BacktestScreen** | 回测是独立工作流，非实时监控 |
| 下钻能力 | 有 vs 无 | **复用 KlineScreen** | 既有组件直接复用 |
| 免责声明 | 有 vs 无 | **固定显示** | BACKTEST-07 + PITFALLS.md Pitfall 13 |

### Claude's Discretion（agent 自主决策）

- 数据导入管线下载解压的具体实现细节
- 权益曲线绘图库选择
- BacktestScreen 入口位置（新 Tab vs ProfileScreen 按钮）
- Walk-forward 可配置性（v1 硬编码）
- 参数扫描网格可配置性（v1 硬编码）

## Deferred Ideas

| 想法 | 原因 |
|------|------|
| 完整参数扫描增强 | v2 SCAN-01 |
| Point-in-time universe | v2，v1 Top-100 声明限制 |
| 移动止损 | v2，与层级策略一起 |
| 多币并发仓位管理 | v2，与自动下单一起 |
| 参数扫描并行化 | v2，Isolate |
| 回测结果导出 CSV/PDF | v2 |
| 参数网格可配置化 | v2 |
| Walk-forward 折叠可配置化 | v2 |

---

*Discussion log: 2026-06-20*
*Mode: Claude autonomous decision-making*
