/// 反弹监控的运行时周期配置——单一真源（per 04-03 决策 D8）。
///
/// 2026-06-20 范围调整：收缩为仅 15m 单周期，降低全市场扫描负载先跑通。
/// 多周期架构（ReboundSignal.timeframe 字段 / 各周期参数 /
/// ReboundConfluenceScorer 共振评分器 / Provider 多 TF map）全部保留，
/// 仅运行时启用的周期由此常量决定。
///
/// 未来恢复多周期（1h/4h/1d）只需改这一行，例如：
///   const monitoredTimeframes = ['15m', '1h', '4h', '1d'];
///
/// 消费方：ReboundMarketScanner（默认扫描周期）、
/// ReboundAlertService（默认监控 / 精跟 / warm-up 周期）。
const List<String> monitoredTimeframes = ['15m'];
