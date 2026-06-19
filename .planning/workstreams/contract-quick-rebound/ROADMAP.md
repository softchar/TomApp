# Roadmap: TomApp — v1.0 多周期合约反弹监控

**Workstream:** `contract-quick-rebound`
**Milestone:** v1.0 多周期合约反弹监控
**Core value:** 在第一时间可靠地识别异常行情信号（拉盘 / V 型快速反弹）并及时提醒交易者——宁可漏报，不可误报刷屏。

## Overview

本里程碑在**已有 pump 检测栈上新增一个并行的反弹监控模块**，不是扩展 pump 栈。路线图按依赖图分 6 阶段：指标基础（gating prerequisite，含 SDK 升级 + drift/fl_chart 依赖落地）→ 纯函数反弹检测器（单一信号逻辑真源，live 与 backtest 共用）→ 实时监控接线（最重基础设施改造：sharded combined-stream WS）→ 实时看板 UI + 推送提醒（并行消费 Phase 3 产出的 score）→ 回测验证（必须排 detector 锁定之后，保证回测对 live 有效，并兑现「阈值标为起步值、由回测校准」决策）。

核心不变量：指标 + 检测器必须最先且纯函数化（gating 一切 downstream）；检测器纯函数锁定后才进回测，否则 live/backtest 逻辑漂移、回测作废。每阶段的 UAT 标准围绕「信号正确性」与「提醒质量」两类核心风险（见 `.planning/research/PITFALLS.md`）。

## Gating Prerequisites & Open Questions

Phase 内部决策（非路线图阻塞项，plan 阶段拍板）：

1. **SDK 升级目标**（Phase 1 plan 前拍板）：`>=3.6.0`（解锁 drift 2.32 + fl_chart 1.2）还是 `>=3.10.0`（drift 2.33 全特性）。推荐 3.6 起步。
2. **WebSocket sharding 轴**（Phase 3 plan 前定）：by-symbol（2×800，per-symbol 计算局部化）还是 by-timeframe（4×400，贴 per-TF toggle）。
3. **回测进场时点**（Phase 6 SPEC 前确认）：signal-close（PROJECT.md 字面）还是 next-open（更现实）。影响胜率 + 与实盘一致性。
4. **监控范围默认值**（Phase 3 SPEC 前定）：全市场 ~400 USDT 永续 还是 watchlist + Top N。推荐 watchlist + Top N，全市场降频轮询。
5. **评分权重起步值**（Phase 2 plan 给表格）：跌幅深 30 / 回补强 30 / 共振 25 / 量能 15（业务先验，Phase 6 校准）。
6. **Notification coalescing 窗口/冷却时长/每日上限**（Phase 5 UAT 调参）：推荐 4h 冷却 + 20 条/天。

**Research flags（建议 `/gsd-plan-phase --research-phase`）：**
- **Phase 3：** combined-stream 消息 shape、`k.x` 语义、IP 连接/消息权重、sharding 轴、reconnect coordinator——对照当前 Binance fapi 文档。
- **Phase 6：** walk-forward 切片策略、point-in-time universe 数据源、历史 funding rate 数据、exit-rule 设计、进场时点。

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: 指标基础（ATR/RSI/Bollinger/swing + SDK 升级 + drift schema）** - 一切 downstream 最早依赖；纯 additive、零触达 pump/chart；同时在此完成 SDK 升级 + drift/fl_chart 依赖 + drift 表 schema
- [ ] **Phase 2: 反弹检测器 + 评分 + 共振（纯函数，零 I/O）** - 单一信号逻辑真源，live 与 backtest 共用；接入任何 I/O 前 100% 单测覆盖
- [ ] **Phase 3: 实时监控接线（sharded combined-stream WS + 编排器 + Provider）** - 最重基础设施改造：1600 stream 拆连接池、`k.x==true` 硬断言、重连 REST 回填重算、warm-up、mark price、watchlist churn
- [ ] **Phase 4: 实时看板 UI（周期 Tab + 评分排序 + sparkline）** - provider 状态已存在，UI 纯消费；可与 Phase 5 并行；drill-down 复用 KlineScreen
- [ ] **Phase 5: 推送提醒（分级 + 冷却 + 归并 + 总量上限）** - 「不可误报刷屏」最后一道防线；可与 Phase 4 并行
- [ ] **Phase 6: 回测验证（event-driven 引擎 + 偏差防护 + 报告披露）** - 必须排 detector（Phase 2）锁定后，保证回测对 live 有效；lookahead-analysis + 双曲线 + 四项披露

## Phase Details

