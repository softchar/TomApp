/// 反弹检测器的全部可调阈值参数（不可变数据类）。
///
/// 所有默认值均为业务先验起步值，Phase 6 回测校准后可能调整。
/// 实例无状态，evaluate 纯函数接受此参数对象。
class ReboundParams {
  // ─── Stage 1：下跌段（drop leg）──────────────────────────
  /// 下跌幅度 ATR 倍数阈值（业务先验起步值 2.0，Phase 6 校准）
  final double dropAtrMultiplier;

  /// 下跌段最大 K 线数（业务先验起步值 3，Phase 6 校准）
  final int dropMaxCandles;

  /// 各周期跌幅 % 兜底（业务先验起步值，Phase 6 校准）
  final double dropMinPct15m; // 2.0
  final double dropMinPct1h; // 3.0
  final double dropMinPct4h; // 5.0
  final double dropMinPct1d; // 8.0

  // ─── Stage 2：拉回段（recovery leg）─────────────────────
  /// 拉回最低回补比例（业务先验起步值 0.5，Phase 6 校准）
  final double recoveryMinRatio;

  /// 拉回段最大 K 线数（业务先验起步值 2，Phase 6 校准）
  final int recoveryMaxCandles;

  // ─── Stage 3：共振过滤（confluence）────────────────────
  /// 放量阈值倍数（业务先验起步值 1.5，Phase 6 校准）
  final double volumeMultiplier;

  /// RSI 超卖阈值（业务先验起步值 30.0，Phase 6 校准）
  final double rsiOversold;

  /// RSI 周期（业务先验起步值 14，Phase 6 校准）
  final int rsiPeriod;

  /// ATR 周期（业务先验起步值 14，Phase 6 校准）
  final int atrPeriod;

  /// swing high/low 回看根数（业务先验起步值 2，Phase 6 校准）
  final int swingLookback;

  /// Fibonacci 水平（业务先验起步值，Phase 6 校准）
  final double fibLevel382; // 0.382
  final double fibLevel500; // 0.5
  final double fibLevel618; // 0.618

  // ─── 共振过滤器开关 ────────────────────────────────────
  /// 是否启用 RSI 超卖拐头共振（业务先验起步值 true，Phase 6 校准）
  final bool confluenceRsiOversoldTurning;

  /// 是否启用量能确认共振（业务先验起步值 true，Phase 6 校准）
  final bool confluenceVolumeConfirm;

  /// 是否启用支撑位共振（业务先验起步值 true，Phase 6 校准）
  final bool confluenceSupportLevel;

  /// 是否启用 K 线形态共振（业务先验起步值 true，Phase 6 校准）
  final bool confluenceCandlePattern;

  const ReboundParams({
    this.dropAtrMultiplier = 2.0,
    this.dropMaxCandles = 3,
    this.dropMinPct15m = 2.0,
    this.dropMinPct1h = 3.0,
    this.dropMinPct4h = 5.0,
    this.dropMinPct1d = 8.0,
    this.recoveryMinRatio = 0.5,
    this.recoveryMaxCandles = 2,
    this.volumeMultiplier = 1.5,
    this.rsiOversold = 30.0,
    this.rsiPeriod = 14,
    this.atrPeriod = 14,
    this.swingLookback = 2,
    this.fibLevel382 = 0.382,
    this.fibLevel500 = 0.5,
    this.fibLevel618 = 0.618,
    this.confluenceRsiOversoldTurning = true,
    this.confluenceVolumeConfirm = true,
    this.confluenceSupportLevel = true,
    this.confluenceCandlePattern = true,
  });

