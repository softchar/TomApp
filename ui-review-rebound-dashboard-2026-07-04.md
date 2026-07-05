# Phase — UI Review: 合约反弹监控页面

**Audited:** 2026-07-04
**Baseline:** 抽象 6 柱标准（无 UI-SPEC.md）
**Screenshots:** 未捕获（Flutter 移动应用，无 Web dev server）
**模式:** 纯代码审计

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | 良好中文文案，空状态覆盖完整；测试页标签偏技术化 |
| 2. Visuals | 3/4 | 看板层级清晰，响应式布局；测试页视觉语言完全不同，页面密度偏高 |
| 3. Color | 2/4 | 看板完美使用 AppColors 设计令牌；测试页 46 处硬编码 Colors.*，完全绕过设计系统 |
| 4. Typography | 2/4 | 字阶分布过宽（9sp-16sp）；AppTextStyles 看板中几乎未使用；9sp 标签移动端可访问性差 |
| 5. Spacing | 2/4 | AppSpacing 令牌存在但看板未遵循，大量 ad-hoc 值（2/4/6/8/10/12/16 混杂） |
| 6. Experience Design | 3/4 | loading/error/empty 状态完备，响应式列裁剪优秀；缺少下拉刷新、搜索过滤、排序功能 |

**Overall: 15/24**

---

## Top 3 Priority Fixes

1. **测试页硬编码全部 Colors.*（46 处）** — 测试页与看板视觉断裂，用户从看板跳转到测试页时体验割裂。替换为 `AppColors.*` / `AppTextStyles.*`，保持视觉一致性。

2. **字体规范不统一，AppTextStyles 形同虚设** — 看板中几乎全部使用内联 `TextStyle` 硬编码 font-size，不引用 `AppTextStyles.*`。统一重构为设计令牌。

3. **间距规范未落地，AppSpacing 被架空** — `EdgeInsets.symmetric(horizontal: 12, vertical: 10)` 等 ad-hoc 值散布，既不遵循 AppSpacing 预定义的 xs/sm/md/lg/xl/xxl 体系，也无法做全局主题替换。统一为 AppSpacing 令牌。

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

**看板（rebound_dashboard_screen.dart）:**

- ✅ 空状态：`暂无监控候选`、`暂无通知历史`、`暂无日志` — 三处均清晰
- ✅ 错误态：`市场数据连接失败`、`请求过于频繁，已被限流`、`监控服务启动失败` — 分类明确
- ✅ 操作标签：`重试`、`重试中...`、`正在重新连接...`、`正在连接市场数据...`
- ✅ 扫描横幅：`全市场扫描 · 第 X 轮 · 精跟 X 个`
- ✅ 预热横幅：`监控准备中 · X 个合约数据加载中`
- ✅ 列标签：`评分`、`跌幅`、`回补`、`死猫`、`止损` — 自解释
- ✅ 图例对话框：详细的字段说明，含评分分级、死猫风险三档解释
- ✅ 风险声明：`历史回测需打 30-50% 折扣，不构成投资建议`

**测试页（rebound_test_screen.dart）:**

- ⚠️ 模式名称：`V型反弹`/`死猫反弹`/`随机游走`/`持续下跌` — 技术术语，普通用户理解门槛较高
- ⚠️ 标签：`跌幅ATR`、`回补比例`、`放量倍数` — 可读但偏技术
- ⚠️ `暂无高评分信号` — 与看板的 `暂无监控候选` 不一致（同义但不同词）

**建议：** 统一空状态文案风格（如看板已做的 `暂无X` 模式）；测试页参数标签可加 tooltip 解释每个参数含义。

---

### Pillar 2: Visuals (3/4)

**看板（rebound_dashboard_screen.dart）:**

- ✅ 清晰的主体焦点：评分圆形徽章（金/橙/灰三档）作为视觉锚点
- ✅ 形状冗余：`▼`标记跌幅（红色）、`▲`标记回补（金色 但颜色名称为 success 实际为金色）— 色盲友好
- ✅ 死猫风险三档图标：`dangerous`(红骷髅)、`warning_amber`(橙三角)、`check_circle_outline`(金勾)— 形状冗余
- ✅ 响应式布局：`ReboundSignalLayout.resolve()` 按屏宽裁剪止损列和 sparkline，覆盖 336-434+px 范围
- ✅ sparkline 涨金跌红（`isUp ? AppColors.success : AppColors.destructive`）
- ✅ 字段说明 tooltip 图标
- ✅ 通知历史可折叠

