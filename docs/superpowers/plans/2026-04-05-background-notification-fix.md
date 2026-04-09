# 后台通知修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标:** 修复小米 MIUI 设备上应用后台无法接收通知的问题，使用前台服务确保后台任务正常运行。

**架构:**
- 使用 Android 前台服务（Foreground Service）防止应用被系统杀死
- 首次启动时引导用户授予后台运行权限
- 针对小米 MIUI 设备提供专门的权限设置说明

**技术栈:**
- flutter_background_service - 前台服务
- flutter_local_notifications - 通知管理
- shared_preferences - 存储引导状态
- platform_channel - 跳转系统设置

---

## 文件结构

### 新增文件
| 文件 | 职责 |
|------|------|
| `lib/utils/device_info.dart` | 设备检测工具（检测 MIUI） |
| `lib/screens/permission_guide_screen.dart` | 权限引导页面 |
| `lib/services/background_task_service.dart` | 统一的后台任务服务（替代现有服务） |

### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `lib/main.dart` | 添加启动流程，检查并显示引导 |
| `android/app/src/main/AndroidManifest.xml` | 添加前台服务权限 |
| `lib/services/pump_background_service.dart` | 增强前台服务配置 |
| `lib/screens/profile_screen.dart` | 添加重新引导按钮 |

---

## Task 1: 添加 Android 前台服务权限

**文件:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加前台服务权限到 AndroidManifest.xml**

在 `<manifest>` 标签内，`<application>` 标签前添加：

```xml
<!-- 前台服务权限 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_REMOTE_MESSAGING" />

<!-- 通知权限 (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- 精确闹钟权限 (可选) -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<!-- 跳转应用设置权限 -->
<uses-permission android:name="android.permission.WRITE_SETTINGS" tools:ignore="ProtectedPermissions"/>
```

同时在 `<application>` 标签内添加 `<service>` 声明（如果尚未存在）：

```xml
<service
    android:name="id.flutter.flutter_background_service.BackgroundService"
    android:exported="false"
    android:foregroundServiceType="dataSync|remoteMessaging">
    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
    </intent-filter>
</service>
```

- [ ] **Step 2: 验证修改**

确认文件语法正确，标签闭合正确。

- [ ] **Step 3: 提交**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat: add foreground service permissions to AndroidManifest"
```

---

## Task 2: 创建设备检测工具

**文件:**
- Create: `lib/utils/device_info.dart`

- [ ] **Step 1: 创建设备检测工具文件**

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 设备信息检测工具
class DeviceInfo {
  static const String _permissionGuideShownKey = 'permission_guide_shown';
  static const String _permissionGuideVersionKey = 'permission_guide_version';
  static const int _currentGuideVersion = 1;

  /// 检测是否为 MIUI 系统
  static Future<bool> isMIUI() async {
    if (!Platform.isAndroid) return false;

    try {
      // 方法1: 尝试读取 MIUI 系统属性
      final result = await Process.run('getprop', ['ro.miui.ui.version.name']);
      if (result.stdout.toString().trim().isNotEmpty) {
        debugPrint('[DeviceInfo] 检测到 MIUI: ${result.stdout}');
        return true;
      }
    } catch (e) {
      debugPrint('[DeviceInfo] getprop 检测失败: $e');
    }

    try {
      // 方法2: 检查 MIUI 特有的文件路径
      final miuiFiles = [
        '/system/app/MiuiSystemUI',
        '/system/priv-app/MiuiSystemUI',
        '/system/app/miui',
      ];
      for (final path in miuiFiles) {
        final file = File(path);
        if (await file.exists()) {
          debugPrint('[DeviceInfo] 通过文件检测到 MIUI: $path');
          return true;
        }
      }
    } catch (e) {
      debugPrint('[DeviceInfo] 文件检测失败: $e');
    }

    return false;
  }

  /// 获取 MIUI 版本信息
  static Future<String?> getMIUIVersion() async {
    try {
      final result = await Process.run('getprop', ['ro.miui.ui.version.name']);
      final version = result.stdout.toString().trim();
      if (version.isNotEmpty) return version;
    } catch (e) {
      debugPrint('[DeviceInfo] 获取 MIUI 版本失败: $e');
    }

    try {
      final result = await Process.run('getprop', ['ro.build.version.incremental']);
      final version = result.stdout.toString().trim();
      if (version.isNotEmpty) return version;
    } catch (e) {
      debugPrint('[DeviceInfo] 获取版本号失败: $e');
    }

    return null;
  }

  /// 检测是否为小米设备
  static Future<bool> isXiaomi() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await Process.run('getprop', ['ro.product.manufacturer']);
      final manufacturer = result.stdout.toString().trim().toLowerCase();
      return manufacturer.contains('xiaomi') || manufacturer.contains('redmi');
    } catch (e) {
      debugPrint('[DeviceInfo] 检测小米设备失败: $e');
    }

    return false;
  }

  /// 检查是否需要显示权限引导
  static Future<bool> shouldShowPermissionGuide() async {
    // 导入 SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    final shown = prefs.getBool(_permissionGuideShownKey) ?? false;
    final version = prefs.getInt(_permissionGuideVersionKey) ?? 0;

    // 如果从未显示过，或版本更新了，则需要显示
    return !shown || version < _currentGuideVersion;
  }

  /// 标记权限引导已显示
  static Future<void> markPermissionGuideShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionGuideShownKey, true);
    await prefs.setInt(_permissionGuideVersionKey, _currentGuideVersion);
  }

  /// 重置引导状态（用于测试或重新引导）
  static Future<void> resetPermissionGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionGuideShownKey);
  }
}
```

