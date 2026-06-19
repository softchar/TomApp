# Project Research Summary

**Project:** TomApp — 合约快速反弹监控 (Contract Quick-Rebound Monitoring) milestone v1.0
**Domain:** 加密货币合约交易信号 — V 型快速反弹实时检测 + 多周期监控 + 评分排序 + 看板 + 推送 + 回测（Flutter/Dart brownfield 增量）
**Researched:** 2026-06-19
**Confidence:** HIGH

## Executive Summary

本里程碑是在**已有 pump 检测栈上新增一个并行的反弹监控模块**，不是扩展 pump 栈。研究四个维度（栈/特性/架构/陷阱）结论高度一致：把反弹功能做成 `PumpAlertService` 的双胞胎——新建 `ReboundAlertService` 编排器、新建一个 **combined-stream 多币多周期 kline 流服务**、新建一个 **纯函数 `ReboundDetector`**（live 与 backtest 共用同一信号逻辑单一真源），并复用现有 `BinanceApiService` / `notification_service` / `DatabaseHelper` / `shared_preferences`。所有新代码遵守既有 4 层 UI→Provider→Service→Data 与 ChangeNotifier 模式，**与 pump 栈解耦**（不子类化、不共享可变状态），保护已上线能力稳定。

**三条事实必须先固化**：(1) 项目实际状态管理是 **`provider` 6.1.0 (ChangeNotifier)，不是 Riverpod**——CLAUDE.md 表述有误，以 `pubspec.yaml` + codebase map 为准，新代码走 `lib/providers/` 下 ChangeNotifier 模式（镜像 `PumpListProvider`/`PumpAlertService`）；(2) 三处**基础设施前置**决定 phase 顺序——`TechnicalIndicators` 缺 ATR+RSI 必须先补、现有 WebSocket/Kline 服务是单币单周期 chart 向无法承担 1600 stream 监控需新建 sharded combined-stream 服务、`drift`(kline 持久化) + `fl_chart 1.2.0`(candlestick) 需把 Dart SDK 从 3.0 提到 ≥3.6；(3) **检测器必须纯函数、live 与 backtest 共用**，否则回测结论失真、核心价值崩塌。

**核心风险**围绕 PROJECT.md「**宁可漏报，不可误报刷屏**」原则，集中在两类：**信号正确性**（回测 look-ahead/survivorship/curve-fit/忽略手续费资金费滑点、实盘未收盘 K 线算导致 repaint、死猫/pump-dump 残留误判）与**提醒质量**（alert spam）。缓解手段已落到 UAT 硬标准：lookahead-analysis 测试、event-driven 回测、`k.x==true` 硬断言、walk-forward、零成本 vs 含成本双曲线、每币全局冷却 + 跨周期事件归并 + 每日总量上限、信号统一文案「监控候选」+ 强制免责声明。

## Key Findings

### Recommended Stack

详见 STACK.md。新增依赖极小，多数基础设施已就位。

**新增 runtime：**
- **drift `2.33.0`**（或 `2.32.x` 若 SDK 停 3.5）— 历史 OHLCV + 回测产物类型安全 SQLite 层；reactive `Stream<List<Kline>>` 契合 ChangeNotifier；`(symbol, interval, openTime)` 主键做 O(log n) range scan + `insertOnConflictUpdate` 幂等回填。选 drift 而非 Hive（原作者已弃）/Isar（abandoned）。
- **archive `^4.0.2`** — 解压 `data.binance.vision` 月度 kline ZIP（纯 Dart）。

**升级：** **fl_chart `0.65.0` → `1.2.0`** — v1.0.0 起原生 `CandlestickChart`；SDK ≥3.6.2 与 drift 对齐。v1 仅用于新反弹看板，**不迁移** `KlineScreen` 的 `flutter_chen_kchart`（迁移留待 cleanup 阶段）。

**新增 dev：** **drift_dev `^2.6.0`**（配合既有 build_runner）。

**已就位直接复用（不动）：** `flutter_local_notifications 17.2.3`、`flutter_background_service 5.0.10`、`shared_preferences`、`web_socket_channel 2.4.0`、`sqflite`、`mockito`。

