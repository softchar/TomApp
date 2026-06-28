---
phase: 01-atr-rsi-bollinger-swing-sdk-drift-schema
plan: 01
type: execute
revision: 1
wave: 1
depends_on: []
files_modified:
  - pubspec.yaml
  - lib/services/technical_indicators.dart
  - lib/services/drift_database.dart
  - lib/services/database_helper.dart
  - test/technical_indicators_test.dart
  - test/drift_database_test.dart
  - test/database_helper_migration_test.dart
autonomous: true
requirements: [INDIC-01, INDIC-02, INDIC-03, INDIC-04]

must_haves:
  truths:
    - "ATR(14) 用 Wilders 平滑（RMA）实现，live 路径与回测路径调用同一纯 instance 方法（TechnicalIndicators 类上）拿到完全相同的值；同一输入两次调用逐位相等"
    - "ATR 在头 14 根 K 线返回 null/未就绪（warm-up 行为被单测覆盖）"
    - "RSI(14) 可判定超卖拐头（前一根 <30 且当前根向上），Bollinger Bands 输出上/中/下轨，swing high/low 可被识别并通过单测"
    - "所有新增指标沿用既有风格：使用 KlineData（package:tomapp/models/kline_data.dart）作为 OHLC 类型，作为 TechnicalIndicators 类的无状态 instance 方法；不引入新的 OHLC 类型、不混用 static/instance"
    - "新增指标方法为纯函数：无 DateTime.now、无 async、无 Provider/IO、无跨调用可变状态"
    - "Dart SDK 已升至 >=3.6.0 <4.0.0，drift ^2.32.0 / archive ^4.0.2 / drift_dev ^2.6.0 装入，flutter pub get 退出码 0，无版本冲突"
    - "fl_chart 版本号在本阶段保持 ^0.65.0 不变（fl_chart 1.2 升级延后到 Phase 4）"
    - "drift 三表（Klines / BacktestRuns / BacktestTrades）在 DatabaseHelper 的 onCreate（全新安装）与 onUpgrade（升级路径）两条路径上都被创建；全新安装路径有专门单测覆盖"
    - "DatabaseHelper schema migration 通过；既有 pump/chart 功能回归无影响（flutter analyze 退出 0，既有测试退出 0）"
  artifacts:
    - path: "pubspec.yaml"
      provides: "sdk >=3.6.0 <4.0.0, drift ^2.32.0, drift_dev ^2.6.0 (dev), archive ^4.0.2；fl_chart 保持 ^0.65.0 不动"
      contains: "sdk: '>=3.6.0 <4.0.0'"
    - path: "lib/services/technical_indicators.dart"
      provides: "在既有 TechnicalIndicators 类中追加 ATR / RSI / Bollinger / swing high/low 的无状态 instance 方法，沿用 KlineData；不破坏现有 calculateMA/calculateBOLL/calculateMACD"
      contains: "double? atr(List<KlineData> klines"
    - path: "lib/services/drift_database.dart"
      provides: "drift Database + Klines/BacktestRuns/BacktestTrades 表定义"
      contains: "class Klines extends Table"
    - path: "lib/services/database_helper.dart"
      provides: "升级后的 schema migration（version 递增；onCreate 与 onUpgrade 两条路径都创建 drift 三表；保留既有 pump 表）"
      contains: "version:"
    - path: "test/technical_indicators_test.dart"
      provides: "ATR Wilders 平滑、warm-up 头 14 根未就绪、纯函数幂等冒烟（同输入两次结果相等、无副作用）、RSI 超卖拐头、Bollinger 三轨、swing high/low 单测"
      contains: "warm"
    - path: "test/drift_database_test.dart"
      provides: "drift 三表 CRUD/外键级联通过测试"
      contains: "Klines"
    - path: "test/database_helper_migration_test.dart"
      provides: "fresh-install 路径（onCreate on empty DB）后三表 Klines/BacktestRuns/BacktestTrades 都存在"
      contains: "onCreate"
  key_links:
    - from: "lib/services/technical_indicators.dart"
      to: "(本阶段) 指标方法作为纯 API 已可被调用且幂等（同一输入两次调用结果逐位相等、无副作用，由单测验证）；live 路径接线（Phase 2 pump 路径消费）与回测接线（Phase 6）发生在后续阶段，本阶段不接线"
      via: "TechnicalIndicators 类上的无状态 instance 方法（atr / rsiTurningUp / bollingerBands / swingHigh / swingLow），接收 List<KlineData>"
      pattern: "TechnicalIndicators\\(\\)\\.atr\\(|\\.atr\\(List<KlineData>"
    - from: "lib/services/drift_database.dart"
      to: "lib/services/database_helper.dart"
      via: "DatabaseHelper 在 onCreate 与 onUpgrade 两条路径都通过同一 CREATE TABLE IF NOT EXISTS 块（或同一 helper）注册 drift 管理的三表；fresh-install 与 upgrade 均由单测覆盖"
      pattern: "CREATE TABLE IF NOT EXISTS (Klines|BacktestRuns|BacktestTrades)"
