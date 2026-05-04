# TomApp Design System

> 基于 UI/UX Pro Max 生成的 TomApp 设计系统

## 🎨 Color Palette

| Role | Hex | Usage |
|------|-----|-------|
| **Primary** | `#F59E0B` | Gold - 品牌色，用于涨幅、收藏 |
| **Secondary** | `#FBBF24` | Lighter Gold - 辅助品牌色 |
| **Accent/CTA** | `#8B5CF6` | Purple - 操作按钮、链接 |
| **Background** | `#0F172A` | Deep Dark - 背景色 |
| **Surface** | `#1E293B` | Surface - 卡片背景 |
| **Surface Variant** | `#272F42` | Surface Variant - 输入框等 |
| **Border** | `#334155` | Border - 边框、分割线 |

### Semantic Colors

| Role | Hex | Usage |
|------|-----|-------|
| **Gain** | `#F59E0B` | Gold - 涨幅（中国习惯红色为涨） |
| **Loss** | `#22C55E` | Green - 跌幅（中国习惯绿色为跌） |
| **Destructive** | `#EF4444` | Red - 错误、危险操作 |
| **Warning** | `#F97316` | Orange - 警告 |
| **Info** | `#3B82F6` | Blue - 信息 |

## ✏️ Typography

### Font Family
- **Inter** - Google Fonts
- 适用于：开发者工具、金融/交易应用、数据仪表盘

### Type Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Heading Large | 28 | 700 | 页面标题 |
| Heading Medium | 22 | 600 | 区块标题 |
| Heading Small | 18 | 600 | 卡片标题 |
| Body Large | 16 | 400 | 正文 |
| Body Medium | 14 | 400 | 次要文本 |
| Body Small | 12 | 400 | 辅助文本 |
| Label Large | 14 | 500 | 标签 |
| Label Medium | 12 | 500 | 小标签 |
| Label Small | 11 | 500 | 微标签 |

## 📐 Spacing

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Tight gaps |
| `sm` | 8px | Icon gaps |
| `md` | 16px | Standard padding |
| `lg` | 24px | Section padding |
| `xl` | 32px | Large gaps |
| `xxl` | 48px | Section margins |

## 🔄 Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 6px | Small elements |
| `md` | 8px | Buttons, inputs |
| `lg` | 12px | Cards |
| `xl` | 16px | Modals |
| `full` | 9999px | Pills, badges |

## 🎯 Component Styles

### Cards
- Background: `AppColors.surface`
- Border: 1px `AppColors.border`
- Radius: `AppRadius.lg` (12px)
- Margin: `4px vertical`

### Buttons
- Primary: `AppColors.accent` background
- Secondary: Transparent with `AppColors.primary` border
- Radius: `AppRadius.md` (8px)
- Padding: `12px 24px`

### Inputs
- Fill: `AppColors.surfaceVariant`
- Border: `AppColors.border`
- Focus Border: `AppColors.primary` (2px)
- Radius: `AppRadius.md` (8px)

### Navigation
- Bottom Bar: `AppColors.surface` with shadow
- Selected: `AppColors.primary`
- Unselected: `AppColors.onSurfaceVariant`

## 🚫 Anti-Patterns (避免)

- ❌ 使用 emoji 作为图标
- ❌ 可点击元素没有 cursor:pointer
- ❌ 布局偏移的 hover 效果
- ❌ 低对比度文本 (< 4.5:1)
- ❌ 瞬间状态变化（无过渡动画）
- ❌ 不可见的焦点状态

## ✅ Pre-Delivery Checklist

- [ ] 无 emoji 图标（使用 SVG: Material Icons）
- [ ] 所有图标来自一致的风格（Material Icons）
- [ ] 可点击元素有明确的按下反馈
- [ ] Hover 状态有平滑过渡（150-300ms）
- [ ] 亮色模式下文本对比度 ≥ 4.5:1
- [ ] 焦点状态可见
- [ ] 响应式支持：375px, 768px, 1024px, 1440px
- [ ] 内容不被固定导航栏遮挡
- [ ] 移动端无横向滚动

## 📝 Usage in Flutter

```dart
import 'package:tomapp/services/theme_provider.dart' show AppColors, AppTextStyles, AppSpacing, AppRadius;

// Colors
Container(color: AppColors.primary)
Text('Gain', style: TextStyle(color: AppColors.gain))

// Text Styles
Text('Title', style: AppTextStyles.headingMedium)

// Spacing
Padding(padding: EdgeInsets.all(AppSpacing.md))

// Border Radius
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  ),
)
```

## 🔗 Related Files

- `lib/services/theme_provider.dart` - Color and style definitions
- `lib/main.dart` - Theme configuration
- `design-system/tomapp/MASTER.md` - Full design system spec
