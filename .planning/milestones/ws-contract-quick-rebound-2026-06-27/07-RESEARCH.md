# Phase 7: rebound-test-page - Research

**Researched:** 2026-06-27
**Domain:** 模拟数据生成 + fl_chart CandlestickChart + 测试调试页面架构
**Confidence:** HIGH

## Summary

Phase 7 的目标是创建一个独立的测试调试页面，用于验证反弹检测逻辑。核心组件包括：TestDataGenerator（模拟 K 线数据生成器）、TestOrchestrator（测试编排器，每 5 秒驱动数据生成+检测）、ReboundTestScreen（UI 页面，上半部分 K 线图、下半部分信号列表）。

本阶段依赖 Phase 2 的 ReboundDetector 纯函数，不涉及网络 I/O 或外部服务。所有数据为本地模拟生成，检测逻辑复用现有 `ReboundDetector.evaluate`。

**主要建议：** 使用 fl_chart 1.2.0 的 CandlestickChart 展示 K 线数据，通过自定义 `CandlestickStyleProvider` 实现下跌段（红色）和拉回段（绿色）的高亮标注。TestDataGenerator 应生成 4 种模式的模拟数据（V 型反弹、死猫反弹、随机游走、持续下跌），每种模式通过确定性算法保证可重现。

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| 模拟数据生成 | Service | — | 纯数据生成逻辑，无 UI 依赖 |
| 检测编排 | Service | — | 定时驱动数据生成+检测，管理状态 |
| K 线可视化 | UI | — | fl_chart CandlestickChart 渲染 |
| 信号列表展示 | UI | — | 消费检测结果，展示评分/死猫风险 |
| 控制栏交互 | UI | — | 开始/暂停、模式切换、参数调整 |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fl_chart | 1.2.0 | CandlestickChart K 线图 | 已在项目中使用，Phase 4 升级到 1.2.0 |
| provider | 6.1.0 | 状态管理 | 项目标准状态管理方案 |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | SDK | 单元测试 | TestDataGenerator 单测 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart CandlestickChart | flutter_chen_kchart | flutter_chen_kchart 已用于 KlineScreen，但 CandlestickChart 更轻量、适合测试页面的简化展示 |
| Provider for test page state | setState | 测试页面状态简单，setState 足够；但如果需要跨组件共享状态则用 Provider |

**Installation:**
无需新增依赖，fl_chart 1.2.0 和 provider 6.1.0 已在项目中。

## Package Legitimacy Audit

本阶段不安装新外部包，无需审计。

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| — | — | — | — | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    ReboundTestScreen                      │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                 Control Bar                          │ │
│  │  [开始/暂停] [模式切换▾] [参数调整▾]                  │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            CandlestickChart (上半部分)                │ │
│  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │ │
│  │  │ ▓▓▓ │ │ ▓▓▓ │ │ ▓▓▓ │ │ ▓▓▓ │ │ ▓▓▓ │ ...      │ │
│  │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘          │ │
│  │  红色=下跌段  绿色=拉回段  灰色=正常                   │ │
│  └─────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Signal List (下半部分)                     │ │
│  │  ┌─────────────────────────────────────────────┐    │ │
│  │  │ Score 65 | 死猫风险 25 | 回补 72% | 2×ATR   │    │ │
│  │  │ RSI拐头✓ 放量✓ | 14:32:05                    │    │ │
│  │  └─────────────────────────────────────────────┘    │ │
│  │  ┌─────────────────────────────────────────────┐    │ │
│  │  │ Score 45 | 死猫风险 70 | 回补 55% | 1.5×ATR  │    │ │
│  │  │ 无共振 | 14:31:55                             │    │ │
│  │  └─────────────────────────────────────────────┘    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
          │                    ▲
          ▼                    │
┌─────────────────────────────────────────┐
│           TestOrchestrator               │
│  ┌───────────────┐  ┌─────────────────┐ │
│  │ TestDataGen   │  │ ReboundDetector │ │
│  │ (4种模式)      │  │ (Phase 2 纯函数)│ │
│  └───────────────┘  └─────────────────┘ │
│  Timer.periodic(5s) → generate → eval   │
└─────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/
├── services/
│   └── rebound/
│       ├── rebound_detector.dart          # 已有
│       ├── test_data_generator.dart       # 新增：模拟 K 线数据生成
│       └── test_orchestrator.dart         # 新增：测试编排器
├── screens/
│   └── rebound_test_screen.dart           # 新增：测试调试页面
└── models/
    └── kline_data.dart                    # 已有
