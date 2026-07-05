import 'package:flutter/material.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/services/test/test_orchestrator.dart';
import 'package:tomapp/services/theme_provider.dart';
import 'package:tomapp/widgets/flchart_kline_widget.dart';
import 'package:tomapp/models/alert_level.dart';
import 'package:tomapp/services/rebound/rebound_notification_service.dart';

/// 反弹检测测试调试页面。
///
/// 上半部分 CandlestickChart 展示最近 50 根 K 线（下跌段红色、拉回段绿色），
/// 下半部分展示检测命中的信号列表（命中由 detector 三阶段门槛决定，与监控页对齐），
/// 顶部控制栏支持开始/暂停、模式切换、参数调整。
class ReboundTestScreen extends StatefulWidget {
  const ReboundTestScreen({super.key});

  @override
  State<ReboundTestScreen> createState() => _ReboundTestScreenState();
}

class _ReboundTestScreenState extends State<ReboundTestScreen> {
  late TestOrchestrator _orchestrator;
  late ReboundParams _params;
  ReboundSignal? _selectedSignal;
  bool _showDebugPanel = false;

  // ── 本地通知（测试页：检测到强反弹信号 → 发手机通知）──
  final ReboundNotificationService _notifService =
      ReboundNotificationService();
  bool _notifReady = false;
  int? _lastNotifiedSignalTs; // 去重：同一信号（按 timestamp）只通知一次
  DateTime? _lastNotifiedAt; // 节流：距上次通知 ≥ 8 秒
  static const int _notifScoreThreshold = 70;

