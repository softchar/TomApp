# Requirements: TomApp — 合约快速反弹监控

**Defined:** 2026-06-19
**Core Value:** 在第一时间可靠地识别异常行情信号（拉盘 / V 型快速反弹）并及时提醒交易者——宁可漏报，不可误报刷屏。

## v1 Requirements

本里程碑 v1.0「多周期合约反弹监控」需求。每条映射到 ROADMAP 阶段（见 Traceability）。

### INDIC — 技术指标基础（前置）

- [ ] **INDIC-01**: 提供 ATR(14) 计算（live 与回测同一实现，保证 2×ATR 阈值与 0.3×ATR 止损一致）
- [ ] **INDIC-02**: 提供 RSI(14) 计算（含超卖拐头判定）
- [ ] **INDIC-03**: 提供 Bollinger Bands 计算
- [ ] **INDIC-04**: 提供 swing high/low 识别

### DETECT — 反弹信号检测（纯函数）

- [ ] **DETECT-01**: 下跌段检测（跌幅 ≥2×ATR + 各周期 % 兜底，≤3 根 K 线内完成）
- [ ] **DETECT-02**: 拉回段检测（回补跌幅 ≥50%、≤2 根内、收盘价站上跌幅中点）
- [ ] **DETECT-03**: 共振过滤（放量 ≥1.5× 下跌段均量、RSI 超卖拐头、支撑位、K 线形态）
- [ ] **DETECT-04**: 检测器为纯函数，live 与回测共用同一逻辑（单一真源）

### SCORE — 评分与死猫风险

- [ ] **SCORE-01**: 输出 0-100 强度评分（回补比例/速度/量能/共振加权）
- [ ] **SCORE-02**: 输出死猫反弹风险分（区分真反转 vs 死猫弹/下跌中继）
- [ ] **SCORE-03**: 评分权重业务先验固定（不进参数扫描）

### MONITOR — 多周期实时监控

- [ ] **MONITOR-01**: 15m/1h/4h/日 四周期独立监控反弹信号
- [ ] **MONITOR-02**: 仅 K 线收盘（`k.x==true`）触发检测，杜绝 repaint
- [ ] **MONITOR-03**: sharded combined-stream WebSocket 订阅多币多周期（~400 USDT 永续）
- [ ] **MONITOR-04**: 新订阅 warm-up（先 REST 拉 ≥50-100 根历史）期间不触发
- [ ] **MONITOR-05**: 重连后 REST 回填缺口 K 线并整体重算指标
- [ ] **MONITOR-06**: 定期刷新 exchangeInfo 自动剔除下架合约（无幽灵币）
- [ ] **MONITOR-07**: 信号用 mark price（非 last price）数据源
- [ ] **MONITOR-08**: 多周期共振检测（同币多周期同步反弹→升级信号）

### DASH — 实时看板

- [x] **DASH-01**: 按周期分 Tab（15m/1h/4h/日）的实时反弹信号看板
- [x] **DASH-02**: 按评分排序，显示币种/周期/跌幅/回补%/评分/迷你 sparkline
- [ ] **DASH-03**: 标注死猫风险（图标/颜色）+ 止损参考位
- [ ] **DASH-04**: 显示 warm-up 状态（未就绪不展示信号）
- [ ] **DASH-05**: 文案统一「监控候选」+ 风险提示（禁用「买入/强买/信号」措辞）
- [ ] **DASH-06**: 点击信号下钻到 K 线详情（复用 KlineScreen）

### ALERT — 推送提醒

- [ ] **ALERT-01**: 强信号分级推送（high 响铃+vibrate / med 横幅 / low 仅看板）
- [ ] **ALERT-02**: 每币全局冷却（4h 内同币不重复推送，冷却期仅看板可见）
- [ ] **ALERT-03**: 跨周期事件归并（共振合并为 1 条）
- [ ] **ALERT-04**: 每周期可独立开关推送
- [ ] **ALERT-05**: 每日推送总量上限（20 条/天，超额留最高分）
- [ ] **ALERT-06**: 同币连续多根 K 线满足只推 1 条（UAT 硬标准）

### BACKTEST — 回测验证

- [ ] **BACKTEST-01**: 导入 Binance 历史 K 线（data.binance.vision ZIP 批量 + REST gap-fill）
- [ ] **BACKTEST-02**: event-driven 逐 bar 回放（复用同一 ReboundDetector，保证对 live 有效）
- [ ] **BACKTEST-03**: 模拟交易（进场 / 止损 swing-low−0.3×ATR / 止盈 61.8% 与 100% Fib，含手续费资金费滑点）
- [ ] **BACKTEST-04**: 报告同屏显示 胜率/平均 R/盈亏比/最大回撤 + 样本数 N
- [ ] **BACKTEST-05**: 零成本 vs 含成本双曲线对比
- [ ] **BACKTEST-06**: 通过 lookahead-analysis 检验（防前视偏差）
- [ ] **BACKTEST-07**: 强制四项披露（前视已检/含成本/标的池/out-of-sample）+ 免责声明（打 30-50% 折扣，非投资建议）

