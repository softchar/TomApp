# 构建环境配置指南

**最后更新:** 2026/06/19
**适用场景:** 中国大陆网络环境下构建 TomApp Android Release APK；换机器、新成员 onboard、CI 配置可直接复用。

---

## 1. 背景

在中国大陆网络下，Flutter Android 构建依赖的两类境外资源会导致构建**永久卡死**（TCP `SYN_SENT`，CPU 占用趋近于 0）：

| 卡点 | 原因 | 已采用的修复 |
|---|---|---|
| Flutter 引擎产物仓库 `storage.flutter-io.cn` | 2026/06 实测该域名解析到死节点 `47.91.170.222`（连接超时），release 构建拉引擎产物时卡死 | 改用腾讯云镜像 |
| `:app:lintVitalAnalyzeRelease` 任务 | AGP 硬编码从 `dl.google.com` 下载 SDK/Maven 索引，**绕过** `build.gradle.kts` 的仓库镜像，被墙后卡死 | 禁用 release lint |

本文档记录已落地的配置，确保 `flutter build apk --release` 稳定通过。

---

## 2. 关键配置（已落地，勿随意回退）

### 2.1 Gradle 仓库镜像 — `android/build.gradle.kts`

```kotlin
allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        // 注意：原 storage.flutter-io.cn 现解析到死节点 47.91.170.222（连接超时），
        // 会导致 release 构建拉 Flutter 引擎产物时永久卡死。改用腾讯云镜像。
        maven { url = uri("https://mirrors.cloud.tencent.com/flutter/download.flutter.io") }
        google()
        mavenCentral()
    }
}
```

- 阿里云两个源负责 AGP / AndroidX / Kotlin 等常规依赖（实测 200，~0.5s）。
- 腾讯云源专门托管 Flutter 引擎产物（`io.flutter:flutter_embedding`、引擎 so 等），实测 200，~0.05s。
- `google()` / `mavenCentral()` 作为兜底；境外 CI 直连也不受影响（Gradle 按序尝试）。

> ⚠️ `settings.gradle.kts` 的 `pluginManagement.repositories` 仍是原始 `google()/mavenCentral()/gradlePluginPortal()`。AGP 8.7.3 与 Kotlin 2.1.0 已缓存，正常离线解析；若换机器首次拉插件卡住，可在此处同步加阿里云镜像。

### 2.2 禁用联网 lint — `android/app/build.gradle.kts`

```kotlin
android {
    // ... 其他配置 ...

    // 跳过 release 的 lintVitalRelease 任务：该任务会联网下载 Google SDK/Maven 索引
    // (dl.google.com 硬编码 URL，绕过仓库镜像)，在国内网络下会卡死。非上架构建可安全跳过。
    lint {
        checkReleaseBuilds = false
    }
}
```

- `lintVital` 本用于检查 manifest 缺权限等关键问题；本项目非应用商店上架，跳过风险可控。
- 如需检查，可在 Android Studio 手动跑 `Analyze → Inspect Code`。

### 2.3 Gradle / JVM 内存 — `android/gradle.properties`

```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
```

- `-Xmx8G` 偏大，适合 16GB+ 内存机器。CI 或低配机器可降到 `-Xmx4G`。

### 2.4 Gradle 版本 — `android/gradle/wrapper/gradle-wrapper.properties`

```
distributionUrl=https\://services.gradle.org/distributions/gradle-8.12-all.zip
```

- 首次构建会下载 ~230MB 的 `gradle-8.12-all.zip`。换机器/CI 建议预置或缓存 `~/.gradle/wrapper/dists/`。

---

## 3. 构建步骤

```bash
# 首次 / 换机器 / 改了 gradle 配置后，建议先 clean
flutter clean

# 只构建 arm64（包更小、更快；目标小米 arm64 设备）
flutter build apk --release --target-platform android-arm64

# 或构建通用 fat APK（含 arm64 + armv7 + x86_64，体积更大、更慢）
flutter build apk --release
```

**产物：** `build/app/outputs/flutter-apk/app-release.apk`

> Flutter CLI 在 Gradle 阶段不实时刷新输出，会长时间停在 `Running Gradle task 'assembleRelease'...`，这是正常显示行为，**不代表卡死**（判断方法见 §6）。

---

## 4. 安装到设备

设备：小米 23113RKC6C（Android 16, arm64）。`adb` 不在 PATH 时用 Android SDK 绝对路径：

