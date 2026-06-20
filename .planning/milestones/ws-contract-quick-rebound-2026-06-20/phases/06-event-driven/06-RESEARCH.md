# Phase 06: 回测验证（event-driven 引擎 + 偏差防护 + 报告披露） — 研究

**Researched:** 2026-06-20
**Domain:** 加密货币回测引擎 / event-driven 逐 bar 回放 / Binance 历史数据管线 / walk-forward 参数优化 / 偏差防护测试
**Confidence:** HIGH

## 摘要

Phase 6 构建一个 event-driven 逐 bar 回测引擎，复用 Phase 2 同一 `ReboundDetector.evaluate` 纯函数，验证反弹信号在历史 Binance 合约 K 线数据上的有效性。回测引擎包含三条独立管线：(1) 历史数据导入管线——从 data.binance.vision 月度 ZIP 批量下载 USDT 永续 K 线并解析写入 drift `Klines` 表，缺口通过 REST 补足；(2) 回测运行管线——逐 bar 消费 K 线序列、调用 detector、模拟交易（含手续费/资金费/滑点）、walk-forward 参数扫描；(3) 报告 UI 管线——Provider 驱动的 BacktestScreen 展示双曲线权益图、统计汇总、可下钻交易列表、四项强制披露。

核心技术难点在对前视偏差（lookahead bias）的防御。关键检测手段是 Freqtrade 风格的 lookahead-analysis 测试：将每根 bar 的 close 替换为下一根的 open，重跑回测，结果应完全不变——这是 Phase 6 的硬性 UAT 标准。引擎必须 event-driven 逐 bar 推进，禁止向量化（向量化 `df.shift()` 错位 bug 极难发现）。

**主要推荐：** event-driven 引擎纯 Dart 手写实现（无现成库），数据导入复用 archive 4.0.2（已安装）解析 ZIP，权益曲线复用 fl_chart 1.2.0（已安装）LineChart，参数扫描走 320 组合 anchored walk-forward 3-fold，报告只报 out-of-sample。

<phase_requirements>
## 阶段需求

| ID | 描述 | 研究支持 |
|----|------|----------|
| BACKTEST-01 | 导入 Binance 历史 K 线（data.binance.vision ZIP 批量 + REST gap-fill） | 数据源格式已确认 (Section 4.1)；REST 端点已查证 (Section 4.2)；Dart archive 解压方案已确认 (Section 4.3) |
| BACKTEST-02 | event-driven 逐 bar 回放（复用同一 ReboundDetector） | 引擎设计模式已研究 (Section 4.5)；lookahead 防御已确认 (Section 4.4) |
| BACKTEST-03 | 模拟交易（进场/止损/止盈/手续费/资金费/滑点） | 成本模型已确认 (Section 4.6)；funding rate 数据源已查证 (Section 4.2) |
| BACKTEST-04 | 报告显示胜率/平均 R/盈亏比/最大回撤 + 样本数 N | 监控指标计算已明确 (Section 4.8) |
| BACKTEST-05 | 零成本 vs 含成本双曲线对比 | fl_chart 多系列 LineChart 方案已确认 (Section 4.7) |
| BACKTEST-06 | 通过 lookahead-analysis 检验 | Freqtrade lookahead-analysis 方法论已查证 (Section 4.4) |
| BACKTEST-07 | 强制四项披露 + 免责声明 | 披露模板已从 CONTEXT.md D-20/D-21 确认 |
</phase_requirements>

<user_constraints>
## 用户约束（来自 CONTEXT.md）

### 已锁定决策

| 决策 ID | 内容 | 研究重点 |
|---------|------|----------|
| D-01 | next-open 进场——信号在 bar[t].close 触发，t+1.open 进场 | 确认引擎不产生 lookahead |
| D-02 | 固定止损：swing-low - 0.3*ATR(14) | 出场规则参数化设计 |
| D-03 | 双止盈：61.8% Fib 退出 50% 仓位 + 100% Fib 退出剩余 50% | 仓位分批退出建模 |
| D-04 | 时间退出：maxHoldBars（默认 20 根） | timeout exit 实现 |
| D-05 | 持仓跨 8h 整点扣历史 funding rate | funding 数据获取方案 |
| D-06 | 成本模型：taker 0.06% 来回 + 滑点 0.1% 单边；成本开关必须支持 | 双曲线总是产出 |
| D-07 | 数据源：data.binance.vision 月度 ZIP → drift Klines 表 | 管线架构方案 |
| D-08 | 标的池：Top-100 流动性币种（按 24h 交易量排序），v1 不做 point-in-time | 数据集范围 |
| D-09 | 历史数据范围：默认 6 个月（~180 天），用户可调起止日期 | 窗口配置化 |
| D-10 | 3-fold 锚定 walk-forward：训练窗口不断增长，测试窗口固定 1 月 | 切片策略锁定 |
| D-11 | 只报告 out-of-sample 聚合指标，禁止报 in-sample 最优 | 报告生成约束 |
| D-12 | 扫描 4 个阈值共 320 组合：dropAtrMultiplier(4) * recoveryMinRatio(5) * dropMaxCandles(4) * volumeMultiplier(4) | 参数网格固定 |
| D-13 | 评分权重（30/30/25/15）不进参数扫描 | 权重固定 |
| D-14 | 共振过滤器开关不进参数扫描，v1 全部保持默认开启 | 过滤器固定 |
| D-15 | Event-driven 逐 bar 推进，非向量化。禁止向量化 | 引擎架构强制 |
| D-16 | 引擎从 drift Klines 表读取，不直接读文件 | 数据抽象层 |
| D-17 | Lookahead-analysis 测试：close→下根 open 结果不变（UAT 硬标准） | 测试设计 |
| D-18 | 独立 BacktestScreen，入口在底部导航或 ProfileScreen | UI 入口位置 |
| D-19 | 报告内容：权益曲线（双曲线）+ 统计卡 + 交易列表 + 下钻 | UI 布局 |
| D-20 | 四项强制披露（缺一项不让展示报告） | 显示守卫 |
| D-21 | 免责声明固定显示 | UI 固定元素 |
| D-22 | 信号文案零执行词：全文禁止"买入/强买/信号/推荐" | 文案审查 |