需要添加依赖：在文件顶部添加
```dart
import 'package:shared_preferences/shared_preferences.dart';
```

- [ ] **Step 2: 检查 pubspec.yaml 确认依赖**

确保 `pubspec.yaml` 包含：
```yaml
dependencies:
  shared_preferences: ^2.0.0
```

如果没有，需要添加：
```yaml
dependencies:
  shared_preferences: ^2.3.0
```

- [ ] **Step 3: 运行 flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 4: 提交**

```bash
git add lib/utils/device_info.dart pubspec.yaml
git commit -m "feat: add device info detection utility"
```

---

## Task 3: 创建权限引导页面

**文件:**
- Create: `lib/screens/permission_guide_screen.dart`
- Modify: `lib/screens/profile_screen.dart` (添加重新引导入口)

- [ ] **Step 1: 创建权限引导页面**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/device_info.dart';
import '../services/pump_background_service.dart';

/// 权限引导页面
class PermissionGuideScreen extends StatefulWidget {
  final bool isFromSettings;

  const PermissionGuideScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  State<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}

class _PermissionGuideScreenState extends State<PermissionGuideScreen> {
  bool _isMIUI = false;
  bool _isXiaomi = false;
  String? _miuiVersion;

  @override
  void initState() {
    super.initState();
    _detectDevice();
  }

  Future<void> _detectDevice() async {
    final miui = await DeviceInfo.isMIUI();
    final xiaomi = await DeviceInfo.isXiaomi();
    final version = await DeviceInfo.getMIUIVersion();

    if (mounted) {
      setState(() {
        _isMIUI = miui;
        _isXiaomi = xiaomi;
        _miuiVersion = version;
      });
    }
  }

