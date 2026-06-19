# TomApp

## What This Is

TomApp 是一款 Flutter 加密货币交易辅助应用，聚焦异常行情的实时检测与提醒——从**拉盘（pump）检测**起步，扩展到**合约快速反弹监控**。面向需要第一时间捕捉短线交易机会的交易者。

## Core Value

**在第一时间可靠地识别异常行情信号（拉盘 / V 型快速反弹）并及时提醒交易者——宁可漏报，不可误报刷屏。**

这条原则驱动所有权衡：检测引擎的阈值宁可偏严，提醒宁可分级过滤，也不能让噪声淹没真正的机会。

## Requirements

### Validated

<!-- 从现有代码库推断（详见 .planning/codebase/）。已上线、被依赖的能力。 -->

- ✓ **PUMP-01**: 实时检测拉盘（pump）行情 — 现有引擎
- ✓ **DATA-01**: Binance 行情数据接入（REST + WebSocket 实时流） — 现有
- ✓ **DATA-02**: 实时市场数据分析与展示 — 现有
- ✓ **APP-01**: Flutter 3.24 + Riverpod 应用框架与基础 UI — 现有

### Active

<!-- 本里程碑 v1.0 范围。构建中。 -->

- [ ] 反弹信号检测引擎（三阶段：下跌段 + 拉回段 + 共振过滤）
- [ ] 多周期（15m/1h/4h/日）独立监控 + 共振评分
- [ ] 反弹强度评分系统（0-100，多维加权）
- [ ] 实时看板（周期分 Tab、评分排序、WebSocket 增量计算）
- [ ] 推送提醒（信号分级、周期可独立开关）
- [ ] 回测验证（历史回放 + 参数扫描）

### Out of Scope

- **自动下单 / 策略执行** — 风险最高，先用回测验证信号有效性，再谈执行（留待后续里程碑）
- **非 Binance 交易所** — 现有基础设施仅接 Binance，多交易所留待后续
- **现货监控** — 本工作流聚焦合约（USDT 永续），现货反弹暂不纳入
- **"大周期定方向、小周期找进场"层级策略** — v1 用各周期独立 + 共振，层级策略更复杂，留待后续
- **社区/分享/跟单** — 非核心，与本监控价值无关

## Context

- **Brownfield 项目**：TomApp 已有 pump detection 引擎、Binance REST/WebSocket 接入、Flutter + Riverpod 框架。详细代码库映射见 `.planning/codebase/`（ARCHITECTURE.md / STACK.md / CONVENTIONS.md / CONCERNS.md）。
- **本工作流** `contract-quick-rebound` 新增「合约快速反弹监控」模块，**复用现有行情基础设施**，不重造轮子。
- **策略设计**：详见本里程碑 `REQUIREMENTS.md` 与 `ROADMAP.md`。核心是「下跌后快速拉回」的 V 型反弹检测，ATR 归一化、多周期共振、评分排序。
- **已知技术债/关注点**：见 `.planning/codebase/CONCERNS.md`。

## Constraints

- **Tech stack**: Flutter 3.24 / Dart 3.6 / Riverpod 状态管理 — 现有栈，必须沿用
- **架构**: 4 层 UI → Provider → Service → Data — 新模块须遵循
- **行情源**: Binance USDT 永续合约，WebSocket kline 流 — K 线收盘增量计算
- **实时性**: 信号须在 K 线收盘后尽快计算并更新看板/触发提醒
- **语言**: UI 与文档中文优先（见 CLAUDE.md）
- **标的规模**: 全市场 USDT 永续（~400+），需高效订阅/心跳管理

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 跌幅用 ATR 归一化（2×ATR(14)）而非固定 % | 跨币种波动率差异巨大，ATR 让高/低波动币用同一把尺子；% 仅作兜底 | — Pending |
| 四周期独立监控 + 共振加分 | v1 实现简单（四套同逻辑跑不同周期），共振可捕捉大级别反转 | — Pending |
| 反弹强度评分 0-100 多维加权 | 看板可排序、提醒可分级，优于二元开关 | — Pending |
| v1 不做自动下单 | 自动执行风险最高，先回测验证信号有效性 | — Pending |
| 所有阈值标为「起步值」，由回测模块校准 | 市场无完美参数；回测 + 参数扫描即校准引擎 | — Pending |
| 工作流名用 ASCII slug `contract-quick-rebound` | GSD 名称策略只接受 ASCII；中文 slug 为空会破坏路由 | ✓ Good |

## Current Milestone: v1.0 多周期合约反弹监控

**Goal:** 监控 Binance 合约，实时识别「下跌后快速拉回」的 V 型反弹信号，跨 15m/1h/4h/日 多周期，通过实时看板 + 推送提醒 + 回测验证三种形态交付。

**Target features:**
- 反弹信号检测引擎（下跌段 2×ATR + 拉回段 ≥50% 回补 + 共振过滤）
- 多周期独立监控 + 共振评分
- 实时看板（周期分 Tab、评分排序）
- 推送提醒（信号分级）
- 回测验证（历史回放 + 参数扫描）

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-19 after milestone v1.0 started*
