# External Integrations

**Analysis Date:** 2026/06/19

## APIs & External Services

**Cryptocurrency Exchange Data:**
- Binance Futures API - Real-time and historical market data
  - SDK/Client: Custom `BinanceApiService` (lib/services/binance_api_service.dart)
  - Auth: No authentication required for public endpoints
  - Endpoints: 
    - `/fapi/v1/premiumIndex` - Funding rates and mark prices
    - `/fapi/v1/fundingInfo` - Funding interval information
    - `/futures/data/topLongShortAccountRatio` - Long/short ratios
    - `/fapi/v1/ticker/price` - Real-time price data
  - WebSocket: Real-time market data streams
    - `BinanceWebSocketManager` (lib/services/binance_websocket_manager.dart)
    - `KlineWebSocketService` (lib/services/kline_websocket_service.dart)
  - Configuration: Proxy support via `BinanceApiService.setCustomBaseUrl()`
  - Rate limiting: Custom timeout handling (30s for REST, 2s polling for background)

## Data Storage

**Databases:**
- SQLite - Local persistent storage
  - Connection: `DatabaseHelper` (lib/services/database_helper.dart)
  - Client: sqflite 2.3.0 package
  - Database file: `tomapp.db` (version 3)
  - Tables: 
    - `PumpHistory` - Detected pump events with pullback analysis
    - `futures_symbols` - Cached contract information
    - Indexes on symbol, triggerTime, and confirmation status

**File Storage:**
- Local filesystem only - No cloud storage integration
- Shared preferences for user settings and favorites

**Caching:**
- SharedPreferences - User preferences and favorite symbols
- SQLite database - Historical pump data and contract information
- In-memory caching - `KlineCacheService` for chart data

## Authentication & Identity

**Auth Provider:**
- None (Custom) - No user authentication system
- Implementation: Local data only, no cloud sync
- User preferences stored locally on device

## Monitoring & Observability

**Error Tracking:**
- None - No crash reporting or error tracking service
- Basic debug logging via `debugPrint()`

**Logs:**
- Console logging only - `debugPrint()` for development
- No centralized logging service
- Background service logs tagged with 🔧 emoji for filtering

## CI/CD & Deployment

**Hosting:**
- None - Local development and manual APK distribution
- GitHub Actions for build automation only

**CI Pipeline:**
- GitHub Actions - `.github/workflows/main.yml`
  - Triggers: Push to main, pull requests, manual workflow dispatch
  - Build environment: Ubuntu-latest with Flutter 3.27.1
  - Java 17 (Temurin distribution) for Android build
  - Artifact retention: 7 days
  - Output: Split-per-abi APK files

## Environment Configuration

**Required env vars:**
- None - Environment configuration handled through code
- Optional proxy configuration for Binance API access:
  ```dart
  BinanceApiService.setCustomBaseUrl('https://your-proxy.com/api');
  ```

**Secrets location:**
- No secrets management system
- No API keys required for public Binance endpoints
- Build signing uses debug keys (not production-ready)

## Webhooks & Callbacks

**Incoming:**
- None - No webhook receivers

**Outgoing:**
- None - No outbound webhooks
- Polling-based architecture for background monitoring

## Background Services

**Android Background Execution:**
- flutter_background_service 5.0.10 - Native Android background service
- Implementation: `PumpBackgroundService` (lib/services/pump_background_service.dart)
- Entry point: `callbackDispatcher()` top-level function in `main.dart`
- Foreground service with notification
- 2-second polling interval for price monitoring
- 5-cycle (~2.5 minute) interval for pullback analysis

**Local Notifications:**
- flutter_local_notifications 17.2.3 - Alert system
- Channel: `pump_alerts` for rapid price increases
- High priority notifications for pump detection

## Third-Party Services

**Charting Libraries:**
- fl_chart 0.65.0 - General-purpose charting
- flutter_chen_kchart 2.0.4 - Specialized candlestick charts
- Custom technical indicators: `TechnicalIndicators` (lib/services/technical_indicators.dart)

**Development Tools:**
- mockito 5.4.0 - Test mocking
- build_runner 2.4.0 - Code generation
- flutter_lints 3.0.0 - Static analysis

---

*Integration audit: 2026/06/19*