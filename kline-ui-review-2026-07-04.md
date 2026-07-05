# K线图页面 — UI Review

**Audited:** 2026-07-04
**Baseline:** 抽象 6 柱标准（无 UI-SPEC.md）
**Screenshots:** 未捕获（真机运行中，vision 模型不可用）
**模式:** 纯代码审计

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | 文案清晰、定价智能、时间轴自适应；周期标签中英混用 |
| 2. Visuals | 3/4 | 图表渲染精良、信息层级好；缺少交互反馈（十字线/触摸） |
| 3. Color | 1/4 | **全线硬编码 Colors.*，零 AppTokens 使用** — 与设计系统完全断裂 |
| 4. Typography | 2/4 | 全部内联 TextStyle，未使用 AppTextStyles；9sp 标签可读性问题 |
| 5. Spacing | 2/4 | 全 ad-hoc padding，未使用 AppSpacing 令牌 |
| 6. Experience Design | 3/4 | 状态覆盖好、手势交互完善；缺少十字线/缩放功能/指标配置 |

**Overall: 14/24**

---

## Top 3 Priority Fixes

1. **全线 Colors.* 替换为 AppColors.*（约 50+ 处）** — `kline_screen.dart`、`flchart_kline_widget.dart`、`kline_skeleton.dart`、`interval_selector.dart` 全部使用硬编码 `Colors.*`，与设计系统完全断裂。看板和测试页已完成迁移，K 线页是唯一未迁移的大页面。

2. **内联 TextStyle 全量替换为 AppTextStyles.*（约 20+ 处）** — 包括价格、涨跌幅、MA 图例、时间轴、周期选择器等全部文案。

3. **Ad-hoc padding 替换为 AppSpacing.*（约 15+ 处）** — `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` → 对应 AppSpacing 令牌。

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

**已有：**
- ✅ 价格智能格式化：≥100 → 2 位小数，≥1 → 3 位，<1 → 5 位（`_fmtPrice`）
- ✅ 时间轴自适应：1m/5m/15m → HH:MM；1h/4h → MM/DD HH:MM；1d/1w → MM/DD
- ✅ 涨跌幅格式：`+X.XX%` / `-X.XX%`
- ✅ 空状态：`暂无数据`
- ✅ 多空比标题：`5分钟多空比 - {symbol}` — 清晰
- ✅ 做多/做空百分比标签
- ✅ 涨跌颜色按中国习惯（红涨绿跌）

**问题：**
- ⚠️ AppBar 标题 `K线图` — 太通用，建议显示当前币种（如 `BTC K线图` 或直接用币种名）
- ⚠️ 周期选择器标签中英混用：`1m/5m/15m/1H/4H/日K/周K` — 建议统一为英文或中文
- ⚠️ MA 图例：`MA5/MA10/MA20` 使用英文缩写，对中国用户可加中文标注（`MA5(5日均线)` 或 tooltip）
- ⚠️ `Colors.grey` 用于辅助文本 — 本身正确但应使用 `AppColors.textSecondary`

---

### Pillar 2: Visuals (3/4)

**已有：**
- ✅ 深色背景（`Colors.black`）— 视觉一致，适合交易场景
- ✅ 红涨绿跌蜡烛图 ✅
- ✅ MA5（黄）+ MA10（橙）+ MA20（青）三条均线覆盖 ✅
- ✅ 蜡烛固定宽度 + 等距排列 ✅
- ✅ 右侧 5 档价格刻度 ✅
- ✅ 底部时间轴（4 档，带黑色半透明背景）✅
- ✅ 最新价虚线 + 带色标签 ✅
- ✅ 涨跌幅徽章（右上角，带色边框）✅
- ✅ MA 图例（左上角，色块+标签）✅
- ✅ 反弹标注（紫色下跌段 + 绿色回补段半透明背景）✅
- ✅ 底部成交量柱（涨红跌绿）✅
- ✅ Top10 币种横向滚动 ✅
- ✅ 多空比条形图（红绿对比）✅
- ✅ 周期选择器横向滚动 ✅
- ✅ 单指水平拖动查看历史 ✅

