# Technology Stack

**Analysis Date:** 2026/06/19

## Languages

**Primary:**
- Dart 3.0.0+ - Core application logic, UI components, and business rules

**Secondary:**
- Kotlin - Android native configuration and background service implementation
- Java 17 - Android build tooling and Gradle dependencies

## Runtime

**Environment:**
- Flutter 3.27.1 - Cross-platform mobile application framework
- Android SDK - Native Android platform integration

**Package Manager:**
- Pub (Dart/Flutter) - `pubspec.yaml` dependency management
- Gradle 8.x - Android build configuration
- Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- Flutter SDK 3.27.1 - Cross-platform UI framework
- Material Design 3 - Design system implementation
- Provider 6.1.0 - State management pattern

**Testing:**
- flutter_test - Built-in Flutter testing framework
- mockito 5.4.0 - Mocking framework for unit tests
- build_runner 2.4.0 - Code generation for mocks

**Build/Dev:**
- flutter_lints 3.0.0 - Dart linting rules
- flutter_background_service 5.0.10 - Background task execution
- flutter_local_notifications 17.2.3 - Local notification system

## Key Dependencies

**Critical:**
- http 1.1.0 - HTTP client for Binance API communication
- web_socket_channel 2.4.0 - WebSocket connections for real-time market data
- sqflite 2.3.0 - Local SQLite database for persistence
- provider 6.1.0 - State management architecture foundation

**Infrastructure:**
- shared_preferences 2.2.2 - Key-value storage for user preferences
- timezone 0.9.4 - Timezone handling for funding rate calculations
- path 1.8.0 - File system path manipulation
- intl 0.18.1 - Internationalization and date formatting

**UI Components:**
- fl_chart 0.65.0 - Chart rendering for K-line and MACD visualizations
- flutter_chen_kchart 2.0.4 - Candlestick chart components
- shimmer 3.0.0 - Loading skeleton animations

## Configuration

**Environment:**
- Runtime configuration via `BinanceApiService` custom base URL support
- No `.env` file system - configuration through code
- Proxy support for Binance API access restrictions

**Build:**
- `pubspec.yaml` - Dart/Flutter dependency configuration
- `analysis_options.yaml` - Linting rules and analyzer configuration
- `android/app/build.gradle.kts` - Android build configuration
- `.github/workflows/main.yml` - CI/CD pipeline

## Platform Requirements

**Development:**
- Flutter SDK 3.27.1
- Dart 3.0.0+
- Android SDK with NDK 27.0.12077973
- Java 17 runtime
- Gradle build system

**Production:**
- Android 5.0+ (minSdk 21)
- Target Android 14+ (targetSdk 34)
- Network access for Binance API
- Background service permissions
- Notification permissions

---

*Stack analysis: 2026/06/19*