  /// 不可变副本，支持覆盖任意字段。
  ReboundParams copyWith({
    double? dropAtrMultiplier,
    int? dropMaxCandles,
    double? dropMinPct15m,
    double? dropMinPct1h,
    double? dropMinPct4h,
    double? dropMinPct1d,
    double? recoveryMinRatio,
    int? recoveryMaxCandles,
    double? volumeMultiplier,
    double? rsiOversold,
    int? rsiPeriod,
    int? atrPeriod,
    int? swingLookback,
    double? fibLevel382,
    double? fibLevel500,
    double? fibLevel618,
    bool? confluenceRsiOversoldTurning,
    bool? confluenceVolumeConfirm,
    bool? confluenceSupportLevel,
    bool? confluenceCandlePattern,
  }) {
    return ReboundParams(
      dropAtrMultiplier: dropAtrMultiplier ?? this.dropAtrMultiplier,
      dropMaxCandles: dropMaxCandles ?? this.dropMaxCandles,
      dropMinPct15m: dropMinPct15m ?? this.dropMinPct15m,
      dropMinPct1h: dropMinPct1h ?? this.dropMinPct1h,
      dropMinPct4h: dropMinPct4h ?? this.dropMinPct4h,
      dropMinPct1d: dropMinPct1d ?? this.dropMinPct1d,
      recoveryMinRatio: recoveryMinRatio ?? this.recoveryMinRatio,
      recoveryMaxCandles: recoveryMaxCandles ?? this.recoveryMaxCandles,
      volumeMultiplier: volumeMultiplier ?? this.volumeMultiplier,
      rsiOversold: rsiOversold ?? this.rsiOversold,
      rsiPeriod: rsiPeriod ?? this.rsiPeriod,
      atrPeriod: atrPeriod ?? this.atrPeriod,
      swingLookback: swingLookback ?? this.swingLookback,
      fibLevel382: fibLevel382 ?? this.fibLevel382,
      fibLevel500: fibLevel500 ?? this.fibLevel500,
      fibLevel618: fibLevel618 ?? this.fibLevel618,
      confluenceRsiOversoldTurning:
          confluenceRsiOversoldTurning ?? this.confluenceRsiOversoldTurning,
      confluenceVolumeConfirm:
          confluenceVolumeConfirm ?? this.confluenceVolumeConfirm,
      confluenceSupportLevel:
          confluenceSupportLevel ?? this.confluenceSupportLevel,
      confluenceCandlePattern:
          confluenceCandlePattern ?? this.confluenceCandlePattern,
    );
  }

  /// ⚠️ 测试期宽松参数（仅用于 flutter run 快速观察反弹数据，正式使用前禁用）。
  ///
  /// 大幅降低下跌/拉回门槛 + 关闭全部共振过滤器，让小波动也能触发反弹，
  /// 方便前期调试看板 / 扫描链路。通过 `--dart-define=LOOSE_PARAMS=true` 启用
  /// （dashboard 据此环境变量切换）。正式阈值仍为默认构造值（Phase 6 回测校准）。
  static const looseForTesting = ReboundParams(
    dropAtrMultiplier: 1.0, // 原 2.0 — 跌幅 ≥ 1×ATR 即可
    dropMaxCandles: 5, // 原 3 — 允许更长下跌段
    dropMinPct15m: 0.3, // 原 2.0 — 15m 跌 0.3% 即触发
    dropMinPct1h: 0.5,
    dropMinPct4h: 1.0,
    dropMinPct1d: 2.0,
    recoveryMinRatio: 0.15, // 原 0.5 — 回补 15% 即可
    recoveryMaxCandles: 4, // 原 2
    confluenceRsiOversoldTurning: false, // 关闭共振过滤，减少过滤更易触发
    confluenceVolumeConfirm: false,
    confluenceSupportLevel: false,
    confluenceCandlePattern: false,
  );

  /// 根据周期标识（"15m"/"1h"/"4h"/"1d"）返回对应的 % 兜底阈值。
  double dropMinPctForTimeframe(String tf) {
    switch (tf) {
      case '15m':
        return dropMinPct15m;
      case '1h':
        return dropMinPct1h;
      case '4h':
        return dropMinPct4h;
      case '1d':
        return dropMinPct1d;
      default:
        return dropMinPct15m;
    }
  }
}
