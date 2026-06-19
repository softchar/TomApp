# Pitfalls Research

**Domain:** 合约快速反弹监控 (Contract Quick-Rebound Monitoring) added to existing Flutter crypto app (Binance USDT futures, Riverpod, live WebSocket, existing pump detection)
**Researched:** 2026-06-19
**Confidence:** HIGH

本风险登记册塑造 v1.0 里程碑的路线图阶段与成功标准。TomApp 核心价值驱动排序:**「宁可漏报，不可误报刷屏」**——任何会让误报变多的坑，严重度自动上调一级。

---

## Critical Pitfalls

### Pitfall 1: 回测 Look-Ahead Bias（前瞻偏差）— 用了决策时刻拿不到的信息

**What goes wrong:**
回测里某根 K 线收盘那一刻就用了「这根 K 线的收盘价 / 这根 K 线算出来的 ATR / 当根 funding 快照」去决定是否触发反弹信号——而实盘里，这些值要到下一根 K 线开盘后才"确定"。结果：回测胜率虚高，实盘完全复现不了。

**Why it happens:**
向量化回测天然倾向于「同一行同时拿到 OHLC」。ATR/RSI/Bollinger 如果用 `t` 时刻收盘价算又在 `t` 时刻触发，就是在用未确认数据。funding rate 快照同理——它每 8 小时结算一次，t 时刻的 funding 在盘中是变化的。

**How to avoid:**
- 严格规则:**信号只能在 `bar[t].close` 已收盘、且指标用 `bar[0..t-1]` 计算**的前提下触发。换言之，t 根收盘触发信号、t+1 根开盘才进场。
- ATR(14) 在 t 根的值，要么用 t-1 根之前的 14 根算，要么显式标注「t 根收盘的 ATR 仅供 t+1 根决策使用」。
- 回测引擎实现成 **event-driven / 逐 bar 推进**，而非向量化 `df.shift()`——向量化的 shift 错位 bug 极难发现。
- 借鉴 Freqtrade 的 `lookahead-analysis` 思路:写一个测试,**故意把每根 bar 的 close 换成下一根的 open，若回测结果不变 → 说明你没用未来信息；若结果剧烈变化 → 有 look-ahead bug**。这是最强检测手段。

**Warning signs:**
- 回测胜率 > 70% 且无明显逻辑支撑（crypto 信号胜率 55-60% 已属优秀）。
- 信号触发的 timestamp 与 K 线收盘 timestamp 完全相等（说明用了当根收盘）。
- 向量化实现里出现 `df['atr'].iloc[i]` 同行比较。

**Phase to address:** 回测验证阶段（Backtest 模块）。**该阶段的 UAT 必须包含「lookahead-analysis 测试通过」**作为硬性成功标准。

---

### Pitfall 2: Survivorship Bias（幸存者偏差）— 只测至今还活着的币

**What goes wrong:**
历史回测用的标的池 = 「今天 Binance 上还在的 USDT 永续合约」。但 2023-2025 期间大量合约被下架（FTT、LUNA 系列、各种山寨）。下架的往往是**暴跌后被踢出**的——正是 V 型反弹策略最容易"捞到底"也会"接飞刀"的标的。只测活下来的币 → 策略看起来永远不会踩到归零标的。

**Why it happens:**
Binance `/fapi/v1/exchangeInfo` 只返回**当前**上市的合约。拉历史 K 线时，下架的币直接没有数据。最省事的实现就是用今天的标的池拉历史——这就是偏差入口。

**How to avoid:**
- 维护一份「历史标的成员表」(point-in-time universe):**某日 T 的回测只能用 T 当天还在线的合约**。
- 数据层至少要记录每个合约的 `onboardDate` 和 `delistDate`(Binance 有公告/接口)。
- **务实折中（MVP 可接受）**:v1 回测先在当前 top-100 流动性币种上跑（流动性高的币下架概率低，偏差小），但必须在回测报告里**显式声明这个限制**，并标注「结论不适用于小币」。不要假装这是全市场回测。

**Warning signs:**
- 回测报告里没有任何关于标的池的说明。
- 标的池固定不变，不随回测日期变化。
- 用户拿一个 2024 年下架的币测，发现数据直接缺失（说明 universe 没处理）。

**Phase to address:** 回测验证阶段。成功标准之一:**回测报告必须输出"标的池说明 + 时间范围 + 是否含下架币"三项元数据**。

