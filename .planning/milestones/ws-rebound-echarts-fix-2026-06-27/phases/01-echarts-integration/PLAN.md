# Phase 01: ECharts K 线图集成

## 目标
在反弹检测测试页面用 ECharts 替换 fl_chart 的 CandlestickChart，实现专业级 K 线展示。

## 问题分析
国内网络环境下 `flutter_echarts` 等 pub 包可能无法下载。需要三级降级策略。

## 方案对比

| 方案 | 优点 | 缺点 | 可行性 |
|------|------|------|--------|
| A: flutter_echarts | 原生集成，性能好 | 依赖 pub 下载 | 需验证 |
| B: webview_flutter + CDN ECharts | 不依赖 pub 镜像 | WebView 性能开销 | 高 |
| C: CustomPainter 自绘 | 零外部依赖 | 工作量大，功能有限 | 备选 |

## 执行计划

### Step 1: 尝试 flutter_echarts
```bash
# 配置 pub 镜像
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter pub add flutter_echarts
```
- 如果成功 → 使用方案 A
- 如果失败 → 进入 Step 2

### Step 2: webview_flutter + CDN ECharts
```bash
flutter pub add webview_flutter
```
- 创建 `EchartsKlineWidget` 封装 WebView
- 使用 jsDelivr/BootCDN 加载 ECharts
- 通过 JavaScript Channel 传递数据

### Step 3: 实现 ECharts K 线配置
- 专业 K 线图（蜡烛图 + 成交量柱）
- 支持缩放、拖拽
- 标注下跌段（红色阴影）和回拉段（绿色阴影）
- MA5/MA10/MA20 均线叠加
- 实时更新（每 2 秒追加新 K 线）

## 验收标准
- [ ] K 线图正常渲染，支持缩放拖拽
- [ ] 下跌段/回拉段高亮标注
- [ ] 成交量柱状图
- [ ] 实时更新无闪烁
- [ ] 在国内网络环境下可正常工作
