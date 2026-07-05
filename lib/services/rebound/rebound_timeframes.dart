/// 反弹监控的运行时周期配置——单一真源（per 04-03 决策 D8）。
///
/// 2026-07-04 扩展为多周期：15m / 1h / 4h / 1d。
/// 15m 提供快速反应（60s 扫描间隔，每轮发现即时信号），
/// 1h/4h/1d 提供中期趋势验证，配合 ReboundConfluenceScorer 做跨周期共振评分。
///
/// 限流核算（Binance fapi weight，limit=99 → weight=1）：
///   400 symbols × 4 TFs = 1600 weight/轮
///   1600 / 60s ≈ 1600/min ≤ 2400/min 上限，保留 33% 余量。
///
/// 消费方：ReboundMarketScanner（默认扫描周期）、
/// ReboundAlertService（默认监控 / 精跟 / warm-up 周期）。
const List<String> monitoredTimeframes = ['15m', '1h', '4h', '1d'];
