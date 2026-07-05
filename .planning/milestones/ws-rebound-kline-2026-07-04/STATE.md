# Workstream: rebound-kline

## Status: ✅ Complete

## Objective
扩展合约反弹监控为多周期：增加 1h / 4h / 1d K线监控（原仅 15m）。

## Changes
| File | Change |
|------|--------|
| `lib/services/rebound/rebound_timeframes.dart` | `monitoredTimeframes` 从 `['15m']` → `['15m', '1h', '4h', '1d']` |
| `test/services/rebound_market_scanner_test.dart` | Test 1 更新为 1600 请求 × 4 TF 断言 |

## Architecture Note
整个代码库已为多周期做好准备，无需其他修改：
- `ReboundParams` 已有 `dropMinPct1h/4h/1d` 阈值
- `ReboundKlineStreamService._intervalDuration` 已支持 `1h/4h/1d`
- `AlertSettingsProvider.load()` 动态遍历 `monitoredTimeframes`
- UI 设置页动态渲染 TF 开关列表
- `ReboundConfluenceScorer.scoreMultiTimeframe` 已实现跨周期共振加分

## Rate Limit Budget
- 400 symbols × 4 TFs = 1600 requests/round
- limit=99 → weight=1 per request → 1600 weight/min
- Binance limit: 2400/min → 33% headroom preserved

## Tests
- 135 tests passed (1 pre-existing failure: trade_simulator floating point precision)
- 0 new test failures