---

<objective>
为下游检测器、监控、回测提供共享的纯函数技术指标计算基础（ATR/RSI/Bollinger/swing），同时完成 Dart SDK 升级与 drift/archive 依赖落地（fl_chart 1.2 升级延后到 Phase 4，本阶段不触碰 fl_chart 版本号）。本阶段是 gating prerequisite，解锁后续阶段（Phase 2 反弹检测器、Phase 4 反弹仪表盘、Phase 6 回测）。

Purpose: 锁定的 SDK 3.6 + drift 2.32 + archive 4.0.2 + drift_dev 2.6 是后续阶段共同前置；ATR/RSI/swing 纯函数必须 live 与回测同源，否则 Phase 2 的 2×ATR 跌幅阈值 / 0.3×ATR 止损阈值与 Phase 6 回测结果会发散。fl_chart 0.65→1.2 是破坏性 major bump 会牵连既有 macd_chart_widget.dart，集中到 Phase 4 图表阶段一起做更内聚——本阶段保持 fl_chart ^0.65.0 不动，使零回归闸真正可达。

Output: pubspec.yaml（升级 sdk/drift/archive/drift_dev，不动 fl_chart）、technical_indicators.dart（在既有类追加 ATR/RSI/swing instance 方法，沿用 KlineData）、drift_database.dart（新建三表）、database_helper.dart（migration：onCreate + onUpgrade 双路径建表）、三个测试文件。
</objective>

<execution_context>
@gsd-core/workflows/execute-plan.md
@gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/workstreams/contract-quick-rebound/REQUIREMENTS.md
@.planning/workstreams/contract-quick-rebound/ROADMAP.md
@.planning/workstreams/contract-quick-rebound/STATE.md
@.planning/research/SUMMARY.md
@.planning/research/STACK.md
@.planning/research/ARCHITECTURE.md
@.planning/research/PITFALLS.md
@lib/services/technical_indicators.dart
@lib/models/kline_data.dart
@lib/services/database_helper.dart
@lib/services/pump_detector.dart
@pubspec.yaml
@CLAUDE.md
</context>

<artifacts_this_phase_produces>
## 本阶段产出的工件（符号清单）

**pubspec.yaml（升级，per D-01/D-02/D-03；fl_chart 延后到 Phase 4，本阶段不动）**
- `sdk: '>=3.6.0 <4.0.0'`（per D-01）
- `drift: ^2.32.0`
- `archive: ^4.0.2`（Phase 6 data.binance.vision ZIP 用，本阶段先装，per D-03）
- dev: `drift_dev: ^2.6.0`（per STACK.md 锁定，与 drift 主版本系列对齐）
- **`fl_chart` 行保持 `^0.65.0` 不动**（fl_chart 1.2 升级 + macd_chart_widget.dart 迁移属于 Phase 4，per ROADMAP Phase 1 success criteria 第 3 条）
- 保留既有 sqflite / provider / web_socket_channel / flutter_chen_kchart 等依赖

**lib/services/technical_indicators.dart（沿用既有风格：instance 方法 + KlineData，per WARNING 3 / CLAUDE.md）**
- 在既有 `TechnicalIndicators` 类中追加无状态 instance 方法（**不**用 static，**不**引入新的 OHLC 类型，**不**混用 static/instance）：
- `double? atr(List<KlineData> klines, {int period = 14})` — Wilders/RMA 平滑，头 14 根返回 null
- `List<double?> atrSeries(List<KlineData> klines, {int period = 14})` — 整条 ATR 序列（回测逐根取值），与单值 atr 同源
- `double? rsi(List<KlineData> klines, {int period = 14})` — 最新 RSI
- `({double rsi, bool oversoldTurningUp}) rsiTurningUp(List<KlineData> klines, {int period = 14, double oversold = 30})` — 超卖拐头判定（前一根 <30 且当前根向上）
- `BollingerBands calculateBOLL(...)` 已存在并满足需求 → 复用既有方法；不新增并行 Bollinger 入口
- `int? swingHigh(List<KlineData> klines, {int lookback = 2})` / `int? swingLow(...)` — 返回最近 swing 索引（左右各 lookback 根更小/更大）

> 类型严格沿用既有 `KlineData`（`package:tomapp/models/kline_data.dart`），其字段为 `.open/.high/.low/.close/.volume/.time`；不引入 `Candle` 或其他并行 OHLC 类型。instance 方法无状态即为纯函数（保持纯函数不变量）。

