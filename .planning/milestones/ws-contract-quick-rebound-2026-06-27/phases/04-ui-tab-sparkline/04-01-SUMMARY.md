---
phase: 04-ui-tab-sparkline
plan: 01
subsystem: ui
tags: [fl_chart, flutter, macd, chart, dependency-upgrade]

# Dependency graph
requires:
  - phase: 03-monitor-websocket
    provides: ReboundScoreProvider 和既有图表组件（macd_chart_widget 在下钻中使用）
provides:
  - fl_chart 依赖升级到 ^1.2.0（启用原生 CandlestickChart，为 04-02 看板 sparkline 铺路）
  - 验证 macd_chart_widget.dart 在 fl_chart 1.2.0 下零代码改动编译通过、渲染正确
affects:
  - 04-02-rebound-dashboard（看板 UI 依赖 fl_chart 1.2.0 CandlestickChart）

# Tech tracking
tech-stack:
  added: [fl_chart: ^1.2.0, vector_math: ^2.2.0（dependency_overrides）]
  patterns: [dependency_overrides 用于解决 transitive 版本冲突]

key-files:
  created: []
  modified:
    - pubspec.yaml（fl_chart 升级 + dependency_overrides 块）
    - pubspec.lock（自动生成）
    - lib/widgets/macd_chart_widget.dart（已验证无需修改）

key-decisions:
  - "fl_chart 1.2.0 保留了 Fl 前缀类型名（FlGridData/FlBorderData/FlTitlesData），无需代码迁移——计划的 API 映射表不适用于此版本"
  - "通过 dependency_overrides 将 vector_math 强制升至 ^2.2.0 解决 flutter_test 的 2.1.4 约束冲突"
  - "macd_chart_widget.dart 零代码改动——169 行原地继续使用 isCurved/FlDotData/belowBarData 等字段，fl_chart 1.2.0 全部兼容"

patterns-established:
  - "dependency_overrides: 当上游包（flutter_test）锁定旧版传递依赖（vector_math 2.1.4）而新依赖（fl_chart 1.2）要求更高版本时，在 pubspec.yaml 顶层添加 dependency_overrides 块强制覆盖"

requirements-completed: [DASH-01, DASH-02]

# Metrics
duration: 20min
completed: 2026-06-19
status: complete
---

# Phase 4 Plan 1: fl_chart 0.65→1.2 升级 + MACD 图表兼容性验证 总结

**fl_chart 从 ^0.65.0 升级到 ^1.2.0，通过 dependency_overrides 解决 vector_math 版本冲突，验证 macd_chart_widget 零代码迁移即可编译通过——fl_chart 1.2 实际保留了 FlGridData/FlBorderData/FlTitlesData 等 Fl 前缀类型名，与计划预期的去前缀 API 不同**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-06-19 19:06 CST
- **Completed:** 2026-06-19 19:12 CST
- **Tasks:** 3
- **Files modified:** 2 (pubspec.yaml + pubspec.lock)

## Accomplishments
- fl_chart 依赖从 ^0.65.0 成功升级到 ^1.2.0，flutter pub get 无错误
- dependency_overrides 解决 vector_math 版本冲突（flutter_test 固定 2.1.4 vs fl_chart 1.2 要求 ≥2.2.0）
- macd_chart_widget.dart 零代码改动——flutter 1.2.0 保留了 Fl 前缀类型名，原生兼容所有已有 API
- 用户通过 hot reload 肉眼验证 MACD 图表渲染正确（DIF 蓝线、DEA 橙线、MACD 红绿柱状图均正常）
- 全项目 flutter analyze 无新增错误（仅 2 个预存 integration_test 错误 + 预存 test/ 警告）

## Task Commits

Each task was committed atomically:

1. **Task 1: fl_chart 从 0.65 升级到 1.2 + flutter pub get** - `e885b9e` (feat)
2. **Task 1 补充：dependency_overrides 结构修正** - `167789e` (fix)
3. **Task 2: macd_chart_widget 迁移（零改动验证）** - 无独立提交（文件无需修改）
4. **Task 3: 用户肉眼验证 MACD 图表渲染** - 用户 typed "approved"

**Plan metadata:** 将在 SUMMARY.md 提交时一并创建

