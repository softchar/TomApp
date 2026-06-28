# Phase 06: 回测验证（event-driven 引擎 + 偏差防护 + 报告披露） — Context

**Gathered:** 2026-06-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 6 交付一个 event-driven 逐 bar 回测引擎，回放历史 Binance K 线数据通过 Phase 2 同一份 `ReboundDetector.evaluate` 纯函数，验证反弹信号在历史数据上的有效性。引擎包含：历史数据导入管线、event-driven 回放核心、模拟交易（含手续费/资金费/滑点）、walk-forward 参数扫描、lookahead-analysis 偏差检测、以及含四项强制披露的回测报告 UI。

核心目标：兑现 ROADMAP「阈值标为起步值、由回测校准」决策——将 `ReboundParams` 中所有「Phase 6 校准」标记的阈值通过 out-of-sample 回测验证，输出校准建议。
</domain>

<decisions>
## Implementation Decisions

### 进场时点（Entry Timing）
- **D-01:** **next-open 进场**。信号在 bar[t].close 收盘后触发，模拟交易在 bar[t+1].open 进场。依据 PITFALLS.md Pitfall 1（杜绝前视偏差）+ ROADMAP 开放问题 #3 + Freqtrade 等行业标准。signal-close 同根进场不被允许（会产生 lookahead bias）。
- **入场价格:** bar[t+1].open（即确认信号后下根 K 线开盘价）。

### 出场规则（Exit Rules）
- **D-02:** **固定止损**：swing-low − 0.3×ATR(14)。在进场 K 线的 swing low 往下 0.3×ATR 设止损价，一旦 bar.low ≤ 止损价即触发退出。
- **D-03:** **双止盈**：61.8% Fib 退出 50% 仓位 + 100% Fib 退出剩余 50%。在 swing high → swing low 的 Fib 回撤水平上挂限价单。v1 固定限价单，不做移动止损（反弹是短线策略，复杂度收益比不高）。
- **D-04:** **时间退出**：持仓超过 `maxHoldBars` 根 K 线（默认 15m 周期 20 根 = 5h，由周期换算）未触及止损/止盈，则在第 `maxHoldBars+1` 根开盘市价退出。
- **D-05:** **资金费率扣费**：持仓跨 8h 整点结算时刻（00:00/08:00/16:00 UTC），按该时刻历史实际 funding rate × 名义仓位价值扣费。funding rate 历史数据从 Binance `/fapi/v1/fundingRate` 获取（需事先拉取并存入本地）。
- **D-06:** **成本模型**：taker 0.06% 来回（进场吃 taker + 出场吃 taker = 0.12%）+ 滑点 0.1% 单边。依据 PITFALLS.md Pitfall 4 最低底线。引擎必须支持「成本开关」，报告中零成本 vs 含成本双曲线必出。

### 数据导入与标的池（Data Import & Universe）
- **D-07:** **数据源与管线**：data.binance.vision 月度 ZIP（含所有 USDT 永续 K 线）→ 解压 → 按 symbol+interval 解析 → 写入 drift `Klines` 表 → REST `/fapi/v1/klines` gap-fill 当前月份缺口。管线在 Dart 侧实现（文件下载 + 解析 + 批量写入）。
- **D-08:** **标的池（v1 务实折中）**：Top-100 流动性币种（按 24h 交易量排序）。不做 point-in-time universe（v1 成本过高）。依据 PITFALLS.md Pitfall 2 务实折中。回测报告必须在「标的池说明」中显式声明："仅覆盖当前 Top-100 流动性币种，不包含已下架合约，结论不适用于小币/低流动性标的。"
- **D-09:** **历史数据范围**：默认 6 个月（约 180 天），用户可在回测配置中调整起止日期。起始日期默认为当前日期 −180 天。

### Walk-Forward 切片（Walk-Forward Splitting）
- **D-10:** **3-fold 锚定 walk-forward**：训练窗口不断增长（anchored），测试窗口为固定 1 个月 out-of-sample。Fold 1: train 月1-3 → test 月4; Fold 2: train 月1-4 → test 月5; Fold 3: train 月1-5 → test 月6。总计 6 个月数据、3 个 out-of-sample 月。
- **D-11:** **只报告 out-of-sample 聚合指标**。禁止报 in-sample 最优参数。依据 PITFALLS.md Pitfall 3（防止过拟合）。