### Phase 1: 指标基础（ATR/RSI/Bollinger/swing + SDK 升级 + drift schema）
**Goal**: 为下游检测器、监控、回测提供共享的纯函数技术指标计算基础，同时完成 SDK 升级（≥3.6）与 drift/archive 依赖落地（gating prerequisite，解锁后续全部阶段）。注：fl_chart 1.2 升级延后到 Phase 4（其 CandlestickChart 仅看板需要，且 0.65→1.2 是破坏性升级会牵连既有 macd_chart_widget，集中到图表阶段一起做更内聚）。
**Depends on**: Nothing (first phase)
**Requirements**: INDIC-01, INDIC-02, INDIC-03, INDIC-04
**Success Criteria** (what must be TRUE):
  1. ATR(14) 计算可在 live 与回测拿到**同一实现、同一值**（验证 2×ATR 跌幅阈值与 0.3×ATR 止损阈值一致），合成 K 线序列单测覆盖 Wilders 平滑与 warm-up 头 14 根返回未就绪
  2. RSI(14) 含超卖拐头判定（<30 拐头向上）可输出，Bollinger Bands（上/中/下轨）与 swing high/low 识别可通过单测
  3. Dart SDK 已升到 ≥3.6（满足 drift 2.32 的 ≥3.6 要求），`flutter pub get` 无版本冲突；drift 2.3x / archive 4.0.2 / drift_dev 装好（fl_chart 1.2 升级延后到 Phase 4）
  4. drift `Klines` / `BacktestRuns` / `BacktestTrades` 表已建 + `DatabaseHelper` schema migration 通过；既有 pump/chart 功能回归无影响
**Plans**: TBD

### Phase 2: 反弹检测器 + 评分 + 共振（纯函数，零 I/O）
**Goal**: 锁定反弹信号的单一逻辑真源——一个纯函数 `ReboundDetector.evaluate`，live 与回测共用同一份代码，接入任何 I/O 前 100% 单测覆盖
**Depends on**: Phase 1
**Requirements**: DETECT-01, DETECT-02, DETECT-03, DETECT-04, SCORE-01, SCORE-02, SCORE-03
**Success Criteria** (what must be TRUE):
  1. 三阶段检测可在合成 K 线 fixtures 上判定：下跌段（跌幅 ≥2×ATR + 各周期 % 兜底，≤3 根内）+ 拉回段（回补 ≥50%、≤2 根内、收盘站上跌幅中点）+ 共振过滤（放量 ≥1.5×、RSI 超卖拐头、支撑位、K 线形态）
  2. `ReboundDetector.evaluate(List<KlineData> window, ReboundParams p) → ReboundSignal?` 为纯函数——无 `DateTime.now()`、无 async、无网络、无 Provider、无跨调用可变状态（静态分析可验证）；同一输入 live 路径与回测路径调用结果完全一致
  3. 输出 0-100 强度评分（回补比例/速度/量能/共振加权）+ 死猫反弹风险分；评分权重业务先验固定（跌幅深 30/回补强 30/共振 25/量能 15，标「Phase 6 校准」，不进参数扫描）
  4. 合成 fixtures 单测覆盖：lookahead 抵御、warm-up 抵御、死猫 vs 真反转判别、下跌中继/dump 残留不误触发
**Plans**: TBD

### Phase 3: 实时监控接线（sharded combined-stream WS + 编排器 + Provider）
**Goal**: 把纯函数检测器接到真实 Binance 合约 K 线流——sharded combined-stream WS 订阅多币多周期，单一编排器持有 `Map<symbol, Map<TF, signal>>` 跑共振评分，喂给 `ReboundScoreProvider`；最重基础设施改造 phase
**Depends on**: Phase 2
**Requirements**: MONITOR-01, MONITOR-02, MONITOR-03, MONITOR-04, MONITOR-05, MONITOR-06, MONITOR-07, MONITOR-08
**Success Criteria** (what must be TRUE):
  1. 15m/1h/4h/日 四周期独立监控反弹信号；引擎层硬断言**仅 `k.x==true`（K 线收盘）触发检测**——单元测试塞 partial kline 消息断言不触发任何信号（杜绝 repaint，Pitfall 5/8）
  2. sharded combined-stream WebSocket 订阅多币多周期（1600 stream 拆 2-4 连接池，每池 ≤~400 stream，遵守 Binance IP 连接数与消息权重限制）；400 标的全订阅下连续运行 1 小时无未恢复断连、K 线收盘确认根数 ≥ 预期的 99%（Pitfall 6）
  3. 新订阅 warm-up（先 REST 拉 ≥50-100 根历史）期间该标的标记 `warming-up` 不触发信号；重连成功后 REST 按 `lastConfirmedCloseTime` 回填缺口 K 线并**整体重算指标**（非增量）；解析失败不再静默吞（计数 + 熔断）（Pitfall 7/8）
  4. 信号数据源明确为 **mark price kline**（非 last price，last 仅展示）；定期（≥1h）刷新 `/fapi/v1/exchangeInfo` 自动剔除下架合约，看板无幽灵币（Pitfall 12）
  5. 多周期共振检测：同币多周期同步反弹 → 升级信号；可先 headless（日志）验证，再接 Provider
**Plans**: TBD