**问题：**
- ❌ **无十字线 / 触摸交互** — 手指点按蜡烛时无高亮、无价格/时间 tooltip
- ❌ 无捏合缩放（pinch-to-zoom）
- ❌ 成交量区无网格线（与蜡烛区的视觉分割不清晰）
- ⚠️ Top10 币种按钮选中用 `Colors.blue` → 应使用 `AppColors.primary`（金色）
- ⚠️ 多空比条形图用 `Colors.red` / `Colors.green` → 应用 `AppColors.destructive` / `AppColors.success`
- ⚠️ 图表仅占屏幕 25% 高度 — 在小屏手机上偏小
- ⚠️ K线图与多空比之间无视觉分隔线
- ⚠️ `_PriceInfoWidget` 使用 `Colors.black` 背景 → 与页面底色相同，无层级感

---

### Pillar 3: Color (1/4) ⚠️ 最严重问题

**文件级硬编码统计：**

| 文件 | 硬编码 Colors.* | 应替换为 |
|------|----------------|---------|
| `kline_screen.dart` | ~25 处 | AppColors.* |
| `flchart_kline_widget.dart` | ~15 处 | AppColors.* + 自定义静态常量 |
| `kline_skeleton.dart` | ~6 处 | AppColors.* |
| `interval_selector.dart` | 使用 `colorScheme` 较好 | — |

**`kline_screen.dart` 硬编码清单：**

| 位置 | 硬编码 | 应替换为 |
|------|--------|---------|
| L55 | `Colors.black` (Scaffold bg) | `AppColors.background` |
| L58 | `Colors.black` (AppBar bg) | `AppColors.background` |
| L59 | `Colors.white` (AppBar fg) | `AppColors.onBackground` |
| L104 | `Colors.black` (interval bg) | `AppColors.background` |
| L130 | `Colors.black` (top symbols bg) | `AppColors.background` |
| L171 | `Colors.blue` (选中) | `AppColors.primary` |
| L171 | `Colors.grey[850]` (未选中) | `AppColors.surface` |
| L174 | `Colors.blue` (选中边框) | `AppColors.primary` |
| L174 | `Colors.grey[700]` (未选中边框) | `AppColors.border` |
| L185 | `Colors.white` (选中文字) | `AppColors.onPrimary` |
| L185 | `Colors.grey[300]` (未选中文字) | `AppColors.textSecondary` |
| L213 | `Colors.black` (price bg) | `AppColors.background` |
| L214 | `Colors.red` (涨) | `AppColors.destructive` |
| L214 | `Colors.green` (跌) | `AppColors.success` |
| L285 | `Colors.black` (chart bg) | `AppColors.background` |
| L288 | `Colors.white` (loading spinner) | `AppColors.textPrimary` |
| L331 | `Colors.grey[900]` (ratio bg) | `AppColors.surface` |
| L338 | `Colors.grey` (icon) | `AppColors.textSecondary` |
| L345 | `Colors.white` (title) | `AppColors.textPrimary` |
| L359 | `Colors.red` (做多) | `AppColors.destructive` |
| L364 | `Colors.green` (做空) | `AppColors.success` |
| L375 | `Colors.red` (做多标签) | `AppColors.destructive` |
| L379 | `Colors.green` (做空标签) | `AppColors.success` |

**`flchart_kline_widget.dart` 硬编码：**
| L50-51 | `0xFFef5350` / `0xFF26a69a` | 与 `AppColors.destructive(0xFFEF4444)` / `AppColors.success(0xFFF59E0B)` 不同 — 建议统一或改为 `kColorUp` / `kColorDown` 语义常量 |
| L55 | `0xFFAB47BC` (紫标记) | 可保留（反弹段专用色） |
| L358-364 | `0xFFFFC107`(黄) / `0xFFFF9800`(橙) / `0xFF26C6DA`(青) | MA 均线色可保留（均线属于可视化语义色） |

---

### Pillar 4: Typography (2/4)

**当前字阶分布：**