### 参数扫描范围（Parameter Scan Scope）
- **D-12:** **扫描 4 个物理含义明确的阈值**（共 ~100-200 组合）：
  - `dropAtrMultiplier`: 1.5, 2.0, 2.5, 3.0（4 档）
  - `recoveryMinRatio`: 0.3, 0.4, 0.5, 0.6, 0.7（5 档）
  - `dropMaxCandles`: 2, 3, 4, 5（4 档）
  - `volumeMultiplier`: 1.0, 1.5, 2.0, 3.0（4 档）
  总计 4×5×4×4 = 320 参数组合，按 v1 数据量可行。
- **D-13:** **评分权重（30/30/25/15）不进参数扫描**。依据 ROADMAP 决策 + PITFALLS.md Pitfall 10（权重先固定，只扫阈值）。
- **D-14:** **共振过滤器开关（RSI/量能/支撑位/K线形态）不进参数扫描**。v1 全部保持默认开启。关掉过滤器会严重增加误报，违背"宁可漏报不可误报"原则。

### 回测引擎架构（Engine Architecture）
- **D-15:** **Event-driven 逐 bar 推进**，非向量化。引擎按时间顺序逐 bar 消费 KlineData 序列，每根 bar 收盘后调用 `ReboundDetector.evaluate(rollingWindow, params)`。禁止向量化（向量化 `df.shift()` 错位 bug 极难发现——PITFALLS.md 技术债表标为"永不可接受"）。
- **D-16:** **引擎数据源**：从 drift `Klines` 表读取（由数据导入管线预先填充），不直接读文件。引擎不关心数据从哪来，只消费 `List<KlineData>` 序列。
- **D-17:** **Lookahead-analysis 测试**：将每根 bar 的 close 替换为下一根的 open（`window[i].close = window[i+1].open`），重新跑回测。若结果不变（信号触发时间/数量/评分完全一致）→ 通过。若结果变化 → 说明有前视偏差，引擎必须修正。依据 PITFALLS.md Pitfall 1（"这是最强检测手段"）。这是 UAT 硬标准。

### 回测报告 UI（Backtest Report UI）
- **D-18:** **独立 BacktestScreen**，不作为看板 Tab 嵌入。入口放在底部导航栏（新 Tab）或 ProfileScreen 内的入口按钮（规划阶段与现有 UI 布局比对后拍板）。
- **D-19:** **报告内容**包含：
  - 权益曲线（折线图：时间 × 累计 PnL，零成本 + 含成本双曲线）
  - 汇总统计卡（胜率 / 平均 R / 盈亏比 / 最大回撤 / 样本数 N / 总 PnL / 平均每笔 R）
  - 交易列表（币种 / 进场时间-价格 / 出场时间-价格 / PnL / R 倍数），可排序
  - 点击单笔交易 → 下钻到 KlineScreen，高亮该笔交易的持仓区间
- **D-20:** **四项强制披露**（缺一项不让展示报告，依据 BACKTEST-07 + PITFALLS.md Pitfall 13）：
  1. 前视偏差已检（lookahead-analysis 通过 ✓）
  2. 含手续费/资金费/滑点（成本模型摘要）
  3. 标的池说明（Top-100 流动性币种 + 时间范围 + 不含下架币声明）
  4. Out-of-sample only（walk-forward 3-fold，仅报 out-of-sample）
- **D-21:** **免责声明**固定显示于报告页头/页脚："回测表现通常需打 30-50% 折扣作为实盘预期；本工具不构成投资建议。"（依据 PITFALLS.md Pitfall 13）
- **D-22:** **信号文案零执行词延续**：回测报告中所有信号的描述统一为"监控候选"，全文禁止出现"买入/强买/信号/推荐"等措辞（贯穿 04/05/06 三阶段的不变量）。

