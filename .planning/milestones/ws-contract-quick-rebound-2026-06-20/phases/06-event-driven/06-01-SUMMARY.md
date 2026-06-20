---
phase: 06-event-driven
plan: 01
type: execute
tags: [backtest, domain-models, data-import, funding-rate, drift]
status: complete

requires:
  - phase/02-i-o (ReboundDetector.evaluate 纯函数)
  - phase/01-indicators (drift Klines 表 schema)
provides:
  - BacktestConfig/BacktestReport/BacktestTrade/BacktestStatus/FundingRate/Position 模型
  - DataImportService (data.binance.vision ZIP → drift Klines)
  - FundingRateService (Binance REST 分页 + 本地缓存)
  - test_fixtures.dart (syntheticKlines/vShapedRecovery/mockFundingRates)
affects:
  - phase/06-02 (回测引擎消费这些模型 + test fixtures)
  - phase/06-03 (回测 UI 消费 BacktestReport)

tech-stack:
  added:
    - archive 4.0.2 (ZIP 解压，已安装)
    - http 1.1.0 (HTTP 下载 + REST 调用，已安装)
  patterns:
    - 不可变数据类 (final + const 构造器 + copyWith)
    - fromJson/toJson 序列化 (ISO 8601 日期 + drift JSON 兼容)
    - fromFundingRateEndpoint factory (Binance REST 响应解析)
    - 时间戳标准化 (≤13位毫秒 / >13位微秒→毫秒)
    - Drift batch insert + InsertMode.insertOrIgnore 去重
    - Mock HTTP client 注入测试 (httpClient 可选参数)

key-files:
  created:
    - lib/models/backtest_config.dart
    - lib/models/backtest_report.dart
    - lib/models/backtest_trade.dart
    - lib/models/backtest_status.dart
    - lib/models/position.dart
    - lib/services/rebound/data_import_service.dart
    - lib/services/rebound/funding_rate_service.dart
    - test/services/rebound/test_fixtures.dart
    - test/services/rebound/data_import_test.dart
  modified:
    - lib/models/funding_rate.dart (添加 ==/hashCode + fromFundingRateEndpoint factory)

decisions:
  - "FundingRate 重用现有类——添加 fromFundingRateEndpoint factory + ==/hashCode 覆盖，保留所有现有字段和构造器以保证向后兼容（实时行情展示不受影响）"
  - "DataImportService._parseCsv 公开为 parseCsvForTest (@visibleForTesting) 以便单元测试时间戳标准化和容错逻辑"
  - "FundingRateService HTTP 客户端可注入 (httpClient 可选参数) 以便测试 mock 分页行为"
  - "ZIP 响应体 200MB 上限 + entry.name 防路径遍历——对齐 threat register T-06-02"

metrics:
  duration: 11min
  tasks: 3
  files: 9 total (8 created + 1 modified)
  completed_date: 2026-06-20

deviations: null
---

# Phase 6 Plan 1: 回测数据基础层 Summary

**One-liner:** 构建 6 个回测领域模型、历史 K 线数据导入管线（data.binance.vision ZIP → drift Klines）、资金费率历史 REST 拉取与缓存——为回测引擎(06-02)和回测UI(06-03)提供类型安全的数据层。

## Tasks Executed

### Task 1: 回测领域模型 (TDD)
- **RED** (ac895a2): `test/services/rebound/test_fixtures.dart` — syntheticKlines、vShapedRecovery、mockFundingRates 共享测试 fixtures
- **GREEN** (558d19f): 6 个模型文件 — BacktestConfig、BacktestReport、BacktestTrade、BacktestStatus、Position、FundingRate 增强
- **Verify:** `flutter analyze` 零 error，13 条 acceptance criteria 全部满足

