---
phase: 06-event-driven
reviewed: 2026-06-20T08:00:00Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/models/backtest_config.dart
  - lib/models/backtest_report.dart
  - lib/models/backtest_trade.dart
  - lib/models/backtest_status.dart
  - lib/models/position.dart
  - lib/models/funding_rate.dart
  - lib/services/rebound/data_import_service.dart
  - lib/services/rebound/funding_rate_service.dart
  - lib/services/rebound/backtest_engine.dart
  - lib/services/rebound/trade_simulator.dart
  - lib/services/rebound/walk_forward.dart
  - lib/services/rebound/report_generator.dart
  - lib/providers/backtest_provider.dart
  - lib/screens/backtest_screen.dart
  - lib/widgets/equity_curve_chart.dart
  - lib/widgets/backtest_stats_card.dart
  - lib/widgets/backtest_trade_list.dart
  - lib/screens/profile_screen.dart
  - lib/main.dart
findings:
  critical: 3
  warning: 6
  info: 6
  total: 15
status: issues_found
---

# Phase 06: 代码审查报告

**审查日期:** 2026-06-20
**审查深度:** standard
**审查文件数:** 19
**状态:** issues_found

## 摘要

审查了 Phase 06（事件驱动回测引擎 + Walk-Forward + 回测 UI）的全部 19 个源文件。核心架构（event-driven 逐 bar 回测、零向量化、纯计算服务）设计合理，6 个领域模型结构清晰。

发现 3 个关键问题：**数据库 double-close 崩溃风险**、**资金费率历史从未传入引擎导致费用始终为零**、**交易成本计算在价格比率与 R 倍数之间单位不匹配**。6 个警告涵盖 Walk-Forward 退化折叠问题、profitFactor 计算不一致、类型安全缺失等。6 个信息项涉及代码重复、注释错误、调试残留等。

---

## 关键问题

### CR-01: BacktestProvider 数据库连接 double-close 崩溃风险

**文件:** `lib/providers/backtest_provider.dart:119-125, 131-134`
**问题:** 在 `runBacktest()` 方法的早期返回路径中，`db.close()` 被调用后未将 `db` 设为 null。`finally` 块（第 207 行）无条件执行 `await db?.close()`，对已关闭的数据库再次调用 `close()`。Drift 的 `NativeDatabase.close()` 在已关闭状态下再次调用会抛出 `StateError`。此异常发生在 `finally` 块中，将导致未处理的异常传播，在 UI 层表现为静默崩溃或异常状态。

受影响路径：
1. `insertedCount == 0` 早期返回（第 119-125 行）：`await db.close()` 后 `return`，但 `db` 未置 null
2. `_cancelled` 在数据读取循环中（第 131-134 行）：同样 `await db.close()` 后 `return`

对比正确路径：第 155-156 行 `await db.close(); db = null;` 正确地将引用置空。

**修复:**
```dart
// 第 119-125 行，修复为:
if (insertedCount == 0) {
  _status = BacktestStatus.error;
  _errorMessage = '未获取到任何历史 K 线数据';
  notifyListeners();
  await db.close();
  db = null;  // 防止 finally 块 double-close
  return;
}

// 第 131-134 行，同样修复:
if (_cancelled) {
  _status = BacktestStatus.idle;
  notifyListeners();
  await db.close();
  db = null;  // 防止 finally 块 double-close
  return;
}
```

---

### CR-02: 资金费率历史未传入回测引擎——资金费扣费始终为零

**文件:** `lib/providers/backtest_provider.dart:185-190`, `lib/services/rebound/backtest_engine.dart:269`
**问题:** `BacktestProvider.runBacktest()` 调用 `engine.runBacktestOnKlines()` 时从未传入 `fundingRateHistory` 参数。引擎中该参数默认值为 `null`，在 `applyFundingFee` 调用时使用 `fundingRateHistory ?? {}`（空 Map）。导致所有回测的持仓资金费扣除始终为零。