### Claude's Discretion
以下由规划/执行阶段的 agent 自主决定，无需用户再确认：
- 数据导入管线下载解压的具体实现（下载并发数、解压路径、批量写入策略）
- 权益曲线绘图库选择（复用 fl_chart 1.2.0 或引入新库）
- BacktestScreen 入口位置（底部导航新 Tab vs ProfileScreen 入口按钮）——与现有 UI 布局比对后选择更内聚的方案
- Walk-forward 折叠是否可配置（v1 硬编码 3-fold，可配置化延后 v2）
- 参数扫描网格大小是否可配置（v1 硬编码 4×5×4×4=320 组合）
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### 反弹检测器核心（Phase 6 必须复用）
- `lib/services/rebound/rebound_detector.dart` — `ReboundDetector.evaluate` 纯函数，回测引擎核心调用
- `lib/models/rebound_signal.dart` — `ReboundSignal` 信号输出模型（含所有字段）
- `lib/models/rebound_params.dart` — `ReboundParams` 全部可调阈值（所有默认值标"Phase 6 校准"）
- `lib/models/kline_data.dart` — `KlineData` K 线数据模型（回测窗口单位）
- `lib/services/technical_indicators.dart` — `TechnicalIndicators` 技术指标（ATR/RSI/swing/布林带）

### 数据库与持久化
- `lib/services/drift_database.dart` — drift 表定义（`Klines` / `BacktestRuns` / `BacktestTrades`），回测引擎读写目标
- `lib/services/database_helper.dart` — sqflite `DatabaseHelper`（drift 表与 sqflite 表共存于同一 SQLite 文件）

### 风险管理与规则
- `.planning/research/PITFALLS.md` — 13 个关键风险登记册，Phase 6 重点：Pitfall 1（lookahead）、2（survivorship）、3（curve-fitting）、4（零成本）、13（虚假信心）
- `.planning/workstreams/contract-quick-rebound/ROADMAP.md` § Phase 6 — 阶段目标 + 7 条成功标准
- `.planning/workstreams/contract-quick-rebound/REQUIREMENTS.md` § BACKTEST — BACKTEST-01 至 BACKTEST-07
- `.planning/PROJECT.md` — 核心价值声明 + Key Decisions 表

### 先前阶段摘要（跨阶段上下文）
- `.planning/workstreams/contract-quick-rebound/phases/02-i-o/02-01-SUMMARY.md` — Phase 2 检测器实现决策
- `.planning/workstreams/contract-quick-rebound/phases/02-i-o/02-02-SUMMARY.md` — Phase 2 测试 fixtures 与边缘场景
- `.planning/workstreams/contract-quick-rebound/phases/04-ui-tab-sparkline/04-03-SUMMARY.md` — 监控周期收缩到 15m + 多周期架构保留决策

### 外部参考
- Freqtrade Lookahead Analysis: https://www.freqtrade.io/en/stable/lookahead-analysis/ — lookahead-analysis 测试思路来源
- Binance 历史 K 线数据: https://data.binance.vision/ — 月度 ZIP 下载入口
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`ReboundDetector.evaluate`**（`lib/services/rebound/rebound_detector.dart`）：纯函数，零 I/O，直接可被回测引擎逐 bar 调用。v1 监控已缩到 15m 单周期，但 detector 本身接受任意 `timeframe` 字符串——回测可以测 15m/1h/4h/1d 全部周期。
- **`ReboundParams`**（`lib/models/rebound_params.dart`）：所有阈值默认值 + `copyWith` 不可变覆盖——参数扫描直接构造 N 个 `ReboundParams` 实例即可。
- **`ReboundSignal`**（`lib/models/rebound_signal.dart`）：信号输出模型已有 `entryPrice`/`swingLowPrice`/`timestamp` 字段——回测引擎可以此为基础计算出场和 PnL。
- **drift `Klines` 表**（`lib/services/drift_database.dart`）：bust 已有 schema + build_runner DAO，数据导入管线可直接写入。
- **drift `BacktestRuns` / `BacktestTrades` 表**：已建表（Phase 1），回测引擎产出直接写入，无需新建 schema。

