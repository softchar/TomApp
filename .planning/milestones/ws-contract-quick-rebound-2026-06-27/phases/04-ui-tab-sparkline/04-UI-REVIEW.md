# Phase 4 — UI Review

**Audited:** 2026-07-02
**Baseline:** abstract 6-pillar standards（无 UI-SPEC.md）
**Screenshots:** not captured（Flutter app，无 localhost dev server，code-only audit）
**Audit target:** `lib/screens/rebound_dashboard_screen.dart`（合约反弹监控页面本体，800 行）+ `lib/screens/kline_screen.dart`（信号下钻 K 线详情页，387 行）

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 2/4 | 错误态透传原始异常字符串；日志文案含禁词「信号」（应为「候选」） |
| 2. Visuals | 2/4 | 焦点与层级尚可，但多处 icon-only 按钮无 tooltip/Semantics（删除、历史折叠） |
| 3. Color | 1/4 | 无设计系统：硬编码 `Color(0xFF2E7D32)`/`0xFFF57F17`，全页靠 8 档 Material grey 灰阶堆砌；红绿二元编码无色盲冗余 |
| 4. Typography | 2/4 | 7+ 种 fontSize（含魔数 10.5），无字号体系；3 种 fontWeight |
| 5. Spacing | 2/4 | 魔数 vertical 10/6/3 不在 4/8 grid；信号行固定宽度列 + 24% 屏宽 sparkline 在 360px 小屏必溢出 |
| 6. Experience Design | 3/4 | loading/error/empty 三态齐全（亮点）；但错误态无重试按钮，加载无预计时长 |

**Overall: 12/24**

---

## Top 3 Priority Fixes

1. **建立 Color 设计系统 + 解决红绿色盲风险（BLOCKER，Pillar 3 = 1/4）**
   - 影响用户：~8% 男性色盲用户无法区分跌幅（红 `Colors.red[300]`）与回补（绿 `Colors.green[300]`），交易类应用这是误判风险的硬伤；同时维护方需面对散落全文件的硬编码颜色。
   - 具体修复：(a) 在 `lib/theme/app_colors.dart` 抽出 `AppColors`（`surface`、`surfaceRaised`、`border`、`textPrimary`、`textMuted`、`accentBullish`、`accentBearish`、`scoreHigh`、`scoreMid`、`scoreLow`），删除 `Color(0xFF2E7D32)` / `Color(0xFFF57F17)` 硬编码（rebound_dashboard_screen.dart:682-684）；(b) 为「跌幅/回补」列加冗余编码——例如跌幅列前缀「▼」、回补列前缀「▲」，或用徽章形状（圆/方）而非纯色区分；(c) 灰阶收敛到 3 档（如 `surface`/`surfaceRaised`/`border`），消除 grey[850/900/800/700/600/500/400/300] 八档散用。

2. **错误态加可操作的「重试」按钮（BLOCKER，Pillar 1 + 6）**
   - 影响用户：`rebound_dashboard_screen.dart:155` 的 `_initError = '启动监控失败: $e'` 把原始异常透传给用户，既不安全也不可操作；用户除「离开页面再回来」外无任何恢复路径。
   - 具体修复：(a) 改文案为「市场数据连接失败，请检查网络后重试」（不暴露 `$e`）；(b) 在错误视图下方加 `TextButton(onPressed: _startAlertService, child: Text('重试'))`（第 192-205 行 Column children 内）；(c) 加错误分类（网络错误 / API 限流 / 其他），不同文案 + 不同默认重试延迟。

3. **窄屏适配：信号行固定宽度列布局在 360px 必溢出（BLOCKER，Pillar 5）**
   - 影响用户：`_SignalRow` 用 7 个固定 SizedBox（40+36+40+50+38+30+46 ≈ 280px，rebound_dashboard_screen.dart:570-623）+ sparkline `MediaQuery.width * 0.24`（360px 屏 ≈ 86px）+ 间隔 ≈ 380px，已超出 360px 屏宽，且无 LayoutBuilder / Wrap / 响应式回退，sparkline 会被压到 0。
   - 具体修复：(a) 用 `LayoutBuilder` 检测可用宽度，<600px 时折叠 sparkline 或换两行布局；(b) 把固定宽度列改成 `Expanded(flex: ...)` 弹性分配；(c) 小屏把 sparkline 移到行下方（占满宽度）而非右侧。

---

## Detailed Findings