这直接影响：
- 含成本权益曲线（`equityCurveWithCost`）严重高估收益
- 四项强制披露第 2 项（"含手续费 + 资金费"）的内容与计算实际不符——UI 声称包含资金费但实际从未计算
- 与 D-05 需求（"UTC 00:00/08:00/16:00 资金费结算"）的实现意图矛盾

**修复:** 在 BacktestProvider 中集成 FundingRateService 并传入引擎：

```dart
// 在 runBacktest() 中，引擎调用前添加:
final fundingRateService = FundingRateService();
await fundingRateService.prefetch(
  _config.symbols,
  _config.startDate,
  _config.endDate,
);

// 构建 fundingRateHistory map（{fundingTime(ms): rate}）
final fundingRateHistory = <int, double>{};
for (final symbol in _config.symbols) {
  final rates = fundingRateService._cache[symbol]; // 或通过公开 getter
  if (rates != null) {
    for (final rate in rates) {
      fundingRateHistory[rate.fundingTime] = rate.fundingRate;
    }
  }
}

// 传入引擎
final folds = await walkForward.runWalkForward(
  allKlines: allKlines,
  paramGrid: paramGrid,
  engine: engine,
  config: _config,
  // 需要在 WalkForward.runWalkForward 中增加 fundingRateHistory 参数透传
);
```

同时需要在 `WalkForward.runWalkForward` 和 `BacktestEngine.runBacktestOnKlines` 之间透传 `fundingRateHistory` 参数。目前 `runWalkForward` 已在内部调用 `engine.runBacktestOnKlines` 但未传递此参数，需要修改方法签名以支持透传。

---

### CR-03: 交易成本计算单位不匹配——价格比率与 R 倍数混合计算

**文件:** `lib/services/rebound/trade_simulator.dart:114-127`
**问题:** `applyTransactionCost` 方法计算成本比例时以 `entryPrice` 为分母（`costRatio = (entryFee + exitFee + slippage) / entryPrice`），但将此值直接从 `rMultiple`（R 倍数）中扣除。R 倍数的 1 单位 = `entryPrice - stopLoss`（入场价到止损价的距离），而非 `entryPrice`。这导致成本被严重低估。

具体示例：入场价 100，止损价 95（1R = 5）。费用约 0.32（按价格比率计）。代码减去 0.0032（价格比率），实际应减去 0.064（0.32 / 5 = 0.064R）。低估约 20 倍。

当 risk（entryPrice - stopLoss）远小于 entryPrice 时（大多数情况），成本被系统性低估。反之当 risk 接近或超过 entryPrice 时（极少见），成本被高估。

**修复:**
```dart
double applyTransactionCost(
  double rMultiple,
  double entryPrice,
  double exitPrice,
  double stopLoss, // 新增参数：需要止损价来换算 R 单位
) {
  const takerFeeRate = 0.0006;
  const slippageRate = 0.001;

  final entryFee = entryPrice * takerFeeRate;
  final exitFee = exitPrice * takerFeeRate;
  final slippage = entryPrice * slippageRate + exitPrice * slippageRate;
  final totalCostInPrice = entryFee + exitFee + slippage;

  // 关键修复：用 (entryPrice - stopLoss) 即 1R 对应的价格距离换算
  final riskPerR = (entryPrice - stopLoss).abs();
  if (riskPerR <= 0) return rMultiple; // 风险为零时无法换算
  final costInR = totalCostInPrice / riskPerR;

  return rMultiple - costInR;
}
```

此修复需要同步更新 `BacktestEngine._buildReport` 中所有调用 `applyTransactionCost` 处（约 8 处），每处需额外传入 `position.stopLoss`。同时需要更新 `TradeSimulator.applyTransactionCost` 方法签名。

---

## 警告

### WR-01: Walk-Forward 数据不足时退化折叠使用全量数据（In-Sample）

