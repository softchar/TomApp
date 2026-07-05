---
phase: 01
slug: tradingview
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-27
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (SDK) |
| **Config file** | none — Flutter 默认配置 |
| **Quick run command** | `flutter test test/widgets/tradingview_kline_widget_test.dart` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/widgets/tradingview_kline_widget_test.dart`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | TV-01 | — | N/A | widget | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | TV-02 | — | N/A | widget | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | TV-03 | — | N/A | unit | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | DATA-01 | — | N/A | unit | `flutter test test/widgets/tradingview_kline_widget_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/widgets/tradingview_kline_widget_test.dart` — 覆盖 TV-01/TV-02/TV-03/DATA-01
- [ ] 测试框架：已内置（flutter_test），无需额外安装

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 蜡烛线粗细固定，不随缩放变化 | CHART-01 | WebView 内部 TradingView 渲染，无法通过 Flutter widget test 验证像素级效果 | 打开图表 → 缩放 → 观察蜡烛宽度是否变化 |
| 蜡烛线从左往右按时间顺序排列 | CHART-02 | 视觉验证，需确认时间轴方向 | 打开图表 → 确认左侧为旧数据，右侧为新数据 |
| 图表加载流畅，无卡顿或白屏 | CHART-03 | 性能感知，需实际设备测试 | 打开 ReboundTestScreen → 观察加载时间和流畅度 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
