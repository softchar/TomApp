<!-- refreshed: 2026/06/19 -->
# Architecture

**Analysis Date:** 2026/06/19

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                   UI Layer (Screens & Widgets)                │
├──────────────────┬──────────────────┬───────────────────────┤
│   MainNavigation │   HomeScreen     │    FundingScreen      │
│  `lib/screens/   │  `lib/screens/   │   `lib/screens/       │
│   main_navigation│   home_screen    │   funding_screen      │
│   .dart`         │   .dart`         │   .dart`              │
├──────────────────┼──────────────────┼───────────────────────┤
│   PumpScreen     │   KlineScreen    │    ProfileScreen      │
│  `lib/screens/   │  `lib/screens/   │   `lib/screens/       │
│   pump_screen    │   kline_screen   │   profile_screen      │
│   .dart`         │   .dart`         │   .dart`              │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Provider Layer (State Management)          │
│         `lib/providers/`                                    │
├──────────────────┬──────────────────┬───────────────────────┤
│ FundingRateProvider│ KlineProvider  │  PumpListProvider      │
│ `lib/providers/  │ `lib/providers/│ `lib/providers/        │
│  funding_rate_    │  kline_provider │  pump_list_provider   │
│  provider.dart`   │  .dart`         │  .dart`               │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Service Layer (Business Logic)             │
│         `lib/services/`                                      │
├──────────────────┬──────────────────┬───────────────────────┤
│ BinanceApiService│ PumpDetector     │  ContractSyncService   │
│ `lib/services/   │ `lib/services/   │ `lib/services/        │
│  binance_api_    │  pump_detector   │  contract_sync_       │
│  service.dart`   │  .dart`          │  service.dart`        │
├──────────────────┼──────────────────┼───────────────────────┤
│ WebSocketManager │ RepositoryFactory│  ThemeProvider        │
│ `lib/services/   │ `lib/services/   │ `lib/services/        │
│  binance_        │  pump_repository │  theme_provider       │
│  websocket_      │  .dart`          │  .dart`               │
│  manager.dart`   │                  │                       │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Data Layer (Models & Storage)               │
├──────────────────┬──────────────────┬───────────────────────┤
│   SQLite DB      │   SharedPrefs    │    Binance API         │
│  DatabaseHelper  │  FavoriteService│  External Websocket    │
│ `lib/services/   │ `lib/services/   │                       │
│  database_       │  favorite_       │                       │
│  helper.dart`    │  service.dart`   │                       │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| **MainNavigation** | Bottom navigation bar, screen routing | `lib/screens/main_navigation.dart` |
| **HomeScreen** | Market overview, top gainers, recent pumps | `lib/screens/home_screen.dart` |
| **FundingScreen** | Funding rate display, notifications | `lib/screens/funding_screen.dart` |
| **PumpScreen** | Pump detection history, analytics | `lib/screens/pump_screen.dart` |
| **KlineScreen** | K-line chart, technical indicators | `lib/screens/kline_screen.dart` |
| **ProfileScreen** | Settings, theme, configuration | `lib/screens/profile_screen.dart` |
| **FundingRateProvider** | Funding rate state, periodic updates | `lib/services/funding_rate_provider.dart` |
| **KlineProvider** | K-line data, caching, websocket | `lib/providers/kline_provider.dart` |
| **PumpListProvider** | Pump history, statistics display | `lib/providers/pump_list_provider.dart` |
| **BinanceApiService** | REST API calls, rate limiting | `lib/services/binance_api_service.dart` |
| **WebSocketManager** | WebSocket connections, reconnection | `lib/services/binance_websocket_manager.dart` |
| **PumpDetector** | Price change detection, strategies | `lib/services/pump_detector.dart` |
| **ContractSyncService** | Contract metadata synchronization | `lib/services/contract_sync_service.dart` |
| **PumpRepository** | Pump data persistence, statistics | `lib/services/pump_repository.dart` |
| **DatabaseHelper** | SQLite database initialization | `lib/services/database_helper.dart` |

## Pattern Overview

**Overall:** Provider-based state management with layered architecture

**Key Characteristics:**
- **Provider Pattern**: State management via ChangeNotifier
- **Repository Pattern**: Data access abstraction (PumpRepository)
- **Strategy Pattern**: Pluggable detection strategies
- **Singleton Pattern**: Service instances (DatabaseHelper, ExchangeInfoService)
- **Observer Pattern**: Provider listeners for UI updates

## Layers

**UI Layer (lib/screens/ & lib/widgets/):**
- Purpose: Display data, handle user interaction, navigation
- Location: `lib/screens/`, `lib/widgets/`
- Contains: StatefulWidget, StatelessWidget, UI components
- Depends on: Providers layer for state, Services for business logic
- Used by: Flutter framework

**Provider Layer (lib/providers/):**
- Purpose: State management, data caching, event handling
- Location: `lib/providers/`
- Contains: ChangeNotifier classes, state models
- Depends on: Services layer for data operations
- Used by: UI layer for reactive updates

**Service Layer (lib/services/):**
- Purpose: Business logic, API communication, data processing
- Location: `lib/services/`
- Contains: API clients, background services, algorithms
- Depends on: Data layer for persistence, external APIs
- Used by: Provider layer, background services