### Established Patterns
- **4 层架构**（UI → Provider → Service → Data）：回测引擎放 Service 层（`lib/services/rebound/`），BacktestScreen 放 UI 层（`lib/screens/`），BacktestProvider 放 Provider 层（`lib/providers/`）。
- **ChangeNotifier Provider** 状态管理：回测运行状态（idle/running/complete/error）+ 报告数据用 Provider 管理，UI 通过 `Consumer`/`context.watch` 响应。
- **Repository 模式**：数据导入管线可参考 `PumpRepository`（`lib/services/pump_repository.dart`）的抽象，隔离 drift DAO 与业务逻辑。
- **策略模式**：`PumpDetectionStrategy`（`lib/services/strategies/`）的接口 + 多实现模式，可类比回测引擎中"不同的出场规则"作为可插拔策略。

### Integration Points
- **main.dart**：回测 Provider（BacktestProvider）在 `MultiProvider` 中注册。回测不依赖实时 WebSocket，不需要 WS 订阅——独立于 Phase 3-5 的实时管线。
- **KlineScreen**：现有 `lib/screens/kline_screen.dart` 可复用于回测交易下钻（传入 symbol + 高亮区间，复用既有图表渲染）。
- **Bottom Navigation**：`lib/screens/main_navigation.dart` 的 `IndexedStack` 现有 5 个 Tab——新增 Backtest Tab 需调整导航栏布局（考虑滚动或替换低频入口）。
- **drift Database**：`AppDatabase` (drift) 与 `DatabaseHelper` (sqflite) 指向同一 SQLite 文件——数据导入管线写入 drift DAO 即可，不与既有 sqflite 表冲突。
</code_context>

<specifics>
## Specific Ideas

- **PITFALLS.md 是 Phase 6 的设计约束文件**：Pitfall 1/2/3/4/13 直接对应 BACKTEST-01 至 BACKTEST-07 各条需求的实现约束。规划 agent 应逐条对照 Pitfall 到每个 task 的 `<acceptance_criteria>` 中。
- **"Looks Done But Isn't" 清单**（PITFALLS.md 末尾）中与 Phase 6 相关的 6 项必须在 VERIFICATION.md 中全部通过：
  - 回测 lookahead-analysis（close→下根 open 结果不变）
  - 回测成本（零成本 vs 含成本双曲线都出）
  - 回测标的池（报告是否声明 universe 处理方式）
  - 回测 walk-forward（是否只报 in-sample 最优？应为 only out-of-sample）
  - 回测/看板免责声明（页面是否固定显示）
  - 信号文案（全文 grep 无"买入/强买"等执行性词——贯穿 04/05/06）
- **回测时间范围默认 6 个月**，起点从 data.binance.vision 最新可用月度 ZIP 向前推。用户可在 UI 调整起止日期，但不得早于 2020-01-01（Binance 永续合约历史数据起始）。
- **模拟交易仓位管理**：v1 简化——每币种同时最多持有 1 个仓位，新信号触发时不叠加（旧仓位未平则跳过新信号）。不模拟保证金/杠杆（回测报告以 R 倍数展示，不涉及绝对金额）。
</specifics>

<deferred>
## Deferred Ideas

以下不在 Phase 6 范围，已登记但不实现：

- **SCAN-01（完整 walk-forward 参数扫描增强）**：更大的参数网格、更多可调维度、敏感性分析热力图 → v2
- **参数扫描网格可配置化**：v1 硬编码 4×5×4×4=320 组合，用户自定义网格 → v2
- **Walk-forward 折叠数可配置化**：v1 硬编码 3-fold，用户可调 → v2
- **Point-in-time universe（历史标的成员表）**：维护 onboardDate/delistDate、精确处理幸存者偏差 → v2
- **移动止损/Trailing Stop**：v1 固定止损，不做移动止损 → v2（与层级策略一起）
- **多币并发仓位管理**：v1 每币最多 1 个仓位 → v2（与自动下单一起）
- **参数扫描并行化**：v1 单线程逐组合跑 → v2（Isolate 并行）
- **回测结果导出 CSV/PDF**：v1 仅屏幕展示 → v2

---

*Phase: 06-event-driven*
*Context gathered: 2026-06-20*