---

### Pitfall 3: Curve-Fitting / Over-Optimization（过拟合）— 参数扫描调到历史噪声上

**What goes wrong:**
参数扫描（ATR 倍数 1.5-3.0、回补比例 40-60%、各周期权重...）网格组合可能有几千个。总能凑出一组参数在某段历史上表现亮眼——但这组参数只是**记住了历史噪声**，换段历史立刻失效。这是 TomApp 把阈值标为「起步值、由回测校准」决策的最大风险:校准成过拟合。

**Why it happens:**
参数越多、扫描越细、回测窗口越短，过拟合概率越趋近 100%。「在参数空间里找最优」本身就是 data snooping。

**How to avoid:**
- **Walk-forward validation**:把历史切成 N 段，前 N-1 段调参，第 N 段(out-of-sample)验证，滚动推进。只报告 out-of-sample 表现。
- **限制参数自由度**:v1 最多 3-4 个可调参数，且每个参数的物理含义明确（ATR 倍数=波动归一化、回补比例=反弹强度）。禁止为提升回测指标引入无意义参数。
- **敏感性分析**:最优参数 ±10% 时表现应平稳下降；若最优是一个尖锐峰值（邻居参数暴跌）→ 必然过拟合。
- 报告 out-of-sample 表现时，**默认打 30-50% 折扣**作为实盘预期（行业经验:回测收益打对折是合理预期）。

**Warning signs:**
- 回测最优参数的邻居参数表现断崖式下跌（尖锐峰）。
- 参数扫描结果「刚好」是一个不规整的值（如 ATR=2.37），说明在硬凑。
- in-sample 胜率 65%，out-of-sample 胜率 45%。

**Phase to address:** 回测验证阶段。**参数扫描功能必须强制 walk-forward 模式，禁止只报 in-sample 最优**。

---

### Pitfall 4: 回测忽略手续费 + 资金费 + 滑点（合约三连击）

**What goes wrong:**
合约反弹策略通常是**高频短线**（15m/1h 周期、持仓几小时），这意味着:
- 手续费(0.04% maker / 0.06% taker，来回 ~0.1-0.12%)反复扣。
- 持仓跨 8 小时资金费结算 → 可能吃掉全部利润。
- 反弹时刻往往伴随**极端波动 + 流动性真空**，滑点远超平时，尤其在小币上市价单可能滑 1-3%。

回测里这三项=0，结果一个亏损策略看起来稳定盈利。

**Why it happens:**
零成本回测最简单。funding 历史数据不好拿。滑点建模复杂。开发者默认"先看信号有效性再算成本"。

**How to avoid:**
- **最低底线**:手续费按 taker 0.06% 来回算（反弹进场大概率吃 taker），滑点按 0.1% 单边固定值，funding 按历史实际 funding rate 在持仓跨结算时扣除。
- 回测引擎必须支持「成本开关」，并能对比 `cost=0` vs `cost=realistic` 两条曲线——**如果开成本后策略从盈利变亏损，说明这是个被成本掩盖的伪策略**。
- 反弹信号触发时记录当时的 bid-ask spread（如果能拿到），用于估算真实滑点。

**Warning signs:**
- 回测平均每笔盈利 < 0.2%（基本被成本吃光）。
- 回测持仓时长中位数 > 8 小时（跨 funding 结算）却没扣 funding。
- 用户反馈「实盘每笔都比回测少赚一大截」。

**Phase to address:** 回测验证阶段。成功标准:**回测报告必须同时输出「零成本」与「含成本」两条结果**。

---

### Pitfall 5: WebSocket 在未收盘 K 线上计算 → 实盘 repaint（重绘）

**What goes wrong:**
Binance futures kline stream 每 ~250ms 推一次当前正在形成的 K 线(partial candle)。如果监控引擎在每次推送上都重新计算 ATR/反弹信号并刷新看板，会出现:
- 盘中 K 线还没收盘，ATR、回补比例都在跳，信号闪烁触发又消失。
- 用户看到的看板数字实时跳动，但收盘后又变样。
- 更糟:提醒在盘中触发了一次，收盘后信号消失——纯误报。

**Why it happens:**
Binance 的 kline 消息有个布尔字段 **`k.x`(Is this kline closed?)**。`k.x=false` 是 partial、`k.x=true` 才是收盘确认。引擎若不检查 `k.x`，就把 partial 当 final 用。注意:Freqtrade 社区指出 Binance futures 的 `k.x=true` 消息比名义收盘时间**晚 ~2 秒**到达，这是正常延迟。