**明确延后：** **`firebase_messaging`** — v1 监控器 in-process + Android 前台服务即可；FCM 需 Firebase 项目 + APNs + 后端，与「无 server」冲突。

**SDK 升级（gating prerequisite）：** 现 `sdk: '>=3.0.0 <4.0.0'`，推荐升 **`>=3.6.0 <4.0.0'`**（同时满足 fl_chart 1.2 ≥3.6.2 与 drift 2.32）；用 drift 2.33 全特性再提 ≥3.10。**开 plan 前必须与用户拍板。**

**Build vs install 决策：**
- **TA 指标（ATR/RSI/Bollinger/SMA/swing）= 全部手写**，不装 `deriv_technical_analysis`（tick 模型耦合、stale、适配≈重写、仅 4 指标）。ATR 必须 live 与 backtest 同一实例以保证 `2×ATR` 阈值与 `0.3×ATR` 止损一致。
- **回测引擎 = 自研 event-replay**（~400 LOC），无成熟 Dart 框架契合；Python backtrader/vectorbt 破坏纯 Flutter 部署。
- **历史 kline 数据源** = `data.binance.vision` 月度 ZIP 批量（主，400 币×多年唯一可行路） + REST `/fapi/v1/klines` 分页 gap-fill（次，限 1500/请求）。
- **WebSocket at scale（400×4=1600 stream）= 必须 shard**：单连接 ≤1024 stream、≤10 msg/sec、每 IP ~300 连接。推荐 **2 连接×800 stream**（by-symbol，per-symbol 计算局部化）或 **4 连接×400 stream**（by-timeframe，更贴合 per-TF toggle）。**sharding 轴开 plan 前必须定。**

### Expected Features

详见 FEATURES.md。V 型反弹 vs 死猫反弹区分是最高风险，所有 table stakes 围绕「多维结构输出（recovery_ratio/speed/volume_ratio/rsi_state/fib_level/mtf_confluence）+ 0-100 评分」展开。

**Table stakes：** ATR 归一化下跌段检测（≥2×ATR，% 兜底）、拉回段（≥50% 回补+速度窗）、RSI 超卖 + 成交量 + Fibonacci 回撤（38.2/50/61.8%）、四周期（15m/1h/4h/1d）独立监控 + 共振评分、0-100 评分（**权重业务先验固定、不进参数扫描**）、K 线收盘增量计算（`k.x==true`，**不继承** `kline_provider` 逐 tick 性能债）、实时看板（周期 Tab + 评分排序 + sparkline）、推送提醒（分级 + 每周期 toggle + 同币冷却去重）、回测（胜率/平均 R/盈亏比/最大回撤**四指标同屏 + 样本数 N + 免责声明**）、信号历史持久化（SQLite，复用 `PumpRepository` 模式）。

**Differentiators：** 死猫反弹显式风险分（多数同类不区分，硬兑现「宁可漏报」）、无代码参数扫描回测（中间地带）、ATR 归一化（跨币一把尺）、移动端原生实时推送、共振雷达/sparkline/进场止损参考价（v1.x）。

**Anti-features：** 自动下单（Out of Scope，风险最高）、层级策略（复杂度爆炸）、现货/非 Binance（基础设施未覆盖）、**只展示胜率**（致命误导，胜率 80% 可能负期望）、每 tick 重算（性能+repaint）、AI/ML（v1 无标注数据、黑盒不可回测）、「保证盈利」措辞（过拟合+合规）。

### Architecture Approach

详见 ARCHITECTURE.md。反弹模块是 `PumpAlertService`/`PumpDetector` 的**架构双胞胎，不是扩展**——独立 detector/编排器/流服务，仅共享纯函数 `TechnicalIndicators`。

