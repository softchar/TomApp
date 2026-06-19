# Coding Conventions

**Analysis Date:** 2026/06/19

## Naming Patterns

**Files:**
- **snake_case.dart** - All Dart files use lowercase with underscores
- Examples: `pump_model.dart`, `funding_rate_provider.dart`, `binance_api_service.dart`
- Screen files: `home_screen.dart`, `pump_screen.dart`, `kline_screen.dart`
- Test files: `pump_model_test.dart`, `pump_detector_test.dart`

**Classes:**
- **PascalCase** - All classes use upper camel case
- Examples: `PumpModel`, `FundingRateProvider`, `BinanceApiService`, `DatabaseHelper`
- Private classes: `_PumpDetector`, `_PricePoint` (underscore prefix)

**Functions/Methods:**
- **camelCase** - All functions and methods use lower camel case
- Examples: `save()`, `findAll()`, `loadMore()`, `setSearchQuery()`
- Async functions: `Future<void> save()`, `Future<List<PumpHistoryModel>> findAll()`

**Variables:**
- **camelCase** - All variables use lower camel case
- Private members: `_state`, `_repository`, `_config` (underscore prefix)
- Constants: `PascalCase` - `DatabaseHelper`, `AppColors`, `AppSpacing`
- Static constants: `SCREAMING_SNAKE_CASE` in other codebases, but this project uses `PascalCase` for design system constants

**Types/Enums:**
- **PascalCase** - All types and enums use upper camel case
- Examples: `PumpListStatus`, `PumpListSort`, `FundingRate`, `LongShortRatio`
- Enum values: `PumpListStatus.initial`, `PumpListStatus.loading`

## Code Style

**Formatting:**
- Tool: Flutter's built-in formatter
- Key settings from `analysis_options.yaml`:
  - `prefer_const_constructors: true`
  - `prefer_const_literals_to_create_immutables: true`
  - `avoid_print: false` (debug prints allowed)

**Linting:**
- Tool: `flutter_lints` (v3.0.0)
- Configuration: `analysis_options.yaml` extends `package:flutter_lints/flutter.yaml`
- Custom plugin: `flutter_background_service`

**Code Organization:**
- Maximum file length observed: 635 lines (`lib/main.dart`)
- Large files typically contain multiple related classes or widgets
- Widget decomposition: Private widgets extracted with underscore prefix (`_TopGainersWidget`, `_GainerListTile`)

## Import Organization

**Order:**
1. Dart SDK imports
2. Flutter package imports
3. Third-party package imports (http, provider, etc.)
4. Project imports (relative paths)
5. Conditional show/hide imports for specific symbols

**Examples from codebase:**
```dart
// Standard organization
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:tomapp/models/pump_model.dart';
import 'package:tomapp/services/pump_repository.dart';
```

**Path Aliases:**
- Package import: `package:tomapp/...`
- No custom path aliases configured

**Conditional imports:**
```dart
// Show/hide specific imports to avoid symbol conflicts
import 'services/theme_provider.dart' hide AppColors, AppTextStyles, AppSpacing, AppRadius;
import 'services/theme_provider.dart' show AppColors, AppTextStyles, AppSpacing, AppRadius, ThemeProvider;
```

## Error Handling

**Patterns:**
- **Try-catch blocks** for async operations
- **Exception throwing** with descriptive messages
- **Null returns** for failure cases in some functions
- **debugPrint** for error logging in development

**Examples from codebase:**
```dart
// Pattern 1: Throw exception with context
try {
  final response = await _client.get(uri).timeout(const Duration(seconds: 30));
  if (response.statusCode == 200) {
    return data.map((json) => Model.fromJson(json)).toList();
  } else {
    throw Exception('API请求失败: ${response.statusCode}');
  }
} on TimeoutException {
  throw Exception('请求超时，请检查网络连接');
} catch (e) {
  throw Exception('获取数据失败: $e');
}

// Pattern 2: Return null on failure
Future<FundingRate?> getFundingRateBySymbol(String symbol) async {
  try {
    // ... implementation
  } catch (e) {
    return null;
  }
}

// Pattern 3: State-based error handling
catch (e) {
  _state = _state.copyWith(
    status: PumpListStatus.error,
    errorMessage: e.toString(),
  );
}
```

