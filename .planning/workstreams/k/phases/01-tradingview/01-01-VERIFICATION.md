---
phase: 01-tradingview
verified: 2026-06-27T12:00:00Z
status: human_needed
score: 1/6 must-haves verified (1 fixed, 5 behavior-unverified)
behavior_unverified: 5
overrides_applied: 0
gaps:
  - truth: "ECharts 组件和依赖已完全移除"
    status: resolved
    reason: "echarts_kline_widget.dart 已在验证后删除。文件之前因未跟踪（untracked）未被 worktree 操作覆盖，现已手动移除。"
    artifacts:
      - path: "lib/widgets/echarts_kline_widget.dart"
        issue: "已修复 — 文件已删除"
    resolved_by: "orchestrator gap closure"
behavior_unverified_items:
  - truth: "用户打开 ReboundTestScreen 时能看到 TradingView K线图表正常渲染"
    test: "运行应用 → 打开 ReboundTestScreen → 点击开始按钮 → 观察图表区域"
    expected: "WebView 加载 TradingView Lightweight Charts 4.1.3 CDN，蜡烛图和成交量正常渲染，无白屏"
    why_human: "WebView 内部渲染依赖 CDN 加载和 JS 执行，grep 无法验证运行时渲染效果"
  - truth: "图表界面为中文显示（十字光标标签、时间格式、价格格式均为中文）"
    test: "触摸图表区域查看十字光标标签，观察时间轴和价格轴格式"
    expected: "十字光标显示中文标签（开/高/低/收），时间格式为 MM-dd HH:mm，价格带千位分隔符"
    why_human: "TradingView locale='zh-CN' 的实际翻译行为需运行时验证，timeFormatter/priceFormatter 的输出效果需视觉确认"
  - truth: "蜡烛线粗细在缩放时保持固定不变（barSpacing=6）"
    test: "双指缩放图表，观察蜡烛线宽度是否变化"
    expected: "缩放时蜡烛宽度不变，仅可见蜡烛数量变化"
    why_human: "barSpacing=6 已配置，但实际缩放视觉效果需运行时验证"
  - truth: "蜡烛线从左往右按时间顺序排列，最新数据在右侧"
    test: "观察图表初始视图，确认最新K线在右侧，向左滚动查看历史"
    expected: "最新50根K线显示在右侧，可向左滚动查看更早数据"
    why_human: "setVisibleLogicalRange 配置正确，但实际渲染顺序需视觉确认"
  - truth: "成交量占底部15%，涨绿跌红（国际习惯）"
    test: "观察成交量柱状图位置和颜色"
    expected: "成交量占图表底部约15%空间，上涨蜡烛成交量为绿色，下跌为红色"
    why_human: "scaleMargins 配置正确，但视觉占比和颜色效果需运行时确认"
human_verification:
  - test: "运行 flutter run → 打开 ReboundTestScreen → 点击开始 → 观察图表渲染"
    expected: "TradingView K线图表正常显示，蜡烛图+成交量+标记均可见"
    why_human: "WebView 渲染依赖 CDN 加载，无法通过静态分析验证"
  - test: "触摸图表查看十字光标标签"
    expected: "显示中文标签（开/高/低/收），时间格式 MM-dd HH:mm，价格有千位分隔符"
    why_human: "TradingView locale 行为需运行时验证"
  - test: "双指缩放图表"
    expected: "蜡烛宽度不变（barSpacing=6 固定），仅可见范围变化"
    why_human: "缩放行为是 TradingView 运行时行为"
  - test: "确认最新K线在右侧，可向左滚动"
    expected: "初始视图最新50根在右侧，左滑显示更早数据"
    why_human: "可见范围设置需视觉确认"
  - test: "观察成交量区域"
    expected: "成交量占底部约15%，涨绿跌红"
    why_human: "scaleMargins 视觉效果需运行时确认"
---