**How to avoid:**
- **硬规则:所有信号/ATR/评分计算只在 `k.x == true` 的推送上触发**。partial 推送只用于刷新 UI 上的「实时价格」，不进信号管线。
- 在引擎层加一道断言:`assert message.k.x == true` 才调 `computeSignal()`。开发期就拦住。
- 处理收盘确认延迟(~2s):看板上可显示「等待 K 线收盘确认」状态，提醒比信号慢 2-3 秒属正常。
- 现有代码 `lib/providers/kline_provider.dart` 已经在每根 K 线更新上算 MACD/EMA——**新增反弹引擎必须与这个「逐 tick 重算」的旧模式隔离**，否则会继承 repaint bug。新建独立的 `ReboundSignalEngine`，只消费 closed-kline 事件。

**Warning signs:**
- 看板上同一个币的反弹评分在 15 分钟内来回跳动多次。
- 提醒触发后，用户点进去看，信号已经消失。
- 回测（用收盘 K 线）与实盘看板对不上——实盘多触发了一堆盘中假信号。

**Phase to address:** 反弹信号检测引擎阶段 + 实时看板阶段。**两个阶段的 UAT 都必须包含「partial 推送不触发信号」的单元测试**。

---

### Pitfall 6: WebSocket 在 ~400 标的 × 4 周期规模下的连接/限流风暴

**What goes wrong:**
现网 CONCERNS.md 已记录:`WebSocketManager` 重连逻辑硬编码(3-4 次)、多个 WebSocket 服务各自独立指数退避不协调、单连接容量限制。新增 400 标的 × 4 周期 = 1600 个 kline stream，若每个 symbol+TF 单开 stream → Binance 单连接订阅上限(约 1024 streams/连接 for combined)会被打爆，触发限流或断连。

**Why it happens:**
现有 pump 检测只跑 ticker + 单一 kline，连接数小。直接按老模式扩展到 1600 stream 不会立即报错，但在波动尖峰(全市场普跌/普涨)时消息洪流 + 重连风暴同时爆发，表现为「突然所有信号都停了 30 秒」。

**How to avoid:**
- 用 Binance **combined stream**(单连接多订阅)，单连接控制在 ~200-400 stream 以内，400 标的 × 4 周期拆成 2-4 个连接池。
- 关注 Binance **WebSocket 连接数限制**(每 IP ~300 连接)和**消息权重限制**，做客户端侧的限流退避。
- 重连逻辑改造:借鉴 CONCERNS.md 的修复方向——指数退避带上限 + jitter(避免所有连接同时重连的「重连风暴」)+ 全局连接协调器。
- 监控指标:每连接的消息速率、重连次数、确认收到 `k.x=true` 的根数 vs 预期。若某周期确认根数 < 预期 → 说明有 gap，看板信号可能 stale。

**Warning signs:**
- 波动大时看板大面积「卡住」或「集体更新延迟」。
- 日志里短时间内大量 reconnect。
- 某些币的信号永远不更新(订阅丢失但没报错)。

**Phase to address:** 多周期监控阶段（基础设施扩展）。**成功标准:在 400 标的全订阅下，连续运行 1 小时无未恢复断连、K 线收盘确认根数 ≥ 预期的 99%**。

---

### Pitfall 7: 重连 gap 导致 stale 信号 / 漏掉的 K 线

**What goes wrong:**
WebSocket 断连重连期间，恰好有 K 线收盘，那条 closed-kline 推送丢了。引擎不知道这根收盘了，于是:
- 该币这根的反弹信号没算 → 漏报(违反"宁可漏报不可误报"还能忍)。
- 更糟:下一根收盘时，ATR 用的是缺了一根的序列，计算错位 → 误报。

**Why it happens:**
重连后 Binance 不会补推历史 closed-kline。现有代码 `binance_websocket_manager.dart` 解析失败静默吞掉(CONCERNS.md 已记录)，gap 更隐蔽。

**How to avoid:**
- 重连成功后，**用 REST `/fapi/v1/klines` 回填缺口区间**(从最后确认的 K 线时间到当前)，把缺失的 closed-kline 补进序列再继续。
- 每个标的周期维护 `lastConfirmedCloseTime`，重连后据此回填。
- ATR/指标序列在补数据后必须**整体重算**(不能用增量)，避免错位。
- 解析失败不再静默吞(CONCERNS.md 已有修复方向)——记录计数，超阈值熔断告警。

