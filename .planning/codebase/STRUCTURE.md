# Codebase Structure

**Analysis Date:** 2026/06/19

## Directory Layout

```
[project-root]/
├── android/                    # Android platform configuration
│   ├── app/                   # Android app source
│   │   └── src/main/         # Main Android source
│   ├── gradle/               # Gradle wrapper files
│   └── .gradle/              # Gradle cache
├── build/                     # Flutter build output
├── design-system/             # Design system resources
├── docs/                      # Documentation
├── lib/                       # Main Dart source code
│   ├── main.dart             # App entry point
│   ├── models/               # Data models
│   ├── providers/            # State management
│   ├── screens/              # UI screens
│   ├── services/             # Business logic services
│   │   └── strategies/       # Pump detection strategies
│   ├── utils/                # Utility functions
│   └── widgets/              # Reusable UI components
├── .planning/                 # GSD planning documents
├── .worktrees/               # Git worktrees
└── pubspec.yaml              # Flutter dependencies

```

## Directory Purposes

**lib/:**
- Purpose: Main application source code
- Contains: All Dart application code
- Key files: `lib/main.dart` (entry point)

**lib/screens/:**
- Purpose: UI screen implementations
- Contains: Top-level screen widgets
- Key files: `lib/screens/main_navigation.dart`, `lib/screens/home_screen.dart`

**lib/providers/:**
- Purpose: State management providers
- Contains: ChangeNotifier classes for reactive state
- Key files: `lib/providers/kline_provider.dart`, `lib/providers/pump_list_provider.dart`

**lib/services/:**
- Purpose: Business logic, API clients, data processing
- Contains: Service classes for API calls, database operations, background tasks
- Key files: `lib/services/binance_api_service.dart`, `lib/services/pump_detector.dart`

**lib/services/strategies/:**
- Purpose: Pump detection strategy implementations
- Contains: Strategy pattern implementations for threshold adjustment
- Key files: `lib/services/strategies/adaptive_strategy.dart`, `lib/services/strategies/time_based_strategy.dart`

**lib/models/:**
- Purpose: Data model classes
- Contains: Plain data classes for API responses, database entities
- Key files: `lib/models/pump_model.dart`, `lib/models/kline_data.dart`

**lib/widgets/:**
- Purpose: Reusable UI components
- Contains: Custom widgets for common UI patterns
- Key files: `lib/widgets/kline_chart_widget.dart`, `lib/widgets/pump_item.dart`

**lib/utils/:**
- Purpose: Utility functions and helpers
- Contains: Navigation utilities, helper functions
- Key files: `lib/utils/app_navigation.dart`

**android/:**
- Purpose: Android platform-specific configuration
- Contains: Android manifest, gradle files, Kotlin/Java code
- Generated: Partially (build output)
- Committed: Yes (configuration files)

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Application entry point, provider tree setup
- `lib/screens/main_navigation.dart`: Main navigation container

**Configuration:**
- `pubspec.yaml`: Flutter dependencies and project metadata
- `lib/services/theme_provider.dart`: Theme configuration
- `lib/services/funding_rate_settings.dart`: Funding rate preferences
- `lib/services/contract_sync_settings.dart`: Contract sync preferences

**Core Logic:**
- `lib/services/binance_api_service.dart`: Binance REST API client
- `lib/services/binance_websocket_manager.dart`: WebSocket connection management
- `lib/services/pump_detector.dart`: Pump detection algorithm
- `lib/providers/kline_provider.dart`: K-line data management
- `lib/providers/market_overview_provider.dart`: Market overview state

**Data Persistence:**
- `lib/services/database_helper.dart`: SQLite database setup
- `lib/services/pump_repository.dart`: Pump data repository pattern
- `lib/services/favorite_service.dart`: Favorite symbols persistence
- `lib/services/kline_cache_service.dart`: K-line data caching

**Background Processing:**
- `lib/services/pump_background_service.dart`: Background pump detection service
- `lib/services/contract_sync_service.dart`: Contract metadata synchronization

**Testing:**
- No dedicated test directory (testing should be added in `test/`)

## Naming Conventions

**Files:**
- snake_case: `binance_api_service.dart`, `pump_detector.dart`
- Screen files: `[name]_screen.dart` (e.g., `home_screen.dart`)
- Provider files: `[name]_provider.dart` (e.g., `kline_provider.dart`)
- Model files: `[name]_model.dart` (e.g., `pump_model.dart`)
- Widget files: `[name]_widget.dart` or descriptive names (e.g., `pump_item.dart`)

**Directories:**
- Plural nouns: `screens/`, `providers/`, `services/`, `models/`, `widgets/`
- Subdirectories group related functionality: `services/strategies/`

**Classes:**
- PascalCase: `BinanceApiService`, `PumpDetector`, `KlineProvider`

**Functions/Variables:**
- camelCase: `loadKlines()`, `calculateIndicators()`, `_priceHistory`

**Private members:**
- Underscore prefix: `_priceHistory`, `_calculateIndicators()`, `_config`

**Constants:**
- camelCase or UPPER_CASE: `baseThreshold`, `MAX_THRESHOLD`

## Where to Add New Code

**New Feature (Screens):**
- Primary code: `lib/screens/[feature]_screen.dart`
- Related widgets: `lib/widgets/[feature]_[widget].dart`

**New Feature (Business Logic):**
- Service implementation: `lib/services/[feature]_service.dart`
- Provider (if state needed): `lib/providers/[feature]_provider.dart`

**New API Integration:**
- Service: `lib/services/[api_name]_service.dart`
- Models: `lib/models/[entity]_model.dart`

**New Data Model:**
- Model definition: `lib/models/[entity]_model.dart`
- Repository (if persistence): `lib/services/[entity]_repository.dart`

**New UI Component:**
- Reusable widget: `lib/widgets/[component]_widget.dart`
- Screen-specific widget: In same file as screen or as private widget

**New Detection Strategy:**
- Strategy implementation: `lib/services/strategies/[strategy]_strategy.dart`
- Must implement `PumpDetectionStrategy` interface

**New Provider:**
- State provider: `lib/providers/[feature]_provider.dart`
- Register in `lib/main.dart` MultiProvider

**Utility Functions:**
- Helper functions: `lib/utils/[purpose].dart`

**Background Tasks:**
- Background service: `lib/services/[task]_background_service.dart`
- Configure initialization in `lib/main.dart`

## Special Directories

**android/:**
- Purpose: Android platform-specific code and configuration
- Generated: Partially (build artifacts in `build/`)
- Committed: Yes (source files)
- Contains: AndroidManifest.xml, gradle files, Kotlin/Java code

**build/:**
- Purpose: Flutter build output directory
- Generated: Yes (entirely)
- Committed: No (in .gitignore)

**.dart_tool/:**
- Purpose: Dart build tools cache
- Generated: Yes (entirely)
- Committed: No (in .gitignore)

**.gradle/ (in android/):**
- Purpose: Gradle cache
- Generated: Yes (entirely)
- Committed: No (in .gitignore)

**.planning/:**
- Purpose: GSD planning documents and codebase analysis
- Generated: Yes (by GSD tools)
- Committed: Yes (for project tracking)

**design-system/:**
- Purpose: Design system resources and documentation
- Generated: No
- Committed: Yes

**docs/:**
- Purpose: Project documentation
- Generated: No
- Committed: Yes

**.worktrees/:
- Purpose: Git worktrees for parallel development
- Generated: Yes (by git worktree commands)
- Committed: No (in .gitignore)

---

*Structure analysis: 2026/06/19*