### Phase 4: 实时看板 UI（周期 Tab + 评分排序 + sparkline）
**Goal**: 用户能在按周期分 Tab 的实时看板上看到当前反弹监控候选，按评分排序，并下钻到 K 线详情；信号统一文案「监控候选」+ 风险提示。本阶段同时完成 fl_chart `^0.65.0`→`^1.2.0` 升级（启用原生 CandlestickChart）并迁移既有 `lib/widgets/macd_chart_widget.dart` 到 1.x API，保持零回归。
**Depends on**: Phase 3
**Requirements**: DASH-01, DASH-02, DASH-03, DASH-04, DASH-05, DASH-06
**Success Criteria** (what must be TRUE):
  1. 看板按周期分 Tab（15m/1h/4h/日），每个 Tab 内信号按评分降序排列，展示币种/周期/跌幅/回补%/评分/迷你 sparkline
  2. 每条信号标注死猫风险（图标/颜色）+ 止损参考位；warming-up 状态标的明确展示且不出信号
  3. 文案全文 grep 无「买入/强买/信号」等执行性词，统一为「监控候选」+ 固定风险提示（防虚假信心，Pitfall 13）
  4. 点击信号下钻到既有 `KlineScreen`（复用，最小改动接受初始标注参数），高亮检测到的下跌+拉回窗口
**Plans**: TBD
**UI hint**: yes

### Phase 5: 推送提醒（分级 + 冷却 + 归并 + 总量上限）
**Goal**: 守住「宁可漏报，不可误报刷屏」最后一道防线——强信号分级推送，每币全局冷却、跨周期事件归并、周期独立开关、每日总量上限
**Depends on**: Phase 3
**Requirements**: ALERT-01, ALERT-02, ALERT-03, ALERT-04, ALERT-05, ALERT-06
**Success Criteria** (what must be TRUE):
  1. 强信号分级推送：high 响铃+vibrate / med 横幅 / low 仅看板；每周期（15m/1h/4h/日）可独立开关推送
  2. 每币全局冷却（4h 内同币不再推送，冷却期内信号仅看板可见）——**UAT 硬标准：构造同币连续 4 根 K 线满足信号的场景，验证只收到 1 条推送**（Pitfall 11）
  3. 跨周期事件归并：同币多周期共振触发合并为 1 条「多周期共振」高级提醒（非多条）；每日推送总量上限 20 条/天，超额仅留最高分
**Plans**: TBD

### Phase 6: 回测验证（event-driven 引擎 + 偏差防护 + 报告披露）
**Goal**: 用 event-driven 逐 bar 回放复用 Phase 2 同一 `ReboundDetector`，验证信号在历史数据上的有效性，并通过 lookahead-analysis + 双曲线 + 四项披露防止虚假信心；兑现「阈值标为起步值、由回测校准」决策
**Depends on**: Phase 2 (detector 必须锁定)；逻辑上不需 Phase 3-5，放最后让先验参数先在 live 跑一轮收集真实分布
**Requirements**: BACKTEST-01, BACKTEST-02, BACKTEST-03, BACKTEST-04, BACKTEST-05, BACKTEST-06, BACKTEST-07
**Success Criteria** (what must be TRUE):
  1. 可导入 Binance 历史 K 线（data.binance.vision 月度 ZIP 批量 + REST gap-fill 到 drift `Klines`），event-driven 逐 bar 回放调用 Phase 2 同一 `ReboundDetector.evaluate`（保证回测对 live 有效）
  2. **lookahead-analysis 测试通过**——故意把每根 bar 的 close 换成下一根的 open，回测结果不变 → 说明无前视偏差（Pitfall 1，UAT 硬标准）
  3. 模拟交易含手续费（taker 0.06% 来回）+ 滑点（0.1% 单边）+ 持仓跨 8h 扣历史 funding；回测报告同屏输出**零成本 vs 含成本双曲线**（Pitfall 4，UAT 硬标准）
  4. 报告同屏显示胜率 / 平均 R / 盈亏比 / 最大回撤 + 样本数 N；参数扫描强制 walk-forward，只报 out-of-sample，权重业务先验固定不进扫描（Pitfall 2/3/10）
  5. 强制四项披露（前视已检 / 含成本 / 标的池说明 / out-of-sample）+ 免责声明（回测需打 30-50% 折扣，不构成投资建议），缺一项不让展示（Pitfall 13）
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4|5（并行）→ 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. 指标基础 | 0/0 | Not started | - |
| 2. 反弹检测器 + 评分 + 共振 | 0/0 | Not started | - |
| 3. 实时监控接线 | 0/0 | Not started | - |
| 4. 实时看板 UI | 0/0 | Not started | - |
| 5. 推送提醒 | 0/0 | Not started | - |
| 6. 回测验证 | 0/0 | Not started | - |

---

*Roadmap created: 2026-06-19*
*Workstream: contract-quick-rebound | Milestone: v1.0 多周期合约反弹监控*