**Warning signs:**
- 某些币的 ATR 值长期偏低(序列里混进了 0 或错位)。
- 重连后短时间内大量信号同时触发或同时静默。
- 日志显示重连但看不到回填 REST 调用。

**Phase to address:** 多周期监控阶段。与 Pitfall 6 同期解决。

---

### Pitfall 8: ATR/RSI 指标 warm-up + 数据源错误

**What goes wrong:**
- ATR(14) 需要至少 14 根历史 K 线才能给出有效值。新订阅的标的或刚上线的合约，前 14 根的 ATR 是 NaN 或垃圾值。若引擎在这期间触发信号，跌幅 2×ATR 的判断完全失效。
- RSI/Bollinger 同理有 warm-up。
- funding rate 与 liquidation cascade 在极端行情下扭曲价格:一根插针 K 线的 high/low 被 1 笔大单打出来又秒回，ATR 被这根异常 K 线拉爆，后续多根都失真。

**Why it happens:**
指标库通常静默返回 NaN 或部分值，调用方不检查。合约的 mark price vs last price 在插针时差异巨大——用 last price 算指标会被插针污染。

**How to avoid:**
- 引擎订阅标的后，**先用 REST 拉足够历史(至少 50-100 根)再开始计算**，期间该标的标记为 `warming-up`，不触发信号也不上提醒。
- ATR 对异常值敏感:用 **ATR 的中位数平滑或跳过单根异常 K 线**(如某根 TR > 5×中位数 TR 时标记为异常，不纳入或缩放)。
- 明确数据源:**信号用 mark price kline**(更平滑、抗插针、抗 manipulation)，last price 仅用于显示。Binance 提供 mark price kline stream。
- funding rate 作为**辅助过滤维度**(高正资金费 + 反弹 = 多头被套反弹概率高)，不直接进价格指标计算。

**Warning signs:**
- 刚订阅的标的立刻有信号触发。
- 某些标的 ATR 值明显离群(比同类币大一个数量级)。
- 插针后多个周期信号同时误触发。

**Phase to address:** 反弹信号检测引擎阶段。**成功标准:所有指标计算有 warm-up 保护；信号数据源明确为 mark price**。

---

### Pitfall 9: 误把"下跌中继 / 死猫反弹 / pump-dump 残留"当成真 V 型反转

**What goes wrong:**
V 型反弹策略最怕三类假信号:
- **下跌中继**:跌了一波，横盘喘息，再继续跌——回补比例刚好达到 50% 阈值，但趋势没反转。
- **死猫反弹**:暴跌后必然有技术反弹，反弹幅度可能到 50%+，但反弹完继续创新低。
- **pump-dump 残留**:TomApp 本身就在检测 pump——一个 pump 后的 dump，K 线形态上酷似"先跌后弹"，其实是同一个 pump 事件的尾部。

**Why it happens:**
"跌幅 2×ATR + 回补 50%" 是**形态匹配**，不包含"是否真的反转"的语义。形态匹配会捕获所有相似 K 线组合，包括上面三类。

**How to avoid:**
- **多周期共振**:要求至少 2 个周期(如 1h + 4h)同时出现反弹结构，才升级为高置信信号。单一周期的形态不触发高等级提醒(守住"宁可漏报不可误报")。
- **量能确认**:反弹段成交量需 > 下跌段均量的某个倍数(无量反弹大概率是死猫)。
- **趋势过滤**:反弹前不能处于强下跌趋势的中段(用更大周期如 1d 的 EMA 斜率过滤)。
- **去重**:与近期(如 24h 内)的 pump 检测事件做关联——如果是某 pump 的 dump 残留，降级或跳过。
- **评分制而非二元**:0-100 评分，只有高分(如 ≥75)才触发提醒，低分仅上看板。这正好契合 PROJECT.md 的"反弹强度评分 0-100"决策。
- **纪律性止损披露**:信号始终附带建议止损位(如反弹起点下方)，明示"这是监控候选，不是买入指令"。

**Warning signs:**
- 信号触发后继续下跌的比例 > 40%。
- 信号集中在已 pump 过的币上(其实是 dump 残留)。
- 单周期信号数远多于多周期共振信号(说明共振过滤没起作用)。