```bash
ADB="$LOCALAPPDATA/Android/sdk/platform-tools/adb.exe"   # Windows: ~/AppData/Local/Android/sdk/platform-tools/adb.exe
APK="build/app/outputs/flutter-apk/app-release.apk"

# 1. 确认设备在线
"$ADB" devices                     # 应显示 <device-id>  device

# 2. 覆盖安装
"$ADB" -s <device-id> install -r "$APK"

# 3. 直接启动应用（包名 com.example.tomapp）
"$ADB" -s <device-id> shell monkey -p com.example.tomapp -c android.intent.category.LAUNCHER 1
```

> 小米 MIUI / 暂拍OS 首次安装非商店 APK 可能在手机端弹「风险提示」，需手动点「继续安装」/输入密码授权。USB 安装需在「开发者选项」开启「USB 安装」。

---

## 5. 环境依赖清单（换机器 / CI）

| 依赖 | 版本 / 来源 |
|---|---|
| Flutter SDK | 3.32.8 stable（本机 `C:\Tools\flutter_windows_3.32.8-stable\flutter`） |
| Android SDK | `compileSdk`/`minSdk`/`targetSdk` 由 Flutter 插件提供 |
| NDK | `27.0.12077973`（`app/build.gradle.kts` 指定） |
| CMake | `3.22.1`（有 native 代码，`.cxx`） |
| JDK | 21（用 Android Studio 自带 `jbr`） |
| Gradle | 8.12（wrapper 自动拉取） |
| AGP | 8.7.3 |
| Kotlin | 2.1.0 |

**CI 缓存建议：**
- `~/.gradle/caches/`（依赖 + 元数据）
- `~/.gradle/wrapper/dists/`（Gradle 发行包）
- `build/`（增量构建，同分支时）

---

## 6. 故障排查：构建卡死诊断法

构建卡在 `Running Gradle task 'assembleRelease'...` 长时间不动时，按此流程定位（**先判断「真卡死」还是「正常编译慢」**）：

```bash
# 1. 找到 TomApp 当前的 Gradle daemon（状态 BUSY 的 PID）
cd android && ./gradlew --status

# 2. 监控该 daemon CPU（5~6 秒增量）
#    增量 < 0.5 秒  → 网络死等（socket 阻塞）
#    增量 > 3 秒    → 正在编译 / R8 混淆，属正常慢
powershell -Command "C1=(Get-Process -Id <PID>).CPU; Start-Sleep 6; C2=(Get-Process -Id <PID>).CPU; C2-C1"

# 3. 抓卡点：daemon 卡在连哪个 IP
netstat -ano | grep <PID>            # 找 SYN_SENT 的 RemoteAddress

# 4. 测该 IP / 对应域名连通性
curl -o /dev/null -w "%{http_code} %{time_total}s\n" --max-time 8 https://<域名>/

# 5. 连不上的镜像 → 换源（见 §2.1）或配代理（见 §7）
```

**已知的死点（2026/06 实测）：**
- `storage.flutter-io.cn` → `47.91.170.222` 不可达 → 已换腾讯云镜像
- `dl.google.com`（lint 索引）→ 已通过禁用 lint 规避

---

## 7. 代理方案（备选根治）

若有 Clash / V2Ray 等本地代理（如端口 7890），在 `android/gradle.properties` 追加：

```properties
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=7890
systemProp.https.proxyHost=127.0.0.1
systemProp.https.proxyPort=7890
```

配代理后可保留原始 `google()` 等源，无需镜像。**二选一即可**（镜像方案已默认启用，代理为可选增强）。

---

## 8. 常见干扰因素

- **VSCode Oracle Java 扩展**（`oracle.oracle-java`）会在后台持续跑 Gradle（`nbcode` 进程），抢占 daemon / CPU / 内存，拖慢甚至阻塞 Flutter 构建。纯 Flutter 项目建议在该工作区禁用此扩展。
- **多个 Gradle daemon 残留**会吃光内存（每个 `-Xmx8G`）。定期清理：`cd android && ./gradlew --stop`；顽固进程用任务管理器结束。
- **Android Studio 同时开着**会再起一套 Gradle/JVM，构建时建议关闭或至少关闭其后台索引。

---

## 9. 变更记录

| 日期 | 变更 |
|---|---|
| 2026/06/19 | 初版。修复 `storage.flutter-io.cn` 死节点（换腾讯云镜像）；禁用 `lintVitalRelease`；记录完整构建/安装/诊断流程。 |