**lib/services/drift_database.dart（新建，per D-07）**
- `class Klines extends Table` — symbol(text), interval(text), openTime(integer PK), open/high/low/close/volume(real), closeTime(integer)
- `class BacktestRuns extends Table` — id(integer autoincrement PK), params(text JSON), startedAt(integer), stats(text JSON)
- `class BacktestTrades extends Table` — id(integer autoincrement PK), runId(integer FK→BacktestRuns onDelete cascade), symbol(text), entryTime(integer), entryPrice(real), exitTime(integer), exitPrice(real), side(text), pnl(real), rMultiple(real)
- `AppDatabase extends GeneratedDatabase` — `AppDatabase(QueryExecutor e)` 构造，包含三表 DAO
- 生成的 `*.g.dart`（build_runner 产物）

**lib/services/database_helper.dart（migration：onCreate + onUpgrade 双路径，per BLOCKER 2 / D-03/D-07/D-08）**
- 把 drift 管理的三表建表语句（`CREATE TABLE IF NOT EXISTS Klines ...` 等）抽到**同一个 helper 方法**（如 `_createDriftTables(Database db)`），在 `_onCreate` 与 `_onUpgrade(oldVersion < newVersion)` 中都调用，确保全新安装（onCreate）与升级（onUpgrade）都能建出三表。
- 递增 schema version（既有 3 → 4），新增 `if (oldVersion < 4) { await _createDriftTables(db); }` 分支。
- 既有 pump / futures_symbols 路径保留；既有 pump/chart 路径零回归。
- **已知既有不一致**（kline_cache 只在 onUpgrade 出现、未在 onCreate 出现）属于 pre-existing bug，**本阶段不修**（out of scope）；但 drift 三表不得重蹈覆辙——必须 onCreate 与 onUpgrade 双路径都建。

**测试**
- `test/technical_indicators_test.dart` — ATR Wilders、warm-up 头 14 根 null、纯函数幂等冒烟（同输入两次结果逐位相等、无副作用）、RSI 超卖拐头、Bollinger 三轨、swing high/low
- `test/drift_database_test.dart` — 三表插入/查询/外键级联通过
- `test/database_helper_migration_test.dart` — **fresh-install 路径**：对空 DB 触发 onCreate，断言 Klines / BacktestRuns / BacktestTrades 三表都存在（BLOCKER 2 验收）
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: 升级 Dart SDK 与依赖（drift/archive/drift_dev），不动 fl_chart，保证 flutter pub get 退出 0</name>
  <files>pubspec.yaml</files>
  <read_first>
    - pubspec.yaml（当前 sdk >=3.0.0、fl_chart ^0.65.0、sqflite ^2.3.0、build_runner ^2.4.0）
    - .planning/research/STACK.md（锁定版本：sdk 3.6、drift 2.32、archive 4.0.2、drift_dev ^2.6.0；fl_chart 1.2 升级延后到 Phase 4）
    - .planning/workstreams/contract-quick-rebound/ROADMAP.md（Phase 1 success criteria 第 3 条：fl_chart 1.2 升级延后到 Phase 4）
    - .planning/research/PITFALLS.md（SDK bump 风险）
    - CLAUDE.md（4 层架构、provider 状态管理）
  </read_first>
  <action>
按锁定决策升级 pubspec.yaml（per D-01/D-03；fl_chart 延后到 Phase 4，per ROADMAP Phase 1 success criteria 第 3 条）：
1. environment.sdk 改为 `'>=3.6.0 <4.0.0'`（不要升到 3.10，本阶段上限严格 3.6.x 范围，per D-01）。
2. dependencies 新增 `drift: ^2.32.0`。
3. dependencies 新增 `archive: ^4.0.2`（Phase 6 data.binance.vision ZIP 用，本阶段先装入，per D-03）。
4. dev_dependencies 新增 `drift_dev: ^2.6.0`（per STACK.md 锁定；drift_dev 2.6.x 系列与 drift 2.32 配对；以 `flutter pub get` 解析成功为准，per WARNING 5）。build_runner 沿用既有 ^2.4.0。
5. **`fl_chart` 行保持 `fl_chart: ^0.65.0` 不动**——fl_chart 1.2 升级 + macd_chart_widget.dart 迁移属于 Phase 4，本阶段不触碰（per ROADMAP Phase 1 success criteria 第 3 条、Phase 4 Goal）。
6. 保留既有 sqflite、provider、web_socket_channel、flutter_chen_kchart 等依赖，不要删除（per D-03 共存策略、D-08 零回归）。
7. 不要在本任务动任何 lib/ 源码，仅改 pubspec。