| 字号 | 位置 | 文本样式 |
|------|------|---------|
| 9sp | MA 图例标签、时间轴标签 | `TextStyle(color: Colors.grey, fontSize: 9)` |
| 10sp | 右侧价格刻度、最新价标签 | `TextStyle(color: Colors.grey, fontSize: 10)` |
| 12sp | 周期选择器、币种按钮、多空比百分比 | `TextStyle(fontSize: 12, ...)` |
| 13sp | 涨跌幅徽章 | `TextStyle(fontSize: 13, fontWeight: bold)` |
| 14sp | 多空比标题、涨跌幅详情 | `TextStyle(fontSize: 14, ...)` |
| 20sp | 当前价格 | `TextStyle(fontSize: 20, fontWeight: bold)` |

**问题：**
- ❌ **AppTextStyles 完全未使用** — 全部内联 `TextStyle(fontSize: N, color: ...)`
- ⚠️ 字阶 7 级（9/10/12/13/14/16/20sp）— 超过设计系统的 5 级
- ⚠️ 9sp 时间轴标签在 360px 屏上几乎不可读
- ⚠️ 20sp 价格与 14sp 涨跌幅之间缺少中间字阶（建议 16sp 作为价格区域辅助文本）

**建议映射：**
| 当前 | 应替换为 |
|------|---------|
| `fontSize: 20, bold` → 价格 | `AppTextStyles.headingSmall(18sp).copyWith(fontWeight: FontWeight.bold)` |
| `fontSize: 14` → 涨跌幅/标题 | `AppTextStyles.bodyMedium` |
| `fontSize: 13, bold` → 涨跌幅徽章 | `AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold)` |
| `fontSize: 12` → 周期/按钮/百分比 | `AppTextStyles.labelMedium` |
| `fontSize: 10` → 刻度/最新价 | `AppTextStyles.labelSmall` (11sp) |
| `fontSize: 9` → MA 图例/时间轴 | 升级至 `AppTextStyles.labelSmall(11sp)` 或调整布局 |

---

### Pillar 5: Spacing (2/4)

**`kline_screen.dart` 间距值：**

| 值 | 位置 |
|----|------|
| `EdgeInsets.symmetric(h: 16, v: 8)` | 周期选择器容器、价格信息容器 |
| `EdgeInsets.all(16)` | 多空比容器 padding |
| `EdgeInsets.symmetric(h: 12, v: 8)` | 币种按钮 padding |
| `EdgeInsets.symmetric(h: 16)` | Top10 列表水平 padding |
| `SizedBox(width: 8)` | 币种按钮间隔、周期按钮间隔 |
| `SizedBox(height: 12)` | 多空比标题与条形图间距 |

**`flchart_kline_widget.dart` 间距：**
| 值 | 位置 |
|----|------|
| `_candleStep = 8` | 每根蜡烛步长 |
| `_priceAxisWidth = 46` | 右侧价格刻度区宽度 |
| `padding: EdgeInsets.symmetric(h: 3, v: 1)` | 时间轴标签 |
| `padding: EdgeInsets.symmetric(h: 5, v: 2)` | MA 图例 |
| `padding: EdgeInsets.symmetric(h: 6, v: 3)` | 涨跌幅徽章 |
| `padding: EdgeInsets.symmetric(h: 3, v: 1)` | 最新价标签 |

**问题：**
- ❌ **AppSpacing 完全未使用** — 全 ad-hoc 值
- ⚠️ padding 值无层级感：8、12、16 三个值被混用且无明显语义差异
- ⚠️ `candleStep = 8` + `bodyWidth = 6` → 蜡烛间隔仅 2px，密集时难以分辨
- ⚠️ 图表 85%/15% 的 flex 分割缺乏可配置性

---

### Pillar 6: Experience Design (3/4)

**状态覆盖：**