**Phase to address:** 反弹信号检测引擎阶段(共振 + 评分 + 量能) + 推送提醒阶段(分级)。

---

### Pitfall 10: 阈值过拟合到历史噪声(共振/评分维度)

**What goes wrong:**
Pitfall 3 的变种:把回补比例、共振权重、量能倍数、评分各维度权重一起调，参数空间爆炸，最后调出一组在 2024 某段历史上"完美区分真假反弹"的参数——其实是记住了那段的噪声。

**Why it happens:**
评分系统天然鼓励"调权重让回测好看"。维度越多越容易过拟合。

**How to avoid:**
- **权重先验**:评分各维度权重先用**业务直觉固定**(跌幅深 30%、回补强 30%、共振 25%、量能 15%)，不进参数扫描。只扫物理含义明确的阈值(回补比例、ATR 倍数)。
- 真要扫权重，必须 walk-forward + out-of-sample，且报告权重稳定性。
- 反弹引擎的"可调旋钮"数量写进文档上限(如 ≤5 个)，超出需评审。

**Warning signs:**
- 评分权重是小数点后两位的精确值。
- 加了权重维度后回测显著变好但 out-of-sample 变差。

**Phase to address:** 反弹信号检测引擎阶段(先固定权重) + 回测阶段(只扫阈值)。

---

### Pitfall 11: Alert Spam(提醒轰炸)— 同币每根 K 线重触发，毁掉信任

**What goes wrong:**
没有去重/冷却:某币连续 3 根 15m K 线都满足反弹形态 → 连发 3 条提醒。4 个周期都满足 → 4 条。400 标的 × 波动期 → 每分钟几十条推送。用户 5 分钟内关通知。**直接违背 TomApp 核心价值「宁可漏报，不可误报刷屏」**。

**Why it happens:**
信号引擎是无状态的——每根 K 线收盘独立判断，不记得"这个币这个周期刚报过"。多周期各自独立 → 同一事件 N 倍放大。

**How to avoid:**
- **每币全局冷却**:同一币触发后，至少 N 小时(如 4h)内不再提醒，无论哪个周期。冷却期内的信号仅上看板。
- **事件归并**:同一币短时间内多周期共振触发 → 合并成**一条**「多周期共振」高级提醒，而非多条。
- **周期独立开关 + 分级**:用户可独立关 15m/1h/4h/1d；只高分(≥阈值)才推送，低分仅看板。
- **每日提醒总量上限**:如硬上限 20 条/天，超额后只保留最高分。
- **静默窗口**:极度波动期(如全市场 1h 跌幅 > X%)进入静默——这种时候全是反弹信号，但全是噪声，符合"宁可漏报"。

**Warning signs:**
- 用户反馈"通知太多关了"。
- 单日提醒数 > 50 条。
- 同一币一天提醒 > 2 次。

**Phase to address:** 推送提醒阶段。**成功标准(UAT):构造一个币连续 4 根 K 线满足信号的场景，验证只收到 1 条提醒**。

---

### Pitfall 12: 合约专属陷阱 — 强平连环爆制造的假 V 形 + 资金费/mark价/下架

**What goes wrong:**
合约特有的几个扭曲:
- **强平连环爆(liquidation cascade)**:价格跌穿关键位 → 多头连环强平 → 价格插针暴跌 → 强平买回 → V 型反弹 K 线完美成形。但这是**机械性强平反弹**，不是价值反转，往往反弹完继续跌。形态上和真 V 反弹无法区分。
- **funding rate 快照**:高正资金费(多头拥挤)时反弹概率和性质与平常不同，忽略这个维度丢失信息。
- **mark vs last price**:last price 易被单笔大单/低流动性扭曲，用它算信号 → 插针误触发。
- **合约下架/标的 churn**:USDT 永续下架频繁，watchlist 里残留已下架合约 → 订阅失败、信号 stale、看板出现"幽灵币"。

**Why it happens:**
现货思维套到合约。现货没有强平、没有资金费、没有 mark 价。代码若复用现货 K 线处理逻辑，这些维度全丢。

