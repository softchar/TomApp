# Feature Research

**Domain:** 加密货币合约交易信号 — V 型快速反弹（quick rebound）监控模块
**Researched:** 2026-06-19
**Confidence:** HIGH（领域知识成熟，PROJECT.md 已确立核心策略决策）

> 上下文：本模块为 **subsequent milestone**，复用 TomApp 现有 Binance REST/WebSocket 行情基础设施、PumpDetector 架构（Strategy 模式）、Riverpod + 4 层架构。下文每条均标注对现有能力的依赖。
> 现有可复用能力（**不重复研究**）：`BinanceApiService`（REST klines/`fapi`）、`WebSocketManager`（kline 流）、`PumpRepository`（SQLite + Memory fallback）、`technical_indicators.dart`（MA/EMA/MACD/BOLL，但**不含 RSI/ATR，需新增**）、`FavoriteService`、`flutter_local_notifications`、`flutter_background_service`。

---

## 领域核心：V 型反弹 vs 死猫反弹（#1 假信号风险）

任何反弹监控的产品价值都取决于能否区分「真反弹」与「下跌中继（dead-cat bounce）」。这是模块的**最高风险**，所有 table-stakes 特性都围绕它展开。

### 交易者如何定义「V 型快速反弹」

成熟定义包含**三段**（与 PROJECT.md 中「下跌段 + 拉回段 + 共振过滤」一致）：

1. **下跌段（Leg Down）**
   - 在 N 根 K 线内出现急跌。**必须用波动率归一化**——固定 % 阈值在高波动币（如 meme 永续）会天天触发、低波动币永远不触发。PROJECT.md 已决策：**跌幅 ≥ 2×ATR(14)**（起步值），% 仅兜底。
   - 下跌斜率/速度是隐含维度：3 根 K 线跌 2×ATR（恐慌）远强于 10 根 K 线跌 2×ATR（阴跌）。

2. **拉回段（Leg Up / Recovery）**
   - 从低点反弹幅度 / 下跌幅度的**回补率（recovery ratio）**。PROJECT.md 起步阈值 **≥50% 回补**。
   - 速度维度：在 M 根 K 线内完成回补（典型 1–3 根 K 线 = V 型；>10 根 = U 型/横盘，不算快反弹）。

3. **共振过滤（Confluence Filters）**——决定「真反弹 vs 死猫」
   - **RSI 超卖回归**：RSI(14) 从 <30 区回到 >40/50，是经典真反弹确认。
   - **成交量确认**：拉回段成交量 > 下跌段均量（量价齐升=真反弹；缩量反弹=死猫，典型中继信号）。
   - **关键支撑**：低点位于前期结构支撑 / 整数关口 / 成交密集区。
   - **Fibonacci 回撤**：拉回突破 38.2% 阈值=弱反弹（易演变为死猫），突破 50%/61.8% = 强反弹。**38.2% 之下未回补 50% 是死猫 bounce 的经典形态**。

### 死猫反弹（dead-cat bounce / continuation-down）的判别信号

模块必须**显式**对每个候选打一个「假反弹风险」维度，否则刷屏误报（违反 PROJECT.md「宁可漏报不可误报」原则）：

| 真反弹信号 | 死猫反弹信号（高危） |
|---|---|
| 拉回**放量**（量比 >1.2×下跌段均量） | 拉回**缩量**（量比 <0.8×） |
| 突破 Fib 50%/61.8% | 卡在 Fib 38.2% 下方 |
| RSI 从 <30 回到 >50 | RSI 卡在 40–50（弱势区） |
| 大周期（4h/1d）同步出现企稳 | 大周期仍处明确下降趋势 |
| 反弹后未创新低 | 反弹后**再创新低**（最重要的滞后确认） |

> **设计含义**：检测引擎输出必须是**多维结构**（recovery_ratio / speed / volume_ratio / rsi_state / fib_level / mtf_confluence），而非二元 bool。这正是评分系统（见下）的输入。

---

## Feature Landscape

### Table Stakes（用户默认期望，缺失=产品残缺）

