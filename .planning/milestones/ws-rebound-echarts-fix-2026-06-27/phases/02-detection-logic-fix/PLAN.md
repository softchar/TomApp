# Phase 02: 反弹检测逻辑深度修复

## 目标
修复 `ReboundDetector` 中导致明显反弹未被检出的 5 个核心问题。

## 问题诊断摘要

通过逐行审查 `rebound_detector.dart` + `test_data_generator.dart` + `technical_indicators.dart`，
发现以下导致反弹漏检的核心问题：

---

## 问题 1（致命）：midpoint 条件与 recoveryMinRatio 双重门槛

### 位置
`rebound_detector.dart:138,145-146`

### 现状代码
```dart
final midpoint = (window[startIdx].high + window[lowIdx].low) / 2;
// ...
if (recoveryRatio >= params.recoveryMinRatio &&
    window[i].close > midpoint) {
```

### 问题分析
- `recoveryMinRatio=0.5` 要求回补 50% 跌幅
- `close > midpoint` 要求收盘价超过跌幅中点（≈回补 50%）
- **看似一致，实则不同**：midpoint 基于 `startIdx.high` 和 `lowIdx.low`，
  而 recoveryRatio 基于同样的两个值，但 midpoint 是**绝对价格**条件
- 在 V 型反弹模拟中：3 根各跌 4% → 跌幅约 12%，midpoint 在 -6% 处
  - 回拉第 1 根 +5%：recoveryRatio ≈ 42%，close ≈ -7%，不满足 midpoint
  - 回拉第 2 根 +5%：recoveryRatio ≈ 83%，close ≈ -2%，满足 midpoint
  - **但如果有噪声**，第 2 根 close 可能刚好卡在 midpoint 附近 → 漏检

### 修复方案
**移除 midpoint 条件**，只保留 `recoveryRatio >= recoveryMinRatio`。
理由：recoveryRatio 本身已经衡量了回补质量，midpoint 是冗余且过于严格的条件。

```dart
// 修复后
if (recoveryRatio >= params.recoveryMinRatio) {
  return (i, recoveryRatio, i - lowIdx);
}
```

---

## 问题 2（严重）：RSI 超卖拐头在急跌中难以触发

### 位置
`rebound_detector.dart:178-186` + `technical_indicators.dart:271-294`

### 问题分析
- RSI(14) 从 50（平稳段）开始下降
- 3 根各跌 4% 的急跌，RSI 可能只降到 35-40，不满足 < 30
- Wilder 平滑使 RSI 变化缓慢，14 周期的 RSI 对短期急跌反应迟钝
- **结果**：RSI 拐头共振过滤器在 V 型反弹测试中几乎从不触发

### 修复方案
**增加 RSI 周期参数到测试页面 Slider**，允许用户调低 RSI 周期（如 7 或 9）以提高灵敏度。
同时在检测器中增加一个**快速 RSI**（周期=7）作为辅助判定：

```dart
// 方案 A：使用更短周期的 RSI
if (params.confluenceRsiOversoldTurning) {
  // 快速 RSI（周期 7）对急跌更敏感
  final fastRsiResult = _ti.rsiTurningUp(
      window.sublist(0, recoveryEndIdx + 1),
      period: 7,  // 固定短周期
      oversold: params.rsiOversold);
  // 标准 RSI（周期 14）
  final stdRsiResult = _ti.rsiTurningUp(
      window.sublist(0, recoveryEndIdx + 1),
      period: params.rsiPeriod,
      oversold: params.rsiOversold);
  // 任一满足即可
  if (fastRsiResult.oversoldTurningUp || stdRsiResult.oversoldTurningUp) {
    filters.add(ConfluenceType.rsiOversoldTurning);
  }
}
```

---

## 问题 3（中等）：swingLow 在连续下跌中可能找不到

### 位置
`technical_indicators.dart:314-328`

### 问题分析
```dart
// 要求 low 严格小于左右各 lookback(2) 根
if (!(l < klines[i - j].low) || !(l < klines[i + j].low)) {
```
- 3 根连续急跌时，如果第 3 根的 low 不严格小于第 2 根（噪声导致接近），
  swingLow 返回 null → 整个下跌段检测失败
- 在平稳段（phase 0-19），由于波动率小，swing low 可能找不到

### 修复方案
**增加 fallback 逻辑**：如果 swingLow 返回 null，使用 window 中最近 N 根的最低 low 作为备选：

```dart
int? lowIdx = _ti.swingLow(window, lookback: params.swingLookback);
// fallback：如果 swingLow 找不到，用最近 dropMaxCandles+recoveryMaxCandles 根的最低 low
if (lowIdx == null) {
  final searchWindow = params.dropMaxCandles + params.recoveryMaxCandles + 1;
  final start = window.length - searchWindow;
  if (start < 0) return null;
  double minLow = double.infinity;
  int minIdx = -1;
  for (int i = start; i < window.length; i++) {
    if (window[i].low < minLow) {
      minLow = window[i].low;
      minIdx = i;
    }
  }
  lowIdx = minIdx;
}
```

---

## 问题 4（中等）：dropMaxCandles=3 对部分反弹过于严格

### 位置
`rebound_params.dart:11` + `rebound_detector.dart:119`

### 问题分析
- V 型反弹模拟：3 根下跌，但 swingLow 可能在第 2 根
- 如果 swingLow 在第 2 根，backward search 只能看 1 根
- 可能找不到足够的 drop 起始高度

### 修复方案
**将 dropMaxCandles 默认值从 3 增加到 5**（与 looseForTesting 一致）。
同时在测试页面增加 dropMaxCandles Slider。

---

## 问题 5（低）：成交量共振在模拟数据中无法验证

### 位置
`test_data_generator.dart:96-98`

### 问题分析
```dart
final baseVolume = 100.0;
final volumeMultiplier = exp(_gaussianRandom() * 0.5);
final volume = (baseVolume * volumeMultiplier).roundTo2();
```
- 成交量与涨跌方向无关，使用相同的对数正态分布
- **结果**：成交量过滤器在测试中表现随机

### 修复方案
**修改模拟器**，在急跌段和回拉段注入放量：

```dart
// 急跌段：成交量放大 2-3 倍
if (phase >= 20 && phase < 23) {
  volumeMultiplier = exp(_gaussianRandom() * 0.5) * 2.5;
}
// 回拉段：成交量放大 1.5-2 倍
else if (phase >= 23 && phase < 25) {
  volumeMultiplier = exp(_gaussianRandom() * 0.5) * 1.8;
}
```

---

## 执行顺序

1. **Step 1**: 修复问题 1（移除 midpoint 条件）— 最大影响
2. **Step 2**: 修复问题 3（swingLow fallback）— 确保下跌段能被检测到
3. **Step 3**: 修复问题 2（RSI 快速周期）— 提高共振触发率
4. **Step 4**: 修复问题 4（dropMaxCandles 默认值）
5. **Step 5**: 修复问题 5（模拟器成交量）
6. **Step 6**: 运行测试验证

## 验收标准
- [ ] V 型反弹模式下，每个周期都能检出信号
- [ ] 死猫反弹模式下，信号的 deadCatRiskScore 明显高于 V 型
- [ ] RSI 拐头共振过滤器在 V 型反弹中能触发
- [ ] 成交量共振过滤器在放量模式下能触发
- [ ] 现有单元测试全部通过
