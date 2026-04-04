# K线图功能

## 概述
应用新增K线图功能，支持多时间周期查看交易对价格走势。

## 功能特性
- 支持7种时间周期：分时、1m、15m、1H、4H、日K、周K
- 技术指标：MA(5,10,20)、BOLL布林带、MACD
- 实时价格更新（WebSocket）
- 数据持久化缓存（SQLite）
- 从资费页面和多空页面便捷跳转

## 使用方法
1. 在资费页面或多空页面点击交易对名称
2. 进入K线图页面查看走势
3. 使用顶部周期选择器切换不同时间周期
4. 使用下拉菜单切换不同交易对
5. 点击右上角图表图标或底部按钮查看MACD指标
6. 在个人中心可以管理K线缓存

## 技术实现
- **UI库**: flutter_chen_kchart (K线图), fl_chart (MACD指标)
- **状态管理**: Provider
- **数据缓存**: sqflite
- **实时更新**: web_socket_channel (币安WebSocket API)
- **骨架屏**: shimmer

## 新增文件
- `lib/models/kline_data.dart` - K线数据模型
- `lib/models/macd_data.dart` - MACD指标数据模型
- `lib/services/technical_indicators.dart` - 技术指标计算工具
- `lib/services/kline_cache_service.dart` - K线缓存服务
- `lib/services/kline_websocket_service.dart` - K线WebSocket服务
- `lib/providers/kline_provider.dart` - K线状态管理
- `lib/screens/kline_screen.dart` - K线图页面
- `lib/widgets/interval_selector.dart` - 周期选择器组件
- `lib/widgets/kline_chart_widget.dart` - K线图组件
- `lib/widgets/kline_skeleton.dart` - 骨架屏加载组件
- `lib/widgets/macd_chart_widget.dart` - MACD图表组件

## 修改文件
- `pubspec.yaml` - 添加flutter_chen_kchart、shimmer依赖
- `lib/services/binance_api_service.dart` - 添加KlineApi扩展
- `lib/services/database_helper.dart` - 添加kline_cache表(version 2)
- `lib/screens/funding_screen.dart` - 添加导航到KlineScreen
- `lib/screens/long_short_screen.dart` - 添加导航到KlineScreen
- `lib/screens/profile_screen.dart` - 添加K线缓存管理选项
- `lib/main.dart` - 注册KlineProvider