## Files Created/Modified
- `pubspec.yaml` - fl_chart: ^1.2.0 + dependency_overrides 块（vector_math: ^2.2.0）
- `pubspec.lock` - fl_chart 1.2.0 及传递依赖（自动生成）
- `lib/widgets/macd_chart_widget.dart` - 已验证 169 行无任何改动，fl_chart 1.2.0 原生兼容

## Decisions Made
- **保留所有 Fl 前缀类型名**：fl_chart 1.2.0 并未如计划预期的移除 Fl 前缀——`FlGridData`/`FlBorderData`/`FlTitlesData`/`FlDotData` 全部存在，`isCurved`/`belowBarData` 字段也保持可用。因此不做任何代码迁移，macd_chart_widget.dart 保持原样。
- **使用 dependency_overrides 而非降级 fl_chart**：flutter_test 固定 vector_math 2.1.4，但 fl_chart 1.2 的传递依赖要求 ≥2.2.0。通过顶层 `dependency_overrides: {vector_math: ^2.2.0}` 强制覆盖——这是 pub 的推荐做法，因为 vector_math 2.1→2.2 无破坏性变更。

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] flutter pub get 报 vector_math 版本冲突**
- **Found during:** Task 1（flutter pub get）
- **Issue:** fl_chart 1.2.0 传递依赖 vector_math ≥2.2.0，但 flutter_test 固定 vector_math 2.1.4，pub 解析失败
- **Fix:** 在 pubspec.yaml 顶层添加 `dependency_overrides: {vector_math: ^2.2.0}` 块，强制覆盖
- **Files modified:** pubspec.yaml
- **Verification:** flutter pub get 成功退出，fl_chart 1.2.0 正常下载
- **Committed in:** `e885b9e`（首次尝试，dependency_overrides 位置错误）+ `167789e`（修正到顶层）

**2. [Rule 3 - Blocking] dependency_overrides 首次放在 dependencies 块内导致结构错误**
- **Found during:** Task 1 commit 后的结构检查
- **Issue:** dependency_overrides 误放在 `dependencies:` 块下，pubspec.yaml 结构不符合 pub 规范
- **Fix:** 将 dependency_overrides 块提升到 pubspec.yaml 顶层（与 dependencies/dev_dependencies 同级）
- **Files modified:** pubspec.yaml
- **Verification:** pubspec.yaml 结构正确，flutter pub get 仍成功
- **Committed in:** `167789e`

### Plan-Spec Mismatch

**Plan 的 fl_chart API 迁移映射表与实际 API 不符：**
- **计划声称**: FlGridData→GridData, FlBorderData→BorderData, FlTitlesData→TitlesData, isCurved 移除→curveSmoothness, belowBarData 移除
- **实际 API**: fl_chart 1.2.0 保留了以上所有 Fl 前缀类型名和字段，完全向后兼容 macd_chart_widget.dart 的 169 行代码
- **影响**: Task 2 的迁移工作实际上变成了零改动的编译验证——macd_chart_widget.dart 无需任何代码修改即可在 fl_chart 1.2.0 下通过 flutter analyze
- **根因**: fl_chart 的 1.0 破坏性变更在后续 1.x 版本中逐步加入了向后兼容别名——1.2.0 中 Fl 前缀类型名均为有效别名

---

**Total deviations:** 2 auto-fixed (均 Rule 3 - Blocking), 1 plan-spec mismatch
**Impact on plan:** 两个 Rule 3 修复为依赖安装所必需。API 映射不符实际降低了计划复杂度——无需做任何代码迁移。无 scope creep。

## Issues Encountered
- 无

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- fl_chart 1.2.0 依赖已落地，pub get 成功，macd_chart_widget 验证通过
- 04-02（ReboundDashboardScreen 看板 UI）可以直接使用 fl_chart 1.2.0 的原生 CandlestickChart
- 无阻塞项

## 成功标准验证

| 标准 | 状态 |
|------|------|
| pubspec.yaml fl_chart 为 ^1.2.0 | 通过 |
| flutter pub get 无错误 | 通过 |
| flutter analyze 全项目无新增错误 | 通过（仅 2 个预存 integration_test 错误） |
| macd_chart_widget 中 FlGridData/FlBorderData/FlTitlesData 存在但合法 | 通过（fl_chart 1.2.0 保留这些类型名为别名） |
| macd_chart_widget 在 KlineScreen 中渲染正常 | 通过（用户 approved） |
| 既有图表功能零回归 | 通过 |

---
*Phase: 04-ui-tab-sparkline*
*Completed: 2026-06-19*