**核心决策（load-bearing）：**
1. **`ReboundDetector.evaluate(List<KlineData> window, ReboundParams p) → ReboundSignal?` 是纯函数**，无 `DateTime.now()`/async/网络/Provider/跨调用可变状态。**live 与 backtest 调同一份代码**——回测可信的前提。接入任何 I/O 前 100% 单测覆盖。
2. **单一编排器 + 单一流服务**（非 4 个 detector 实例）。三段逻辑跨周期相同，confluence scorer 天然跨周期需单一 `Map<symbol, Map<TF, signal>>` 持有者（`ReboundAlertService`）。Provider 只读物化 `ReboundScore`。
3. **新建 combined-stream WS `ReboundKlineStreamService`**，镜像 `BinanceWebSocketManager` `!ticker@arr`；**不复用** `KlineWebSocketService`（单币单周期 chart-only，400×4 会炸）。
4. **WS 仅 `k.x==true` 触发检测**，partial 仅刷新 buffer 尾 + UI 实时价；与逐 tick 重算的 `kline_provider` **物理隔离**。
5. **回测复用同一 detector**：`BacktestService` 从 `KlineCacheService`/`getKlines()` 拉历史 → 按 TF 逐 bar slice → 调同一 `ReboundDetector.evaluate` → `SimulateTrade` → 聚合 stats。

**新组件（4 层）：** Service: `ReboundKlineStreamService`/`ReboundDetector`/`ReboundConfluenceScorer`/`ReboundAlertService`/`BacktestService`/`SimulateTrade`/`KlineImporter`；Provider: `ReboundScoreProvider`/`BacktestProvider`；UI: `ReboundDashboardScreen`/`BacktestScreen`；Data: `ReboundSignal`/`ReboundScore`/`ReboundConfig`/`BacktestRun|Trade|Stats` + drift 新表。

**MODIFIED（additive）：** `technical_indicators.dart`(+ATR/RSI)、`notification_service.dart`(+`rebound_high`/`rebound_med` 通道+coalescing)、`database_helper.dart`(+新表+migration)、`binance_api_service.dart`(+`getKlinesPaged`)、`main_navigation.dart`(+tab)、`main.dart`(+provider 注册)。

**NOT touched（刻意不复用）：** `KlineWebSocketService`/`KlineProvider`/`PumpDetector`/`PumpAlertService`（仅作模板）。

### Critical Pitfalls (Top)

详见 PITFALLS.md。按对核心价值威胁排序：

1. **回测 Look-ahead bias** — 信号只在 `bar[t].close` 已收盘且指标用 `bar[0..t-1]` 计算时触发；t 根收盘触发、t+1 根开盘进场；**回测必须 event-driven 逐 bar**（禁向量化 `df.shift()`）。UAT：lookahead-analysis 测试通过（close 换下根 open 结果不变）。Warning：胜率 >70% 无逻辑支撑。
2. **Survivorship + Curve-fitting + 忽略手续费/资金费/滑点（偏差三连击）** — point-in-time universe（务实折中：v1 先 top-100 流动性币 + 报告声明）；参数扫描**强制 walk-forward + 只报 out-of-sample**；权重业务先验固定（跌幅深 30/回补强 30/共振 25/量能 15），只扫物理含义阈值；**回测报告必须同屏零成本 vs 含成本双曲线**（taker 0.06% 来回 + 0.1% 单边滑点 + 持仓跨 8h 扣历史 funding）。Warning：邻居断崖、ATR=2.37 硬凑、in-sample 65%/out-of-sample 45%。
3. **WebSocket 未收盘 K 线上算 → repaint** — 引擎层硬断言 `assert message.k.x == true` 才调 `computeSignal()`；partial 仅刷新实时价；新建独立 `ReboundSignalEngine` 与 `kline_provider` **物理隔离**；接受收盘确认延迟 ~2s。UAT：塞 partial 消息断言不触发。
4. **假信号（死猫/下跌中继/pump-dump 残留）** — 形态匹配不含「是否真反转」语义。缓解：多周期共振（≥2 周期同步才升级）、量能确认、大周期 EMA 斜率趋势过滤、与 24h 内 pump 事件去重、**评分制非二元**（仅高分≥阈值推送）、每信号附止损位。Warning：信号后继续下跌 >40%、单周期信号数远多于共振。
5. **Alert spam（摧毁核心价值）** — 缓解（全部要）：**每币全局冷却**（4h 内不再提醒，冷却期仅看板）、**跨周期事件归并**（共振合并 1 条）、**周期独立 toggle + 分级**（仅高分推送）、**每日总量上限**（20 条/天，超额留最高分）、**静默窗口**（全市场 1h 跌幅 >X% 进入）。UAT：同币连续 4 根满足只推 1 条。
6. **合约专属（强平连环爆/mark vs last/下架 churn）** — 信号用 **mark price kline**（last 仅展示）；强平密度作辅助过滤；funding 作辅助维度；**watchlist 定期（≥1h）刷 `/fapi/v1/exchangeInfo` 自动剔下架**，避免幽灵币。UAT：grep 确认 mark price；看板无空标的。
7. **虚假信心/信号当「买入指令」** — UI 禁用「买入/强买/信号」，统一「**监控候选**」；回测报告强制披露四项（look-ahead 已检/含手续费资金费滑点/标的池说明/out-of-sample），缺一不让展示；固定提示「回测需打 30-50% 折扣；不构成投资建议」；每信号附止损 + 风险提示（不附止盈）。
8. **指标 warm-up + 数据源污染** — 新订阅先 REST 拉 ≥50-100 根，期间标 `warming-up` 不触发；ATR 异常值（TR >5×中位数）标记不纳入或缩放；信号用 mark price kline。
9. **WS 规模化连接/限流风暴 + 重连 gap** — 1600 stream 拆 2-4 连接池；退避带上限 + jitter + 全局协调器；**重连成功必须 REST 按 `lastConfirmedCloseTime` 回填并整体重算指标**（非增量）；解析失败不再静默吞（计数+熔断）。UAT：400 标的连续 1h 无未恢复断连、确认根数 ≥99%。