### Claude 自主决定范围

- 数据导入管线下载解压的具体实现（下载并发数、解压路径、批量写入策略）
- 权益曲线绘图库选择（复用 fl_chart 1.2.0 或引入新库）
- BacktestScreen 入口位置（底部导航新 Tab vs ProfileScreen 入口按钮）
- Walk-forward 折叠是否可配置（v1 硬编码 3-fold）
- 参数扫描网格大小是否可配置（v1 硬编码 320 组合）

### 已延后想法（不在 Phase 6 范围）

- 完整 walk-forward 参数扫描增强（SCAN-01）
- 参数扫描网格可配置化
- Walk-forward 折叠数可配置化
- Point-in-time universe（历史标的成员表）
- 移动止损/Trailing Stop
- 多币并发仓位管理
- 参数扫描并行化（Isolate）
- 回测结果导出 CSV/PDF
</user_constraints>

## 架构责任映射

| 能力 | 主要层 | 次要层 | 理由 |
|------|--------|--------|------|
| 历史数据下载+解析+写入 | Service (Data Import) | Data (drift DAO) | 管线含业务逻辑（时间戳标准化、gap 检测），但最终写操作走 drift DAO |
| Event-driven 回测引擎核心 | Service (BacktestEngine) | — | 纯计算逻辑，无 I/O，调用 Phase 2 detector 纯函数 |
| 模拟交易（进场/出场/成本） | Service (BacktestEngine) | Model (Trade/Position) | 交易状态机在引擎内，数据结构在 model |
| Walk-forward 参数扫描编排 | Service (BacktestEngine) | Provider (BacktestProvider) | 扫描循环是计算密集操作，Provider 负责状态广播 |
| Funding rate 数据获取 | Service (FundingRateService) | Data (drift 可选) | REST API 调用，结果缓存在本地 |
| 回测报告 UI | UI (BacktestScreen) | Provider (BacktestProvider) | 纯消费 Provider 暴露的报告数据 |
| Lookahead-analysis 测试 | Test (单元测试) | Service (BacktestEngine) | 测试代码，复用引擎跑两次不同数据 |
| 权益曲线绘制 | UI (Widget) | — | fl_chart LineChart 在 BacktestScreen 内渲染 |

## 标准技术栈

### 核心

| 库 | 版本 | 用途 | 为什么是标准选择 |
|----|------|------|-----------------|
| Dart SDK | 3.6 (已锁定) | 回测引擎语言 | 项目语言，无需额外运行时 |
| `archive` | ^4.0.2 (已安装) | ZIP 解压 | Dart 社区事实标准 ZIP 库，支持 stream 和 in-memory 解码 [VERIFIED: pub.dev archive package page] |
| `http` | ^1.1.0 (已安装) | HTTP 下载 ZIP / REST 调用 | Dart 团队维护的标准 HTTP 客户端 [VERIFIED: pub.dev http package page] |
| `fl_chart` | ^1.2.0 (已安装) | 权益曲线折线图 | 项目已用（Phase 4 sparkline），Flutter 社区最活跃图表库，支持多系列 LineChart [VERIFIED: 项目 pubspec.yaml] |
| `drift` | ^2.19 (已安装) | K 线/回测结果持久化 | Phase 1 已建表（Klines/BacktestRuns/BacktestTrades），类型安全 DAO [VERIFIED: 项目 drift_database.dart] |

### 辅助

| 库 | 版本 | 用途 | 使用时机 |
|----|------|------|----------|
| `path_provider` | 已安装 | 获取应用文档目录（ZIP 下载路径） | 数据导入管线需要本地存储路径 [ASSUMED] |
| `provider` | ^6.1.0 (已安装) | 回测状态管理 | 项目标准状态管理，BacktestProvider 用 ChangeNotifier [VERIFIED: 项目 pubspec.yaml] |

### 已考虑但无需引入的替代方案

| 标准方案 | 替代方案 | 取舍 |
|---------|---------|------|
| 手写 event-driven 回测引擎 (Dart) | nautilus_trader (Python) | Python 方案需跨语言调用，增加复杂度；Dart 手写可直调 `ReboundDetector.evaluate`，零序列化开销 |
| fl_chart LineChart | syncfusion_flutter_charts | syncfusion 是商业授权（Community License 有约束），fl_chart 完全 MIT 且已集成 |
| archive 解压 | dart:io gzip + 手动 zip | `archive` 已安装（Phase 1），API 简洁，避免重复造轮子 |
| 向量化回测（Pandas 风格） | Event-driven | 用户决策 D-15 强制 event-driven；向量化被 PITFALLS.md 标为"永不可接受" |

**安装：**

```bash
# 所有依赖已在 pubspec.yaml 中，无需新增
flutter pub get
```

**版本验证：** 所有核心包在 `pubspec.yaml` 均有版本锁。`archive` 4.0.2、`fl_chart` 1.2.0、`drift` 2.19 均为 2026-06-20 时的最新稳定版。实际名称和版本以 `pubspec.yaml` 文件中的声明为准。

## 包合法性审计