  Future<void> _openAppSettings() async {
    try {
      final platform = MethodChannel('com.tomapp/app_settings');
      await platform.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('打开设置失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开设置，请手动前往系统设置')),
        );
      }
    }
  }

  Future<void> _onSkip() async {
    // 显示警告
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认跳过？'),
        content: const Text(
          '跳过后台权限设置可能导致应用在后台无法正常接收通知。\n\n'
          '你可以在稍后通过设置页面重新打开此引导。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('仍然跳过'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DeviceInfo.markPermissionGuideShown();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开启后台通知'),
        automaticallyImplyLeading: !widget.isFromSettings,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 图标
            const Icon(
              Icons.notifications_active,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),

            // 标题
            Text(
              '让应用在后台正常工作',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 说明文字
            const Text(
              '为了在后台正常接收资金费率和快速上涨提醒，'
              '请允许应用在后台运行。',
              style: TextStyle(fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // MIUI 特别说明
            if (_isMIUI || _isXiaomi) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_android, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '小米/MIUI 用户特别注意',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '请按以下步骤设置：\n'
                      '1. 点击下方「去设置」按钮\n'
                      '2. 找到「自启动管理」→ 开启 TomApp\n'
                      '3. 找到「后台弹出界面」→ 开启\n'
                      '4. 找到「省电策略」→ 设为「无限制」',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                    if (_miuiVersion != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '检测到 MIUI 版本: $_miuiVersion',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 操作按钮
            FilledButton.tonalIcon(
              onPressed: _openAppSettings,
              icon: const Icon(Icons.settings),
              label: const Text('去设置开启'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: _onSkip,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('跳过'),
            ),

            const SizedBox(height: 32),

            // 补充说明
            Text(
              '💡 设置完成后，返回应用即可继续使用。',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 MethodChannel 处理类**

创建 `lib/utils/app_settings.dart`:

```dart
import 'package:flutter/services.dart';

class AppSettings {
  static const MethodChannel _channel = MethodChannel('com.tomapp/app_settings');

  static Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      throw Exception('无法打开设置: $e');
    }
  }
}
```

同时更新 `permission_guide_screen.dart` 的导入：
```dart
import '../utils/app_settings.dart';
```

并将 `_openAppSettings` 方法改为：
```dart
Future<void> _openAppSettings() async {
  try {
    await AppSettings.openAppSettings();
  } catch (e) {
    debugPrint('打开设置失败: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开设置，请手动前往系统设置')),
      );
    }
  }
}
```

- [ ] **Step 3: 修改 permission_guide_screen.dart 中的导入**

确保文件顶部的导入包含：
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/device_info.dart';
import '../utils/app_settings.dart';
```

同时在 `device_info.dart` 顶部添加（如果还没有）：
```dart
import 'dart:io';
```

- [ ] **Step 4: 提交**

```bash
git add lib/screens/permission_guide_screen.dart lib/utils/app_settings.dart
git commit -m "feat: add permission guide screen for MIUI devices"
```

---

## Task 4: 添加 Android 端 MethodChannel 实现

**文件:**
- Modify: `android/app/src/main/kotlin/com/tomapp/MainActivity.kt` (或对应的 MainActivity 文件)

- [ ] **Step 1: 检查 MainActivity 文件位置**

```bash
find android/app/src/main -name "MainActivity.*"
```

- [ ] **Step 2: 添加 MethodChannel 处理代码**

在 MainActivity 中添加：

```kotlin
package com.example.tomapp  // 根据实际包名调整

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.tomapp/app_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openAppSettings") {
                openAppSettings()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openAppSettings() {
        val intent = Intent(
            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:" + context?.packageName)
        )
        intent.addCategory(Intent.CATEGORY_DEFAULT)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }
}
```

如果使用 Java 版本：

```java
package com.example.tomapp;  // 根据实际包名调整

import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.tomapp/app_settings";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("openAppSettings")) {
                    openAppSettings();
                    result.success(null);
                } else {
                    result.notImplemented();
                }
            });
    }

    private void openAppSettings() {
        Intent intent = new Intent(
            android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:" + getPackageName())
        );
        intent.addCategory(Intent.CATEGORY_DEFAULT);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(intent);
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add android/app/src/main/kotlin/com/example/tomapp/MainActivity.kt
git commit -m "feat: add MethodChannel for opening app settings"
```

---

## Task 5: 修改 main.dart 添加引导流程

**文件:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 main.dart 顶部添加导入**

```dart
import 'screens/permission_guide_screen.dart';
import 'utils/device_info.dart';
```

- [ ] **Step 2: 创建启动判断 Widget**

在 main.dart 中添加：

```dart
/// 启动包装器 - 处理权限引导
class StartupWrapper extends StatefulWidget {
  final Widget child;

  const StartupWrapper({super.key, required this.child});

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  bool _isChecking = true;
  bool _needsGuide = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionGuide();
  }

  Future<void> _checkPermissionGuide() async {
    final needsGuide = await DeviceInfo.shouldShowPermissionGuide();

    if (mounted) {
      setState(() {
        _isChecking = false;
        _needsGuide = needsGuide;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_needsGuide) {
      return MaterialApp(
        home: PermissionGuideScreen(
          onCompleted: () {
            setState(() {
              _needsGuide = false;
            });
          },
        ),
      );
    }

    return widget.child;
  }
}
```

- [ ] **Step 3: 修改 PermissionGuideScreen 添加回调**

更新 `permission_guide_screen.dart`，添加 `onCompleted` 回调参数：

```dart
class PermissionGuideScreen extends StatefulWidget {
  final bool isFromSettings;
  final VoidCallback? onCompleted;

  const PermissionGuideScreen({
    super.key,
    this.isFromSettings = false,
    this.onCompleted,
  });

  @override
  State<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}
```

并在跳过时调用回调：
```dart
Future<void> _onSkip() async {
  // ... existing code ...

  if (confirmed == true && mounted) {
    await DeviceInfo.markPermissionGuideShown();
    widget.onCompleted?.call();
    if (mounted && !widget.isFromSettings) {
      Navigator.of(context).pop();
    }
  }
}
```

同时在用户从设置返回后也调用：
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  if (state == AppLifecycleState.resumed) {
    // 用户从设置返回
    widget.onCompleted?.call();
    if (mounted && !widget.isFromSettings) {
      Navigator.of(context).pop();
    }
  }
}
```

需要让 State 类实现 `WidgetsBindingObserver`：
```dart
class _PermissionGuideScreenState extends State<PermissionGuideScreen>
    with WidgetsBindingObserver {
  // ...

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detectDevice();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 用户从设置返回，等待一下让用户看清效果
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.onCompleted?.call();
        if (mounted && !widget.isFromSettings) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  // ... rest of the code
}
```

- [ ] **Step 4: 用 StartupWrapper 包装 MyApp**

找到 `runApp` 调用，修改为：

```dart
void main() {
  runApp(
    StartupWrapper(
      child: const MyApp(),
    ),
  );
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/main.dart lib/screens/permission_guide_screen.dart
git commit -m "feat: add startup wrapper for permission guide"
```

---

## Task 6: 增强 PumpBackgroundService

**文件:**
- Modify: `lib/services/pump_background_service.dart`

- [ ] **Step 1: 更新前台服务配置**

修改 `initialize` 方法中的配置：

```dart
Future<void> initialize({
  required Future<void> Function(ServiceInstance service) onStart,
}) async {
  await _service.configure(
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: (service) async {
        return true;
      },
      autoStart: false,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.remoteMessaging,
      ],
      initialNotificationTitle: 'TomApp',
      initialNotificationContent: '后台监控运行中...',
    ),
  );
}
```

- [ ] **Step 2: 添加动态通知更新方法**

添加以下方法：

```dart
/// 更新前台服务通知
Future<void> updateNotification({
  String? title,
  String? content,
}) async {
  if (await isRunning) {
    _service.invoke('updateNotification', {
      'title': title ?? 'TomApp',
      'content': content ?? '后台监控运行中...',
    });
  }
}

/// 停止服务并移除通知
Future<void> stopService() async {
  if (await isRunning) {
    await _service.invoke('stopService');
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/services/pump_background_service.dart
git commit -m "feat: enhance PumpBackgroundService with multiple foreground types"
```

---

## Task 7: 在设置页面添加重新引导入口

**文件:**
- Modify: `lib/screens/profile_screen.dart`

- [ ] **Step 1: 添加重新引导按钮**

在设置页面适当位置添加：

```dart
ListTile(
  leading: const Icon(Icons.notifications_active),
  title: const Text('重新设置后台权限'),
  subtitle: const Text('如果通知不工作，可以重新设置'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    // 重置引导状态
    await DeviceInfo.resetPermissionGuide();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PermissionGuideScreen(
            isFromSettings: true,
          ),
        ),
      );
    }
  },
),
```

需要添加导入：
```dart
import '../utils/device_info.dart';
import 'permission_guide_screen.dart';
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/profile_screen.dart
git commit -m "feat: add re-setup permission button in settings"
```

---

## Task 8: 更新后台服务启动逻辑

**文件:**
- Modify: `lib/main.dart` 或服务初始化位置

- [ ] **Step 1: 确保服务在引导完成后启动**

在 `MyApp` 或适当的初始化位置添加：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  NotificationService().initialize();

  runApp(
    StartupWrapper(
      child: const MyApp(),
    ),
  );
}
```

- [ ] **Step 2: 在应用启动时启动后台服务**

在 `MyApp` 的 `initState` 或适当的生命周期方法中：

```dart
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _startBackgroundService();
  }

  Future<void> _startBackgroundService() async {
    final service = PumpBackgroundService.instance;

    // 配置服务处理
    await service.initialize(
      onStart: (serviceInstance) async {
        // 这里处理后台任务
        if (serviceInstance is! AndroidServiceInstance) return;

        // 定时执行的任务
        Timer.periodic(const Duration(hours: 1), (timer) async {
          // 检查资费
          // ...

          // 更新通知
          await PumpBackgroundService.instance.updateNotification(
            content: '最后检查: ${DateTime.now().toString().substring(11, 16)}',
          );
        });

        // 处理停止命令
        serviceInstance.on('stop').listen((event) {
          timer?.cancel();
          serviceInstance.stopSelf();
        });

        // 处理更新通知命令
        serviceInstance.on('updateNotification').listen((event) {
          final title = event['title'] ?? 'TomApp';
          final content = event['content'] ?? '后台监控运行中...';

          serviceInstance.setForegroundNotificationInfo(
            title: title,
            content: content,
          );
        });
      },
    );

    // 启动服务
    await service.start();
  }

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/main.dart
git commit -m "feat: integrate background service with app lifecycle"
```

---

## Task 9: 测试验证

- [ ] **Step 1: 在小米 K70 上测试**

1. 卸载现有应用
2. 安装新版本
3. 首次启动应该显示权限引导页面
4. 检查是否正确识别为 MIUI 设备
5. 点击"去设置"按钮，验证跳转到应用设置页面
6. 在设置中开启所有权限
7. 返回应用，验证引导页面关闭
8. 验证通知栏显示常驻通知
9. 应用切换到后台
10. 等待 1 小时或手动触发快速上涨，验证通知是否正常

- [ ] **Step 2: 在其他设备上测试**

1. 在非小米设备上安装
2. 验证是否也显示引导页面（应该显示，但没有 MIUI 特别说明）
3. 验证功能正常工作

- [ ] **Step 3: 测试跳过流程**

1. 重置应用数据或卸载重装
2. 在引导页面点击"跳过"
3. 验证显示警告对话框
4. 确认跳过后应用继续运行
5. 验证设置页面可以重新打开引导

- [ ] **Step 4: 测试重新引导**

1. 打开设置页面
2. 点击"重新设置后台权限"
3. 验证引导页面打开
4. `isFromSettings` 参数为 true，不应自动关闭

- [ ] **Step 5: 记录测试结果**

测试通过后创建测试提交：

```bash
git add .
git commit -m "test: verify background notification fix on MIUI devices"
```

---

## 验收标准

- [ ] 首次启动显示权限引导页面
- [ ] 小米设备显示 MIUI 专属说明
- [ ] "去设置"按钮正确跳转到应用设置
- [ ] 授权后返回应用，引导页面自动关闭
- [ ] 通知栏显示简洁的常驻通知
- [ ] 应用在后台时仍能接收快速上涨通知
- [ ] 每小时资费检查正常执行
- [ ] 设置页面可重新打开引导
- [ ] 非小米设备不受影响

---

## 注意事项

1. **前台服务常驻通知** 是 Android 系统要求，无法移除
2. **不同 MIUI 版本** 设置路径可能有差异，需要根据实际情况调整说明
3. **电量消耗** 后台运行会增加耗电，建议在设置中提供关闭选项
4. **权限说明** 第一次使用时向用户解释为什么需要这些权限

---

## 相关文档

- 设计文档: `docs/superpowers/specs/2026-04-05-background-notification-fix-design.md`
- flutter_background_service 文档: https://pub.dev/packages/flutter_background_service
- Android 前台服务: https://developer.android.com/guide/components/foreground-services