### Pillar 1: Copywriting (2/4)

**合规情况（亮点）：** 风险提示文案 `rebound_dashboard_screen.dart:523` 完全符合 D-07；字段说明对话框（`_showLegendDialog`, 第 457-510 行）解释清晰、可操作（解释每个字段计算方式 + 测试期 LOOSE_PARAMS 警告）；图标 tooltip `「字段说明」`（第 173 行）、`「死猫反弹高风险」`/`「注意死猫风险」`（第 721/729 行）措辞具体。

**问题：**

- **WARNING — 错误态文案透传异常：** `rebound_dashboard_screen.dart:155` — `_initError = '启动监控失败: $e'`。`$e` 是原始异常字符串（可能含 socket 路径、API key 片段、堆栈），既不安全也非用户可操作。改为分类化、可重试的文案。
- **WARNING — 日志文案违反 D-07 禁词：** `rebound_dashboard_screen.dart:137` — `'第 ${result.round} 轮完成 · 命中 ${result.hitSymbols.length} · 写入 $count 信号'`。日志是面向用户的（在底部日志面板显示），「信号」一词违反 D-07「面向用户文案禁『信号』，统一『监控候选』」的硬约束。改为「写入 $count 个候选」。
- **WARNING — 空态缺操作引导：** `rebound_dashboard_screen.dart:253` `「暂无监控候选」` 与 `:327` `「暂无日志」` / `:395` `「暂无通知历史」` 仅描述状态，无「下一步」指引。空态应给出原因与预期，如「全市场扫描首轮进行中（约 40-50s），命中后将在此显示」。
- **WARNING — 加载文案无预计时长：** `rebound_dashboard_screen.dart:186` `「正在连接市场数据...」`。04-03 SUMMARY 显示首轮扫描需 40-50s，用户在 spinner 上等近 1 分钟无任何预期管理。建议改 `「正在扫描全市场（约 40-50s）...」` 或加进度百分比（scanner 已有 round/scanned/total 字段）。

### Pillar 2: Visuals (2/4)

**亮点：** `_ScoreBadge`（第 676-707 行）通过圆形徽章 + 三档颜色建立清晰视觉焦点；`_DeadCatIndicator`（第 710-742 行）通过图标 + 颜色 + Tooltip 三重编码（骷髅/警告/勾）——冗余编码对色盲也友好，是设计典范。

**问题：**

- **WARNING — icon-only 按钮无 tooltip/Semantics：**
  - 日志清空按钮 `rebound_dashboard_screen.dart:316-320` — `GestureDetector` + `Icon(Icons.delete_outline)`，无 `tooltip`、无 `Semantics`。屏幕阅读器用户无法操作。
  - 通知历史折叠按钮 `:364-387` — 同样无 `tooltip`/`Semantics`。
  - 修复：用 `IconButton(tooltip: '清空日志', ...)` 或外层包 `Tooltip(message: ...)`。
- **WARNING — `_MiniSparkline` 无 Semantics label：** `:745-800`。sparkline 是纯视觉图表，无 `Semantics(label: '最近 20 根收盘价折线，起始 X 结束 Y')`。盲人用户完全感知不到这一列存在。
- **MINOR — KlineScreen 下钻无返回提示：** `kline_screen.dart` AppBar 默认返回箭头，但无 breadcrumb 或「从反弹监控跳入」上下文提示，用户不知道高亮区域的来源语义。建议 AppBar title 加 `「X · 反弹窗口」` 副标题。

### Pillar 3: Color (1/4) — BLOCKER

**问题集中且严重：**