**文件:** `lib/services/rebound/walk_forward.dart:98-111`
**问题:** 当月份数 < 2 时，`runWalkForward` 执行单个退化折叠，以 `trainKlines = allKlines, testKlines = allKlines` 运行。这意味着引擎在全部数据上检测信号，`_runFold` 的 `fullKlines` 为重复的全量数据。由于 train == test，过滤出的交易实际上是 In-Sample 结果。这与 D-10/D-11 的 "仅报告 Out-of-Sample 指标" 约束矛盾。

UI 的强制披露第 4 项声明 "仅报告 Out-of-Sample 聚合指标"，在此退化情况下声明与计算不一致。

**修复:**
```dart
if (months.length < 2) {
  // 数据不足时返回空 folds 列表，由 aggregateOutOfSample 生成空报告
  // UI 应在收到空报告后展示 "数据不足，无法执行 Walk-Forward 分析" 提示
  return [];
}
```

---

### WR-02: profitFactor 在无盈亏时的不一致——ReportGenerator vs BacktestEngine

**文件:** `lib/services/rebound/report_generator.dart:52-54`, `lib/services/rebound/backtest_engine.dart:364-366`
**问题:** 当 `negativePnl.abs()` 为 0 时（即无亏损交易），两个类产生的 `profitFactor` 值不一致：
- `ReportGenerator.generate`: 返回 `positivePnl > 0 ? double.infinity : 0.0`
- `BacktestEngine._buildReport`: 返回 `double.infinity`（无条件）

这意味着对于完全相同的 trades 数据，通过 `WalkForward.aggregateOutOfSample` → `ReportGenerator.generate` 路径和直接 `engine.runBacktestOnKlines` 路径可能产生不同统计。对于全是盈亏平衡（0 PnL）的交易，前者返回 0.0，后者返回 infinity。

**修复:** 统一逻辑。合理的处理：当无亏损且无盈利时（所有交易 PnL=0），profitFactor = 0.0（表示没有可用的盈亏比信息）；当无亏损但至少有一笔盈利时，profitFactor = double.infinity。

```dart
// ReportGenerator 第 52-54 行修改为:
final profitFactor = negativePnl.abs() > 0
    ? positivePnl / negativePnl.abs()
    : (positivePnl > 0 ? double.infinity : 0.0);
// 此时与 BacktestEngine._buildReport 保持一致
```

同时需要在 `BacktestEngine._buildReport` 中也应用相同逻辑。

---

### WR-03: BacktestScreen 多处使用 `dynamic` 类型丢失类型安全

**文件:** `lib/screens/backtest_screen.dart:453, 491, 526, 586`
**问题:** 四个方法 `_buildEquityCurveCard`、`_buildStatsGrid`、`_buildTradeListCard`、`_buildDisclosuresCard` 的 `report` 和 `config` 参数声明为 `dynamic`，而非 `BacktestReport` / `BacktestConfig`。这完全丢失了编译期类型检查，对这些字段的任何错误访问（如拼写错误的方法名）只能在运行时被发现。

既然这些方法都从 `_buildCompleteContent` 的明确 `BacktestReport?` 类型传入，使用 `dynamic` 没有合理理由。

**修复:**
```dart
// 第 453 行:
Widget _buildEquityCurveCard(BacktestReport report) { ... }

// 第 491 行:
Widget _buildStatsGrid(BacktestReport report) { ... }

// 第 526 行:
Widget _buildTradeListCard(BacktestReport report) { ... }

// 第 586 行:
Widget _buildDisclosuresCard(BacktestReport report, BacktestConfig config) { ... }
```

---

### WR-04: TradeSimulator.applyFundingFee 硬编码 15 分钟 Bar 时长