## Implications for Roadmap

四位 researcher 顺序略异（ARCHITECTURE 7 步 A/B/C 分组、PITFALLS 6 阶段 P1-P6、FEATURES 依赖图、STACK 按特性分块）。综合依赖图 + gating prerequisites，**推荐 6 阶段**：indicators → detector → live wiring → dashboard → alerts → backtest。核心不变量：**indicators + detector 必须最先且纯函数化**（gating 一切 downstream）；**backtest 必须排 detector 锁定后**（保证回测对 live 有效）；dashboard 与 alerts 可在 live wiring 后并行。

### Phase 1: 指标基础 (ATR + RSI + Bollinger/SMA/swing)
**Rationale:** 一切 downstream 最早依赖；纯 additive、零风险触达 pump/chart；可独立单测。同时在此 phase 完成 SDK 升级 + drift/fl_chart 依赖落地 + drift 表 schema，避免后续卡环境。
**Delivers:** `technical_indicators.dart` 增 ATR/RSI/Bollinger/swing；drift `Klines`/`BacktestRuns`/`BacktestTrades` 表 + migration；SDK 升 ≥3.6；fl_chart 1.2 + drift + archive + drift_dev 装好；`DatabaseHelper` 新表迁移。
**Addresses:** ATR 归一化前置、RSI 超卖前置、信号历史持久化表结构。
**Avoids:** P8 warm-up（接口契约）、P10 权重先验（`ReboundParams` 结构）。
**Research flag:** 标准 textbook，无需 `/gsd-plan-phase --research-phase`；plan 中验证 2×ATR/50% 起步值在样本币的可行性。

### Phase 2: 反弹检测器 + 评分 + 共振 (纯函数，零 I/O)
**Rationale:** 单一信号逻辑真源；live 与 backtest 共用；接入任何 I/O 前 100% 单测。
**Delivers:** `ReboundDetector.evaluate`、`ReboundConfluenceScorer.score`、`ReboundParams`（阈值全标 starting values）、`ReboundSignal`/`ReboundScore`/`ScoreTier`；合成 kline fixtures 单测（lookahead 抵御/warm-up 抵御/死猫判别）。
**Addresses:** 下跌+拉回+共振过滤、0-100 评分、死猫风险分、共振评分。
**Avoids:** P9 假信号、P10 权重先验、P1 lookahead（纯函数）。
**Research flag:** 评分权重起步值 plan 中给明确表格并标「业务先验，Phase 6 校准」。