**How to avoid:**
- 信号数据源用 **mark price kline**(Pitfall 8 已述)，last price 仅展示。
- 把**近期强平密度**(Binance 有强平流)作为辅助过滤:强平密集期的反弹降级处理。
- funding rate 作为信号维度或过滤(高正资金费 + 反弹 = 多头解套型，性质偏空；资金费转负 + 反弹更可信)。
- **watchlist 动态维护**:定期(如每小时)用 `/fapi/v1/exchangeInfo` 刷新合约列表，自动剔除已下架合约，避免幽灵币。
- 文档明确:**v1 信号是监控候选，不预测强平反弹能否延续**——交给用户结合强平流自行判断。

**Warning signs:**
- 信号大量集中在刚发生强平瀑布的币。
- 看板上出现订阅失败/数据为空的标的(疑似下架未清理)。
- 用 last price 算的信号与 mark price 信号对不上。

**Phase to address:** 反弹信号检测引擎阶段(mark price 数据源) + 多周期监控阶段(watchlist churn 管理)。

---

### Pitfall 13: 回测结果让用户产生虚假信心 + 把信号当"买入指令"

**What goes wrong:**
回测报告显示"过去 6 个月胜率 65%"，用户据此加杠杆实盘 → 亏惨。原因:
- 回测胜率 ≠ 实盘期望(Pitfall 1/3/4 叠加)。
- 信号被呈现为"买入信号"，用户理解为"买了就涨"。
- 无免责声明 → 法律与信任风险。

**Why it happens:**
回测 UI 天然倾向展示亮眼数字。开发者也想证明策略有效。但 crypto 信号的不确定性极高，65% 回测胜率实盘可能 45%。

**How to avoid:**
- **文案定位**:所有反弹信号在 UI 上标注为「**监控候选 / 关注名单**」，禁用「买入」「强买」「信号」等暗示执行的词。
- **回测报告强制披露**:页头固定显示「回测结果含 look-ahead 已检 / 含手续费资金费滑点 / 标的池说明 / out-of-sample 表现」四项；缺一项不让展示。
- **预期管理文案**:回测页固定提示「回测表现通常需打 30-50% 折扣作为实盘预期；本工具不构成投资建议」。
- 每条信号附带**建议止损位 + 风险提示**，而非止盈位。
- 回测模块的 UAT 包含「报告必须包含免责声明」检查。

**Warning signs:**
- UI 上出现"买入""强买"字样。
- 回测报告页无免责声明。
- 用户反馈"按信号操作亏了"。

**Phase to address:** 回测验证阶段(报告披露) + 实时看板/推送阶段(信号文案定位)。

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| 信号引擎在 partial kline 上也算 | 看板"实时感"强 | repaint、误报、违反核心价值 | 永不可接受 |
| 回测用当前标的池(不处理下架币) | 实现快 10 倍 | survivorship bias、结论失真 | 仅 top 流动性币种且报告明示限制 |
| 零成本回测 | 简单 | 伪策略看起来盈利 | 仅作为对照基线，必须同时出含成本版本 |
| 向量化回测(非 event-driven) | 快、代码短 | look-ahead bug 极难发现 | 永不可接受(反弹策略必须 event-driven) |
| 每币每根 K 线独立无状态触发提醒 | 逻辑简单 | alert spam | 仅看板更新，不可用于推送 |
| 评分权重进参数扫描 | 回测更好看 | 过拟合 | 永不可接受(权重先固定) |
| last price 算信号 | 数据现成 | 插针误触发 | 仅展示用，信号必须 mark price |
| 复用现有逐 tick 重算的 kline_provider 管线 | 少写代码 | 继承 repaint bug | 永不可接受(建独立 ReboundSignalEngine) |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Binance futures kline WS | 不检查 `k.x`，partial 当 final | 只在 `k.x==true` 触发信号；接受 ~2s 收盘确认延迟 |
| Binance combined stream | 1600 stream 单连接 | 拆 2-4 连接池，每池 ≤400 stream，遵守 IP 连接数限制 |
| 重连后历史回填 | 不补缺口直接继续 | REST `/fapi/v1/klines` 按 `lastConfirmedCloseTime` 回填后重算指标 |
| mark price kline stream | 用 last price 算信号 | 信号用 mark price kline；last price 仅显示 |
| funding rate | 回测不扣 / 当普通维度 | 持仓跨结算扣历史实际 funding；作为辅助过滤维度 |
| `/fapi/v1/exchangeInfo` | 一次性拉取后不更新 | 定期刷新(≥1h)自动剔除下架合约，避免幽灵币 |
| 强平流 | 忽略 | 作为辅助维度，强平密集期反弹降级 |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| 逐 tick 全量重算指标(继承 kline_provider 模式) | CPU 飙升、UI 卡顿 | 只在 closed-kline 增量计算，独立引擎 | 400 标的 × 波动期 |
| 每标的单开 WS 连接 | 连接数爆炸、被 Binance 限流 | combined stream + 连接池 | >50 标的 |
| 重连风暴(多连接同时退避) | 全市场信号同时停 30s | jitter + 全局协调器 | 网络抖动/波动尖峰 |
| 看板全量 notifyListeners | rebuild storm | 仅变更项增量刷新、debounce | 400 标的实时更新 |
| 回测全量重算(非增量) | 一次扫描跑数小时 | 增量指标、缓存中间值 | 参数扫描网格大 |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| 无 API 限流(CONCERNS.md 已记) | IP 被 Binance 封 | 重连回填等 REST 调用走限流队列 + 指数退避 |
| 信号引擎解析 WS 消息静默吞异常(CONCERNS.md) | 静默丢数据、信号 stale | 解析失败计数 + 熔断告警 |
| 本地存储无加密(CONCERNS.md) | 用户偏好/设置泄露 | 复用既有修复路线 |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| 信号文案当"买入指令" | 用户据此加杠杆亏损、信任崩塌 | 定位"监控候选"，附止损位 + 免责声明 |
| 回测页只展示亮眼胜率 | 虚假信心、过度交易 | 强制披露 4 项元数据 + 预期折扣提示 |
| 看板无 warm-up 状态 | 新订阅标的立刻出垃圾信号 | 标的标记 warming-up，保护期内不触发 |
| 提醒无冷却/分级 | 通知轰炸、用户关闭通知 | 全局冷却 + 事件归并 + 总量上限 + 周期独立开关 |
| 提醒带止盈不带止损 | 助长赌徒式操作 | 信号只附止损位 + 风险提示 |
| 多周期共振不归并 | 同事件 N 条提醒 | 共振合并为单条高级提醒 |

