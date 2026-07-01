# 合约反弹监控页 ↔ 反弹检测测试页 业务逻辑对齐

- 日期：2026-06-29
- 范围：核心对齐（决策 1+2）
- 状态：已批准，待实现

## 背景

对比 `rebound_dashboard_screen.dart`（合约反弹监控，生产）与 `rebound_test_screen.dart`（我 → 反弹检测测试，调试）两条路径，确认：

- **检测算法一致**：两页都调用同一个纯函数 `ReboundDetector.evaluate()`，三阶段管线（下跌段 → 拉回段 → 共振过滤 → 评分 → 死猫风险）完全相同。
- **编排层存在 2 处实质分歧**（命中/收集口径不同），会导致两页对同样 K 线给出不同信号集合。

## 目标

以**生产监控页**（`ReboundMarketScanner` + `ReboundAlertService`）为单一真源，将**测试页**（`TestOrchestrator`）向其对齐。只改测试页，生产代码核心不动。

## 决策

### 决策 1：移除测试页 `score >= 60` 命中门槛

- 现状：`TestOrchestrator._tick` 仅在 `signal.score >= 60` 时收集信号（`test_orchestrator.dart:113`）；监控页 scanner `onScanComplete` 与 alertService `handleClosedKline` 均**无此门槛**（detector 非 null 即命中）。
- 改为：移除 `score >= 60` 条件，统一为「detector 非 null 即命中」。
- 理由：detector 是单一真源（per D-01），命中判定应由其三阶段门槛（跌幅 / 回补 / 共振）决定；`score` 是强度指标，用于排序 / 着色 / 通知分级，不应混入命中收集。`60` 是 ad hoc 数字，且与通知阈值体系（med=50 / high=75）脱节。
- 副作用：测试页信号列表会增多（含弱信号）——对调试页反而更好，能完整看到 detector 产出。

### 决策 2：测试页补上 `recentBars` 时间窗过滤

- 现状：监控页 scanner 只保留 `recoveryEndIndex >= window.length - recentBars`（默认 6）内结束的反弹（`rebound_market_scanner.dart:288-294`）；测试页 orchestrator **无此过滤**。
- 改为：`TestOrchestrator._tick` 增加同样的过滤，`recentBars` 提为常量 `6`（与 scanner 默认一致）。
- 理由：这是生产业务逻辑（只关心刚发生的反弹，不报窗口里的历史反弹）。测试页缺它 → 语义不一致。

## 明确不做

- **决策 3（LOOSE_PARAMS）**：`bool.fromEnvironment('LOOSE_PARAMS')` 不传 define 默认 `false` → 默认严格，与测试页参数已一致，无需改代码。仅在手动 `--dart-define=LOOSE_PARAMS=true` 时分歧（测试期临时配置）。相关 IN-01（release 守卫 + legend 误导提示）本次不处理。
- **决策 4（通知阈值）**：提醒层差异，测试页本就是手动验证通知的工具，不属检测逻辑，不改。

## 改动文件

- 必改：`lib/services/test/test_orchestrator.dart`（移除 `score >= 60` + 加 `recentBars` 过滤 + 常量）
- 配套：`test/services/test/test_orchestrator_test.dart`（更新断言）
- 不动：`rebound_detector.dart`、`rebound_params.dart`、`rebound_market_scanner.dart`、`rebound_alert_service.dart`、`rebound_dashboard_screen.dart`（生产真源保持不动）

## 验证

- 更新 orchestrator 单测：弱信号（score<60）现在入库；窗口内历史反弹（recoveryEndIndex 过早）被 recentBars 过滤。
- 跑 `flutter test test/services/test/` 与反弹相关测试，确保无回归。