| Feature | Why Expected | Complexity | 依赖 / Notes |
|---------|--------------|------------|-------|
| **下跌段检测（ATR 归一化）** | 没有下跌就没有反弹；波动率归一化是跨币种公平的唯一方式 | MEDIUM | 复用 `BinanceApiService.getKlines`；**需新增 ATR(14) 指标**（现有 `technical_indicators.dart` 仅有 MA/EMA/MACD/BOLL）。低复用成本。 |
| **拉回段检测（≥50% 回补 + 速度窗）** | 回补率是「反弹」的最小定义 | MEDIUM | 纯计算，无外部依赖。需定义「速度窗」（如 N 根 K 线内回补）。 |
| **RSI 超卖过滤** | RSI 是反弹检测的事实标准；不带 RSI 的反弹信号在交易者眼中不可信 | LOW | **需新增 RSI 指标**。增量计算（参考现有 MACD 增量实现）。 |
| **成交量确认** | 量价是区分真假反弹的第一维度 | LOW | kline 已含 volume 字段，WebSocket 流已推送。 |
| **Fibonacci 回撤水平** | 38.2/50/61.8% 是反弹强度的通用语言 | LOW | 从下跌段高低点计算，无外部依赖。 |
| **四周期独立监控（15m/1h/4h/1d）** | 用户期望按持有周期看不同信号；15m=日内、1h=短线、4h=波段、1d=中线 | HIGH | **关键架构决策**：需 4 个并行 kline 订阅（每周期一个）。现有 `WebSocketManager` 仅 2 并发连接（ticker+kline），**需扩展为多流复用**（Binance 单连接可订阅多 symbol/stream，是规模化必经之路）。 |
| **多周期共振评分（加分项）** | 同一币种多周期同步=大级别反转，是 v1 核心差异化 | MEDIUM | 依赖上一条。聚合层从 4 周期实例汇总。 |
| **反弹强度评分 0–100（多维加权）** | 用户要排序、提醒要分级，二元信号无法支撑 | MEDIUM | 输入=上述检测引擎所有维度；输出=单分。权重起步值，回测校准。 |
| **实时看板（周期 Tab + 评分排序）** | 这是模块的主交付面；用户打开 app 第一眼 | MEDIUM | 新 `ReboundDashboardScreen` + `ReboundListProvider`（仿 `PumpListProvider`）。复用 fl_chart 做 mini sparkline。 |
| **K 线收盘增量计算** | 实时性约束（PROJECT.md）：收盘后立即出信号 | MEDIUM | 监听 WebSocket kline `k.x==true`（isClosed）事件触发计算，非每 tick 重算（避免 CONCERNS.md 已记录的「技术指标每 tick 重算」性能债）。 |
| **基础推送提醒（信号分级 + 每周期开关）** | 「监控」类产品的核心价值就是「不用盯着看」 | MEDIUM | 复用 `flutter_local_notifications` + `flutter_background_service`。新增分级（强/中/弱）+ 每周期独立 toggle。 |
| **提醒去重（同币种同周期冷却窗）** | 不去重=刷屏=用户卸载。PROJECT.md 明确「不可误报刷屏」 | LOW | 简单状态：`symbol+timeframe → lastNotifiedAt`，冷却窗（如 15m 周期内不重复推同币）。 |
| **回测：历史回放（给定时间段复现信号）** | 没有回测的信号引擎在交易者眼中=玩具；PROJECT.md 把回测当「阈值校准引擎」 | HIGH | 需历史 kline 拉取（`BinanceApiService` 已支持）、回放调度器、信号记录。**最大单项工作**。 |
| **回测：绩效指标（胜率 / 平均 R / 盈亏比 / 最大回撤）** | 交易者只认这四个数；只给胜率=误导（高胜率可能每笔小赚一次大亏） | MEDIUM | 必须同时展示四项 + 样本数 N（避免小样本错觉）。 |

