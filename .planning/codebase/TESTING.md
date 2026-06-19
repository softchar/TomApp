# Testing Patterns

**Analysis Date:** 2026/06/19

## Test Framework

**Runner:**
- Flutter Test (bundled with Flutter SDK)
- Integration Test support via `integration_test` package
- Config: `analysis_options.yaml` (no dedicated test config file)

**Assertion Library:**
- Built-in `expect()` from `package:flutter_test/flutter_test`
- Custom matchers: `closeTo()`, `identical()`, `lessThanOrEqualTo()`

**Run Commands:**
```bash
flutter test                      # Run all unit tests
flutter test --name "pump"        # Run tests matching pattern
flutter test integration_test/     # Run integration tests
flutter test --coverage           # Generate coverage (if coverage package added)
```

## Test File Organization

**Location:**
- **Co-located pattern**: Tests in separate `test/` directory mirroring `lib/` structure
- Integration tests in `integration_test/` directory

**Naming:**
- Test files: `*_test.dart` suffix (e.g., `pump_model_test.dart`)
- 1:1 mapping with source files where applicable
- Test directory structure mirrors lib structure

**Structure:**
```
test/
├── models/
│   ├── pump_model_test.dart
│   ├── pump_history_model_test.dart
│   └── macd_data_test.dart
├── services/
│   ├── binance_websocket_manager_test.dart
│   ├── database_helper_test.dart
│   ├── pump_alert_service_test.dart
│   ├── pump_detector_test.dart
│   ├── pump_repository_test.dart
│   ├── pump_store_test.dart
│   ├── strategies/
│   │   └── time_based_strategy_test.dart
│   └── technical_indicators_test.dart
└── integration_test/
    └── pump_alert_test.dart
```

**Files mapped:**
- `lib/models/pump_model.dart` → `test/models/pump_model_test.dart`
- `lib/services/pump_detector.dart` → `test/services/pump_detector_test.dart`
- `lib/services/database_helper.dart` → `test/services/database_helper_test.dart`

## Test Structure

**Suite Organization:**
```dart
void main() {
  group('PumpModel', () {
    test('should create model with all required fields', () {
      // Test implementation
    });

    test('should serialize to map correctly', () {
      // Test implementation
    });

    test('should deserialize from map correctly', () {
      // Test implementation
    });
  });

  group('PumpDetector', () {
    late PumpDetector detector;

    setUp(() {
      // Setup before each test
      detector = PumpDetector(
        config: PumpConfig(),
        repository: MemoryPumpRepository(),
      );
    });

    test('should return null when price change is below threshold', () async {
      // Test implementation
    });

    test('should detect pump when price change exceeds threshold', () async {
      // Test implementation
    });
  });
}
```

**Patterns:**
- **Grouping**: Related tests grouped using `group()` descriptor
- **Setup/Teardown**: `setUp()` for test initialization, no explicit `tearDown()` observed
- **Test naming**: Descriptive test names starting with "should" or action verbs
- **AAA pattern**: Arrange-Act-Assert structure in test bodies

**Async Testing:**
```dart
test('should detect pump when price change exceeds threshold', () async {
  // Arrange
  final baseTime = DateTime(2026, 4, 1, 10, 0, 0);
  detector.addPricePoint('BTCUSDT', 65000.0, baseTime);

  // Act
  final result = await detector.check(
    'BTCUSDT',
    66950.0,
    baseTime.add(const Duration(minutes: 1)),
  );

  // Assert
  expect(result, isNotNull);
  expect(result!.symbol, 'BTCUSDT');
  expect(result.priceChange, closeTo(3.0, 0.1));
});
```

## Mocking

**Framework:**
- Mockito v5.4.0 (listed in dev_dependencies)
- Manual test doubles (in-memory repositories, test configs)

**Patterns:**
```dart
// Pattern 1: In-memory test double
setUp(() {
  detector = PumpDetector(
    config: PumpConfig(),
    repository: MemoryPumpRepository(), // Test implementation
  );
});

// Pattern 2: Singleton verification
test('instance returns singleton', () {
  final helper1 = DatabaseHelper.instance;
  final helper2 = DatabaseHelper.instance;
  expect(identical(helper1, helper2), true);
});
```

**What to Mock:**
- External dependencies (HTTP clients, databases)
- Time-dependent operations (DateTime usage in tests)
- Platform-specific services

**What NOT to Mock:**
- Domain models (test real implementations)
- Business logic (test actual algorithms)
- Data serialization (test real fromJson/toJson)

## Fixtures and Factories

**Test Data:**
```dart
// Direct construction in tests
final model = PumpModel(
  symbol: 'BTCUSDT',
  priceChange: 3.5,
  triggerTime: DateTime(2026, 4, 1, 10, 23, 45),
  currentPrice: 67234.50,
);

// Map-based construction for deserialization tests
final map = {
  'symbol': 'BTCUSDT',
  'priceChange': 3.5,
  'triggerTime': DateTime(2026, 4, 1, 10, 23, 45).toIso8601String(),
  'currentPrice': 67234.50,
};
```