完成后执行 `flutter pub get`，若出现版本冲突优先调整 drift_dev 与 sqlite3_flutter_libs 的传递依赖；冲突无法解决时停止并在 SUMMARY 记录。
  </action>
  <verify>
    <automated>cd C:/Users/softc/Desktop/TomApp && flutter pub get && grep -q "sdk: '>=3.6.0 <4.0.0'" pubspec.yaml && grep -q "drift: ^2.32.0" pubspec.yaml && grep -q "archive: ^4.0.2" pubspec.yaml && grep -q "drift_dev: ^2.6.0" pubspec.yaml && grep -q "fl_chart: ^0.65.0" pubspec.yaml</automated>
  </verify>
  <acceptance_criteria>
    - pubspec.yaml 含字符串 `sdk: '>=3.6.0 <4.0.0'`
    - pubspec.yaml 含字符串 `drift: ^2.32.0`
    - pubspec.yaml 含字符串 `archive: ^4.0.2`
    - pubspec.yaml dev_dependencies 含字符串 `drift_dev: ^2.6.0`（必须含 `^2.6`，per WARNING 5 / STACK.md，不能只 grep `drift_dev`）
    - pubspec.yaml 中 `fl_chart` 行**仍为** `fl_chart: ^0.65.0`（`grep 'fl_chart: ^0.65.0' pubspec.yaml` 成功）——fl_chart 在本阶段不动
    - `flutter pub get` 退出码 0 且无 "version solving failed"
    - 既有 sqflite / provider / flutter_chen_kchart 依赖未被删除
  </acceptance_criteria>
  <done>SDK 升到 3.6 范围，drift 2.32 / archive 4.0.2 / drift_dev 2.6 装入且 pub get 无冲突；fl_chart 保持 ^0.65.0 不动；既有依赖保留。</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: 在 technical_indicators.dart 既有 TechnicalIndicators 类中追加 ATR/RSI/Bollinger/swing 的无状态 instance 方法（沿用 KlineData）+ 单测</name>
  <files>lib/services/technical_indicators.dart, test/technical_indicators_test.dart</files>
  <read_first>
    - lib/services/technical_indicators.dart（既有 TechnicalIndicators 类，已是 instance 方法风格：calculateMA / calculateBOLL / calculateMACD；**沿用其风格与 KlineData 类型**，仅追加 instance 方法，不破坏既有）
    - lib/models/kline_data.dart（既有 OHLC 类型 KlineData，字段 open/high/low/close/volume/time；**沿用，不引入新的 Candle 类型**）
    - lib/services/pump_detector.dart（既有 detector 如何消费指标，确保新方法签名与之风格一致且不触碰该文件）
    - .planning/research/STACK.md（ATR=Wilders/RMA、warm-up 头 14 根返回 null）
    - .planning/research/PITFALLS.md（warm-up、指标计算常见错误、数据源污染）
    - .planning/research/SUMMARY.md（Phase 1 指标纯函数不变量）
    - CLAUDE.md（中文注释、既有命名风格）
  </read_first>
  <behavior>
    - ATR(Wilders/RMA, period=14)：对一条合成 KlineData 序列，第 1..14 根返回 null（未就绪）；第 15 根起返回与手算 Wilders 平滑一致的值（精度 1e-9）。
    - ATR 幂等（纯函数不变量 / key_links 验证）：对同一 List<KlineData> 序列两次调用 atr/atrSeries 结果逐位相等，且调用前后序列对象与全局状态无变化（无副作用）。
    - RSI(14)：对一条单调上涨序列返回接近 100；对包含超卖（连续下跌至 RSI<30）后向上拐头的序列，rsiTurningUp 返回 oversoldTurningUp=true。
    - Bollinger：复用既有 calculateBOLL（middle=MA20，upper/lower=middle±k*std）；既有调用方零破坏。
    - swingHigh(lookback=2)：返回最近一根其 high 严格大于左右各 2 根的索引；swingLow 对称。
    - 风格约束（WARNING 3）：新方法为 instance 方法（与 calculateMA/calculateBOLL 一致），OHLC 类型为 KlineData；不引入新的 OHLC 类型；不新增 static 方法（避免 static/instance 混用）。
    - 纯函数约束：方法体内不得出现 DateTime.now、async/await、Provider、文件/网络 IO、可变字段（grep 校验）。
  </behavior>
  <action>
先写 test/technical_indicators_test.dart（RED），覆盖 behavior 全部用例（含 Wilders 手算固定值、warm-up 头 14 根 null、纯函数两次调用逐位相等且无副作用、RSI 超卖拐头、Bollinger 三轨（复用既有 calculateBOLL 验证三轨齐备）、swing high/low）。运行 `flutter test test/technical_indicators_test.dart` 确认失败（方法尚未实现）。