**测试页（rebound_test_screen.dart）:**

- ❌ 完全不同的视觉语言：`Colors.black` 背景 vs 看板的 `AppColors.background(0xFF0F172A)`
- ❌ 控制栏用 `Colors.grey[900]` 面板 vs 看板的 `AppColors.surface(0xFF1E293B)`
- ❌ 滑块 `activeColor: Colors.blue` / `Colors.orange` — 看板无蓝色元素，紫色 accent 被忽略
- ❌ 信号卡 `Colors.blueGrey[800]` — 看板信号卡统一 `AppColors.surface`
- ❌ 信号行选中 `Colors.cyan` 描边 — 看板无青色系

**看板问题：**

- ⚠️ 无信号行分隔线（所有卡片紧挨，扫描时易迷失行）
- ⚠️ sparkline 仅 40px 高度，细节辨识度低
- ⚠️ 页面整体密度高：扫描横幅 + 预热横幅 + 信号列表 + 通知历史 + 日志面板 + 风险声明 — 6 个区域垂直堆叠

---

### Pillar 3: Color (2/4)

**看板 — 令牌使用（优秀）：**

- ✅ 100% 使用 `AppColors.*` 令牌，零硬编码颜色
- ✅ `AppColors.success` (金 #F59E0B) = 涨/高分徽章 — 与 `gain` 语义一致
- ✅ `AppColors.destructive` (红 #EF4444) = 跌/死猫高风险
- ✅ `AppColors.warning` (橙 #F97316) = 中分/中风险
- ✅ `AppColors.textTertiary` (#64748B) = 列标签/辅助文本
- ✅ `AppColors.surface` (#1E293B) = 卡片容器
- ✅ `AppColors.surfaceVariant` (#272F42) = 横幅背景

**测试页 — 令牌完全未使用（严重）：**

- ❌ 46 处硬编码 `Colors.*` — 完整清单：

| 硬编码 | 出现次数 | 应替换为 |
|--------|---------|---------|
| `Colors.black` | 3 | `AppColors.background` |
| `Colors.white` | 6 | `AppColors.onBackground` 或 `AppColors.textPrimary` |
| `Colors.grey` | 8 | `AppColors.textSecondary` 或 `AppColors.textTertiary` |
| `Colors.grey[700]` | 1 | `AppColors.textDisabled` |
| `Colors.grey[800]` | 3 | `AppColors.surface` 或 `AppColors.surfaceVariant` |
| `Colors.grey[850]` | 1 | `AppColors.surfaceVariant` |
| `Colors.grey[900]` | 2 | `AppColors.surface` |
| `Colors.blue` | 2 | `AppColors.info` (#3B82F6) |
| `Colors.blue.withAlpha(70)` | 1 | 无对应令牌 |
| `Colors.blueGrey[800]` | 2 | `AppColors.surface` |
| `Colors.cyan` / `.withAlpha(90)` | 3 | 无对应令牌 |
| `Colors.red` | 1 | `AppColors.destructive` |
| `Colors.red[300]` | 1 | `AppColors.destructive` |
| `Colors.orange` | 2 | `AppColors.warning` |
| `Colors.green` | 1 | `AppColors.success` |
| `Colors.green[300]` | 1 | `AppColors.success` |
| `Colors.green[700]` | 1 | `AppColors.success` |
| `Colors.yellow` | 3 | 无直接对应（可考虑 `AppColors.primary` #F59E0B） |
| `Colors.black54` | 1 | 无对应令牌 |
| `Colors.blue` (Icon.check_circle) | 1 | `AppColors.success` |

---

### Pillar 4: Typography (2/4)

**看板使用分布（font-size，从 `rebound_dashboard_screen.dart` 统计）：**

| 字号 | 使用位置 | 频次 |
|------|---------|------|
| 9sp | 列标签（评分/跌幅/回补/死猫/止损） | ~7 处 |
| 10sp | 时间（monospace）、死猫风险详情 | ~4 处 |
| 10.5sp | 日志行（monospace） | 1 处 |
| 11sp | 通知历史 symbol/score、空状态提示 | ~6 处 |
| 12sp | 跌幅值、回补值、扫描横幅、预热横幅、风险声明、评分徽章 | ~12 处 |
| 13sp | 图例对话框标题 | ~2 处 |
| 14sp | 币种 symbol（bold）、空状态文案 | ~3 处 |

**问题：**

- ❌ **AppTextStyles 看板中几乎未使用** — 仅 2 处使用 `AppTextStyles.bodyMedium`：
  - `rebound_dashboard_screen.dart` line 331 (错误态文案)
- ⚠️ **字阶过多**：7 个非标准字号（9/10/10.5/11/12/13/14sp），超过设计系统应有的 4-5 级
- ⚠️ **9sp 可访问性问题**：Flutter Material 最小推荐字号 12sp，9sp 在小屏手机上几乎不可读
- ⚠️ **`AppTextStyles` 定义的字阶与使用脱节**：设计系统定义了 headingLarge(28sp)/headingMedium(22sp)/headingSmall(18sp)/bodyLarge(16sp)/bodyMedium(14sp)/bodySmall(12sp)/labelLarge(14sp)/labelMedium(12sp)/labelSmall(11sp)，但看板实际使用的 9/10/10.5sp 不在其中

**建议：** 
- 设计系统 `AppTextStyles` 补充 `labelXSmall(10sp)` 或 `caption(10sp)`；或调整列标签为 `labelSmall(11sp)` + 更紧凑布局
- 看板全面切换为 `AppTextStyles.*`，消除内联 `TextStyle`
- 测试页同理：全面切换为 `AppTextStyles.*` + `AppColors.*`

---

### Pillar 5: Spacing (2/4)

**看板间距值分布（从 `rebound_dashboard_screen.dart` 统计）：**

| 间距值 | 使用位置 |
|--------|---------|
| 2px | 止损列前导、图例 item 内 |
| 4px | 信号行内部列间距 `SizedBox(width: 4)`、日志面板上下 padding |
| 6px | 扫描横幅 vertical 6、历史面板 vertical 6 |
| 8px | 预热横幅 vertical 8、信号行 card margin 水平 8/垂直 3 |
| 10px | 信号行 padding vertical 10、日志面板 horizontal 10 |
| 12px | 信号行 padding horizontal 12、历史面板 horizontal 12 |
| 16px | 扫描横幅 horizontal 16、错误态卡片 padding 16 |

**AppSpacing 预定义体系（未遵循）：**
| 令牌 | 值 | 看板使用 |
|------|----|---------|
| `AppSpacing.xs` | 4 | 日志面板正确使用了 4，但信号行也用 4（应一致） |
| `AppSpacing.sm` | 8 | 未使用（预热横幅用的 8 但没用令牌） |
| `AppSpacing.md` | 16 | 仅错误态正确使用了 `AppSpacing.md` |
| `AppSpacing.lg` | 24 | 未使用 |
| `AppSpacing.xl` | 32 | 未使用 |
| `AppSpacing.xxl` | 48 | 未使用 |

**问题：**
- ❌ 7 个不同间距值被使用，但仅 2 处引用了 AppSpacing 令牌
- ❌ 信号行内部 `SizedBox(width: 4)` 与 `const SizedBox(width: 2)` 混用 — 增删止损列时布局微偏
- ⚠️ 4/6/8/10/12/16 无层级关系：哪个是"相邻元素间距"、哪个是"内边距"、哪个是"外边距"未约定

**建议：**
- 信号行内部列间距统一为 `AppSpacing.xs`(4) 或 `AppSpacing.sm`(8)
- 卡片 padding 统一为 `EdgeInsets.all(AppSpacing.sm)` 或 `EdgeInsets.symmetric(h: AppSpacing.md, v: AppSpacing.sm)`
- 横幅横向 padding 统一为 `AppSpacing.md`(16)
- 测试页同理

---

### Pillar 6: Experience Design (3/4)

**看板状态覆盖：**

| 状态 | 实现 | 位置 |
|------|------|------|
| ✅ loading | `CircularProgressIndicator` + 文案 `正在连接市场数据...` | L278-293 |
| ✅ retrying | `CircularProgressIndicator` + 文案 `正在重新连接...` | L278-293 |
| ✅ error | 卡片式错误态：icon + 可读消息 + 重试按钮 + 重试中禁用状态 | L310-359 |
| ✅ error 分类 | SocketEx/HandshakeEx → 连接失败; 429 → 限流; 其它 → 通用 | L219-232 |
| ✅ empty(signals) | `暂无监控候选` | L397-402 |
| ✅ empty(history) | `暂无通知历史` | L548-551 |
| ✅ empty(log) | `暂无日志` | L475-480 |
| ✅ warming | 横幅：`监控准备中 · X 个合约数据加载中` | L429-441 |
| ✅ resizing | `ReboundSignalLayout.resolve()` 5 档断点（含 sparkline 极窄模式） | L36-78 |
| ✅ navigation | → KlineScreen 携带 highlight 时间戳和下跌/回补段分界 | L817-837 |
| ✅ retry safe | 旧实例 await stop → 置空 → 新实例（R1 防重复订阅 429） | L238-259 |
| ✅ legend | `?` 图标 → AlertDialog 字段说明 | L610-666 |
| ✅ risk warning | 底部风险声明 | L668-684 |
| ❌ pull-to-refresh | 无下拉刷新 | — |
| ❌ search/filter | 无币种搜索/过滤 | — |
| ❌ sorting | 按评分降序固定，无排序控制 | — |
| ⚠️ history 折叠 | 被点击展开/折叠，但无手势指示（非明显可点击） | L515-518 |

**测试页：**

| 功能 | 实现 |
|------|------|
| ✅ play/pause | 一键启停模拟 |
| ✅ mode switching | 4 种模拟模式 |
| ✅ parameter tuning | 6 个 Slider（跌幅/回补/放量/下跌K线/回补K线/RSI周期） |
| ✅ signal selection | 点击信号行高亮，K 线图表叠加标记 |
| ✅ debug panel | 折叠式调试面板 |
| ✅ test notification | 一键触发测试通知 |
| ❌ param save/load | 无参数持久化 |
| ❌ keyboard | 无键盘输入，全部 Slider（精度受限） |

**建议：**
- 信号列表加 `RefreshIndicator` 实现下拉主动扫描
- 加 `TextField` 过滤币种（或通讯录式字母索引跳转）
- 排序支持切换：按评分/跌幅/死猫风险/时间排序
- 历史面板标题改成明显可点击样式（加箭头/背景色变化）
- 测试页添加参数预设保存/加载

---

## Registry Safety

Flutter 项目，无 shadcn/第三方 registry，跳过。

---

## Files Audited

| File | Lines | Key Coverage |
|------|-------|-------------|
| `lib/screens/rebound_dashboard_screen.dart` | 987 | 主看板：信号列表/响应式/状态管理 |
| `lib/screens/rebound_test_screen.dart` | 777 | 测试调试页：模拟器/参数调整 |
| `lib/services/theme_provider.dart` | 177 | AppColors/AppTextStyles/AppSpacing/AppRadius 设计令牌 |
| `lib/providers/rebound_score_provider.dart` | — | Provider 状态层 |
| `lib/services/rebound/rebound_timeframes.dart` | 13 | 周期配置 |

---

## 优化建议汇总

### 高优先级（Blocking — 影响体验完整性）

1. **`rebound_test_screen.dart` 全线替换为 AppTokens（约 46 处）** — 文件内所有 `Colors.*` 改为对应的 `AppColors.*`，所有内联 `TextStyle` 改为 `AppTextStyles.*`，所有 ad-hoc padding 改为 `AppSpacing.*`

2. **`rebound_dashboard_screen.dart` 全线替换为 AppTokens** — 消除全部内联 `TextStyle(fontSize: N, color: AppColors.X)` 模式，用 `AppTextStyles.bodyMedium.copyWith(color: AppColors.X)` 
   - 列标签：`Text('评分', style: TextStyle(color: AppColors.textTertiary, fontSize: 9))` → `Text('评分', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary))`

3. **间距统一** — 信号行内部间距 `SizedBox(width: 4)` → `SizedBox(width: AppSpacing.xs)`；卡片 padding 全部按 AppSpacing 体系归一化

### 中优先级（Warning — 提升品质）

4. **9sp 列标签字号** — 建议升到 10-10.5sp 并补充 `AppTextStyles` 新 token（`caption` 或 `labelXSmall`），当前 9sp 在 360px 屏上可读性差
5. **页面密度** — 考虑将日志面板折叠/可开关（目前 140px 固定高度）；风险声明可缩至一行
6. **信号行分隔线** — 加 `Divider` 或 card margin 增加视觉间隔，避免行间粘连

### 低优先级（Nice to have）

7. **Pull-to-refresh** — `RefreshIndicator` + `_scanner.scanOnce()`
8. **币种搜索过滤** — `TextField` + provider 过滤
9. **排序控制** — 评分/跌幅/死猫风险多维度排序
10. **测试页参数持久化** — SharedPreferences 保存/加载

---

*审计完成。代码经手后覆盖率与逻辑已确认，主要问题是测试页与看板的视觉断裂及设计令牌使用不一致。*
