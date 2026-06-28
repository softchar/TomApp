# Roadmap: 反弹检测页面 ECharts 改造 + 检测逻辑修复

## 目标
1. 反弹检测测试页面 K 线图从 fl_chart 迁移到 ECharts（专业金融图表）
2. 深度修复反弹检测逻辑，解决明显反弹未被检出的问题

## Phase 概览

| Phase | 目标 | 依赖 | 状态 |
|-------|------|------|------|
| 01 | ECharts 集成方案（含降级策略） | 无 | ✅ 完成 |
| 02 | 反弹检测逻辑深度修复 | 无 | ✅ 完成 |
| 03 | 测试页面 UI 整合 | 01, 02 | ✅ 完成 |

## 详细分析

### 🔍 检测逻辑问题深度诊断

通过逐行审查 `rebound_detector.dart` + `test_data_generator.dart`，发现以下 **5 个核心问题**：

#### 问题 1：回拉段 midpoint 条件过于严格（致命）
```dart
// rebound_detector.dart:138,146
final midpoint = (window[startIdx].high + window[lowIdx].low) / 2;
if (recoveryRatio >= params.recoveryMinRatio &&
    window[i].close > midpoint) {  // ← 要求 close > 跌幅中点
```
- V 型反弹模拟：3 根各跌 4% → 总跌幅约 12%，midpoint 在跌幅 50% 处
- 回拉 2 根各涨 5% → recoveryRatio ≈ 83%，但 close 需要 > midpoint（≈ 需 75% 回补）
- **实际效果**：close 刚好卡在 midpoint 附近，噪声导致大量真实反弹被漏检
- **根因**：recoveryMinRatio=0.5 和 midpoint 条件是 **双重门槛**，midpoint 是隐性门槛

#### 问题 2：RSI 超卖拐头条件在急跌中难以满足
```dart
// rebound_detector.dart:178-186
final rsiResult = _ti.rsiTurningUp(
    window.sublist(0, recoveryEndIdx + 1), ...);
// 要求：前一根 RSI < 30 且当前 RSI > 前一根
```
- RSI(14) 从 50（平稳段）下降到 30 需要连续多根大阴线
- V 型反弹：3 根跌 4% 后 RSI 可能只到 35-40，不满足 < 30
- **结果**：RSI 拐头共振过滤器几乎从不触发

#### 问题 3：swingLow 在连续下跌中可能找不到
```dart
// technical_indicators.dart:314-328
// 要求 low 严格小于左右各 2 根
```
- 3 根连续急跌时，如果第 3 根 low 不严格小于第 2 根（噪声），swingLow 返回 null
- **结果**：整个下跌段检测失败

#### 问题 4：dropMaxCandles=3 对 V 型反弹过于严格
- 模拟器生成 3 根下跌，但 swingLow 可能在第 2 根或第 3 根
- 如果 swingLow 在第 2 根，backward search 只能看 1 根，可能找不到足够的 drop 起点
- **结果**：部分周期漏检

#### 问题 5：成交量共振在模拟数据中无法验证
```dart
// rebound_detector.dart:189-193
if (volumeRatio >= params.volumeMultiplier) { ... }
// volumeMultiplier 默认 1.5
```
- 模拟器使用 `exp(_gaussianRandom() * 0.5)` 生成成交量，与涨跌无关
- **结果**：成交量过滤器在测试中表现随机，无法验证逻辑正确性

### 📊 ECharts 集成方案

**问题**：国内网络环境下 `flutter_echarts` 包可能下载失败

**三级降级策略**：
1. **首选**：`flutter_echarts` + pub 镜像源
2. **备选 A**：`webview_flutter` + CDN 加载 ECharts
3. **备选 B**：自定义 `CustomPainter` 实现专业 K 线（无外部依赖）