- **BLOCKER — 无设计系统，硬编码颜色：** `rebound_dashboard_screen.dart:682-684` 直接写 `Color(0xFF2E7D32)` / `Color(0xFFF57F17)`。颜色脱离任何 theme/Token，维护方改色需全文搜索。同问题见 `Colors.blue` 一次性使用（kline_screen.dart:172/505，dashboard 文案按钮 `:505` `TextStyle(color: Colors.blue)`）。
- **BLOCKER — 60/30/10 分布失衡：** 整页背景 `Colors.black`（第 164 行）+ 8 档 Material grey 灰阶（`Colors.grey[850/900/800/700/600/500/400/300]`，散落 20+ 处）作为 surface/border/text 的全部配色。grey 实际占了 ~85% 视觉面积（背景 + 卡片 + 边框 + 次要文字），主色（绿/红/橙）仅在 10% 的强调点上出现。没有任何「主色 + 辅色」的体系感。
- **BLOCKER — 红绿二元编码无色盲冗余：** `Colors.red[300]`（跌幅 `:602`）/ `Colors.green[300]`（回补 `:609`）/ `Colors.red`（死猫高风险 `:722`）/ `Colors.green`（死猫低风险 `:739`）/ 红绿 K 线蜡烛（kline_screen 全屏）。约 8% 男性色盲（红绿色盲最常见）无法区分跌幅与回补两列——这是交易应用的核心信息。建议加形状冗余（▼/▲）或位置冗余（跌幅固定左、回补固定右 + 不同字号）。
- **WARNING — 评分档位颜色与品牌语义未对齐：** `_ScoreBadge`（第 681-685 行）的「高分绿 / 中分橙 / 低分灰」与「回补绿 / 跌幅红」共用绿色但语义不同（一个是评分强度、一个是涨跌方向），用户可能误读「绿色徽章 = 涨」。建议评分用纯强度色（如深蓝/浅蓝/灰）避开涨跌色系。

### Pillar 4: Typography (2/4)

**统计（dashboard + kline 实际渲染 `fontSize:` 值）：**
- Sizes：9（标签 `:542`）、10（时间/止损 `:591/620`，历史 `:421/434/441`）、10.5（日志 `:339`）、11（多处小字）、12（横幅/历史标题 `:234/290/375`）、13（对话框标题 `:466`）、14（币种 `:577`，kline）、16（kline icon）、20（kline 价格 `:224`）。**共 9 档**，远超「4 档」标准。
- Weights：`FontWeight.bold`（`:431/467/576/702`）、`FontWeight.w600`（kline `:342`）、其余默认 normal。3 档 weight。

**问题：**

- **WARNING — 魔数 fontSize 10.5：** `:339` — `fontSize: 10.5`。不在任何字号体系上（既非整数也非 4 的倍数）。改成 10 或 11。
- **WARNING — 无字号 Token / TextStyle 复用：** 每处 `TextStyle(...)` 都内联写 `fontSize:`，无 `Theme.of(context).textTheme` 或自定义 `AppTextStyles`。改字号体系需全文 30+ 处手改。建议抽 `AppTextStyles.caption`（11）/`label`（10）/`body`（12）/`title`（14）等。
- **MINOR — fontFamily: 'monospace' 多处：** `:339/422/592` 等。语义合理（时间戳/日志等宽对齐），但无 fallback 指定，平台无 monospace 字体时静默退化为系统字体。

### Pillar 5: Spacing (2/4)

**spacing 类分布（dashboard 主文件）：**
- `vertical:` 10（`:565` 信号行内边距）、6（`:230` 横幅 / `:369` 历史头）、3（`:559` 卡片 margin）、8（`:285/515` warm-up/风险提示）、4（`:303` 日志面板）、2（`:413/495` 历史行）。
- `horizontal:` 12（`:369/565`）、16（`:230/285/515`）、10（`:303`）、8（`:559` 卡片 margin）。
- `SizedBox(width: ...)` 固定列宽：40（`:417/571`）、36（`:585`）、38（`:611`）、30（`:615`）、46（`:621`）、60（`:763` sparkline 占位）、50（`:605`）。
- `SizedBox(height: ...)`：140（`:301` 日志面板）、150（`:390` 历史面板 maxHeight）。

**问题：**

- **BLOCKER — 信号行窄屏溢出（见 Top 3 #3）。**
- **WARNING — 魔数 vertical 10/6/3 不在 4/8 grid：** `:230/285/303/369/515/559/565` 等。建议统一到 4/8 倍数（4/8/12/16/24/32），把 3→4、6→8、10→8 或 12。
- **WARNING — 底部固定面板栈挤压列表：** `_buildScanBanner` + `_buildHistoryPanel`（maxHeight 150）+ `_buildLogPanel`（height 140）+ `_buildRiskWarning` 四块固定高度合计 ~320px+，在 667px 小屏（iPhone SE）上列表只剩 ~250px，可显示行数极少。建议日志/历史面板默认折叠、高度用 `MediaQuery.height * 比例` 而非硬编码 px。
- **MINOR — 卡片 margin 3（`:559`）：** 既非 4 也非 8，魔数。改 4。

### Pillar 6: Experience Design (3/4)