### Differentiators（差异化，非必需但有价值）

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **死猫反弹显式标记 / 风险分** | 多数同类工具只报「反弹」，不区分真假——这是 PROJECT.md「宁可漏报不可误报」的硬兑现 | MEDIUM | 评分中独立维度；看板用图标/颜色标记「疑似死猫」。 |
| **参数扫描（parameter sweep）回测** | 「阈值标为起步值，由回测校准」——让用户自己对 2×ATR / 50% 回补扫参，找最优组合 | HIGH | 网格搜索 + 结果热力图。v1 可只做小网格。 |
| **共振加分视觉化（4 周期雷达/网格）** | 一眼看出某币在几个周期同时触发=强信号 | MEDIUM | 4 格小卡片，亮起=触发。fl_chart 自定义绘制。 |
| **迷你 sparkline + 标注 V 型低点** | 看板列表项内嵌走势图，比纯文字快 10 倍理解 | LOW | fl_chart LineChart，标 entry/low 点。 |
| **信号历史持久化（SQLite）+ 复盘** | 「这个信号后来涨了还是跌了」——闭环验证，提升用户信任 | MEDIUM | 新表 + 复用 `PumpRepository` 模式。v1 可只存不展示复盘，v1.x 加复盘页。 |
| **持仓周期建议映射**（15m→分钟级、1d→日级） | 帮新手把「周期」翻译成「拿多久」 | LOW | 静态映射表 + UI 文案。 |
| **安静时段（quiet hours）** | 夜间免打扰；同类交易 app 的标配 | LOW | 设置页加时间窗。 |
| **ATR 自适应阈值（非固定 2×）** | 不同波动率 regime 用不同倍数；高级但与 PROJECT.md「起步值由回测校准」契合 | MEDIUM | v1.x：按 ATR 分位数动态调倍数。 |
| **进场/止损参考价（基于 Fib/低点）** | 不只是报信号，还给可执行价位（非自动下单，符合 Out of Scope） | LOW | 拉回未破 Fib 61.8% → 进场=现价，止损=低点下方。纯展示。 |

### Anti-Features（看似好但应排除，含警告）

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **自动下单 / 策略执行** | 「既然检测到就帮我买」 | PROJECT.md 已 Explicit Out of Scope。风险最高：假信号直接亏钱；未经回测验证的信号不该碰真钱；合约杠杆放大错误。 | 先用回测验证信号有效性（本里程碑范围）；执行留待后续里程碑。 |
| **「大周期定方向、小周期找进场」层级策略** | 进阶交易者想要 | PROJECT.md 已 Explicit Out of Scope。实现复杂度高（周期依赖耦合）、参数空间爆炸、回测更难。v1 用「独立 + 共振」已能覆盖大部分场景。 | v1 各周期独立监控 + 共振加分；层级策略留待后续。 |
| **现货监控** | 「现货也有反弹」 | PROJECT.md 已 Explicit Out of Scope。现有基础设施仅合约；混入现货=双数据源、双测试、双维护。 | 本工作流仅 USDT 永续；现货反弹后续里程碑。 |
| **非 Binance 交易所** | 「OKX/Bybit 也有」 | PROJECT.md 已 Explicit Out of Scope。多交易所=多套 API/WS 协议、符号映射、限频差异。 | 现有基础设施仅 Binance。 |
| **只展示胜率（不展示 R/回撤/样本数）** | 简单直观 | **致命误导**：胜率 80% 可能是「8 次赚 1%、2 次亏 10%」=负期望。监管与交易社区共识：必须同时披露 R 多分布与回撤。 | 必须四指标 + 样本数 N 同屏展示；小样本（N<30）显式警告。 |
| **每 tick 实时重算所有信号** | 「越实时越好」 | CONCERNS.md 已记录现有技术指标每 tick 重算的性能债；400+ 标的 × 4 周期 × 每 tick = 卡死 + 耗电。PROJECT.md 明确「K 线收盘后计算」。 | 仅 kline `isClosed=true` 触发计算。 |
| **AI/ML 预测反弹概率** | 「用模型更准」 | 训练数据/标注成本高、可解释性差（交易者不信黑盒）、模型漂移、移动端推理成本。v1 用规则引擎可解释、可回测、可调参。 | 规则引擎先行；ML 留待有足够标注信号历史后（v2+）。 |
| **社区分享 / 跟单** | 「看别人怎么交易」 | 非核心（PROJECT.md Out of Scope），与监控价值无关，且引入合规/责任风险。 | 不做。 |
| **「保证盈利」措辞 / 单一最优参数推荐** | 营销话术 | 加密市场无圣杯；任何「最优」都是过拟合。回测模块必须明确标注「过去表现不代表未来」。 | 回测结果附免责声明；参数扫描展示分布而非单一推荐。 |
| **全市场 400+ 标的 全周期 1-tick 深度监控** | 「不想漏」 | 移动端内存/电池/网络承载不起（CONCERNS.md：现仅 ~200 symbol、2 WS 连接）。 | 分层：默认订阅用户自选 + 热门 Top N；全市场扫描降频轮询。 |

---

## Feature Dependencies