```

### Pattern 1: TestDataGenerator — 模拟数据生成器

**What:** 纯函数类，根据指定模式生成模拟 K 线数据序列
**When to use:** 测试页面需要模拟数据时，替代真实 WebSocket 数据
**Example:**

```dart
/// 模拟数据生成模式枚举。
enum SimulationMode {
  vRebound,      // V 型反弹：急跌后快速回升
  deadCatBounce, // 死猫反弹：弱回补、低量、高死猫风险
  randomWalk,    // 随机游走：无明显趋势
  steadyDecline, // 持续下跌：无反弹
}

/// 模拟 K 线数据生成器（纯函数，无状态）。
///
/// 每次调用 [nextCandle] 返回一根新的模拟 K 线，
/// 根据 [SimulationMode] 生成不同模式的价格序列。
class TestDataGenerator {
  final SimulationMode mode;
  final Random _random;
  double _lastClose;
  int _step;
  // ... 模式特定状态

  TestDataGenerator({
    required this.mode,
    double initialPrice = 100.0,
    int? seed,
  }) : _random = Random(seed),
       _lastClose = initialPrice,
       _step = 0;

  /// 生成下一根 K 线数据。
  KlineData nextCandle(DateTime time) {
    switch (mode) {
      case SimulationMode.vRebound:
        return _generateVRebound(time);
      case SimulationMode.deadCatBounce:
        return _generateDeadCatBounce(time);
      case SimulationMode.randomWalk:
        return _generateRandomWalk(time);
      case SimulationMode.steadyDecline:
        return _generateSteadyDecline(time);
    }
  }
}
```

### Pattern 2: TestOrchestrator — 测试编排器

**What:** 管理定时器、维护滚动窗口、驱动检测、收集信号
**When to use:** 测试页面需要实时模拟+检测循环时
**Example:**

```dart
/// 测试编排器：每 5 秒生成一根 K 线，送入 ReboundDetector 检测。
///
/// 管理状态：滚动窗口（最近 50 根）、信号历史（最多 20 条）、
/// 运行状态（运行中/暂停）。
class TestOrchestrator extends ChangeNotifier {
  final TestDataGenerator _generator;
  final ReboundDetector _detector;
  final ReboundParams _params;

  Timer? _timer;
  final List<KlineData> _window = [];
  final List<ReboundSignal> _signals = [];
  bool _isRunning = false;

  static const int windowSize = 50;
  static const int maxSignals = 20;
  static const Duration interval = Duration(seconds: 5);

  List<KlineData> get window => List.unmodifiable(_window);
  List<ReboundSignal> get signals => List.unmodifiable(_signals);
  bool get isRunning => _isRunning;

  void start() { /* ... */ }
  void pause() { /* ... */ }
  void reset() { /* ... */ }
  void changeMode(SimulationMode mode) { /* ... */ }
}
```

### Pattern 3: ReboundTestScreen — 测试页面 UI

**What:** StatefulWidget，上半部分 CandlestickChart、下半部分信号列表、顶部控制栏
**When to use:** 用户需要可视化验证反弹检测逻辑时
**Example:**

```dart
class ReboundTestScreen extends StatefulWidget {
  const ReboundTestScreen({super.key});

  @override
  State<ReboundTestScreen> createState() => _ReboundTestScreenState();
}

class _ReboundTestScreenState extends State<ReboundTestScreen> {
  late TestOrchestrator _orchestrator;