## "Looks Done But Isn't" Checklist

- [ ] **反弹引擎:** 检查是否真的只在 `k.x==true` 触发——单元测试塞 partial 消息，断言不触发。
- [ ] **ATR 计算:** 检查 warm-up——新订阅标的头 14 根是否被标记 warming-up 不触发。
- [ ] **回测:** 检查 lookahead-analysis——把 close 换成下根 open 结果应不变。
- [ ] **回测:** 检查成本——零成本 vs 含成本两条曲线都出了吗？
- [ ] **回测:** 检查标的池——报告是否声明 universe 处理方式？
- [ ] **回测:** 检查 walk-forward——是否只报 in-sample 最优？
- [ ] **推送:** 检查冷却——同币连续 4 根 K 线满足是否只推 1 条？
- [ ] **推送:** 检查共振归并——多周期同时满足是否合并为 1 条？
- [ ] **信号文案:** 全文 grep 是否出现"买入/强买"等执行性词(应为"监控候选")？
- [ ] **回测/看板免责声明:** 页面是否固定显示免责声明？
- [ ] **watchlist churn:** 是否定期刷新 exchangeInfo 剔除下架合约？
- [ ] **数据源:** 信号是否用 mark price 而非 last price？
- [ ] **重连回填:** 重连后是否有 REST 回填 + 指标重算？

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| repaint(在 partial 上算) | MEDIUM | 引擎加 `k.x` 检查断言 + 重跑历史信号回归测试 |
| alert spam(无冷却) | LOW | 加全局冷却表 + 事件归并 + 总量上限，纯增量改造 |
| look-ahead bug | HIGH | 重写回测为 event-driven + 跑 lookahead-analysis，历史结论作废重测 |
| survivorship bias | HIGH | 重建 point-in-time universe、重拉含下架币历史、全部回测重跑 |
| curve-fitting 已上线参数 | HIGH | 改 walk-forward、降级现有参数为先验、重新校准 |
| last price 误触发 | MEDIUM | 信号源切 mark price，历史信号重算 |
| 幽灵币(下架未清) | LOW | 加 exchangeInfo 定期刷新 + watchlist 自动剔除 |
| 过拟合权重已写死 | MEDIUM | 权重回退到业务先验，只扫阈值 |

## Pitfall-to-Phase Mapping