### Phase 3: 实时监控接线 (multi-stream WS + 编排器 + Provider)
**Rationale:** detector 已就位开始喂数据；可先 headless 验证（日志）。**最重基础设施改造 phase**——sharded combined-stream WS、per-(symbol,TF) rolling buffer、`k.x==true` 硬断言、重连 REST 回填 + 指标重算、watchlist churn。
**Delivers:** `ReboundKlineStreamService`、`ReboundAlertService`、`ReboundScoreProvider`、`main.dart` provider 注册、`main_navigation.dart` tab 占位、warm-up 保护、mark price 数据源、`exchangeInfo` 定期刷新剔下架。
**Addresses:** 四周期独立监控、K 线收盘增量计算、信号历史持久化（写入）。
**Avoids:** P5 repaint、P6 连接/限流风暴、P7 重连 gap 回填、P8 warm-up+mark price、P12 watchlist churn。
**Research flag:** **强烈建议 `/gsd-plan-phase --research-phase 3`** — combined-stream 消息 shape、`k.x` 语义、IP 连接/消息权重、sharding 轴（by-symbol 2×800 vs by-timeframe 4×400）、reconnect coordinator 对照当前 Binance fapi 文档确认。

### Phase 4: 实时看板 UI
**Rationale:** provider 状态已存在，UI 纯消费；可与 Phase 5 并行；drill-down 复用既有 `KlineScreen`（最小改动接受初始标注参数）。
**Delivers:** `ReboundDashboardScreen`（15m/1h/4h/日 Tab）、评分排序列表、mini sparkline、死猫风险标记图标/颜色、warming-up 状态、drill-down 到 `KlineScreen`、信号文案「监控候选」+ 止损位 + 风险提示。
**Addresses:** 实时看板、持仓周期建议映射、文案定位。
**Avoids:** P13 虚假信心（grep 无执行性词、免责声明固定显示）、P11 看板侧（冷却期信号仅看板）、rebuild storm（debounce + 仅变更项 notify）。
**Research flag:** 标准 Flutter UI，无需 research-phase；需 UI/UX 决策（评分色阶、死猫图标、Tab 交互）。

### Phase 5: 推送提醒 (分级 + 去重 + 归并 + 总量上限)
**Rationale:** Phase 3 已产出 score，alerts 是消费侧；可与 Phase 4 并行。「不可误报刷屏」最后一道防线。
**Delivers:** `NotificationService` 新通道 + coalescing map、每币全局冷却表（4h）、跨周期事件归并（共振合并 1 条）、周期独立 toggle、分级（high=响铃+vibrate/med=横幅/low=仅看板）、每日总量上限（20 条/天）、静默窗口、安静时段。
**Addresses:** 推送提醒（分级 + 每周期 toggle + 去重冷却）。
**Avoids:** P11 alert spam（UAT：同币连续 4 根满足只推 1 条）、P9 仅高分推送。
**Research flag:** coalescing 窗口/冷却时长/每日上限/静默阈值需 UX 调参（Phase 5 UAT 决定）。