## Logging

**Framework:**
- Primary: `debugPrint()` from Flutter SDK
- Secondary: `print()` for some provider classes
- kDebugMode guards for conditional logging

**Patterns:**
```dart
// Development-only logging
if (kDebugMode) {
  debugPrint('[ServiceName] 操作详情: ${data.length}');
  print('[KlineProvider] 实时K线更新: $_symbol');
}

// Production-safe logging
debugPrint('🔧 callbackDispatcher: 后台服务回调已启动');
debugPrint('❌ 保存快速上涨记录失败: $e');
```

**Emoji prefixes for categorization:**
- 🔧 = Service/technical operations
- 🚀 = Detected pumps/alerts
- 💾 = Database operations
- ❌ = Errors/failures

## Comments

**When to Comment:**
- Class-level documentation for complex services
- Public method documentation (minimal JSDoc usage observed)
- Section separators in large files
- Configuration explanations

**Examples from codebase:**
```dart
/// PumpRepository 抽象接口
abstract class PumpRepository {
  // ... interface definition
}

/// 统计数据模型
class PumpStatistics {
  // ... implementation
}

/// RepositoryFactory - 根据规范 Section 3.6
class RepositoryFactory {
  // ... implementation
}
```

**Section comments:**
```dart
// ============================================
// API 配置区域
// ============================================

// ==================== 拆分的独立Widget ====================
```

**Inline comments:**
- Explaining "why" not "what"
- Chinese language for business logic explanations
- English for technical comments

## Function Design

**Size:**
- No strict size limit observed
- Large functions decomposed into smaller private methods
- Widget extraction for UI components (50-100 lines typical)

**Parameters:**
- Named parameters for clarity: `findAll({int? limit, int? offset})`
- Required parameters enforced: `required this.symbol`
- Optional parameters with defaults: `int hours = 24`

**Return Values:**
- Explicit typing: `Future<List<PumpHistoryModel>>`
- Nullable returns for failure cases: `Future<FundingRate?>`
- State objects for complex returns: `PumpListState get state => _state;`

**Async patterns:**
- All async operations use `async/await`
- Timeout handling: `.timeout(const Duration(seconds: 30))`
- Error propagation through exceptions

## Module Design

**Exports:**
- Public classes exported by default
- Private implementation classes use underscore prefix: `_PumpDetector`, `_TopGainersWidget`
- Factory pattern for dependency injection: `RepositoryFactory.create()`

**Barrel Files:**
- No barrel files observed
- Direct imports used throughout

**Dependency Injection:**
- Provider pattern for state management
- Constructor injection for dependencies: `PumpListProvider({required PumpRepository repository})`
- Singleton pattern for services: `DatabaseHelper.instance`, `FavoriteService()`

**State Management:**
- Provider package used extensively
- ChangeNotifier for stateful classes
- Immutable state objects with `copyWith()` method
- Enum-based status tracking: `PumpListStatus.initial`, `PumpListStatus.loading`

## Design Patterns

**Factory Pattern:**
```dart
class RepositoryFactory {
  static PumpRepository create() {
    try {
      return SqlitePumpRepository();
    } catch (e) {
      return MemoryPumpRepository(); // Fallback
    }
  }
}
```

**Singleton Pattern:**
```dart
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();
}
```

**State Pattern:**
```dart
class PumpListState {
  final PumpListStatus status;
  final List<PumpHistoryModel> pumps;
  final String? errorMessage;
  // ... with copyWith() method
}
```

---

*Convention analysis: 2026/06/19*