| 包名 | 注册表 | 年龄 | 下载 | 源码仓库 | 判定 | 处置 |
|------|--------|------|------|----------|------|------|
| `archive` | pub.dev | 多年 (Dart 社区核心包) | 高 (Dart 生态基础库) | github.com/brendan-duncan/archive | OK [VERIFIED: pub.dev] | 已批准（已安装） |
| `fl_chart` | pub.dev | 多年 (Flutter 社区 #1 图表库) | 高 | github.com/imaNNeo/fl_chart | OK [VERIFIED: pub.dev] | 已批准（已安装） |
| `http` | pub.dev | 多年 (Dart 官方维护) | 高 | github.com/dart-lang/http | OK [VERIFIED: pub.dev] | 已批准（已安装） |
| `drift` | pub.dev | 多年 | 高 | github.com/simolus3/drift | OK [VERIFIED: pub.dev] | 已批准（已安装） |
| `provider` | pub.dev | 多年 (Flutter 推荐) | 高 | github.com/rrousselGit/provider | OK [VERIFIED: pub.dev] | 已批准（已安装） |

**被移除的包：** 无
**被标记为可疑 [SUS] 的包：** 无
**注意：** 以上包均为项目已有依赖，已在 pubspec.yaml 中声明。无需新增任何外部依赖。

## 架构模式

### 系统架构图

```
                          ┌────────────────────────┐
                          │   BacktestScreen (UI)   │
                          │  - 权益曲线 (fl_chart)  │
                          │  - 统计卡 / 交易列表    │
                          │  - 四项披露 + 免责声明  │
                          └──────────┬─────────────┘
                                     │ context.watch
                          ┌──────────▼─────────────┐
                          │   BacktestProvider      │
                          │  - status: BacktestStatus│
                          │  - report: BacktestReport│
                          │  - runBacktest(params)   │
                          └──────────┬─────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
     ┌────────▼────────┐  ┌─────────▼──────────┐  ┌───────▼──────────┐
     │ BacktestEngine  │  │ FundingRateService │  │ DataImportService│
     │ (Service 层)    │  │ (Service 层)       │  │ (Service 层)     │
     │                 │  │                    │  │                  │
     │ - 逐 bar 推进   │  │ - fapi/v1/        │  │ - ZIP 下载+解压  │
     │ - 调用 Detector │  │   fundingRate     │  │ - CSV 解析       │
     │ - 模拟交易      │  │ - 分页获取全量    │  │ - Klines 批量写  │
     │ - 成本计算      │  │ - 本地缓存        │  │                  │
     │ - 参数扫描编排  │  │                    │  │                  │
     └────────┬────────┘  └─────────┬──────────┘  └───────┬──────────┘
              │                     │                      │
              │   纯函数调用        │    HTTP 请求          │   HTTP 请求
              ▼                     ▼                      ▼
     ┌────────────────┐  ┌──────────────────┐  ┌─────────────────────┐
     │ReboundDetector │  │ Binance REST API │  │ data.binance.vision │
     │ (Phase 2)      │  │ fapi.binance.com │  │ (CDN ZIP files)     │
     │                │  │                  │  │                     │
     │ .evaluate(     │  │ /fapi/v1/        │  │ 月度 ZIP → CSV      │
     │  window, params)│  │  fundingRate     │  │                     │
     └────────────────┘  └──────────────────┘  └─────────┬───────────┘
                                                         │
                                              ┌──────────▼───────────┐
                                              │  drift AppDatabase   │
                                              │  (Data 层)           │
                                              │                      │
                                              │  Klines 表           │
                                              │  BacktestRuns 表     │
                                              │  BacktestTrades 表   │
                                              └──────────────────────┘
```

数据流：
1. **数据导入管线：** DataImportService → HTTP 下载 ZIP (data.binance.vision) → archive 解压 → CSV 解析为 KlineData → 批量写入 drift Klines 表。当月份缺口用 `/fapi/v1/klines` REST 补足。
2. **Funding 数据管线：** FundingRateService → GET /fapi/v1/fundingRate 分页获取 → 本地 Map<symbol, List<FundingRate>> 缓存，供回测引擎持仓跨 8h 结算时扣费。
3. **回测运行管线：** BacktestProvider 触发 → BacktestEngine 从 drift Klines 表读取 → 逐 bar 推进，每根 bar 收盘后调用 ReboundDetector.evaluate → 信号触发后模拟交易跟进（进场/止损/止盈/时间退出/成本扣费）→ 产出 BacktestReport → 写入 BacktestRuns + BacktestTrades → Provider 通知 UI 更新。
4. **Walk-forward 管线：** BacktestEngine 按 3-fold 切片历史 → 对每个 out-of-sample 月遍历 320 参数组合 → 聚合 out-of-sample 指标 → 产出 BacktestReport（只含 out-of-sample 聚合结果）。

### 推荐项目结构

```
lib/
├── models/
│   ├── backtest_config.dart        # 回测配置（起止日期、成本开关、标的列表）
│   ├── backtest_report.dart        # 回测报告模型（统计 + 交易列表 + 权益曲线数据）
│   ├── backtest_trade.dart         # 单笔交易模型（进场/出场/PnL/R 倍数）
│   ├── backtest_status.dart        # 回测运行状态枚举（idle/running/complete/error）
│   ├── funding_rate.dart           # 资金费率快照模型
│   └── position.dart               # 持仓状态模型
├── services/
│   ├── rebound/
│   │   ├── backtest_engine.dart    # Event-driven 回测核心
│   │   ├── data_import_service.dart # 历史数据下载+解压+写入
│   │   ├── funding_rate_service.dart# 资金费率历史拉取+缓存
│   │   ├── trade_simulator.dart    # 模拟交易（进场/出场/成本扣费/仓位管理）
│   │   ├── walk_forward.dart        # Walk-forward 切片+参数扫描编排
│   │   └── report_generator.dart    # 回测报告组装（指标计算+权益曲线生成）
│   └── drift_database.dart         # 已有 — Klines/BacktestRuns/BacktestTrades DAO
├── providers/
│   └── backtest_provider.dart      # 回测状态 + 报告数据 Provider
├── screens/
│   └── backtest_screen.dart        # 回测报告 UI
└── widgets/
    ├── equity_curve_chart.dart      # 权益曲线折线图封装
    ├── backtest_stats_card.dart     # 统计汇总卡片
    └── backtest_trade_list.dart     # 交易列表（可排序+下钻）
```

### 模式 1：Event-Driven 逐 Bar 推进

**是什么：** 回测引擎按时间顺序逐根消费 K 线序列。每根 bar 的处理分两阶段：(1) 收盘阶段——调用 detector、检查出场条件、扣 funding 费；(2) 开盘阶段——进场（如果上一根触发了信号）。

**何时使用：** 所有决策动作。这是 CONTEXT.md D-15 的硬性要求。

**示例（伪代码）：**
```dart
// Source: CONTEXT.md D-15 + PITFALLS.md Pitfall 1
BacktestReport runBacktest(List<KlineData> klines, List<ReboundParams> paramGrid) {
  var position = null;  // 当前持仓
  var signal = null;    // 上一根 bar 的信号
  
  for (int i = 0; i < klines.length; i++) {
    final bar = klines[i];
    final window = klines.sublist(0, i + 1);  // 只用 bar[0..i]
    
    // --- 阶段 1: 收盘处理 ---
    
    // 检查出场条件（若持仓中）
    if (position != null) {
      position = checkExit(position, bar, window);
    }
    
    // 持仓跨 8h 结算扣 funding
    if (position != null && crossesFundingSettlement(position, bar)) {
      position.pnl -= fundingCost(position, bar.time);
    }
    
    // 调用 detector（只在收盘后）
    signal = detector.evaluate(window, params, symbol: sym, timeframe: tf);
    
    // --- 阶段 2: 下一根开盘进场 ---
    
    if (i + 1 < klines.length && signal != null && position == null) {
      position = enterPosition(klines[i + 1].open, signal);  // D-01
    }
  }
}
```

### 模式 2：Walk-Forward 锚定切片

**是什么：** 历史数据按日期排序后切为 6 月。第 1-3 月为第一个训练窗口，第 4 月为第一个测试窗口。训练窗口锚定起点（不滑动），不断向后扩展，测试窗口为固定 1 个月。总计 3 个 out-of-sample 月。

**何时使用：** 参数扫描。CONTEXT.md D-10 锁定此模式。

**示例（伪代码）：**
```dart
// Source: CONTEXT.md D-10
List<FoldResult> walkForward(List<KlineData> fullData, List<ReboundParams> grid) {
  final folds = <FoldResult>[];
  final totalMonths = 6;
  final testMonths = 1;
  
  for (int fold = 0; fold < 3; fold++) {
    final trainEnd = 3 + fold;      // Fold 0: 月1-3, Fold 1: 月1-4, Fold 2: 月1-5
    final testStart = trainEnd;      // 第 trainEnd+1 个月
    final trainData = fullData.sublist(0, monthBoundary(trainEnd));
    final testData = fullData.sublist(monthBoundary(testStart), monthBoundary(testStart + testMonths));
    
    // 训练窗口不调参——每个参数组合在 train window 跑全量、在 test window 跑一遍
    for (final params in grid) {
      final trainResult = runBacktest(trainData, params);
      final testResult = runBacktest(testData, params);
      // 只记录 out-of-sample (test) 结果
    }
  }
  
  // 只聚合 3 个 test months 的结果
  return aggregateOutOfSample(folds);
}
```

### 模式 3：Lookahead-Analysis 测试

**是什么：** 对同一历史数据跑两次回测。第一次是标准回测。第二次将每根 bar 的 close 替换为下一根的 open（`window[i].close = window[i+1].open`）。若两次回测的（信号触发时间、数量、评分）完全一致，则通过。若结果变化，说明引擎有前视偏差。

**何时使用：** BACKTEST-06 的 UAT 验证。这是 PITFALLS.md Pitfall 1 明确要求的最强检测手段。

**示例（单元测试）：**
```dart
// Source: FREQTRADE lookahead-analysis methodology [CITED: freqtrade.io/en/stable/lookahead-analysis/]
test('lookahead-analysis: close replaced with next open yields identical signals', () {
  final engine = BacktestEngine(detector);
  final originalData = loadKlines('BTCUSDT', '15m');
  
  // 创建偏差数据：每根 bar 的 close = 下一根的 open
  final biasedData = List<KlineData>.from(originalData);
  for (int i = 0; i < biasedData.length - 1; i++) {
    biasedData[i] = biasedData[i].copyWith(close: biasedData[i + 1].open);
  }
  
  final originalReport = engine.runBacktest(originalData, params);
  final biasedReport = engine.runBacktest(biasedData, params);
  
  // 结果必须一致
  expect(originalReport.totalSignals, equals(biasedReport.totalSignals));
  for (int i = 0; i < originalReport.trades.length; i++) {
    expect(originalReport.trades[i].entryTime, equals(biasedReport.trades[i].entryTime));
    expect(originalReport.trades[i].signalScore, equals(biasedReport.trades[i].signalScore));
  }
});
```

### 需避免的反模式

- **向量化回测（禁用）：** 用 `df.shift()` 或类似向量化操作。PITFALLS.md 技术债表标为"永不可接受"。lookahead bug 极难发现。ContEXT.md D-15 强制 event-driven。
- **signal-close 同根进场（禁用）：** 在触发信号的同一根 bar 进场。产生严格 lookahead bias。ContEXT.md D-01 强制 next-open 进场。
- **零成本回测作为唯一产出（禁用）：** 只出零成本曲线。PITFALLS.md Pitfall 4 要求双曲线必出。ContEXT.md D-06 强制。
- **报告 in-sample 最优参数（禁用）：** 只报 in-sample 最优。产生过拟合误导。ContEXT.md D-11 强制只报 out-of-sample。
- **四项披露缺失（禁用）：** 缺任意一项不让展示报告。ContEXT.md D-20 强制。

## 不要手写实现

| 问题 | 不要自己实现 | 使用已有方案 | 原因 |
|------|-------------|-------------|------|
| ZIP 文件解压 | 手写 ZIP 解码器 | `archive` ^4.0.2（已安装） | 已安装，API 成熟，支持 stream 和 in-memory 模式 [VERIFIED: pub.dev] |
| HTTP 下载 | 手写 HTTP 客户端 | `http` ^1.1.0（已安装） | 已安装，Dart 官方维护 [VERIFIED: pub.dev] |
| 权益曲线折线图 | 手写 Canvas 绘图 | `fl_chart` ^1.2.0（已安装） | 已安装（Phase 4），LineChart 原生支持多系列、颜色、线型 [VERIFIED: pub.dev] |
| SQLite 持久化 | sqflite raw SQL | `drift` ^2.19（已安装） | Klines/BacktestRuns/BacktestTrades 表已在 drift 定义，类型安全 DAO [VERIFIED: 项目 drift_database.dart] |
| CSV 解析 | 手写 CSV parser | Dart 原生 `String.split(',')` | 12 列简单表格，无引号转义，纯数值，手写 split 足够可靠 |
| 时间序列日期分组 | 手写月份裁剪逻辑 | Dart 原生 `DateTime` 比较 | 按 KlineData.time 直接比较即可，无需第三方时间库 |
| 回测引擎核心 | 引入第三方回测框架 | 手写 event-driven 引擎 | 必须直接调用 Phase 2 `ReboundDetector.evaluate`，任何包装层都破坏"同源"不变量 |

**核心洞察：** Phase 6 的计算密集部分（回测引擎、模拟交易、参数扫描）**没有现成的 Dart 回测框架**——这是因为回测必须复用 Phase 2 同源纯函数。引入任何第三方框架都会破坏"live/backtest 同一代码"的不变量。引擎纯手写是正确的设计选择。

## 运行时状态清单

> Phase 6 是绿色场阶段（新增功能），不涉及重命名/重构/迁移。此节不适用（已跳过）。

## 常见陷阱

### 陷阱 1：前视偏差（Lookahead Bias）— 回测用了决策时刻拿不到的信息

**出错表现：** 回测胜率虚高（如 >70%），实盘完全复现不了。
**根因：** `t` 根 K 线收盘那一刻用了 `t` 根的 close/ATR 去决定是否触发反弹信号——实盘里这些值要到 `t` 根收盘后才"确定"。
**预防：**
- 引擎在 bar[t] 触发信号后，强制在 bar[t+1].open 进场（D-01）
- ATR 在 t 根的值仅用于 t+1 根的决策（PITFALLS.md Pitfall 1）
- 所有指标只用 `window[0..t-1]` 计算（不含 t 根自身）
- Lookahead-analysis 测试为 UAT 硬标准（D-17）
**预警信号：**
- 回测胜率 > 70%
- 信号触发 timestamp 与 K 线收盘 timestamp 完全相等
- 向量化实现中出现同行比较

### 陷阱 2：过拟合（Curve-Fitting）— 参数调到历史噪声上

**出错表现：** 回测最优参数表现亮眼，换段历史立刻失效。
**根因：** 320 个参数组合在有限历史上搜索最优——总能凑出一组看似不错的。
**预防：**
- Walk-forward 3-fold 强制只报 out-of-sample（D-10/D-11）
- 参数物理含义明确（D-12 四参数均为 ATR 倍数/回补比例/时间/量能比）
- 权重和过滤器不进扫描（D-13/D-14）
- 报告 out-of-sample 表现默认打 30-50% 折扣（D-21）
**预警信号：**
- 最优参数的邻居参数表现断崖式下跌
- in-sample 胜率 65%，out-of-sample 胜率 45%
- 扫描结果刚好是不规整的值（如 ATR=2.37）

### 陷阱 3：忽略成本（手续费/资金费/滑点）— 合约三连击

**出错表现：** 零成本回测显示盈利，含成本后变亏损。
**根因：** 合约反弹策略高频短线（15m 周期），手续费反复扣、持仓跨 8h funding 结算、反弹时刻波动+流动性真空滑点远超平时。
**预防：**
- 手续费按 taker 0.06% 来回算（D-06）
- 滑点按 0.1% 单边固定值（D-06）
- Funding 按历史实际 rate 扣费（D-05）
- 引擎必须同时出零成本和含成本双曲线（D-06）
**预警信号：**
- 回测平均每笔盈利 < 0.2%
- 持仓时长中位数 > 8h 但没扣 funding
- 开成本后策略从盈利变亏损

### 陷阱 4：幸存者偏差（Survivorship Bias）— 只测至今还活着的币

**出错表现：** 回测报告结果看起来"没有踩到归零标的"。
**根因：** 2023-2025 期间大量合约被下架（FTT、LUNA 系列、各种山寨）。下架的往往是暴跌后被踢出的——正是 V 型反弹策略最容易"接飞刀"的标的。
**预防（v1 务实折中）：**
- v1 只在 Top-100 流动性币种上回测（D-08）
- 回测报告显式声明"仅覆盖当前 Top-100 流动性币种，不包含已下架合约"（D-20）
- 不要假装这是全市场回测（PITFALLS.md Pitfall 2）
**预警信号：**
- 回测报告无标的池说明
- 用户拿已下架币测直接数据缺失

### 陷阱 5：时间戳处理错误 — 毫秒 vs 微秒混用

**出错表现：** 2025 年的 K 线数据显示为 1970 年，或解析崩溃。
**根因：** Binance 在 2025 年 1 月切换了 ZIP CSV 时间戳格式——此前是毫秒（13 位），此后是微秒（16 位）。不注意这个切换会导致时间戳完全错误。
**预防：**
- 解析时检测时间戳长度：<= 13 位按毫秒处理，>13 位按微秒处理
- 统一转为毫秒存储（drift Klines 表 openTime 字段为 int64）
- 数据导入管线有明确的 timestamp normalization 步骤 [VERIFIED: WebSearch, data.binance.vision]

## 代码示例

来自官方来源的已验证模式：

### Binance 历史 ZIP 下载与解析

```dart
// Source: data.binance.vision URL pattern [VERIFIED: WebSearch]
// Source: archive 4.0.2 API [VERIFIED: pub.dev documentation]
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

class DataImportService {
  static const _baseUrl = 'https://data.binance.vision/data/futures/um/monthly/klines';

  Future<List<KlineData>> downloadMonth({
    required String symbol,
    required String interval,
    required int year,
    required int month,
  }) async {
    final monthStr = month.toString().padLeft(2, '0');
    final url = '$_baseUrl/$symbol/$interval/$symbol-$interval-$year-$monthStr.zip';
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception('Download failed: $url');
    
    final archive = ZipDecoder().decodeBytes(response.bodyBytes);
    final csvFile = archive.first;  // 每月 ZIP 仅含 1 个 CSV
    
    final csvContent = String.fromCharCodes(csvFile.readBytes());
    return _parseCsv(csvContent, symbol: symbol, interval: interval);
  }
  
  List<KlineData> _parseCsv(String csv, {required String symbol, required String interval}) {
    return csv
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final cols = line.split(',');
          final rawTime = int.parse(cols[0]);
          // 时间戳标准化：<= 13 位 → 毫秒，>13 位 → 微秒转毫秒
          final timeMs = rawTime > 10000000000000 ? rawTime ~/ 1000 : rawTime;
          return KlineData(
            time: DateTime.fromMillisecondsSinceEpoch(timeMs),
            open: double.parse(cols[1]),
            high: double.parse(cols[2]),
            low: double.parse(cols[3]),
            close: double.parse(cols[4]),
            volume: double.parse(cols[5]),
          );
        })
        .toList();
  }
}
```

### Funding Rate 历史批量拉取

```dart
// Source: Binance API docs [VERIFIED: WebSearch, developers.binance.com]
class FundingRateService {
  static const _baseUrl = 'https://fapi.binance.com/fapi/v1/fundingRate';
  
  Future<List<FundingRate>> fetchHistory({
    required String symbol,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final allRates = <FundingRate>[];
    var currentStart = startTime?.millisecondsSinceEpoch ?? 0;
    final endMs = endTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
    
    while (currentStart < endMs) {
      final uri = Uri.parse('$_baseUrl?symbol=$symbol&limit=1000&startTime=$currentStart');
      final response = await http.get(uri);
      final List<dynamic> data = jsonDecode(response.body);
      
      if (data.isEmpty) break;
      
      for (final item in data) {
        allRates.add(FundingRate(
          symbol: item['symbol'],
          rate: double.parse(item['fundingRate']),
          time: DateTime.fromMillisecondsSinceEpoch(item['fundingTime']),
        ));
      }
      
      // 用最后一条的 fundingTime 作为下页的 startTime
      currentStart = data.last['fundingTime'] + 1;
      
      // 遵守限流（500 req/5min shared）
      await Future.delayed(Duration(milliseconds: 700));
    }
    
    return allRates;
  }
}
```

### fl_chart 权益曲线（双线对比）

```dart
// Source: fl_chart 1.2.0 LineChart API [VERIFIED: pub.dev documentation + 项目 Phase 4 使用先例]
// 关键：使用 LineChartBarData 的 dashArray 属性实现含成本虚线
LineChart(
  LineChartData(
    lineBarsData: [
      // 零成本曲线（实线，蓝色）
      LineChartBarData(
        spots: zeroCostSpots,  // List<FlSpot> from equity data
        isCurved: true,
        color: Colors.blue,
        barWidth: 2,
        dotData: FlDotData(show: false),
      ),
      // 含成本曲线（虚线，橙色）
      LineChartBarData(
        spots: withCostSpots,
        isCurved: true,
        color: Colors.orange,
        barWidth: 2,
        dashArray: [5, 5],  // 虚线效果
        dotData: FlDotData(show: false),
      ),
    ],
    titles: FlTitlesData(/* ... */),
    gridData: FlGridData(show: true),
    borderData: FlBorderData(show: true),
  ),
)
```

## 当前最佳实践

| 旧方法 | 当前方法 | 变更时间 | 影响 |
|--------|---------|---------|------|
| 向量化回测 (df.shift()) | Event-driven 逐 bar 推进 | 决策 D-15（Phase 6 设计阶段） | 杜绝 lookahead bug，引擎实现复杂度增加但可靠性保障 |
| signal-close 同根进场 | next-open 进场 (t+1.open) | 决策 D-01 | 回测胜率降低 5-10%（更接近实盘），但偏差消除 |
| 零成本回测 | 零成本 + 含成本双曲线必出 | 决策 D-06 | 暴露"被成本掩盖的伪策略" |
| In-sample 最优报告 | Walk-forward out-of-sample only | 决策 D-10/D-11 | 防止过拟合信心 |
| 全历史数据 | 数据按月 ZIP 分片 + REST gap-fill | Binance 数据格式 | 需要时间戳标准化处理（ms vs μs） |

**已弃用/过时：**
- **向量化回测：** PITFALLS.md 技术债表标为"永不可接受"。永远不要出现在 Phase 6 的任何代码中。
- **signal-close 同根进场：** ROADMAP 开放问题 #3 已解决（D-01），不产生 lookahead。
- **报告 in-sample 最优：** D-11 禁止。walk-forward 只报 out-of-sample 聚合指标。

## 假设日志

| # | 假设 | 章节 | 错误风险 |
|---|------|------|----------|
| A1 | `path_provider` 为获取 ZIP 下载本地目录的最佳方案 | 标准技术栈 | 低——Flutter 项目标准包，若不存在可用 `dart:io` 的 `Directory.systemTemp` 替代 |
| A2 | Top-100 流动性排序可通过对 Top-100 币种逐个拉 15m K 线并比较 24h 交易量实现 | 数据导入 | 低——数据来源于 Binance `/fapi/v1/ticker/24hr`，该端点已在 Phase 3 使用 |
| A3 | 数据导入管线下载并发数为 3-5 个并发连接（不超过 Binance CDN 限制） | Claude Discretion | 低——经验值，可根据实际限流调整 |
| A4 | BacktestScreen 入口放在底部导航新 Tab 更内聚（而非 ProfileScreen 入口按钮） | Claude Discretion | 低——两个方案均可，规划阶段与现有 UI 比对后拍板 |

## 待解决问题

1. **BacktestScreen 入口位置：新 Tab vs ProfileScreen 按钮**
   - 已知信息：现有底部导航 5 个 Tab（IndexedStack），新增 Tab 需调整布局
   - 不明确：用户对导航栏拥挤的容忍度
   - 建议：规划阶段与现有 UI 布局比对后拍板（Claude Discretion 范围）

2. **数据导入管线批量写入性能**
   - 已知信息：Top-100 币种 × 6 个月 × 15m 周期 ≈ 100 × 6 × 30 × 96 ≈ 170 万条 K 线
   - 不明确：drift 批量写入 170 万条的耗时（单条 insert vs batch insert）
   - 建议：使用 drift 的 `batch` API 按 symbol+interval 分组批量写入，每批 ~1000 条

3. **参数扫描全量耗时估算**
   - 已知信息：320 参数组合 × 3 folds × Top-100 币种 × 6 个月 ≈ 大量 I/O
   - 不明确：移动端计算能力能否在可接受时间内完成（可能需要分钟级到小时级）
   - 建议：v1 单线程串行，UI 显示进度条；v2 引入 Isolate 并行（已在延后清单）

## 环境可用性

| 依赖 | 需要者 | 可用 | 版本 | 回退方案 |
|------|--------|------|------|----------|
| Dart SDK | 全部代码 | 是 | 3.6 (已锁定) | — |
| Flutter SDK | UI 层 | 是 | 3.24 (已锁定) | — |
| `archive` 包 | 数据导入管线 (ZIP解压) | 是 | ^4.0.2 (已安装) | — |
| `http` 包 | 数据下载 + REST 调用 | 是 | ^1.1.0 (已安装) | — |
| `fl_chart` 包 | 权益曲线 (UI) | 是 | ^1.2.0 (已安装) | 可退化到 CustomPaint 手绘，但 fl_chart 已集成 |
| `drift` 包 | K 线/回测持久化 | 是 | ^2.19 (已安装) | — |
| `provider` 包 | 回测状态管理 | 是 | ^6.1.0 (已安装) | — |
| 外网 (data.binance.vision) | ZIP 下载 | 需要网络 | — | 无，离线无法导入历史数据 |
| 外网 (fapi.binance.com) | REST gap-fill + funding rate | 需要网络 | — | 无，离线无法补缺口 |
| `ReboundDetector.evaluate` | 回测引擎核心 | 是 | Phase 2 已锁定 | — |
| drift `Klines` 表 | 回测数据源 | 是 | Phase 1 已建表 | — |
| drift `BacktestRuns`/`BacktestTrades` 表 | 回测结果存储 | 是 | Phase 1 已建表 | — |

**无回退方案的缺失依赖：**
- **外网连接**——数据导入和 funding rate 获取完全依赖 Binance API/CDN。离线环境回测不可用。建议在 BacktestScreen 中检测网络状态并给提示。
- **`ReboundDetector.evaluate`**——Phase 2 必须完成且稳定。若 detector 签名或行为变更，回测引擎需同步适配。

## 验证架构

### 测试框架

| 属性 | 值 |
|------|-----|
| 框架 | flutter_test (Flutter 内置) |
| 配置文件 | 无 —— 使用默认配置 |
| 快速运行命令 | `flutter test test/services/rebound/backtest_engine_test.dart` |
| 全量运行命令 | `flutter test` |

### 阶段需求到测试映射

| 需求 ID | 行为 | 测试类型 | 自动化命令 | 文件存在？ |
|---------|------|----------|------------|-----------|
| BACKTEST-01 | 数据导入管线：ZIP下载→解压→CSV解析→drift写入 + 时间戳标准化 | 单元 | `flutter test test/services/rebound/data_import_test.dart` | 否 — Wave 0 |
| BACKTEST-02 | Event-driven 引擎：逐 bar 推进、调用 detector、信号触发数与 Phase 2 合成 fixture 一致 | 单元 | `flutter test test/services/rebound/backtest_engine_test.dart` | 否 — Wave 0 |
| BACKTEST-03 | 模拟交易：进场(t+1.open)/止损/止盈/时间退出/手续费/滑点/funding扣费 | 集成 | `flutter test test/services/rebound/trade_simulator_test.dart` | 否 — Wave 0 |
| BACKTEST-04 | 报告统计：胜率/平均R/盈亏比/最大回撤/样本数N 计算正确 | 单元 | `flutter test test/services/rebound/report_generator_test.dart` | 否 — Wave 0 |
| BACKTEST-05 | 双曲线：零成本和含成本权益曲线同屏输出 | Widget | `flutter test test/widgets/equity_curve_chart_test.dart` | 否 — Wave 0 |
| BACKTEST-06 | Lookahead-analysis：close→下根open后信号触发时间和数量完全不变 | 单元 | `flutter test test/services/rebound/lookahead_test.dart` | 否 — Wave 0 |
| BACKTEST-07 | 四项披露：报告页面缺任一项不展示 + 免责声明固定显示 | Widget | `flutter test test/screens/backtest_screen_test.dart` | 否 — Wave 0 |

### 采样率

- **每个任务提交时：** `flutter test test/services/rebound/backtest_engine_test.dart -x`
- **每个 Wave 合并时：** `flutter test`（全量）
- **阶段门控：** 全量测试绿色 + lookahead-analysis 通过（BACKTEST-06 UAT 硬标准）

### Wave 0 缺口

- [ ] `test/services/rebound/backtest_engine_test.dart` — 覆盖 BACKTEST-02
- [ ] `test/services/rebound/data_import_test.dart` — 覆盖 BACKTEST-01（含时间戳标准化测试）
- [ ] `test/services/rebound/trade_simulator_test.dart` — 覆盖 BACKTEST-03（含成本扣费测试）
- [ ] `test/services/rebound/report_generator_test.dart` — 覆盖 BACKTEST-04（统计指标正确性）
- [ ] `test/services/rebound/lookahead_test.dart` — 覆盖 BACKTEST-06（UAT 硬标准）
- [ ] `test/services/rebound/walk_forward_test.dart` — 覆盖 walk-forward 切片逻辑
- [ ] `test/widgets/equity_curve_chart_test.dart` — 覆盖 BACKTEST-05（双曲线渲染）
- [ ] `test/screens/backtest_screen_test.dart` — 覆盖 BACKTEST-07（四项披露守卫）
- [ ] `test/services/rebound/test_fixtures.dart` — 共享测试 fixtures（合成历史 K 线、模拟 funding 数据）
- [ ] 框架安装：`flutter test` 已可用

## 安全领域

### 适用的 ASVS 类别

| ASVS 类别 | 适用 | 标准控制 |
|-----------|------|----------|
| V2 认证 | 否 | — |
| V3 会话管理 | 否 | — |
| V4 访问控制 | 否 | — |
| V5 输入验证 | 是 | 回测参数输入（起止日期、标的列表）需验证：日期不早于 2020-01-01、symbol 格式 `[A-Z]+USDT`、interval 为合法枚举值 |
| V6 密码学 | 否 | — |

### 已知威胁模式

| 模式 | STRIDE | 标准缓解 |
|------|--------|---------|
| 恶意构造的 ZIP 文件（ZIP bomb / 路径遍历） | 拒绝服务 | archive 库的 `decodeBytes` 需设置最大解压大小限制；ZIP 内文件名使用 `entry.name` 而非 `entry.fullPathName`，防止路径遍历 |
| 回测参数注入（日期范围超大导致 OOM） | 拒绝服务 | 日期范围最大 365 天、最多 100 个 symbol；超过上限拒绝并返回错误 |
| 数据源中毒（下载的 ZIP 内容被中间人篡改） | 篡改 | 使用 data.binance.vision 附带的 `.CHECKSUM` 文件验证下载完整性；HTTPS 加密传输 |
| 报告展示 XSS | 信息泄露 | BacktestScreen 中所有用户/外部数据显示前做 `flutter` 默认的字符串处理（非 HTML 渲染，风险低） |

## 来源

### 主要来源（HIGH 置信度）

- [WebSearch + 官方文档] Binance data.binance.vision 月度 K 线格式 — URL 结构、CSV 12 列、毫秒/微秒时间戳切换 [VERIFIED]
- [WebSearch + 官方文档] Binance `/fapi/v1/klines` REST 端点 — 参数 (symbol/interval/startTime/endTime/limit)、权重、200 天范围限制 [VERIFIED]
- [WebSearch + 官方文档] Binance `/fapi/v1/fundingRate` — 参数 (symbol/startTime/endTime/limit=1000)、分页策略（last fundingTime+1）、响应格式 [VERIFIED]
- [pub.dev] archive 4.0.2 — ZipDecoder API (decodeBytes/decodeStream)、安装方式 [VERIFIED]
- [pub.dev] fl_chart 1.2.0 — LineChartBarData 多系列、dashArray 虚线 [VERIFIED]
- [项目源码] ReboundDetector.evaluate — 纯函数签名、KlineData/ReboundParams/ReboundSignal 模型 [VERIFIED]
- [项目源码] drift_database.dart — Klines/BacktestRuns/BacktestTrades 表 schema [VERIFIED]
- [CONTEXT.md] Phase 06 全部已锁定决策 (D-01 至 D-22)

### 次要来源（MEDIUM 置信度）

- [WebSearch] Freqtrade lookahead-analysis — 方法论思路（close 替换检测偏差），具体实现细节参考官方文档 [CITED: freqtrade.io/en/stable/lookahead-analysis/]
- [WebSearch] Event-driven backtest engine 架构模式 — bar-by-bar 推进、开盘/收盘双阶段 [CITED: 多个 GitHub 回测项目]
- [WebSearch] Walk-forward anchored validation — 3-fold 锚定方法 [CITED: forvest.io blog]

### 三级来源（LOW 置信度）

- [ASSUMED] path_provider 为缓存路径方案（项目未显式使用此包，待确认 pubspec 中是否有声明）
- [ASSUMED] Top-100 流动性排序通过 `/fapi/v1/ticker/24hr` 获取

## 元数据

**置信度分解：**
- 标准栈：HIGH — 所有依赖已在 pubspec.yaml 锁定，无需新增
- 架构：HIGH — 用户决策 + PITFALLS.md + 官方文档三重验证
- 陷阱：HIGH — PITFALLS.md 13 个陷阱覆盖全面，Phase 6 重点 5 个陷阱（1/2/3/4/13）均有明确预防方案

**研究日期：** 2026-06-20
**有效期至：** 2026-07-20（30 天，Binance API 相对稳定）