**文件:** `lib/services/rebound/trade_simulator.dart:156`
**问题:** 资金费结算时刻判定使用 `barEnd = barTime.add(const Duration(minutes: 15))`，硬编码为 15 分钟间隔。但 `runBacktestOnKlines` 接收 `interval` 参数（"15m"/"1h"/"4h" 等），此参数未传递给 `TradeSimulator`。若未来在 1h 或其他周期上运行回测，资金费结算检测将出错（1h bar 的结算间隔判断应为 60 分钟而非 15 分钟）。

**修复:** 将 `interval` 或 bar 时长传递给 `applyFundingFee` 或 `TradeSimulator` 构造函数：

```dart
// 方案 A：通过构造函数注入 bar 间隔
class TradeSimulator {
  final Duration _barDuration;
  TradeSimulator({Duration barDuration = const Duration(minutes: 15)})
      : _barDuration = barDuration;
  // ...
  // applyFundingFee 中使用 _barDuration 替代硬编码
}

// 方案 B：applyFundingFee 接受 interval 参数并从其中解析时长
```

---

### WR-05: DataImportService.importHistoricalData 返回值包含重复计数

**文件:** `lib/services/rebound/data_import_service.dart:141`
**问题:** `totalInserted += chunk.length` 使用 chunk 长度而非实际插入行数来累加计数。由于使用 `InsertMode.insertOrIgnore`，重复行不会被写入但 `totalInserted` 仍将其计入。返回值不能准确反映实际写入的新行数。

调用方 `BacktestProvider.runBacktest()` 在第 119 行使用此值判断 `insertedCount == 0`，若存在重复数据可能误判为"有数据"而实际全是重复行（零新行）。

**修复:**
```dart
// 方案 A：从 batch 返回值计算实际插入数
final batchResult = await db.batch((batch) {
  batch.insertAll(db.klines, chunk, mode: InsertMode.insertOrIgnore);
});
// batch 的返回值取决于 drift 版本。若不可用，改用:
// 方案 B：在 insertAll 前先查询计数，insertAll 后再次查询并计算差值

// 方案 C（最简）：从 _parseCsv 返回的 klines 计数改为实际数据源计数
// 即 totalInserted 仅作为近似值，注释标明 "含重复近似值"
```

---

### WR-06: BacktestScreen 错误消息拼接有误

**文件:** `lib/screens/backtest_screen.dart:424-432`
**问题:** 错误显示区域将 `provider.errorMessage ?? '未知错误'`（第 424 行）和固定字符串 `'。请检查数据源和网络连接后重试。'`（第 432 行）拼接显示，但拼接结果包含格式异常：若 errorMessage 以句号等标点结尾，会形成 `"...错误。 。请检查..."` 的双标点。当前显示的 leading 句号 `。` 始终出现在错误消息之后，可能形成不自然的阅读停顿。

**修复:**
```dart
Text(
  '${provider.errorMessage ?? "未知错误"}。请检查数据源和网络连接后重试。',
  // ...
)
// 或更简洁:
Text(
  [provider.errorMessage ?? '未知错误', '请检查数据源和网络连接后重试。'].join('。'),
)
```

---

## 信息

### IN-01: FundingRate 类为可变类但注释声明为"不可变"

**文件:** `lib/models/funding_rate.dart:4, 6-13`
**问题:** 文件头部注释 `/// 不可变类` 与实现矛盾。`FundingRate` 的所有字段均为非 final 可变字段，且存在 `setFundingIntervalHours` setter 和 `copyWith` 中直接修改私有字段 `_fundingIntervalHours` 的行为。这是一个跨 Phase 的遗留问题（Phase 2 引入，Phase 6 仅添加了 `fromFundingRateEndpoint` 和 `==`/`hashCode`），不影响本次 Phase 的正确性，但注释具有误导性。

**建议:** 将注释修改为 `/// 币安合约资金费率模型（可变类）。` 或在下一次重构时将所有字段改为 `final`。

---

### IN-02: BacktestEngine._buildReport 与 ReportGenerator.generate 代码重复