# Phase 01: TradingView 配置调整与 ECharts 清理 Verification Report

**Phase Goal:** 用户可以在 ReboundTestScreen 中看到正确渲染的 TradingView K线图表，蜡烛线显示符合预期
**Verified:** 2026-06-27T12:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | 用户打开 ReboundTestScreen 时能看到 TradingView K线图表正常渲染 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | ReboundTestScreen 第8行 import TradingViewKlineWidget，第341行实例化；tradingview_kline_widget.dart 第142行加载 CDN lightweight-charts@4.1.3；WebView 正确初始化。配置完整但运行时渲染需人工确认。 |
| 2 | 图表界面为中文显示（十字光标标签、时间格式、价格格式均为中文） | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | 第195行 `locale: 'zh-CN'`；第196-202行 timeFormatter 返回 `MM-dd HH:mm`；第204-209行 priceFormatter 使用 `toLocaleString('zh-CN')`。配置正确但 TradingView 实际翻译行为需运行时验证。 |
| 3 | 蜡烛线粗细在缩放时保持固定不变（barSpacing=6） | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | createChart 第187行 `barSpacing: 6`；updateChart 第265行 `barSpacing: 6`。配置正确但缩放视觉效果需运行时验证。 |
| 4 | 蜡烛线从左往右按时间顺序排列，最新数据在右侧 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | 第271行 `visibleCount = Math.min(candleCount, 50)`；第274行 `from: candleCount - visibleCount - 0.5`；第275行 `to: candleCount - 0.5`。配置正确但渲染顺序需视觉确认。 |
| 5 | 成交量占底部15%，涨绿跌红（国际习惯） | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | 第231行 `scaleMargins: { top: 0.85, bottom: 0 }`（15%底部）；第98-100行：close>=open → rgba(38,166,154,0.5)（绿），close<open → rgba(239,83,80,0.5)（红）。配置正确但视觉效果需运行时确认。 |
| 6 | ECharts 组件和依赖已完全移除 | ✓ FIXED | `echarts_kline_widget.dart` 已在验证后删除（文件因 untracked 未被 worktree 操作覆盖）。pubspec.yaml 不含 flutter_echarts，grep 确认无 EchartsKlineWidget 引用。 |

**Score:** 1/6 truths verified (1 fixed, 5 behavior-unverified)

### Deferred Items

None — all gaps are actionable in this phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ |------- |
| `lib/widgets/tradingview_kline_widget.dart` | 配置调整后的 TradingView 图表组件 | ✓ VERIFIED | 345行，包含所有 D-01~D-21 配置（barSpacing=6, rightOffset=5, fixLeftEdge/fixRightEdge=true, shiftVisibleRangeOnNewBar=true, scaleMargins 调整, localization zh-CN） |
| `lib/widgets/echarts_kline_widget.dart` | 已删除（exists: false） | ✗ FAILED | 文件仍然存在（236行），包含 flutter_echarts import。应已删除。 |
| `pubspec.yaml` | 清理后的依赖列表，不含 flutter_echarts | ✓ VERIFIED | flutter_echarts 不在 dependencies 中；webview_flutter: ^4.4.2 存在 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `lib/widgets/tradingview_kline_widget.dart` | TradingView Lightweight Charts 4.1.3 CDN | WebView 加载 HTML/JS，CDN 引用 | ✓ WIRED | 第142行 `https://unpkg.com/lightweight-charts@4.1.3/dist/lightweight-charts.standalone.production.js` |
| `lib/screens/rebound_test_screen.dart` | `lib/widgets/tradingview_kline_widget.dart` | import + TradingViewKlineWidget 实例化 | ✓ WIRED | 第8行 import，第341行实例化 `TradingViewKlineWidget(data: displayWindow, ...)` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| TradingViewKlineWidget | widget.data (List\<KlineData\>) | TestOrchestrator.window via ReboundTestScreen | Yes — _buildChartData() converts KlineData to TradingView JSON format | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| flutter analyze passes | N/A | SKIPPED — 需要 Flutter SDK 环境 | ? SKIP |