**Data Layer (lib/models/ & lib/services/database_helper.dart):**
- Purpose: Data models, persistence, caching
- Location: `lib/models/`, SQLite database, SharedPreferences
- Contains: Data classes, repository implementations
- Depends on: Flutter storage APIs, Binance API
- Used by: Service layer

## Data Flow

### Primary Request Path (Home Screen Data Loading)

1. **App initialization** (`lib/main.dart:265`)
   - Initialize services (FavoriteService, ContractSyncSettings, PumpBackgroundService)
   - Configure Provider tree with all providers

2. **MainNavigation loads screens** (`lib/screens/main_navigation.dart:37`)
   - Initialize funding rate updates on first frame
   - Start contract sync if enabled

3. **HomeScreen requests data** (`lib/screens/home_screen.dart:27`)
   - MarketOverviewProvider.refresh() calls Binance API
   - PumpListProvider loads from repository

4. **Data transformation** (`lib/providers/market_overview_provider.dart`)
   - Parse 24h ticker data
   - Sort and filter top gainers

5. **UI updates** via Provider ChangeNotifier.notifyListeners()

### Real-time K-line Update Flow

1. **WebSocket connection** (`lib/services/kline_websocket_service.dart`)
   - Connect to Binance WebSocket stream
   - Subscribe to symbol kline updates

2. **Data processing** (`lib/providers/kline_provider.dart:268`)
   - Parse incoming KlineData
   - Update or append to data list

3. **Indicator calculation** (`lib/providers/kline_provider.dart:122`)
   - Recalculate MA, BOLL, MACD indicators
   - Merge with kline data

4. **UI reactive update** via notifyListeners()

**State Management:**
- Provider pattern with ChangeNotifier
- Local state in StatefulWidget for UI-specific state
- Global services as singletons (DatabaseHelper, ExchangeInfoService)

## Key Abstractions

**PumpDetectionStrategy:**
- Purpose: Pluggable threshold adjustment algorithms
- Examples: `lib/services/strategies/time_based_strategy.dart`, `lib/services/strategies/adaptive_strategy.dart`
- Pattern: Strategy pattern for extensibility

**PumpRepository:**
- Purpose: Data persistence abstraction with fallback
- Examples: `lib/services/pump_repository.dart` (SqlitePumpRepository, MemoryPumpRepository)
- Pattern: Repository pattern with factory method

**BinanceApiService:**
- Purpose: REST API communication with fallback URLs
- Examples: `lib/services/binance_api_service.dart`
- Pattern: Singleton with configurable base URL

**KlineProvider:**
- Purpose: K-line data management with caching and realtime updates
- Examples: `lib/providers/kline_provider.dart`
- Pattern: State management with layered caching (cache → API → WebSocket)

## Entry Points

**main():**
- Location: `lib/main.dart:265`
- Triggers: Application launch
- Responsibilities:
  - Initialize Flutter bindings
  - Configure API base URL
  - Initialize services (favorites, contract sync, background pump detection)
  - Start background pump detection service
  - Build provider tree and run app

**callbackDispatcher():**
- Location: `lib/main.dart:111`
- Triggers: Background service initialization
- Responsibilities:
  - Initialize notification system
  - Set up foreground service for Android
  - Initialize pump detection with price polling
  - Periodically check for pumps and send notifications

**MainNavigation:**
- Location: `lib/screens/main_navigation.dart:15`
- Triggers: App launch, navigation
- Responsibilities:
  - Manage bottom navigation bar
  - Switch between screens using IndexedStack
  - Initialize auto-update services

## Architectural Constraints

- **Threading:** Single-threaded Dart event loop with async/await for I/O operations
- **Global state:**
  - Services: DatabaseHelper (singleton), ExchangeInfoService (singleton)
  - Navigation: AppNavigation.navigatorKey (global key)
- **Circular imports:** Minimal risk due to clear layer separation
- **Background execution:** Limited to Android foreground service via flutter_background_service

## Anti-Patterns

### State Management in UI

**What happens:** Direct service calls in widgets without provider
**Why it's wrong:** Violates single direction of data flow, makes testing difficult
**Do this instead:** Access services through providers (`lib/screens/home_screen.dart:27`)

### Direct Database Access

**What happens:** Direct DatabaseHelper calls in UI code
**Why it's wrong:** Couples UI to persistence implementation
**Do this instead:** Use repository pattern (`lib/services/pump_repository.dart`)

### Hard-coded API URLs

**What happens:** API URLs scattered in code
**Why it's wrong:** Makes proxy configuration difficult
**Do this instead:** Centralized API service with configurable base URL (`lib/services/binance_api_service.dart:31`)

## Error Handling

**Strategy:** Try-catch with user-friendly messages

**Patterns:**
- Service layer: Return null or throw exceptions (`lib/providers/kline_provider.dart:114`)
- UI layer: Display error states in widgets
- Logging: debugPrint for development

## Cross-Cutting Concerns

**Logging:** debugPrint for development logging, no structured logging framework

**Validation:** Input validation in text fields, API response validation

**Authentication:** Not applicable (public Binance API)

**Configuration:** SharedPreferences for settings, pump configuration service

**Background Processing:** flutter_background_service for Android, periodic polling

---

*Architecture analysis: 2026/06/19*