```
[ATR 指标实现]                       (新增, 依赖 technical_indicators.dart)
    └──requires──> [下跌段检测]
                       └──requires──> [拉回段检测（回补率+速度）]
                                          └──requires──> [RSI 指标实现] (新增)
                                                          └── + [成交量] + [Fib] (低耦合)
                                                                      │
                                                                      ▼
                                                          [反弹评分引擎 0–100]
                                                                      │
                            ┌─────────────────────────────────────────┼───────────────────────────┐
                            ▼                                         ▼                           ▼
                  [四周期独立监控]                          [死猫风险分]                   [信号历史持久化]
                            │                                         │                           │
                            ▼                                         │                           ▼
                  [多周期共振评分] ──────────────────────────────────┼────────────────> [回测：历史回放]
                            │                                         │                           │
                            ▼                                         ▼                           ▼
                  [实时看板（周期 Tab+评分排序+sparkline）]    [推送提醒（分级+去重+周期开关+quiet hours）]   [回测：绩效指标(胜率/R/盈亏比/回撤)]
                                                                                                    │
                                                                                                    ▼
                                                                                          [参数扫描] (v1.x)

[WebSocket 多流复用扩展] ──enables──> [四周期独立监控]（4 周期并行订阅前提）
[PumpRepository 模式]    ──enables──> [信号历史持久化]、[回测记录]
[flutter_local_notifications] ──enables──> [推送提醒]
```

### Dependency Notes

- **下跌段检测 requires ATR 指标**：现有 `technical_indicators.dart` 缺 ATR，必须先补；这是模块的最早依赖项，决定 phase 顺序。
- **拉回段检测 requires 下跌段输出**（高低点、ATR 倍数达标判定）——同一引擎内顺序耦合。
- **RSI / 成交量 / Fib enhances 拉回判定**：作为共振过滤维度喂入评分，独立可并行开发。
- **四周期独立监控 requires WebSocket 多流复用**：现有 `WebSocketManager` 仅 2 并发连接（CONCERNS.md），400 标的 × 4 周期必须走单连接多流订阅（`SUBSCRIBE` 列表），否则连接数爆炸。这是**基础设施前置改造**。
- **共振评分 requires 四周期实例**：聚合层，在四周期之上。
- **回测 requires 信号历史持久化 + 历史 kline 拉取**：`BinanceApiService` 已能拉历史 klines，但需新建信号存储表（仿 `PumpRepository`）。
- **自动下单 conflicts with 整个里程碑范围**（PROJECT.md Out of Scope），不得引入任何执行路径代码。

---

## MVP Definition

### Launch With (v1) — 对应 PROJECT.md Active 列表

- [ ] ATR(14) + RSI(14) 指标实现（补 `technical_indicators.dart`）
- [ ] 反弹检测引擎：下跌段(2×ATR) + 拉回段(≥50% 回补 + 速度窗) + 共振过滤(RSI 超卖 / 量能 / Fib)
- [ ] WebSocket 多流复用扩展（4 周期并行订阅基础设施）
- [ ] 四周期（15m/1h/4h/1d）独立监控 + 共振评分
- [ ] 反弹强度评分 0–100（多维加权，起步权重）
- [ ] 死猫反弹风险标记（评分独立维度）
- [ ] 实时看板（周期 Tab、评分排序、mini sparkline、K 线收盘触发）
- [ ] 推送提醒（分级、每周期 toggle、去重冷却窗）
- [ ] 回测：历史回放 + 绩效（胜率/平均 R/盈亏比/最大回撤 + 样本数 N + 免责声明）
- [ ] 信号历史持久化（SQLite，复用 PumpRepository 模式）

### Add After Validation (v1.x)

- [ ] 参数扫描回测（网格搜索 + 热力图）— 触发：用户反馈阈值不适配某些品种
- [ ] 信号复盘页（历史信号后续涨跌可视化）— 触发：用户要「验证」
- [ ] 安静时段（quiet hours）— 触发：夜间扰民反馈
- [ ] 进场/止损参考价位展示 — 触发：用户要可执行价位
- [ ] ATR 自适应阈值（按波动率 regime 动态倍数）— 触发：固定 2× 在极端行情失效

### Future Consideration (v2+)