**亮点（少见的三态齐全）：**
- `_isInitializing` 加载态（`:178`，CircularProgressIndicator + 文案）。
- `_initError` 错误态（`:192`，error icon + 文案）。
- `signals.isEmpty && warmingCount == 0` 空态（`:250`）+ warmingCount>0 时的 warm-up 横幅（`:282`）。
- 通知历史面板可折叠（`_showHistory` state `:48`）——好交互。

**问题：**

- **BLOCKER — 错误态无重试（见 Top 3 #2）：** 错误视图仅显示文案，无重试按钮，无恢复路径。
- **WARNING — 加载态无进度（见 Pillar 1）：** scanner 已有 round/scanned/total 字段（`onProgress` callback `:103`），但加载态只显示 spinner，不暴露进度。
- **WARNING — 无 ErrorBoundary：** `_MiniSparkline` 内的 `LineChart` 若抛异常（如 closes 长度异常），整个 dashboard 崩溃。建议在 `_MiniSparkline` 外包 try/catch 或 `ErrorWidget.builder` 兜底。
- **MINOR — 日志清空无确认：** `:316` `GestureDetector(onTap: provider.clearLogs)` 一键清空，误触不可恢复。低风险（仅日志），但加确认更稳。

---

## Registry Safety

无 `components.json`（非 shadcn / 非 web 项目），跳过 registry audit。

---

## Files Audited

- `C:\Users\softc\Desktop\TomApp\lib\screens\rebound_dashboard_screen.dart`（800 行，审计主目标）
- `C:\Users\softc\Desktop\TomApp\lib\screens\kline_screen.dart`（387 行，下钻体验参考）
- `C:\Users\softc\Desktop\TomApp\CLAUDE.md`（项目约束：中文响应、文案禁执行性词、4 层架构）
- `.planning/milestones/ws-contract-quick-rebound-2026-06-27/phases/04-ui-tab-sparkline/04-01-SUMMARY.md`（fl_chart 升级上下文）
- `.planning/milestones/ws-contract-quick-rebound-2026-06-27/phases/04-ui-tab-sparkline/04-02-SUMMARY.md`（看板实现上下文）
- `.planning/milestones/ws-contract-quick-rebound-2026-06-27/phases/04-ui-tab-sparkline/04-02-PLAN.md`（设计意图，D-03~D-08 决策）
- `.planning/milestones/ws-contract-quick-rebound-2026-06-27/phases/04-ui-tab-sparkline/04-03-SUMMARY.md`（范围收缩到 15m 单周期）

---

## 改进优先级总览（共 14 条，不止 Top 3）

| # | 类别 | 严重度 | 位置 |
|---|------|--------|------|
| 1 | Color 设计系统 + 色盲冗余 | BLOCKER | rebound_dashboard_screen.dart:682-684, 602, 609 |
| 2 | 错误态重试按钮 + 文案 | BLOCKER | rebound_dashboard_screen.dart:155, 192-205 |
| 3 | 窄屏信号行列布局溢出 | BLOCKER | rebound_dashboard_screen.dart:570-623, 757 |
| 4 | 日志文案「信号」→「候选」 | WARNING | rebound_dashboard_screen.dart:137 |
| 5 | icon-only 按钮加 tooltip/Semantics | WARNING | rebound_dashboard_screen.dart:316, 364 |
| 6 | 空态加操作引导 | WARNING | rebound_dashboard_screen.dart:253, 327, 395 |
| 7 | 加载态加进度/预计时长 | WARNING | rebound_dashboard_screen.dart:178-191 |
| 8 | 字号魔数 10.5 | WARNING | rebound_dashboard_screen.dart:339 |
| 9 | 字号体系 Token 化 | WARNING | 全文件 30+ 处 TextStyle |
| 10 | spacing 魔数对齐 4/8 grid | WARNING | rebound_dashboard_screen.dart:230, 285, 303, 369, 515, 559, 565 |
| 11 | 底部固定面板栈挤压列表 | WARNING | rebound_dashboard_screen.dart:208-213, 301, 390 |
| 12 | `_MiniSparkline` 加 Semantics label | WARNING | rebound_dashboard_screen.dart:745-800 |
| 13 | sparkline / LineChart 包 ErrorBoundary | WARNING | rebound_dashboard_screen.dart:776 |
| 14 | 评分色与涨跌色系解耦 | WARNING | rebound_dashboard_screen.dart:681-685 |