然后 GREEN：在 lib/services/technical_indicators.dart 的既有 `TechnicalIndicators` 类中追加以下 **instance 方法**（与既有 calculateMA/calculateBOLL/calculateMACD 风格一致，per WARNING 3 / D-04/D-05/D-06），沿用既有 `KlineData` 类型（来自 package:tomapp/models/kline_data.dart），不修改既有方法体、不新增 static、不引入新的 OHLC 类型：
1. `double? atr(List<KlineData> klines, {int period = 14})`：True Range = max(high-low, |high-prevClose|, |low-prevClose|)；首根无 prevClose 时 TR=high-low。第一个 ATR = 头 period 根 TR 的简单平均；之后用 Wilders 平滑 `atr = (prevAtr*(period-1) + tr) / period`。klines.length <= period 时返回 null（warm-up，per D-06）。
2. `List<double?> atrSeries(List<KlineData> klines, {int period = 14})`：逐根调用同一 Wilders 公式产出序列，前 period 个为 null（供回测逐根取值，与单值 atr 同源）。
3. `double? rsi(List<KlineData> klines, {int period = 14})`：用 Wilders 平滑的 avgGain/avgLoss，loss==0 时返回 100；长度不足返回 null。
4. `({double rsi, bool oversoldTurningUp}) rsiTurningUp(List<KlineData> klines, {int period = 14, double oversold = 30})`：内部基于 RSI 序列，判定「前一根 RSI<oversold 且 当前根 RSI > 前一根」；长度不足返回 rsi=null/oversoldTurningUp=false。
5. Bollinger：复用既有 `calculateBOLL`，不新增并行入口（既有签名满足需求；测试通过既有方法验证三轨齐备）。
6. `int? swingHigh(List<KlineData> klines, {int lookback = 2})`：从末尾向前找第一个满足 `klines[i].high` 严格大于其左右各 lookback 根 high 的索引，找不到返回 null；`swingLow` 对称用 low。