> 假设 v1.0 路线图含如下阶段(供 roadmapper 参考，最终阶段名以实际为准):
> - **P1 反弹信号检测引擎**(三阶段检测 + ATR/指标 + warm-up + mark price 数据源)
> - **P2 多周期监控基础设施**(WS 连接池 + 重连回填 + watchlist churn + ~400 标的)
> - **P3 反弹强度评分 + 共振过滤**(0-100 评分、量能、趋势过滤、去重)
> - **P4 实时看板**(周期 Tab、评分排序、增量更新、文案定位)
> - **P5 推送提醒**(分级、冷却、归并、总量上限、周期开关)
> - **P6 回测验证**(event-driven 引擎、lookahead 检测、walk-forward、成本建模、survivorship 处理、报告披露)

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1 Look-ahead bias | P6 回测 | lookahead-analysis 测试通过(close 换下根 open 结果不变) |
| 2 Survivorship bias | P6 回测 | 报告输出 universe 说明；top 流动性币种回测显式标注限制 |
| 3 Curve-fitting | P6 回测 | 强制 walk-forward；只报 out-of-sample；敏感性分析无尖锐峰 |
| 4 忽略手续费/资金费/滑点 | P6 回测 | 同时输出零成本与含成本两曲线 |
| 5 WS partial repaint | P1 引擎 + P4 看板 | 单测塞 partial 消息断言不触发信号 |
| 6 WS 连接/限流风暴 | P2 多周期 | 400 标的连续 1h 无未恢复断连；确认根数 ≥99% |
| 7 重连 gap/stale | P2 多周期 | 重连后 REST 回填 + 指标重算；日志可见回填调用 |
| 8 指标 warm-up + 数据源 | P1 引擎 | 新订阅标的头 14 根 warming-up 不触发；信号用 mark price |
| 9 假信号(死猫/中继/dump残留) | P1 引擎 + P3 评分共振 | 多周期共振才升级；量能+趋势过滤；与 pump 事件去重 |
| 10 评分权重过拟合 | P3 评分 + P6 回测 | 权重业务先验固定；只扫阈值；旋钮数有上限 |
| 11 Alert spam | P5 推送 | 同币连续 4 根满足只推 1 条；共振归并单条 |
| 12 合约专属(强平/mark/下架) | P1 引擎 + P2 多周期 | 信号用 mark price；强平密集期降级；watchlist 自动剔下架 |
| 13 虚假信心/买入指令文案 | P4 看板 + P5 推送 + P6 回测 | grep 无执行性词；免责声明固定显示；回测报告 4 项披露齐全 |

## Sources

- [Binance USDS-M Futures Kline/Candlestick Streams — 官方文档(确认 `k.x`=is-this-kline-closed 字段)](https://developers.binance.com/docs/derivatives/usds-margined-futures/websocket-market-streams/Kline-Candlestick-Streams)
- [Freqtrade Issue #11571 — Binance futures 收盘确认消息比名义收盘晚 ~2 秒](https://github.com/freqtrade/freqtrade/issues/11571)
- [Freqtrade Lookahead Analysis — 自动检测 look-ahead bias 的工具思路](https://www.freqtrade.io/en/stable/lookahead-analysis/)
- [CoinAPI — How to Eliminate Survivorship Bias in Crypto Backtesting(下架币处理)](https://www.coinapi.io/blog/how-to-eliminate-survivorship-bias-in-crypto-backtesting)
- [SusanPotter — A Taxonomy of Backtest Lies(lookahead/survival/零成本三类偏差)](https://www.susanpotter.net/quant/backtest-bias-taxonomy/)
- [Portfolio Optimization Book — 8.2 The Seven Sins of Quantitative Investing(survivorship/lookahead/成本忽略经典清单)](https://portfoliooptimizationbook.com/book/8.2-seven-sins.html)
- [Michael Harris (Medium) — Look-ahead Bias in Backtests and How to Detect It](https://mikeharrisny.medium.com/look-ahead-bias-in-backtests-and-how-to-detect-it-ad5e42d97879)
- 内部代码库:`.planning/codebase/CONCERNS.md`(WS 重连硬编码、解析静默吞、无限流、逐 tick 重算等技术债)
- 内部代码库:`.planning/codebase/ARCHITECTURE.md`(4 层架构、kline_provider 逐 tick 重算模式、pump_detector 容量阈值)

---
*Pitfalls research for: 合约快速反弹监控 (Contract Quick-Rebound Monitoring) added to TomApp*
*Researched: 2026-06-19*
