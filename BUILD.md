# TomApp APK 构建指南

## 代码修复已完成

以下文件已修改（ANR修复 + 反弹监控修复）：

- `lib/main.dart` — runApp() 前移，后台服务延迟启动
- `lib/screens/main_navigation.dart` — IndexedStack 改懒加载
- `lib/screens/rebound_dashboard_screen.dart` — 等待合约列表加载
- `lib/providers/market_overview_provider.dart` — 加超时
- `lib/services/binance_api_service.dart` — 超时缩短为 10s
- `lib/services/exchange_info_service.dart` — 超时缩短为 10s
- `lib/services/rebound/data_import_service.dart` — 加超时

## 方式一：GitHub Actions 自动编译（推荐）

1. Fork 或创建仓库：
   ```bash
   gh repo create TomApp-fixed --public --source=. --push
   ```

2. 去 GitHub 仓库页面 → Actions 标签
3. 等待 Build APK workflow 完成（约5分钟）
4. 点击完成的 workflow → Artifacts → 下载 app-release

## 方式二：电脑本地编译

```bash
# 前提：已安装 Flutter SDK + Android SDK
cd TomApp
flutter pub get
flutter build apk --release

# APK 路径：
# build/app/outputs/flutter-apk/app-release.apk
```

## 方式三：Android Studio

1. 用 Android Studio 打开 TomApp/android 目录
2. 等待 Gradle 同步完成
3. Build → Build Bundle(s) / APK(s) → Build APK(s)

## 注意

如果在中国大陆使用，需要在 `lib/main.dart` 的 `configureApi()` 中
配置代理地址，否则币安 API 会被墙：

```dart
void configureApi() {
  BinanceApiService.setCustomBaseUrl('https://你的代理地址/api');
}
```