Step 7b: SKIPPED (no runnable entry points without Flutter SDK runtime environment)

### Probe Execution

No probes declared for this phase.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| TV-01 | 01-01-PLAN | 集成 TradingView K线图表组件到 ReboundTestScreen | ✓ SATISFIED | ReboundTestScreen 第8行 import，第341行使用 TradingViewKlineWidget |
| TV-02 | 01-01-PLAN | 配置 TradingView 组件支持中文界面 | ✓ SATISFIED | locale: 'zh-CN', timeFormatter, priceFormatter 均已配置 |
| TV-03 | 01-01-PLAN | 实现 TradingView 组件与现有数据源的对接 | ✓ SATISFIED | _buildChartData() 将 KlineData 转换为 TradingView JSON 格式 |
| CHART-01 | 01-01-PLAN | 蜡烛线粗细固定，不随缩放动态调整 | ✓ SATISFIED | barSpacing: 6 在 createChart 和 updateChart 中均设置 |
| CHART-02 | 01-01-PLAN | 从左往右显示蜡烛（符合时间顺序） | ✓ SATISFIED | setVisibleLogicalRange 设置最新数据在右侧 |
| CHART-03 | 01-01-PLAN | 优化图表加载性能，确保流畅显示 | ? NEEDS HUMAN | WebView + CDN 方案，性能需运行时验证 |
| DATA-01 | 01-01-PLAN | 将现有 Binance K线数据适配到 TradingView 格式 | ✓ SATISFIED | _buildChartData() 完整转换 time/open/high/low/close/volume |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | — | — | — | No debt markers, stubs, or empty implementations found |

### Human Verification Required

#### 1. 图表渲染验证

**Test:** 运行 flutter run → 打开 ReboundTestScreen → 点击开始 → 观察图表区域
**Expected:** TradingView K线图表正常显示，蜡烛图+成交量+下跌/回拉段标记均可见
**Why human:** WebView 内部渲染依赖 CDN 加载和 JS 执行，静态分析无法验证

#### 2. 中文本地化验证

**Test:** 触摸图表区域查看十字光标标签，观察时间轴和价格轴格式
**Expected:** 十字光标显示中文标签（开/高/低/收），时间格式为 MM-dd HH:mm，价格带千位分隔符（如 1,234.56）
**Why human:** TradingView locale='zh-CN' 的实际翻译行为需运行时验证

#### 3. 蜡烛固定粗细验证

**Test:** 双指缩放图表，观察蜡烛线宽度是否变化
**Expected:** 缩放时蜡烛宽度不变（barSpacing=6 固定），仅可见蜡烛数量变化
**Why human:** 缩放行为是 TradingView 运行时行为

#### 4. 数据方向验证

**Test:** 观察图表初始视图，确认最新K线在右侧，向左滚动查看历史
**Expected:** 最新50根K线显示在右侧，可向左滚动查看更早数据
**Why human:** 可见范围设置需视觉确认

#### 5. 成交量显示验证

**Test:** 观察成交量柱状图位置和颜色
**Expected:** 成交量占图表底部约15%空间，上涨蜡烛成交量为绿色（rgba(38,166,154)），下跌为红色（rgba(239,83,80)）
**Why human:** scaleMargins 视觉效果和颜色区分需运行时确认

### Gaps Summary

**已修复的问题：**

`echarts_kline_widget.dart` 已在验证后手动删除。文件因 untracked 未被 worktree 操作覆盖，现已移除。

**5 个行为验证项：** 所有图表渲染相关的 truth 配置正确（barSpacing=6, locale='zh-CN', scaleMargins, visibleRange 等），但 WebView 内部的 TradingView 运行时行为需要人工在设备上验证。

---

_Verified: 2026-06-27T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