**文件:** `lib/services/rebound/backtest_engine.dart:332-413`, `lib/services/rebound/report_generator.dart:12-102`
**问题:** 两个类实现了几乎完全相同的报告生成逻辑（胜率、平均 R、PnL、利润因子、最大回撤、权益曲线计算）。唯一的差异在 profitFactor 的边界处理（见 WR-02）。`WalkForward.aggregateOutOfSample` 调用 `ReportGenerator.generate`，而 `BacktestEngine` 内部调用 `_buildReport`。代码重复使得两个实现的任何细微差异都可能导致行为不一致。

**建议:** `BacktestEngine._buildReport` 应委托给 `ReportGenerator.generate`，消除重复：

```dart
BacktestReport _buildReport(
  BacktestConfig config,
  List<BacktestTrade> trades,
  DateTime startedAt,
) {
  final reportGenerator = ReportGenerator();
  final report = reportGenerator.generate(config: config, trades: trades);
  return report.copyWith(startedAt: startedAt, completedAt: report.completedAt);
}
```

---

### IN-03: DataImportService 使用 `print()` 进行生产日志输出

**文件:** `lib/services/rebound/data_import_service.dart:296, 317-318`
**问题:** CSV 解析中的警告和错误使用 `print()` 直接输出到控制台，而非使用结构化日志框架。在生产运行时，这些输出会不可控地出现在日志流中，且无法按级别过滤。

**建议:** 使用 `debugPrint`（Flutter 环境）或引入 `logger` 包进行分级日志输出。

---

### IN-04: TradeSimulator 注释中的止盈公式与代码不一致

**文件:** `lib/services/rebound/trade_simulator.dart:25-26`
**问题:** 注释第 25 行写：`/// - takeProfit1 = swingHigh − (swingHigh − swingLow) × 0.618`，但代码第 35 行实际为：`signal.swingLowPrice + dropRange * 0.618`。代码是正确的（Phase 06-02 中已修正的 TP 公式 bug），但注释未同步更新，仍展示旧的错误公式。

**修复:**
```dart
/// - takeProfit1 = swingLow + (swingHigh − swingLow) × 0.618（61.8% Fib 回撤位）
```

---

### IN-05: FundingRateService.getRate 缓存未命中时从零时间戳开始全量拉取

**文件:** `lib/services/rebound/funding_rate_service.dart:92-94`
**问题:** 当缓存未命中某个 symbol 时，`getRate` 调用 `fetchHistory(symbol: symbol, endTime: timestamp)` 而未传入 `startTime`。`fetchHistory` 的 `currentStart` 默认为 0（Unix epoch），意味着从 1970 年至今的所有 funding rate 历史都会被分页拉取。对于高流量 symbol 这可能产生数百个 API 请求。

当前 `BacktestProvider` 未使用 `getRate`（因此此问题在当前回测流程中不触发），但作为公开 API 是一个潜在的性能陷阱。

**建议:** 添加默认的合理 startTime（如请求 timestamp 前 30 天），或要求调用方显式传入 startTime 参数。

---

### IN-06: walk_forward.dart 中的 `_runFold` 重复拼接 train+test 序列

**文件:** `lib/services/rebound/walk_forward.dart:214`
**问题:** `_runFold` 对每个参数组合（最多 320 个）都执行 `final fullKlines = [...trainKlines, ...testKlines]` 进行列表拼接拷贝。对于大量 K 线数据和大量参数组合，这会重复分配内存。由于 320 个参数组合的循环是同步+异步混合的（每个组合 `await engine.runBacktestOnKlines`），不会产生内存泄漏，但可优化以避免重复拷贝。

**建议（非 v1）:** 在循环外预构建 `fullKlines`，传入 `_runFold` 避免 320 次重复拼接。

---

_审查完成时间: 2026-06-20T08:00:00Z_
_审查者: Claude (gsd-code-reviewer)_
_审查深度: standard_