### Phase 6: 回测验证 (event-driven 引擎 + 偏差防护 + 报告披露)
**Rationale:** 必须排 detector（Phase 2）锁定后——保证回测对 live 有效。是「阈值标为起步值，由回测校准」决策兑现点 + 参数扫描（v1.x）底座。回测**不需要** Phase 3-5，可 Phase 2 完成后启动；放最后让先验参数先在 live/看板/提醒跑一轮收集真实分布。
**Delivers:** `KlineImporter`（binance.vision ZIP + REST gap-fill → drift `Klines`）、`BacktestService`（event-replay 逐 bar，调 Phase 2 同一 detector）+ `SimulateTrade`（进场**待用户定**；止损=swing-low − 0.3×ATR；目标 61.8% 与 100% Fib；含手续费资金费滑点）、`BacktestProvider` + `BacktestScreen`（配置表单 + 结果表 + fl_chart 权益曲线/直方图）、`BacktestStats`（胜率/平均 R/盈亏比/最大回撤/Sharpe + 样本数 N）、**强制四项披露 + 免责声明 + 零成本 vs 含成本双曲线**。
**Addresses:** 回测（历史回放 + 四指标绩效 + 样本数 + 免责声明）、参数扫描基础（v1 小网格，v1.x 完整 walk-forward）。
**Avoids:** P1 look-ahead（lookahead-analysis + event-driven）、P2 survivorship（top-100 + 报告声明）、P3 curve-fitting（walk-forward + out-of-sample + 敏感性分析无尖锐峰 + 30-50% 折扣）、P4 手续费/资金费/滑点（双曲线 + 跨结算扣 funding）、P13 虚假信心。
**Research flag:** **强烈建议 `/gsd-plan-phase --research-phase 6`** — walk-forward 切片策略、point-in-time universe 数据源、历史 funding rate 数据获取、exit-rule 设计、进场时点（signal-close vs next-open）需用户决策。

### Phase Ordering Rationale

- **依赖驱动：** Phase 1→2 硬依赖无法并行；Phase 2 gating Phase 3/4/5/6 全部（FEATURES 依赖图 + ARCHITECTURE build order step 1-2 一致）。
- **单一真源驱动：** Phase 2 纯函数锁定后才进 Phase 6 backtest——否则 live/backtest 逻辑漂移、回测作废（P1 + ARCHITECTURE anti-pattern 1）。
- **基础设施前置驱动：** Phase 3 最重改造（sharded WS/重连回填/warm-up/watchlist churn），必须在 Phase 4/5 消费真实数据前完成；P5/P6/P7/P8/P12 全部在此拦截。
- **可并行优化：** Phase 4 (dashboard) 与 Phase 5 (alerts) 都消费 Phase 3 score，可并行（可合并一 phase 或拆 4a/4b）。ARCHITECTURE step 4-5 已注明。
- **回测后置驱动：** Phase 6 排最后让先验参数先在 live 跑一轮收集真实信号分布，回测校准才有意义；回测偏差防护是 v1 最高认知风险，集中一 phase 易 UAT 把关。

### Research Flags

**需要 `/gsd-plan-phase --research-phase`：**
- **Phase 3：** combined-stream 消息 shape、`k.x` 语义、IP 连接/消息权重、sharding 轴（by-symbol 2×800 vs by-timeframe 4×400）、reconnect coordinator——对照当前 Binance fapi 文档。
- **Phase 6：** walk-forward 切片策略、point-in-time universe 数据源、历史 funding rate、exit-rule 设计、进场时点（signal-close vs next-open）。

**标准模式（跳过 research-phase）：**
- **Phase 1：** ATR/RSI/Bollinger textbook，Wilders 平滑有公开实现。
- **Phase 2：** 纯函数 + 合成 fixtures 单测，无外部 API。
- **Phase 4：** 标准 Flutter + fl_chart 消费，复用 `KlineScreen`。
- **Phase 5：** 复用既有 `NotificationService` 单例 + channel，仅增 coalescing + 冷却表。

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | 版本经 pub.dev API 验证（drift 2.33/fl_chart 1.2/archive 4.0.2）；Binance WS/REST/data.binance.vision 经官方文档。SDK 升级目标是唯一 open item。 |
| Features | HIGH | 领域知识成熟（V 型/死猫/Fib/RSI/ATR/胜率-R-回撤为交易社区与 CMT 教材标准）；PROJECT.md 已立核心策略。 |
| Architecture | HIGH | 基于 `lib/services/*`、`lib/providers/*` 实际文件检查；NEW vs MODIFIED 均 additive；live+backtest detector 复用由纯函数强制。 |
| Pitfalls | HIGH | 多源印证（Binance 官方 + Freqtrade lookahead-analysis + CoinAPI survivorship + Seven Sins + 内部 CONCERNS.md）；每 pitfall 落 UAT 硬标准。 |

