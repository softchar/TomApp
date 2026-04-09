# 后台通知修复设计文档

**日期:** 2026-04-05
**主题:** 修复小米 MIUI 设备后台通知不工作问题

## 问题背景

在小米 K70（MIUI 系统）等有严格电量管理的设备上，应用切换到后台后无法接收以下通知：
1. 每小时检查 1 小时资费合约的通知
2. 快速上涨警报通知

**根本原因：**
- MIUI 对后台应用有激进的电量管理策略
- Flutter 的 `Timer.periodic` 在后台被暂停
- WebSocket 连接在后台被系统断开

## 用户需求

1. **实时通知** - 即使在后台也要实时接收快速上涨通知
2. **简洁通知栏** - 前台服务通知显示简洁模式
3. **自动引导** - 首次启动时自动引导用户开启后台运行权限

## 设计方案

### 1. 前台服务架构

使用 Android 前台服务（Foreground Service）确保后台任务不被系统杀死。

#### 服务类型配置

```dart
AndroidForegroundType.dataSync     // 数据同步
AndroidForegroundType.remoteMessaging  // 远程消息推送
```

#### 服务生命周期

```
应用启动
    ↓
检查权限 → 需要引导？
    ↓           ↓
   否          是
    ↓           ↓
启动服务    引导页面 → 用户授权
    ↓           ↓
    └───────┬───┘
            ↓
    前台服务运行
    - WebSocket 监听快速上涨
    - 定时器检查资费 (每小时)
    - 常驻通知栏
```

### 2. 权限引导流程

#### 首次启动检测

使用 SharedPreferences 记录是否已显示过引导：
- 首次启动或版本更新后显示引导
- 检测 MIUI 设备显示专门的小米设置引导
- 提供"跳过"选项（但提示可能影响功能）

#### 引导页面内容

```
┌─────────────────────────────────────┐
│         🔔 开启后台通知              │
│                                     │
│ 为了正常接收资费和上涨提醒，         │
│ 请允许应用在后台运行。               │
│                                     │
│ [ 去设置开启 ]  [ 跳过 ]             │
│                                     │
│ 💡 小米用户：                        │
│ 设置 -> 应用设置 -> 应用管理 ->      │
│ TomApp -> 自启动管理 -> 开启         │
└─────────────────────────────────────┘
```

#### 跳转实现

使用 `flutter_local_notifications` 提供的权限引导：
```dart
// 跳转到应用设置
await platform.invokeMethod('AppSettings.openAppSettings');
```

### 3. MIUI 特殊处理

#### 设备检测

```dart
bool isMIUI() {
  try {
    return Platform.isAndroid &&
           (Process.run('getprop', ['ro.miui.ui.version.name']) ||
            Files.exists('/system/app/MiuiSystemUI'));
  } catch (e) {
    return false;
  }
}
```

#### MIUI 权限路径

MIUI (HyperOS/MIUI 14+)：
```
设置 -> 应用设置 -> 应用管理 -> TomApp
  -> 自启动: 开启
  -> 后台弹出界面: 开启
  -> 省电策略: 无限制
```

### 4. 前台服务通知设计

#### 通知样式

简洁模式，最小化干扰：

```
┌────────────────────────────┐
│ 📊 TomApp                  │
│ 正在后台监控合约...         │
│ [停止]                     │
└────────────────────────────┘
```

#### 通知配置

```dart
AndroidNotificationDetails(
  channelId: 'background_service',
  channelName: '后台服务',
  importance: Importance.low,  // 低重要性，不发出声音
  priority: Priority.low,
  ongoing: true,  // 不可滑动删除
  autoCancel: false,
)
```

### 5. 后台任务优化

#### WebSocket 保活

- 实现自动重连机制
- 检测网络状态变化
- 后台服务内维持连接

#### 定时器保活

- 在前台服务中运行
- 使用精确闹钟作为备份（需要额外权限）
- 记录上次执行时间

## 实现文件

| 文件 | 说明 |
|------|------|
| `lib/services/pump_background_service.dart` | 增强前台服务配置 |
| `lib/screens/permission_guide_screen.dart` | 新增权限引导页面 |
| `lib/utils/device_info.dart` | 新增设备检测工具 |
| `lib/main.dart` | 修改启动流程 |
| `android/app/src/main/AndroidManifest.xml` | 添加前台服务权限 |

## Android 权限配置

需要在 AndroidManifest.xml 添加：

```xml
<!-- 前台服务权限 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING" />

<!-- 通知权限 (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 精确闹钟权限 (可选，用于更可靠的定时任务) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

## 服务类型说明

| 前台服务类型 | 用途 | 必需权限 |
|-------------|------|---------|
| dataSync | 数据传输和同步 | FOREGROUND_SERVICE_DATA_SYNC |
| remoteMessaging | 远程消息处理 (WebSocket) | FOREGROUND_SERVICE_REMOTE_MESSAGING |

## 用户体验流程

### 正常流程

```
首次启动
    ↓
检测到需要引导
    ↓
显示引导页面
    ↓
用户点击"去设置"
    ↓
跳转到系统设置
    ↓
用户开启权限
    ↓
返回应用
    ↓
启动后台服务
    ↓
显示常驻通知
    ↓
应用正常工作
```

### 权限被拒绝流程

```
首次启动
    ↓
显示引导页面
    ↓
用户点击"跳过"
    ↓
显示警告提示
    ↓
仍然启动应用
    ↓
后台可能无法正常工作
    ↓
设置中可重新引导
```

## 测试要点

1. **小米 K70 (MIUI 14/15)** 验证核心问题设备
2. **其他品牌** 确保不影响正常设备体验
3. **权限授予后** 验证后台通知正常工作
4. **应用被杀死** 验证重启后仍能正常运行
5. **常驻通知** 验证可以正常停止服务

## 注意事项

1. 前台服务会显示常驻通知，这是 Android 系统要求
2. 小米设备需要用户手动在系统设置中授权
3. 不同 MIUI 版本设置路径可能有差异
4. 后台运行会增加电量消耗，需要在设置中提供关闭选项