**Location:**
- Test data created inline within test methods
- No dedicated fixture files or factories observed
- Constants defined in test methods for reuse

## Coverage

**Requirements:**
- No explicit coverage target enforced
- Coverage package not configured in pubspec.yaml
- Manual test verification for critical paths

**View Coverage:**
```bash
flutter test --coverage  # Requires coverage package
# No lcov or coverage reporting configured
```

**Coverage areas:**
- Models: Serialization/deserialization (`PumpModel`, `PumpHistoryModel`, `MacdData`)
- Services: Business logic (`PumpDetector`, `TechnicalIndicators`)
- Database: Singleton pattern (`DatabaseHelper`)
- Strategies: Pump detection strategies (`TimeBasedStrategy`)

**Uncovered areas (opportunities):**
- UI widgets (no widget tests observed)
- Providers (no provider state management tests)
- API services (no HTTP mocking tests)
- Integration scenarios (limited integration test coverage)

## Test Types

**Unit Tests:**
- Scope: Individual classes and functions
- Approach: Isolated testing with test doubles
- Coverage: Models, services, strategies
- Framework: `flutter_test`

**Examples:**
```dart
// Model serialization tests
test('should serialize to map correctly', () {
  final model = PumpModel(...);
  final map = model.toMap();
  expect(map['symbol'], 'ETHUSDT');
});

// Business logic tests
test('should enforce cooldown period', () async {
  // Test cooldown logic in isolation
});
```

**Integration Tests:**
- Scope: Multi-component interactions
- Approach: Full Flutter app initialization
- Location: `integration_test/` directory
- Framework: `integration_test` package

**Example:**
```dart
// integration_test/pump_alert_test.dart
testWidgets('should navigate to pump screen', (tester) async {
  app.main();
  await tester.pumpAndSettle();

  await tester.tap(find.text('快速上涨'));
  await tester.pumpAndSettle();

  expect(find.byType(PumpScreen), findsOneWidget);
});
```

**E2E Tests:**
- Framework: Not used (no E2E test automation observed)
- Manual testing through device interaction

**Widget Tests:**
- Framework: Not used (no widget test files observed)
- Opportunity: Test widget rendering and user interactions

## Common Patterns

**Async Testing:**
```dart
test('async operation test', () async {
  // Arrange
  final baseTime = DateTime(2026, 4, 1, 10, 0, 0);

  // Act
  final result = await detector.check(
    'BTCUSDT',
    66950.0,
    baseTime.add(const Duration(minutes: 1)),
  );

  // Assert
  expect(result, isNotNull);
});
```

**Error Testing:**
```dart
// Limited error testing observed
// Pattern could be:
test('should throw when API fails', () async {
  expect(
    () async => await service.getData(),
    throwsException,
  );
});
```

**State Testing:**
```dart
// State transition testing
test('should enforce cooldown period', () async {
  // First trigger
  await detector.check(...);

  // Second trigger during cooldown
  final result2 = await detector.check(...);

  expect(result2, isNull); // Verify cooldown active
});
```

**Property-Based Testing:**
- Not used (no property testing libraries observed)

## Test Data Management

**DateTime Testing:**
```dart
// Fixed timestamps for reproducibility
final baseTime = DateTime(2026, 4, 1, 10, 0, 0);
final result = await detector.check(
  'BTCUSDT',
  66950.0,
  baseTime.add(const Duration(minutes: 1)),
);
```

**Numeric Precision:**
```dart
// Approximate equality for floating point
expect(result.priceChange, closeTo(3.0, 0.1));
```

**String Patterns:**
```dart
// Symbol naming conventions
'SymbolUSDT', 'SymbolBUSD'
```

## Testing Best Practices Observed

**✓ Descriptive test names:**
- "should create model with all required fields"
- "should return null when price change is below threshold"

**✓ Test isolation:**
- `setUp()` creates fresh instances
- No shared state between tests

**✓ Arrange-Act-Assert:**
- Clear structure in test bodies
- Logical flow from setup to verification

**✓ Edge case coverage:**
- Cooldown period testing
- Empty result handling
- Boundary conditions

**✓ Async handling:**
- Proper `async/await` usage
- Timeout considerations

## Testing Gaps and Opportunities

**Missing test types:**
- Widget tests for UI components
- Provider state management tests
- HTTP client mocking tests
- WebSocket connection tests
- Background service tests

**Coverage gaps:**
- Large files like `main.dart` (635 lines) have no dedicated tests
- Screen classes (UI components) untested
- Provider logic (critical for state management) untested
- Database migration logic untested

**Test infrastructure needs:**
- Coverage reporting setup
- Continuous integration test configuration
- Golden file testing for UI
- Performance testing for data processing

---

*Testing analysis: 2026/06/19*