**Overall confidence:** HIGH

### Gaps to Address (Open Questions，需用户/plan-phase 决策)

1. **SDK 升级目标**：`>=3.6.0`（解锁 drift 2.32 + fl_chart 1.2）还是 `>=3.10.0`（drift 2.33 全特性）？推荐 3.6 起步。**Phase 1 plan 前拍板。**
2. **WebSocket sharding 轴**：by-symbol（2×800，per-symbol 计算局部化）还是 by-timeframe（4×400，贴 per-TF toggle）？**Phase 3 plan 前定。** per-TF toggle 核心则 by-timeframe；最小连接数则 by-symbol。
3. **回测进场时点**：signal-close（PROJECT.md 字面）还是 next-open（更现实）？影响胜率 + 与实盘一致性。**Phase 6 SPEC 前确认。**
4. **监控范围默认值**：全市场 ~400 USDT 永续 还是 watchlist + Top N？移动端承载（CONCERNS.md：现 ~200 symbol/2 WS）。**Phase 3 SPEC 前定。** 推荐 watchlist + Top N，全市场降频轮询。
5. **评分权重起步值**：跌幅深 30/回补强 30/共振 25/量能 15（P10 先验）是否采纳？**Phase 2 plan 给明确表格标「Phase 6 校准」。**
6. **drift 表 schema 具体列**：deferred to Phase 1/6 PLAN。
7. **Notification coalescing 窗口/冷却时长/每日上限**：推荐 4h + 20 条/天，Phase 5 UAT 调参。
8. **Binance combined-kline 消息确切 shape 与 `k.x` 语义**：Phase 3 plan 对照当前 fapi 文档确认。
9. **历史 funding rate / point-in-time universe 数据源**：Phase 6 research-phase 落实。

## Sources

### Primary (HIGH confidence)
- **pub.dev API** — fl_chart 1.2.0 (2026-03-13)、drift 2.33.0 (2026-05-03)、archive 4.0.2 版本与 SDK 约束。
- **Binance Official Docs** — USD-M futures WS（1024 streams/conn、10 msg/sec、`fstream.binance.com/stream`、`symbol@kline_interval`、`k.x`）；Kline REST（`fapi/v1/klines`、limit 1500、startTime 分页）。
- **data.binance.vision** — `data/futures/um/monthly/klines/{SYMBOL}/{INTERVAL}/{SYMBOL}-{INTERVAL}-{YYYY}-{MM}.zip` + `.CHECKSUM`。
- **内部代码库（直接文件检查）** — `lib/services/binance_websocket_manager.dart`、`kline_websocket_service.dart`、`pump_alert_service.dart`、`notification_service.dart`、`technical_indicators.dart`、`kline_cache_service.dart`、`binance_api_service.dart`（`getKlines` @475/491）、`database_helper.dart`；`.planning/codebase/ARCHITECTURE.md`/`CONCERNS.md`/`CONVENTIONS.md`；`.planning/PROJECT.md`。
- **Freqtrade docs** — lookahead-analysis 工具思路；Issue #11571 收盘确认延迟 ~2s。

### Secondary (MEDIUM confidence)
- **Greenrobot / community surveys (2025)** — Hive deprecated、Isar abandoned、drift maintained 多源共识。
- **CoinAPI / SusanPotter / Portfolio Optimization Book / Michael Harris** — backtest bias taxonomy（look-ahead/survivorship/零成本/curve-fitting 经典清单）。
- **FlutterFire docs** — `firebase_messaging` ~15.x 绑定 BoM 4.7.0 (Dec 2025)，延后采用再 pin。

### Tertiary (需验证)
- **工程判断**（手写 TA / sharded WS 轴 / event-replay backtest / local-notifications-first）— 作者领域推理，MEDIUM，plan-phase 验证。
- **sharding 轴 by-symbol vs by-timeframe 最优解** — 取决于 per-TF toggle UX 权重，Phase 3 research 落实。
- **point-in-time universe 数据源** — Phase 6 research 落实。

---
*Research completed: 2026-06-19*
*Ready for roadmap: yes*