### Task 2: DataImportService (TDD)
- **RED** (6859ff1): `test/services/rebound/data_import_test.dart` — CSV 解析（毫秒/微秒时间戳、空行/畸形行容错）、symbol 校验
- **GREEN** (c96b4ba): `lib/services/rebound/data_import_service.dart` — downloadMonth + importHistoricalData + gapFill + fetchTopSymbols
- **Verify:** 9 个测试全部通过，CSV 解析正确、畸形行跳过不崩溃、symbol 格式校验生效

### Task 3: FundingRateService
- (3b938a0): `lib/services/rebound/funding_rate_service.dart` + 测试扩展 — 分页拉取 + 本地缓存 + getRate 按时戳查询 + prefetch 批量预加载
- **Verify:** 4 个新增测试（缓存查找、自动拉取、缓存命中、分页）全部通过，共 13 个测试全绿

## Verification Results

```
flutter analyze: No issues found! (8 files, 0 errors)

flutter test test/services/rebound/data_import_test.dart:
  00:03 +13: All tests passed!
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] FundingRate 类名冲突——现有类被 10 个文件使用**
- **Found during:** Task 1
- **Issue:** 计划要求创建简化的 FundingRate（symbol/rate/fundingTime），但项目已有同名的 FundingRate 类（含 markPrice/indexPrice 等字段），被 10 个文件引用。直接替换会破坏实时行情功能。
- **Fix:** 保留现有 FundingRate 类全部字段和构造器不变，仅添加：(1) `==` 和 `hashCode` 覆盖基于 symbol + fundingTime；(2) `fromFundingRateEndpoint` factory 解析 `/fapi/v1/fundingRate` 响应。向后兼容，实时行情和回测均可使用。
- **Files modified:** `lib/models/funding_rate.dart`
- **Commit:** 558d19f

**2. [Rule 3 - Blocking] Drift batch API 不匹配**
- **Found during:** Task 2
- **Issue:** 计划使用 `insertAllOnConflictUpdate`，但 drift 2.19 batch API 使用 `insertAll` + `mode: InsertMode.insertOrIgnore`。
- **Fix:** 统一使用 `batch.insertAll(table, rows, mode: InsertMode.insertOrIgnore)` 实现去重写入。
- **Files modified:** `lib/services/rebound/data_import_service.dart`
- **Commit:** c96b4ba

**3. [Rule 3 - Blocking] archive 4.0.2 API——csvFile.readBytes() 返回 Uint8List? 类型不匹配**
- **Found during:** Task 2
- **Issue:** `utf8.decode()` 需要 `List<int>`，`readBytes()` 返回 `Uint8List?`。
- **Fix:** 改用 `csvFile.content`（`List<int>` 类型）。
- **Files modified:** `lib/services/rebound/data_import_service.dart`
- **Commit:** c96b4ba

**4. [Rule 3 - Blocking] `@visibleForTesting` 未导入**
- **Found during:** Task 2
- **Issue:** `@visibleForTesting` 注解需要 `package:flutter/foundation.dart`。
- **Fix:** 添加 `import 'package:flutter/foundation.dart' show visibleForTesting;`。
- **Files modified:** `lib/services/rebound/data_import_service.dart`
- **Commit:** c96b4ba

## Threat Flags

无新增威胁面。威胁缓解均已落实：
- **T-06-01** (HTTPS 传输): downloadMonth 使用 https:// URL + http.get
- **T-06-02** (ZIP bomb): `_maxZipBytes = 200MB` 大小检查 + `entry.name` 防路径遍历（非 `entry.fullPathName`）
- **T-06-03** (日期范围): BacktestConfig.fromJson 校验 startDate>=2020-01-01、endDate<=today、范围≤365天、symbols≤100

## Self-Check: PASSED

- [x] 所有 6 个模型文件存在且通过 analyze
- [x] DataImportService 存在且测试通过
- [x] FundingRateService 存在且测试通过
- [x] test_fixtures.dart 存在且通过 analyze
- [x] data_import_test.dart 13 个测试全部通过
- [x] 所有 commits 存在：ac895a2, 558d19f, 6859ff1, c96b4ba, 3b938a0