中文注释（per CLAUDE.md）说明 Wilders 公式、warm-up 边界、纯函数约束。运行 `flutter test test/technical_indicators_test.dart` 直到全绿（GREEN）。
  </action>
  <verify>
    <automated>cd C:/Users/softc/Desktop/TomApp && flutter test test/technical_indicators_test.dart && ! grep -nE "DateTime\.now|[^A-Za-z]async[^A-Za-z]|[^A-Za-z]await[^A-Za-z]|Provider|File\(" lib/services/technical_indicators.dart && grep -qE "double\? atr\(List<KlineData> klines" lib/services/technical_indicators.dart && grep -q "rsiTurningUp" lib/services/technical_indicators.dart && grep -q "swingHigh" lib/services/technical_indicators.dart && grep -q "swingLow" lib/services/technical_indicators.dart</automated>
  </verify>
  <acceptance_criteria>
    - `flutter test test/technical_indicators_test.dart` 退出码 0（全部用例通过）
    - lib/services/technical_indicators.dart 含 `double? atr(List<KlineData> klines`（**instance 方法、参数类型为 `List<KlineData>`，per WARNING 3**）
    - lib/services/technical_indicators.dart 含 `rsiTurningUp`
    - lib/services/technical_indicators.dart 含 `swingHigh` 与 `swingLow`
    - lib/services/technical_indicators.dart 中新增方法体不含 DateTime.now / async / await / Provider / File( （纯函数不变量，per D-05）
    - **风格一致（WARNING 3）**：新增方法均为 instance 方法（无 `static` 关键字），OHLC 类型沿用 `KlineData`；文件中不出现新的 OHLC 类型（如 `Candle`）；既有 MA/EMA/MACD/Bollinger 方法签名未被破坏（grep `calculateMA` / `calculateBOLL` / `calculateMACD` 仍存在）
    - lib/services/pump_detector.dart 未被修改
    - ATR 单测显式断言前 14 根返回 null（warm-up，per D-06）
    - ATR 单测断言 Wilders 平滑值与固定期望一致（精度 1e-9）
    - **纯函数幂等冒烟（key_links 验证）**：单测对同一序列两次调用 atr/atrSeries，断言结果逐位相等且无副作用
  </acceptance_criteria>
  <done>ATR(Wilders)/RSI(超卖拐头)/Bollinger/swing high/low 全部以 TechnicalIndicators 类的无状态 instance 方法实现（沿用 KlineData，不混 static/instance）并通过单测；warm-up、纯函数不变量与幂等冒烟被显式验证；既有指标与 pump_detector 零破坏。</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: 新建 drift_database.dart（Klines/BacktestRuns/BacktestTrades 三表）+ build_runner + DatabaseHelper migration（onCreate + onUpgrade 双路径建表）+ 单测</name>
  <files>lib/services/drift_database.dart, lib/services/database_helper.dart, test/drift_database_test.dart, test/database_helper_migration_test.dart</files>
  <read_first>
    - lib/services/database_helper.dart（既有 sqflite helper：当前 _databaseVersion=3，_onCreate 建 PumpHistory/futures_symbols，_onUpgrade 含 oldVersion<2/3 分支；沿用其版本号递增策略；**已知 pre-existing 不一致**：kline_cache 仅在 onUpgrade 出现未在 onCreate 出现，本阶段不修）
    - lib/services/pump_detector.dart（确认哪些表被既有路径使用，避免破坏）
    - lib/services/technical_indicators.dart（Task 2 产出，确认风格一致）
    - lib/models/kline_data.dart（确认 OHLC 字段命名，drift Klines 列与之一致）
    - .planning/research/STACK.md（drift 2.32、Dart 3.6、表清单 per D-07；drift_dev ^2.6.0）
    - .planning/research/ARCHITECTURE.md（drift 与 sqflite 共存策略、新表归属 drift）
    - .planning/research/PITFALLS.md（迁移破坏既有功能的风险）
    - pubspec.yaml（Task 1 升级后确认 drift/drift_dev 已在）
  </read_first>
  <behavior>
    - Klines 表可插入并按 (symbol, interval, openTime) 主键去重查询；openTime 为 PK。
    - BacktestRuns 插入返回自增 id；params/stats 以 JSON text 存储。
    - BacktestTrades 外键 runId 关联 BacktestRuns，删除 run 时级联删除其 trades（onDelete: KeyAction.cascade）。
    - DatabaseHelper 升级 schema version（3 → 4）后，**既有 pump 表数据可被既有路径正常读写（回归）**。
    - **fresh-install（onCreate）路径上 drift 三表都被创建**：对空 DB 调用 onCreate 后，sqlite_master 中能查到 Klines / BacktestRuns / BacktestTrades 三张表（BLOCKER 2）。
    - **upgrade（onUpgrade，oldVersion<4）路径上 drift 三表也被创建**。
    - drift 与 sqflite 共存于同一 SQLite 文件不冲突（per D-03 lower-risk）。
  </behavior>
  <action>
先写测试（RED）：
- `test/drift_database_test.dart`：用内存 QueryExecutor（NativeDatabase.memory 或 drift 测试工具）建 AppDatabase，对三表做插入/查询/外键级联验证。
- `test/database_helper_migration_test.dart`：对**空 DB** 触发 onCreate 路径（fresh install），然后查询 sqlite_master 断言 Klines / BacktestRuns / BacktestTrades 三表都存在（BLOCKER 2 的专门验收）。可对 onUpgrade(oldVersion<4) 路径也加一条断言。
运行 `flutter test test/drift_database_test.dart test/database_helper_migration_test.dart` 确认失败。

然后 GREEN：
1. 新建 lib/services/drift_database.dart（per D-07），定义三个 Table 类，列严格按 locked_decisions 第 7 条：
   - `Klines`：symbol TextColumn, interval TextColumn, openTime IntColumn() PK（autoIncrement=false，作主键）, open/ high/ low/ close/ volume RealColumn, closeTime IntColumn。主键约束 = (symbol, interval, openTime) 复合或 openTime 单 PK（按 drift 习惯实现，确保同一 symbol+interval+openTime 唯一）。
   - `BacktestRuns`：id IntColumn autoIncrement PK, params TextColumn（JSON）, startedAt IntColumn, stats TextColumn（JSON）。
   - `BacktestTrades`：id autoIncrement PK, runId IntColumn().references(BacktestRuns, #id, onDelete: KeyAction.cascade)(), symbol TextColumn, entryTime IntColumn, entryPrice RealColumn, exitTime IntColumn, exitPrice RealColumn, side TextColumn, pnl RealColumn, rMultiple RealColumn。
   - 定义 `@DriftDatabase(tables: [Klines, BacktestRuns, BacktestTrades]) class AppDatabase extends GeneratedDatabase`，构造 `AppDatabase(QueryExecutor e)`。
2. 运行 `dart run build_runner build --delete-conflicting-outputs` 生成 `drift_database.g.dart`。
3. 修改 lib/services/database_helper.dart：
   - 递增 schema version（`_databaseVersion` 由 3 改为 4）。
   - **把 drift 三表建表 SQL（`CREATE TABLE IF NOT EXISTS Klines ...` / `BacktestRuns ...` / `BacktestTrades ...`）抽到同一个 private helper 方法**（如 `Future<void> _createDriftTables(Database db)`），在 `_onCreate` 与 `_onUpgrade` 的 `if (oldVersion < 4)` 分支中都调用该 helper，确保 fresh-install 与 upgrade **两条路径**都建出三表（BLOCKER 2）。
   - 保留既有 PumpHistory / futures_symbols 的 onCreate 与 onUpgrade 分支不动（per D-08 零回归）。
   - **不修 pre-existing 的 kline_cache 不一致**（out of scope）；只确保新增 drift 三表不重蹈覆辙——双路径都建。
   - drift 与 sqflite 共享同一 SQLite 文件路径（per D-03）。
4. 运行 `flutter test test/drift_database_test.dart test/database_helper_migration_test.dart` 直到全绿。

中文注释（per CLAUDE.md）说明每张表用途、与既有 sqflite 表的共存关系、迁移版本号含义、以及 onCreate/onUpgrade 双路径建表的设计原因。
  </action>
  <verify>
    <automated>cd C:/Users/softc/Desktop/TomApp && dart run build_runner build --delete-conflicting-outputs && flutter test test/drift_database_test.dart test/database_helper_migration_test.dart && grep -q "class Klines extends Table" lib/services/drift_database.dart && grep -q "class BacktestRuns extends Table" lib/services/drift_database.dart && grep -q "class BacktestTrades extends Table" lib/services/drift_database.dart && grep -q "AppDatabase" lib/services/drift_database.dart && grep -qE "oldVersion < 4|oldVersion<4" lib/services/database_helper.dart</automated>
  </verify>
  <acceptance_criteria>
    - `dart run build_runner build --delete-conflicting-outputs` 退出码 0，生成 lib/services/drift_database.g.dart
    - `flutter test test/drift_database_test.dart` 退出码 0（三表 CRUD + 外键级联）
    - `flutter test test/database_helper_migration_test.dart` 退出码 0，且其中存在一条断言：**对空 DB 触发 onCreate 后 Klines / BacktestRuns / BacktestTrades 三表都存在**（BLOCKER 2 验收）
    - lib/services/drift_database.dart 含 `class Klines extends Table` / `class BacktestRuns extends Table` / `class BacktestTrades extends Table`
    - lib/services/drift_database.dart 含 `AppDatabase`
    - Klines 列含 open/high/low/close/volume/openTime/closeTime/symbol/interval（grep 各列名存在）
    - BacktestTrades 含 runId 外键引用 BacktestRuns（grep `references` 与 `BacktestRuns`）
    - lib/services/database_helper.dart `_databaseVersion` 已递增到 4，含 `oldVersion < 4` 分支，既有 pump / futures_symbols 分支保留
    - **onCreate 与 onUpgrade 双路径都调用同一 drift 三表建表 helper**（grep 同一 helper 方法名出现在 _onCreate 与 _onUpgrade 两处；或两处都含 CREATE TABLE IF NOT EXISTS Klines/BacktestRuns/BacktestTrades）
    - 既有 pump/chart 相关测试（`flutter test` 全量）退出码 0（零回归，per D-08）
  </acceptance_criteria>
  <done>drift 三表通过 build_runner 生成代码并通过单测；DatabaseHelper 迁移升级（version 4），onCreate 与 onUpgrade 双路径都建 drift 三表（fresh-install 单测覆盖，BLOCKER 2 解决）；既有 pump 路径零回归；drift 与 sqflite 共存于同一 SQLite 文件。</done>
</task>

<task type="auto" tdd="false">
  <name>Task 4: 零回归验证闸（flutter analyze + 全量 flutter test）——fl_chart 未动，真正可达</name>
  <files>(不修改文件，仅验证)</files>
  <read_first>
    - pubspec.yaml（确认 Task 1 升级后状态：fl_chart 仍为 ^0.65.0）
    - lib/services/technical_indicators.dart（确认 Task 2 追加未破坏既有）
    - lib/services/drift_database.dart（确认 Task 3 生成代码存在）
    - lib/services/database_helper.dart（确认 Task 3 迁移不破坏既有）
    - lib/widgets/macd_chart_widget.dart（确认既有 fl_chart 0.65 消费者未被本阶段影响）
    - .planning/research/PITFALLS.md（SDK bump 破坏面、drift 新文件破坏面）
  </read_first>
  <action>
执行零回归验证闸（per D-08），不修改源码，仅运行命令并记录结果：
1. `flutter analyze` — 必须退出码 0；若有 warning/error，定位是否由本阶段改动（SDK bump / drift 新文件）引入。**因本阶段未触碰 fl_chart 版本号**（保持 ^0.65.0），macd_chart_widget.dart 等 fl_chart 0.65 消费者理论上不应触发 API 破坏——fl_chart 1.2 升级与既有 widget 迁移属于 Phase 4，本阶段不涉及。若 analyze 报错，必须在本任务内修复（仅限恢复既有行为，不新增 Phase 4 代码）。
2. `flutter test`（全量，不带 path 过滤）— 必须全部通过；既有 pump/chart 测试与本阶段新增三个测试文件（technical_indicators_test.dart / drift_database_test.dart / database_helper_migration_test.dart）均绿。
3. `flutter pub get` 复跑确认无漂移。
若任意步骤失败，停止并记录失败命令与输出摘要；不要为了「过闸」而删除或注释既有测试或降低断言。
  </action>
  <verify>
    <automated>cd C:/Users/softc/Desktop/TomApp && flutter analyze && flutter test && flutter pub get</automated>
  </verify>
  <acceptance_criteria>
    - `flutter analyze` 退出码 0（无 error；warning 数量不高于本阶段开始前基线）
    - `flutter test` 全量退出码 0（既有测试 + 本阶段 technical_indicators_test.dart + drift_database_test.dart + database_helper_migration_test.dart 全绿）
    - `flutter pub get` 退出码 0
    - 验证过程中未删除或 .skip 任何既有测试
    - pubspec.yaml 中 fl_chart 仍为 ^0.65.0（本阶段零触达 fl_chart）
  </acceptance_criteria>
  <done>SDK 升级 + drift 新增两项改动对既有 pump/chart 功能（含 fl_chart 0.65 消费者）零回归；全量测试绿；fl_chart 1.2 升级按计划延后到 Phase 4。</done>
</task>

</tasks>

<threat_model>
## 信任边界

| 边界 | 说明 |
|------|------|
| (本阶段无外部输入边界) | Phase 1 仅产出纯函数指标 + 本地 drift 表，不接入网络/WebSocket/用户输入；指标输入 klines 由调用方（既有 pump 路径 / 未来 Phase 2/6）传入，非本阶段信任边界。 |
| 本地 SQLite 文件 | drift/sqflite 共存的 SQLite 文件为本阶段唯一持久化面；既有路径已有权限边界，本阶段仅追加表。 |

## STRIDE 威胁登记表

| Threat ID | 类别 | 组件 | 处置 | 缓解计划 |
|-----------|------|------|------|----------|
| T-01-01 | Tampering | drift_database.dart BacktestTrades.runId 外键 | mitigate | 使用 references(..., onDelete: KeyAction.cascade) 防止悬挂外键导致数据污染 |
| T-01-02 | Information Disclosure | 本地 SQLite 文件 | accept | 仅本地交易数据，无 PII；既有 sqflite 已沿用同一模型，本阶段不扩大攻击面 |
| T-01-03 | Denial of Service | atrSeries/atr 对超长序列的 O(n) 计算 | accept | 纯函数、单次 O(n)，回测规模有限；不在本阶段引入缓存或限流 |
| T-01-SC | Tampering | pubspec 依赖（drift/archive/drift_dev） | mitigate | 锁定版本范围（per STACK.md：drift ^2.32 / archive ^4.0.2 / drift_dev ^2.6.0），flutter pub get 解析失败即阻塞；未引入 [SLOP] 包；fl_chart 本阶段不动（延后 Phase 4 单独审计） |
</threat_model>

<verification>
- `flutter pub get` 退出 0，pubspec 锁定版本正确（sdk 3.6、drift 2.32、archive 4.0.2、drift_dev ^2.6.0）；**fl_chart 仍为 ^0.65.0**。
- `flutter test test/technical_indicators_test.dart` 通过：ATR Wilders 手算值一致、头 14 根 null、纯函数两次调用逐位相等且无副作用（幂等冒烟）、RSI 超卖拐头、Bollinger 三轨、swing high/low。
- `dart run build_runner build --delete-conflicting-outputs` 通过，drift_database.g.dart 生成。
- `flutter test test/drift_database_test.dart` 通过：三表 CRUD + 外键级联。
- `flutter test test/database_helper_migration_test.dart` 通过：**fresh-install（onCreate on empty DB）后 Klines / BacktestRuns / BacktestTrades 三表都存在**（BLOCKER 2）。
- `flutter analyze` 退出 0。
- `flutter test`（全量）退出 0，既有 pump/chart 测试与本阶段新增测试全绿。
</verification>

<success_criteria>
1. ATR(14) Wilders 平滑实现，live 与回测同源（TechnicalIndicators 类上的同一 instance 方法），单测覆盖头 14 根返回 null 的 warm-up 与幂等冒烟（满足 INDIC-01）。
2. RSI(14) 超卖拐头判定、Bollinger 三轨（复用既有 calculateBOLL）、swing high/low 全部实现并通过单测（满足 INDIC-02）。
3. Dart SDK ≥3.6、drift 2.32、archive 4.0.2、drift_dev ^2.6.0 装入，`flutter pub get` 无冲突；**fl_chart 保持 ^0.65.0 不动**（升级延后 Phase 4）（满足 INDIC-03）。
4. drift `Klines`/`BacktestRuns`/`BacktestTrades` 三表 + DatabaseHelper migration（onCreate + onUpgrade 双路径建表，fresh-install 单测覆盖）通过，既有 pump/chart 零回归（满足 INDIC-04）。
5. 指标函数全部为纯函数（无 DateTime.now/async/Provider/IO），且沿用既有 KlineData 类型与 instance 方法风格，满足 Phase 2/6 的同源不变量。
</success_criteria>

<output>
完成后创建 `.planning/workstreams/contract-quick-rebound/phases/01-atr-rsi-bollinger-swing-sdk-drift-schema/01-SUMMARY.md`
</output>