- [ ] 层级策略（大周期定方向、小周期找进场）— PROJECT.md 已标 Out of Scope，复杂度高
- [ ] AI/ML 反弹概率模型 — 需足够标注信号历史（来自 v1 持久化）后才有训练数据
- [ ] 现货监控 / 多交易所 — PROJECT.md 已标 Out of Scope
- [ ] 自动下单 — PROJECT.md 已标 Out of Scope，须回测长期验证后再议

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| ATR + RSI 指标 | HIGH（前置） | LOW | P1 |
| 下跌段 + 拉回段检测 | HIGH | MEDIUM | P1 |
| 共振过滤（量/RSI/Fib） | HIGH | MEDIUM | P1 |
| 评分引擎 0–100 | HIGH | MEDIUM | P1 |
| WebSocket 多流复用 | HIGH（前置基础设施） | HIGH | P1 |
| 四周期独立监控 + 共振 | HIGH | HIGH | P1 |
| 实时看板 | HIGH | MEDIUM | P1 |
| 推送提醒（分级+去重+toggle） | HIGH | MEDIUM | P1 |
| 回测：历史回放 + 绩效 | HIGH | HIGH | P1 |
| 死猫风险标记 | HIGH（差异化+防误报） | MEDIUM | P1 |
| 信号历史持久化 | MEDIUM（回测依赖） | MEDIUM | P1 |
| mini sparkline | MEDIUM | LOW | P1 |
| 持仓周期建议映射 | LOW | LOW | P2 |
| 参数扫描回测 | MEDIUM | HIGH | P2 (v1.x) |
| 信号复盘页 | MEDIUM | MEDIUM | P2 (v1.x) |
| 安静时段 | LOW | LOW | P2 (v1.x) |
| 进场/止损参考价 | MEDIUM | LOW | P2 (v1.x) |
| ATR 自适应阈值 | MEDIUM | MEDIUM | P2 (v1.x) |
| 共振雷达可视化 | MEDIUM | MEDIUM | P2 |
| AI/ML 预测 | LOW（v1 不做） | HIGH | P3 (v2+) |
| 层级策略 | LOW（v1 不做） | HIGH | P3 (v2+) |
| 自动下单 | 排除 | — | Anti |

---

## Competitor Feature Analysis

| Feature | 通用信号扫描器（TradingView Screener / Coinglass） | 量化回测平台（Freqtrade / Backtrader） | TomApp 反弹模块（Our Approach） |
|---------|-----------|-----------|--------------|
| 反弹检测 | 多用固定 % 阈值，跨币种不公平 | 用户自写策略，门槛高 | **ATR 归一化**，跨币种一把尺子（PROJECT.md 决策） |
| 多周期 | 多为单周期扫描 | 支持但需编码 | 四周期独立 + 共振，开箱即用 |
| 真假反弹区分 | 多数不区分（只报「反弹」） | 由策略代码决定 | **死猫风险分**显式标记（差异化） |
| 评分排序 | 常见 | 不常见（策略二元） | 0–100 多维加权，看板可排序 |
| 实时推送 | 部分有（PC 端为主） | 无（回测平台） | 移动端推送 + 分级 + 去重 + 周期 toggle |
| 回测 | 弱 / 无 | 强（但需编程） | **规则可调 + 参数扫描**，无需编码（中间地带） |
| 绩效披露 | 常只给胜率 | 给完整 R/回撤 | 四指标 + 样本数 + 免责声明（防误导） |
| 移动端原生 | 弱 | 无 | Flutter 原生，复用 TomApp 现有 UI 栈 |

**我们的护城河**：ATR 归一化 + 死猫显式标记 + 移动端原生实时推送 + 无代码回测校准——四者组合在移动端合约反弹监控这个细分场景里几乎没有直接竞品。

---

## Sources

- PROJECT.md（核心策略决策来源，HIGH confidence — 项目自有）
- `.planning/codebase/ARCHITECTURE.md`（现有架构与可复用组件，HIGH）
- `.planning/codebase/CONCERNS.md`（性能/基础设施约束，HIGH）
- 交易领域共识知识（V 型/死猫/Fib/RSI/ATR/胜率-R-回撤四指标）— 成熟公开知识，HIGH confidence；属交易社区与 CMT/技术分析教材标准内容
- Binance Futures API（kline 字段含 volume、`k.x` isClosed 事件）— 官方文档，HIGH

---
*Feature research for: 加密货币合约 V 型快速反弹监控*
*Researched: 2026-06-19*