  @override
  void initState() {
    super.initState();
    _orchestrator = TestOrchestrator(
      generator: TestDataGenerator(mode: SimulationMode.vRebound),
      detector: ReboundDetector(TechnicalIndicators()),
      params: const ReboundParams(),
    );
    _orchestrator.addListener(_onUpdate);
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _orchestrator.removeListener(_onUpdate);
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('反弹检测测试')),
      body: Column(
        children: [
          _buildControlBar(),
          Expanded(flex: 3, child: _buildCandlestickChart()),
          Expanded(flex: 2, child: _buildSignalList()),
        ],
      ),
    );
  }
}
```

### Anti-Patterns to Avoid

- **直接在 UI 中生成数据：** 数据生成逻辑应封装在 TestDataGenerator 中，UI 只负责展示。违反关注点分离。
- **使用 DateTime.now() 作为 K 线时间：** 模拟数据的时间应由编排器控制（基于起始时间+步进），保证可重现性。与 ReboundDetector 的纯函数约束一致。
- **信号列表无限增长：** 必须限制为最多 20 条，否则内存持续增长。
- **在 CandlestickChart 中使用固定 bodyWidth：** 应根据可见 K 线数量动态计算 bodyWidth，避免 K 线过多时重叠。

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| K 线图渲染 | 自定义 Canvas 绘制 | fl_chart CandlestickChart | 已在项目中使用，API 成熟，支持触摸交互 |
| 定时器管理 | 手动 Timer.periodic + dispose | TestOrchestrator 封装 | 集中管理生命周期，避免泄漏 |
| 滚动窗口 | 手动 List 管理 | 固定大小 List + removeAt(0) | 简单有效，窗口大小固定 50 |

## Common Pitfalls

### Pitfall 1: CandlestickChart 的 x 轴索引

**What goes wrong：** CandlestickSpot 的 x 值必须是递增的数值索引（0, 1, 2, ...），不是时间戳。如果直接用时间戳作为 x，会导致 K 线间距不均匀或无法显示。

**Why it happens：** fl_chart 的 CandlestickChart 使用数值轴（非时间轴），x 值是数据点的序号。

**How to avoid：** 使用 `index.toDouble()` 作为 x 值，通过 `titlesData` 自定义底部标签显示时间。

**Warning signs：** K 线全部挤在一起或完全不显示。

### Pitfall 2: 模拟数据的 ATR 计算需要足够 warm-up

**What goes wrong：** TestDataGenerator 生成的前 14 根 K 线如果波动太小，ATR 值会极低，导致 dropMagnitude（跌幅/ATR）异常大，即使小幅下跌也会触发信号。

**Why it happens：** ATR(14) 需要至少 14 根 K 线才能计算，前 14 根的波动率决定了后续的归一化基准。

**How to avoid：** 生成数据时，先用稳定行情填充前 20 根（如 `_stableBars(20)` 模式），确保 ATR 有合理的基础值。与 Phase 2 测试 fixture 策略一致。

**Warning signs：** 检测到的 dropMagnitude 异常大（如 100×ATR）。

### Pitfall 3: Timer 生命周期管理

**What goes wrong：** 页面 dispose 后 Timer 仍在运行，导致 setState called after dispose 错误。

**Why it happens：** Timer.periodic 不会自动随 Widget 生命周期停止。

**How to avoid：** 在 TestOrchestrator.dispose() 中取消 Timer，在 Screen.dispose() 中调用 orchestrator.dispose()。

**Warning signs：** 控制台出现 "setState() called after dispose()" 错误。

### Pitfall 4: 信号高亮区域定位

**What goes wrong：** 需要在 CandlestickChart 上标注下跌段和拉回段的高亮区域，但 fl_chart 的 CandlestickChart 不直接支持区域高亮。

**Why it happens：** CandlestickChart 只支持单根 K 线的样式定制，不支持跨 K 线的区域标注。

**How to avoid：** 通过自定义 `CandlestickStyleProvider`，根据信号的 dropStartIndex/dropEndIndex/recoveryEndIndex，为对应范围内的 K 线设置不同颜色（下跌段红色、拉回段绿色、正常灰色）。这是 per-spot 级别的着色，不是区域矩形覆盖。

**Warning signs：** 高亮区域与实际信号位置不匹配。

## Code Examples

### CandlestickChart 基本用法

```dart
// Source: fl_chart 1.2.0 source - candlestick_chart_data.dart
CandlestickChart(
  CandlestickChartData(
    candlestickSpots: klines.asMap().entries.map((entry) {
      final i = entry.key;
      final k = entry.value;
      return CandlestickSpot(
        x: i.toDouble(),
        open: k.open,
        high: k.high,
        low: k.low,
        close: k.close,
      );
    }).toList(),
    candlestickPainter: DefaultCandlestickPainter(
      candlestickStyleProvider: (spot, index) {
        // 根据信号范围着色
        Color color;
        if (index >= dropStartIdx && index <= dropEndIdx) {
          color = Colors.red;  // 下跌段
        } else if (index > dropEndIdx && index <= recoveryEndIdx) {
          color = Colors.green;  // 拉回段
        } else {
          color = spot.isUp ? Colors.green.shade700 : Colors.red.shade700;
        }
        return CandlestickStyle(
          lineColor: color,
          lineWidth: 1.5,
          bodyStrokeColor: color,
          bodyStrokeWidth: 0,
          bodyFillColor: color,
          bodyWidth: 8,
          bodyRadius: 1,
        );
      },
    ),
    gridData: const FlGridData(show: true),
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(1),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            // 显示时间标签
            final idx = value.toInt();
            if (idx >= 0 && idx < klines.length) {
              final t = klines[idx].time;
              return Text(
                '${t.hour}:${t.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.grey, fontSize: 9),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(
      show: true,
      border: Border.all(color: Colors.grey.shade800, width: 0.5),
    ),
    minY: klines.map((k) => k.low).reduce((a, b) => a < b ? a : b) * 0.99,
    maxY: klines.map((k) => k.high).reduce((a, b) => a > b ? a : b) * 1.01,
  ),
)
```

### TestDataGenerator V 型反弹模式

```dart
/// V 型反弹数据生成：平稳 → 急跌 → 快速回升。
///
/// 阶段划分（基于 _step）：
/// - 0-19: 平稳行情（close ≈ 100，波动小）
/// - 20-22: 急跌段（3 根 K 线跌至 ~90）
/// - 23-24: 快速回升（2 根 K 线回到 ~98，volume 放大）
/// - 25+: 新一轮平稳（等待下一轮模式循环）
KlineData _generateVRebound(DateTime time) {
  final phase = _step % 30; // 30 根一个周期

  double open, close, high, low, volume;

  if (phase < 20) {
    // 平稳段
    open = _lastClose;
    close = open + (_random.nextDouble() - 0.5) * 1.0;
    high = max(open, close) + _random.nextDouble() * 0.5;
    low = min(open, close) - _random.nextDouble() * 0.5;
    volume = 10 + _random.nextDouble() * 5;
  } else if (phase < 23) {
    // 急跌段：每根跌 3-4%
    open = _lastClose;
    close = open * (0.96 - _random.nextDouble() * 0.01);
    high = open;
    low = close - _random.nextDouble() * 0.5;
    volume = 10 + _random.nextDouble() * 5;
  } else if (phase < 25) {
    // 快速回升：每根涨 4-5%，volume 放大
    open = _lastClose;
    close = open * (1.04 + _random.nextDouble() * 0.01);
    high = close + _random.nextDouble() * 0.5;
    low = open - _random.nextDouble() * 0.5;
    volume = 20 + _random.nextDouble() * 10; // 放量
  } else {
    // 新周期平稳
    open = _lastClose;
    close = open + (_random.nextDouble() - 0.5) * 1.0;
    high = max(open, close) + _random.nextDouble() * 0.5;
    low = min(open, close) - _random.nextDouble() * 0.5;
    volume = 10 + _random.nextDouble() * 5;
  }

  _lastClose = close;
  _step++;

  return KlineData(
    time: time,
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume,
  );
}
```

### 信号列表项布局

```dart
/// 单行信号卡片（复用 ReboundDashboardScreen 的 _SignalRow 模式）。
Widget _buildSignalRow(ReboundSignal signal) {
  return Card(
    color: Colors.grey[900],
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        children: [
          // 评分徽章
          _ScoreBadge(score: signal.score),
          const SizedBox(width: 8),
          // 信号详情
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${signal.dropMagnitude.toStringAsFixed(1)}×ATR',
                      style: TextStyle(color: Colors.red[300], fontSize: 12)),
                  const SizedBox(width: 8),
                  Text('回补 ${(signal.recoveryRatio * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: Colors.green[300], fontSize: 12)),
                  const SizedBox(width: 8),
                  _DeadCatIndicator(score: signal.deadCatRiskScore),
                ]),
                const SizedBox(height: 2),
                // 共振过滤器标签
                Wrap(spacing: 4, children: [
                  for (final f in signal.confluenceFilters)
                    Chip(
                      label: Text(_confluenceLabel(f), style: const TextStyle(fontSize: 10)),
                      backgroundColor: Colors.blueGrey[800],
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ]),
              ],
            ),
          ),
          // 时间戳
          Text(
            '${signal.timestamp.hour}:${signal.timestamp.minute.toString().padLeft(2, '0')}:${signal.timestamp.second.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| flutter_chen_kchart K 线图 | fl_chart CandlestickChart | Phase 4 (fl_chart 1.2 升级) | 测试页面使用更轻量的 fl_chart，KlineScreen 保留 flutter_chen_kchart |
| 手动 Canvas 绘制 K 线 | fl_chart CandlestickChart | fl_chart 1.2.0 原生支持 | 减少自定义绘制代码 |

**Deprecated/outdated:**
- fl_chart 0.65 的 CandlestickChart API：1.2.0 已重构，使用 CandlestickSpot + DefaultCandlestickPainter 模式

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | fl_chart 1.2.0 的 CandlestickChart 支持自定义 CandlestickStyleProvider 进行 per-spot 着色 | Code Examples | 需要用 Stack + CustomPaint 叠加高亮层作为备选方案 |

**如果此表为空：** 所有声明均已验证或引用，无需用户确认。

## Open Questions

1. **测试页面入口位置**
   - What we know: BacktestScreen 从 ProfileScreen 通过 Navigator.push 进入
   - What's unclear: ReboundTestScreen 是从 ProfileScreen 进入，还是作为独立 Tab
   - Recommendation: 从 ProfileScreen 进入（与 BacktestScreen 一致），保持主导航栏简洁

2. **参数调整 UI 的粒度**
   - What we know: ReboundParams 有 20+ 个可调参数
   - What's unclear: 控制栏暴露哪些参数给用户调整
   - Recommendation: 只暴露关键参数（dropAtrMultiplier, recoveryMinRatio, volumeMultiplier），其余使用默认值

## Environment Availability

> 本阶段无外部依赖，所有组件均为本地代码。

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| fl_chart | CandlestickChart | ✓ | 1.2.0 | — |
| provider | 状态管理 | ✓ | 6.1.0 | — |
| flutter_test | 单元测试 | ✓ | SDK | — |

**Missing dependencies with no fallback:**
- 无

**Missing dependencies with fallback:**
- 无

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | flutter_test (SDK) |
| Config file | none — 使用默认配置 |
| Quick run command | `flutter test test/services/rebound/test_data_generator_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | 每 5 秒生成一根模拟 K 线，支持 4 种模式 | unit | `flutter test test/services/rebound/test_data_generator_test.dart` | ❌ Wave 0 |
| TEST-02 | 生成数据实时送入 ReboundDetector.evaluate | unit | `flutter test test/services/rebound/test_orchestrator_test.dart` | ❌ Wave 0 |
| TEST-03 | CandlestickChart 展示最近 50 根 K 线，高亮下跌/拉回段 | manual | 手动验证：flutter run → 反弹测试页面 | — |
| TEST-04 | 信号列表展示 score≥60 的信号，最多 20 条 | unit | `flutter test test/services/rebound/test_orchestrator_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/services/rebound/test_data_generator_test.dart test/services/rebound/test_orchestrator_test.dart`
- **Per wave merge:** `flutter test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/services/rebound/test_data_generator_test.dart` — 覆盖 TEST-01（4 种模式数据生成验证）
- [ ] `test/services/rebound/test_orchestrator_test.dart` — 覆盖 TEST-02/TEST-04（编排器状态管理、信号收集）

## Sources

### Primary (HIGH confidence)

- fl_chart 1.2.0 source code — `CandlestickChartData`, `CandlestickSpot`, `DefaultCandlestickPainter`, `CandlestickStyleProvider` API
- 项目现有代码 — `ReboundDetector.evaluate`, `ReboundParams`, `ReboundSignal`, `KlineData` 模型
- Phase 2 测试 — `_bar()`, `_stableBars()`, `_vReboundFixture()` 合成 fixture 模式

### Secondary (MEDIUM confidence)

- ReboundDashboardScreen UI 模式 — `_SignalRow`, `_ScoreBadge`, `_DeadCatIndicator` 组件复用

### Tertiary (LOW confidence)

- 无

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fl_chart 1.2.0 和 provider 6.1.0 已在项目中使用
- Architecture: HIGH — 复用现有 ReboundDetector 纯函数和 UI 组件模式
- Pitfalls: HIGH — 基于 Phase 2/4 的实际开发经验

**Research date:** 2026-06-27
**Valid until:** 2026-07-27（stable，fl_chart 1.2.0 API 不会变）