| 状态 | 实现 | 位置 |
|------|------|------|
| ✅ loading | `CircularProgressIndicator(color: Colors.white)` | `_KlineChartWidget` L287-289 |
| ✅ empty | `暂无数据` | `FlChartKlineWidget` L136-139 |
| ✅ skeleton | `Shimmer.fromColors` 骨架屏 | `kline_skeleton.dart` |
| ❌ error | provider 有 error 字段但 UI 未显式渲染错误态 | — |
| ✅ latest-follow | 默认跟随最新价，拖动后退出跟随模式 | `_followLatest` L69 |
| ✅ smooth drag | `ScaleUpdate` + 浮点 `_rightEdge` 实现平滑拖动 | `_onScaleUpdate` L117-132 |
| ✅ highlight | 反弹段紫色/绿色标记（半透明背景） | `FlChartKlineWidget` L420-440 |
| ✅ symbol switch | Top10 点击切换 → provider.switchSymbol | `_TopSymbolsWidget` L148 |
| ✅ interval switch | 7 档周期切换 → provider.switchInterval | `IntervalSelector` |
| ✅ long/short ratio | 多空比条形图实时刷新 | `_LongShortRatioWidget` |
| ✅ MA overlay | MA5/10/20 三条均线用不同颜色区分 | `_MaPainter` |
| ✅ price axis | 右侧 5 档刻度（自适应可见区间） | `priceTicks` |
| ✅ time axis | 底部 4 档时间戳（按周期格式化） | `timeLabels` |
| ✅ price label | 最新价虚线 + 带色标签 | `_HDashPainter` |
| ✅ change badge | 右上角涨跌幅徽章（涨跌色+边框） | `changeText` |
| ❌ crosshair | 无触摸十字线 / 价量 tooltip | — |
| ❌ pinch-zoom | 无捏合缩放图表 | — |
| ❌ indicator config | 无法选择显示/隐藏 MA 或切换指标 | — |
| ❌ candle detail | 点击无 OHLC 弹出详情 | — |
| ❌ fullscreen | 无全屏图表模式 | — |
| ❌ refresh | 无手动刷新按钮 | — |

**跨页面交互：**
- ✅ 从反弹监控跳转到 K 线图携带 highlight 参数
- ✅ Top10 快速切换币种同步更新多空比

---

## 修复优先级

### P0（Blocking — Color/Typography/Spacing 全线迁移）

1. **`kline_screen.dart` 全部 Colors.* → AppColors.*（~25 处）**
2. **`kline_screen.dart` 全部内联 TextStyle → AppTextStyles.*（~12 处）**
3. **`kline_screen.dart` 全部 padding → AppSpacing.*（~8 处）**
4. **`flchart_kline_widget.dart` 颜色常量对齐 AppColors（`_upColor`/`_downColor`）**
5. **`kline_skeleton.dart` Colors.grey[800/600/900] → AppColors.surface/surfaceVariant/background**
6. **`interval_selector.dart` 确认 colorScheme 使用正确**

### P1（Warning — 体验增强）

7. **添加十字线 touch callback** — 显示触摸点 candle 的 O/H/L/C/Volume
8. **成交量区加网格线** — 与蜡烛区视觉分割更清晰
9. **AppBar 标题显示币种** — `{symbol} K线图` 而非固定 `K线图`
10. **图表高度增至 ~35% 或根据屏幕自适应**

### P2（Info — Nice to have）

11. 捏合缩放支持
12. MA 开关/指标配置
13. 全屏模式
14. 手动刷新按钮

---

## Files Audited

| File | Lines | Key Coverage |
|------|-------|-------------|
| `lib/screens/kline_screen.dart` | 389 | K线页面主布局、子组件拆分 |
| `lib/widgets/flchart_kline_widget.dart` | 635 | fl_chart 蜡烛图、MA 均线、成交量 |
| `lib/widgets/kline_skeleton.dart` | 79 | Shimmer 骨架屏 |
| `lib/widgets/interval_selector.dart` | 75 | 周期选择器 |
| `lib/models/kline_data.dart` | 126 | K线数据模型 |
| `lib/providers/kline_provider.dart` | 406 | K线状态管理 |
| `lib/services/kline_cache_service.dart` | 198 | K线缓存 |
| `lib/services/kline_websocket_service.dart` | 157 | K线实时流 |
| `lib/services/theme_provider.dart` | 177 | 设计令牌（审计基准） |

---

_审计完成。K 线图的渲染质量高但设计系统对齐度远落后于反弹监控页面。_