## v2 Requirements

延后到后续发布。已登记，不在本路线图。

### 参数扫描与策略增强

- **SCAN-01**: 完整 walk-forward 参数扫描（v1 仅小网格）
- **SCAN-02**: 进场止损参考价展示
- **SCAN-03**: 共振雷达（跨币种同步反弹热力图）

### 扩展

- **EXT-01**: 多交易所支持（OKX / Bybit）
- **EXT-02**: 现货反弹监控
- **EXT-03**: 「大周期定方向、小周期找进场」层级策略
- **EXT-04**: 自动下单 / 策略执行（需先经回测验证）
- **EXT-05**: AI/ML 信号增强（需标注数据，黑盒可回测后再议）

## Out of Scope

显式排除，防止范围蔓延。

| Feature | Reason |
|---------|--------|
| 自动下单 / 实盘执行 | 风险最高，先用回测验证信号有效性再谈执行（v2 EXT-04） |
| 非法措辞（「买入/强买/保证盈利」） | 合规 + 过拟合风险；统一用「监控候选」+ 免责声明 |
| 只展示胜率 | 致命误导（胜率 80% 可能负期望）；必须四指标同屏 |
| 每根 tick 重算信号 | 性能 + repaint 风险；只在 K 线收盘算 |
| 现货 / 非 Binance 交易所 | 现有基础设施仅 Binance 合约（v2 EXT-01/02） |
| 迁移 KlineScreen 到 fl_chart | 与本里程碑无关，留待 cleanup 阶段 |
| 全市场 ~400 标的 默认开启 | 移动端承载有限；v1 默认 watchlist + Top N（待 Phase 3 确认） |

## Traceability

哪些阶段覆盖哪些需求。由 roadmapper 在路线图创建时填充（路线图见 `.planning/workstreams/contract-quick-rebound/ROADMAP.md`）。

| Requirement | Phase | Status |
|-------------|-------|--------|
| INDIC-01 | Phase 1 | Pending |
| INDIC-02 | Phase 1 | Pending |
| INDIC-03 | Phase 1 | Pending |
| INDIC-04 | Phase 1 | Pending |
| DETECT-01 | Phase 2 | Pending |
| DETECT-02 | Phase 2 | Pending |
| DETECT-03 | Phase 2 | Pending |
| DETECT-04 | Phase 2 | Pending |
| SCORE-01 | Phase 2 | Pending |
| SCORE-02 | Phase 2 | Pending |
| SCORE-03 | Phase 2 | Pending |
| MONITOR-01 | Phase 3 | Pending |
| MONITOR-02 | Phase 3 | Pending |
| MONITOR-03 | Phase 3 | Pending |
| MONITOR-04 | Phase 3 | Pending |
| MONITOR-05 | Phase 3 | Pending |
| MONITOR-06 | Phase 3 | Pending |
| MONITOR-07 | Phase 3 | Pending |
| MONITOR-08 | Phase 3 | Pending |
| DASH-01 | Phase 4 | Complete |
| DASH-02 | Phase 4 | Complete |
| DASH-03 | Phase 4 | Pending |
| DASH-04 | Phase 4 | Pending |
| DASH-05 | Phase 4 | Pending |
| DASH-06 | Phase 4 | Pending |
| ALERT-01 | Phase 5 | Pending |
| ALERT-02 | Phase 5 | Pending |
| ALERT-03 | Phase 5 | Pending |
| ALERT-04 | Phase 5 | Pending |
| ALERT-05 | Phase 5 | Pending |
| ALERT-06 | Phase 5 | Pending |
| BACKTEST-01 | Phase 6 | Pending |
| BACKTEST-02 | Phase 6 | Pending |
| BACKTEST-03 | Phase 6 | Pending |
| BACKTEST-04 | Phase 6 | Pending |
| BACKTEST-05 | Phase 6 | Pending |
| BACKTEST-06 | Phase 6 | Pending |
| BACKTEST-07 | Phase 6 | Pending |

**Coverage:**

- v1 requirements: 38 total
- Mapped to phases: 38 ✓
- Unmapped: 0

**Phase distribution:** Phase 1 (4) · Phase 2 (7) · Phase 3 (8) · Phase 4 (6) · Phase 5 (6) · Phase 6 (7)

---
*Requirements defined: 2026-06-19*
*Last updated: 2026-06-19 after roadmap creation (traceability filled)*