  @override
  void initState() {
    super.initState();
    _params = const ReboundParams();
    _orchestrator = TestOrchestrator(
      generator: TestDataGenerator(mode: SimulationMode.vRebound, seed: 42),
      detector: ReboundDetector(TechnicalIndicators()),
      params: _params,
    );
    _orchestrator.addListener(_onUpdate);
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      await _notifService.initialize();
      _notifReady = true;
    } catch (e) {
      debugPrint('通知初始化失败: $e');
    }
  }

  void _onUpdate() {
    setState(() {});
    _maybeNotify();
  }

  /// 检测到强反弹信号 → 发本地通知（带去重 + 节流，避免刷屏）。
  Future<void> _maybeNotify() async {
    if (!_notifReady) return;
    final signals = _orchestrator.signals;
    if (signals.isEmpty) return;
    final latest = signals.first;
    if (latest.score < _notifScoreThreshold) return;

    final ts = latest.timestamp.millisecondsSinceEpoch;
    if (ts == _lastNotifiedSignalTs) return; // 同一信号已通知
    final now = DateTime.now();
    if (_lastNotifiedAt != null &&
        now.difference(_lastNotifiedAt!) < const Duration(seconds: 8)) {
      return; // 节流：8 秒内不重复打扰
    }
    _lastNotifiedSignalTs = ts;
    _lastNotifiedAt = now;

    // 分级：高分 + 低死猫风险 → high（响铃+震动）；否则 medium（横幅）
    final level = (latest.score >= 75 && latest.deadCatRiskScore < 50)
        ? AlertLevel.high
        : AlertLevel.medium;
    await _notifService.dispatch(AlertDecision(
      symbol: latest.symbol,
      level: level,
      signal: latest,
      coalescedTimeframes: [latest.timeframe],
      createdAt: now,
    ));
  }

  /// 手动触发一条测试通知（验证通知权限/渠道/震动是否生效，不依赖信号）。
  Future<void> _testNotify() async {
    if (!_notifReady) {
      await _initNotifications();
    }
    final now = DateTime.now();
    await _notifService.dispatch(AlertDecision(
      symbol: 'TESTNOTIFY',
      level: AlertLevel.high,
      signal: ReboundSignal(
        symbol: 'TESTNOTIFY',
        timeframe: '15m',
        dropMagnitude: 3.0,
        recoveryRatio: 0.8,
        speed: 2,
        confluenceFilters: const {},
        score: 85,
        deadCatRiskScore: 10,
        entryPrice: 100,
        swingLowPrice: 90,
        swingHighPrice: 100,
        dropStartIndex: 0,
        dropEndIndex: 2,
        recoveryEndIndex: 4,
        timestamp: now,
      ),
      coalescedTimeframes: const ['15m'],
      createdAt: now,
    ));
  }

  @override
  void dispose() {
    _orchestrator.removeListener(_onUpdate);
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('反弹检测测试'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        actions: [
          IconButton(
            icon: Icon(
              _showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugPanel ? AppColors.warning : AppColors.onBackground,
            ),
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
            tooltip: '调试面板',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlBar(),
          if (_orchestrator.window.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '点击开始按钮启动测试',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            Expanded(flex: 3, child: _buildFlChart()),
            if (_showDebugPanel) _buildDebugPanel(),
            Expanded(flex: 1, child: _buildSignalList()),
          ],
        ],
      ),
    );
  }

  /// 控制栏：第一行播放/暂停+模式+刷新，第二行参数 Slider。
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      color: AppColors.surface,
      child: Column(
        children: [
          // 第一行：播放/暂停、模式切换、刷新
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _orchestrator.isRunning ? Icons.pause : Icons.play_arrow,
                  color: AppColors.onBackground,
                ),
                onPressed: () {
                  if (_orchestrator.isRunning) {
                    _orchestrator.pause();
                  } else {
                    _orchestrator.start();
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<SimulationMode>(
                value: _currentMode,
                dropdownColor: AppColors.surfaceVariant,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: SimulationMode.vRebound,
                    child: Text('V 型反弹'),
                  ),
                  DropdownMenuItem(
                    value: SimulationMode.deadCatBounce,
                    child: Text('死猫反弹'),
                  ),
                  DropdownMenuItem(
                    value: SimulationMode.randomWalk,
                    child: Text('随机游走'),
                  ),
                  DropdownMenuItem(
                    value: SimulationMode.steadyDecline,
                    child: Text('持续下跌'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    _orchestrator.changeMode(mode);
                    setState(() => _currentMode = mode);
                  }
                },
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.notifications_active,
                    color: AppColors.warning),
                onPressed: _testNotify,
                tooltip: '测试通知',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.onBackground),
                onPressed: () => _orchestrator.reset(),
              ),
            ],
          ),
          // 第二行：跌幅/回补/放量参数
          Row(
            children: [
              _buildSlider(
                label: '跌幅ATR',
                value: _params.dropAtrMultiplier,
                min: 0.5,
                max: 5.0,
                divisions: 9,
                onChanged: (v) {
                  setState(() {
                    _params = _params.copyWith(dropAtrMultiplier: v);
                    _orchestrator.changeParams(_params);
                  });
                },
              ),
              _buildSlider(
                label: '回补比例',
                value: _params.recoveryMinRatio,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                onChanged: (v) {
                  setState(() {
                    _params = _params.copyWith(recoveryMinRatio: v);
                    _orchestrator.changeParams(_params);
                  });
                },
              ),
              _buildSlider(
                label: '放量倍数',
                value: _params.volumeMultiplier,
                min: 1.0,
                max: 5.0,
                divisions: 8,
                onChanged: (v) {
                  setState(() {
                    _params = _params.copyWith(volumeMultiplier: v);
                    _orchestrator.changeParams(_params);
                  });
                },
              ),
            ],
          ),
          // 第三行：下跌/回补 K 线数 + RSI 周期
          Row(
            children: [
              _buildIntSlider(
                label: '下跌K线',
                value: _params.dropMaxCandles,
                min: 2,
                max: 10,
                onChanged: (v) {
                  setState(() {
                    _params = _params.copyWith(dropMaxCandles: v);
                    _orchestrator.changeParams(_params);
                  });
                },
              ),
              _buildIntSlider(
                label: '回补K线',
                value: _params.recoveryMaxCandles,
                min: 1,
                max: 5,
                onChanged: (v) {
                  setState(() {
                    _params = _params.copyWith(recoveryMaxCandles: v);
                    _orchestrator.changeParams(_params);
                  });
                },
              ),
              _buildIntSlider(
                label: 'RSI周期',
                value: _params.rsiPeriod,
                min: 7,
                max: 21,
                onChanged: (v) {
                  setState(() {
                    _params = _params.copyWith(rsiPeriod: v);
                    _orchestrator.changeParams(_params);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  SimulationMode _currentMode = SimulationMode.vRebound;

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$label ${value.toStringAsFixed(1)}',
            style: AppTextStyles.bodySmall,
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.info,
            inactiveColor: AppColors.surfaceVariant,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildIntSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$label $value',
            style: AppTextStyles.bodySmall,
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: AppColors.warning,
            inactiveColor: AppColors.surfaceVariant,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  /// fl_chart（原生绘制）图表面板。数据用**全量 window**（可拖动看历史），
  /// 标记索引相对全量 window（activeSignal 产生时的 window，不做 displayWindow offset）。
  Widget _buildFlChart() {
    final window = _orchestrator.window;
    final activeSignal = _selectedSignal ??
        (_orchestrator.signals.isNotEmpty ? _orchestrator.signals.first : null);
    int? dropStart = activeSignal?.dropStartIndex;
    int? dropEnd = activeSignal?.dropEndIndex;
    int? recoveryEnd = activeSignal?.recoveryEndIndex;
    if (dropStart != null && dropStart < 0) dropStart = null;
    if (dropEnd != null && dropEnd < 0) dropEnd = null;
    if (recoveryEnd != null && recoveryEnd < 0) recoveryEnd = null;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Stack(
        children: [
          FlChartKlineWidget(
            data: window,
            dropStartIndex: dropStart,
            dropEndIndex: dropEnd,
            recoveryEndIndex: recoveryEnd,
          ),
        ],
      ),
    );
  }

  /// 信号列表：展示检测命中的信号（命中门槛与合约反弹监控页一致）。
  Widget _buildSignalList() {
    final signals = _orchestrator.signals;

    if (signals.isEmpty) {
      return Center(
        child: Text(
          '暂无高评分信号',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: signals.length,
      itemBuilder: (context, index) => _buildSignalRow(signals[index]),
    );
  }

  /// 单行信号卡片（点击跳转到对应 K 线位置）。
  Widget _buildSignalRow(ReboundSignal signal) {
    final isSelected = _selectedSignal == signal;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSignal = isSelected ? null : signal;
        });
      },
      child: Card(
        // 整体更亮、更显眼：非选中用蓝灰亮底 + 青色描边；选中蓝色高亮。
        color: isSelected ? AppColors.info.withAlpha(70) : AppColors.surface,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.primary.withAlpha(90),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
          child: Row(
            children: [
              // 评分徽章
              _ScoreBadge(score: signal.score),
              const SizedBox(width: AppSpacing.sm),
              // 信号详情
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        '${signal.dropMagnitude.toStringAsFixed(1)}×ATR',
                        style:
                            AppTextStyles.bodySmall.copyWith(color: AppColors.destructive),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '回补 ${(signal.recoveryRatio * 100).toStringAsFixed(0)}%',
                        style:
                            AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _DeadCatIndicator(score: signal.deadCatRiskScore),
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    // 共振过滤器标签
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final f in signal.confluenceFilters)
                          Chip(
                            label: Text(
                              _confluenceLabel(f),
                              style: AppTextStyles.bodySmall,
                            ),
                            backgroundColor: AppColors.surface,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs, vertical: 0),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 时间戳 + 跳转图标
              Column(
                children: [
                  Text(
                    '${signal.timestamp.hour}:${signal.timestamp.minute.toString().padLeft(2, '0')}:${signal.timestamp.second.toString().padLeft(2, '0')}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _confluenceLabel(ConfluenceType type) {
    switch (type) {
      case ConfluenceType.rsiOversoldTurning:
        return 'RSI拐头';
      case ConfluenceType.volumeConfirmation:
        return '放量确认';
      case ConfluenceType.atSupportLevel:
        return '支撑位';
      case ConfluenceType.bullishCandlePattern:
        return 'K线形态';
    }
  }

  /// 调试信息面板：显示当前检测器内部状态。
  Widget _buildDebugPanel() {
    final window = _orchestrator.window;
    final ti = TechnicalIndicators();

    // 计算当前 ATR
    double? currentAtr;
    if (window.length >= _params.atrPeriod) {
      currentAtr = ti.atr(window, period: _params.atrPeriod);
    }

    // 计算当前 RSI（标准 + 快速）
    double? stdRsi;
    double? fastRsi;
    if (window.length >= _params.rsiPeriod + 1) {
      stdRsi = ti.rsi(window, period: _params.rsiPeriod);
    }
    if (window.length >= _params.fastRsiPeriod + 1) {
      fastRsi = ti.rsi(window, period: _params.fastRsiPeriod);
    }

    // 找当前 swingLow
    int? swingLowIdx;
    double? swingLowPrice;
    if (window.length >= _params.swingLookback * 2 + 1) {
      swingLowIdx = ti.swingLow(window, lookback: _params.swingLookback);
      if (swingLowIdx != null) {
        swingLowPrice = window[swingLowIdx].low;
      }
    }

    // 最新信号的共振过滤器状态
    final latestSignal = _orchestrator.signals.isNotEmpty
        ? _orchestrator.signals.first
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔧 调试信息',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 指标行
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _DebugItem(
                label: 'ATR(${_params.atrPeriod})',
                value: currentAtr != null ? currentAtr.toStringAsFixed(4) : '--',
                color: AppColors.success,
              ),
              _DebugItem(
                label: 'RSI(${_params.rsiPeriod})',
                value: stdRsi != null ? stdRsi.toStringAsFixed(1) : '--',
                color: stdRsi != null && stdRsi < _params.rsiOversold
                    ? AppColors.destructive
                    : AppColors.success,
              ),
              _DebugItem(
                label: 'RSI(${_params.fastRsiPeriod})',
                value: fastRsi != null ? fastRsi.toStringAsFixed(1) : '--',
                color: fastRsi != null && fastRsi < _params.rsiOversold
                    ? AppColors.destructive
                    : AppColors.success,
              ),
              _DebugItem(
                label: 'swingLow',
                value: swingLowIdx != null
                    ? '#$swingLowIdx ${swingLowPrice?.toStringAsFixed(2)}'
                    : '--',
                color: AppColors.warning,
              ),
              _DebugItem(
                label: '窗口',
                value: '${window.length}/${TestOrchestrator.windowSize}',
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (latestSignal != null) ...[
            const Divider(color: AppColors.divider, height: AppSpacing.md),
            Text(
              '最新信号共振过滤器',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: ConfluenceType.values.map((type) {
                final passed = latestSignal.confluenceFilters.contains(type);
                return Chip(
                  label: Text(
                    _confluenceLabel(type),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: passed ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: passed ? AppColors.success : AppColors.surfaceVariant,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 0),
                  avatar: Icon(
                    passed ? Icons.check : Icons.close,
                    size: 14,
                    color: passed ? AppColors.onBackground : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// 调试信息单项。
class _DebugItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DebugItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(138),
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
            ),
            TextSpan(
              text: value,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 评分圆形徽章。
class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  Color get _bgColor {
    if (score >= 70) return const Color(0xFF2E7D32); // 深绿
    if (score >= 40) return const Color(0xFFF57F17); // 黄/橙
    return AppColors.textDisabled;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$score',
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 死猫反弹风险标注。
class _DeadCatIndicator extends StatelessWidget {
  final int score;

  const _DeadCatIndicator({required this.score});

  @override
  Widget build(BuildContext context) {
    if (score >= 70) {
      return const SizedBox(
        width: 32,
        child: Tooltip(
          message: '死猫反弹高风险',
          child: Icon(Icons.dangerous, color: AppColors.destructive, size: 18),
        ),
      );
    }
    if (score >= 40) {
      return const SizedBox(
        width: 32,
        child: Tooltip(
          message: '注意死猫风险',
          child:
              Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
        ),
      );
    }
    return const SizedBox(
      width: 32,
      child: Icon(Icons.check_circle_outline,
          color: AppColors.success, size: 18),
    );
  }
}
