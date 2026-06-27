import 'package:flutter/material.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/services/test/test_orchestrator.dart';
import 'package:tomapp/widgets/tradingview_kline_widget.dart';

/// 反弹检测测试调试页面。
///
/// 上半部分 CandlestickChart 展示最近 50 根 K 线（下跌段红色、拉回段绿色），
/// 下半部分展示 score >= 60 的信号列表，
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
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _orchestrator.removeListener(_onUpdate);
    _orchestrator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('反弹检测测试'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebugPanel ? Colors.yellow : Colors.white,
            ),
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
            tooltip: '调试面板',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlBar(),
          Expanded(flex: 3, child: _buildCandlestickChart()),
          if (_showDebugPanel) _buildDebugPanel(),
          Expanded(flex: 2, child: _buildSignalList()),
        ],
      ),
    );
  }

  /// 控制栏：第一行播放/暂停+模式+刷新，第二行参数 Slider。
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[900],
      child: Column(
        children: [
          // 第一行：播放/暂停、模式切换、刷新
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _orchestrator.isRunning ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_orchestrator.isRunning) {
                    _orchestrator.pause();
                  } else {
                    _orchestrator.start();
                  }
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<SimulationMode>(
                value: _currentMode,
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white, fontSize: 13),
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
                icon: const Icon(Icons.refresh, color: Colors.white),
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
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey[800],
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
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: Colors.orange,
            inactiveColor: Colors.grey[800],
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  /// 使用 ECharts 展示专业 K 线图（蜡烛图 + 成交量 + 高亮）。
  Widget _buildCandlestickChart() {
    final window = _orchestrator.window;

    if (window.isEmpty) {
      return const Center(
        child: Text(
          '点击开始按钮启动测试',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 计算最新一根 K 线的涨跌幅
    String latestChangeText = '--';
    Color latestChangeColor = Colors.grey;
    if (window.length > 1) {
      final latest = window.last;
      final prevClose = window[window.length - 2].close;
      final changePercent = ((latest.close - prevClose) / prevClose) * 100;
      final isUp = changePercent >= 0;
      latestChangeText = '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%';
      latestChangeColor = isUp ? Colors.green : Colors.red;
    }

    // 滑动窗口：只显示最后 50 根 K 线
    const displayCount = 50;
    final displayWindow = window.length > displayCount
        ? window.sublist(window.length - displayCount)
        : window;

    // 优先使用选中的信号，否则使用最新信号
    final activeSignal = _selectedSignal ??
        (_orchestrator.signals.isNotEmpty ? _orchestrator.signals.first : null);

    // 获取下跌/回拉段索引（相对于 displayWindow）
    int? dropStart, dropEnd, recoveryEnd;
    if (activeSignal != null) {
      final offset = window.length - displayWindow.length;
      dropStart = activeSignal.dropStartIndex - offset;
      dropEnd = activeSignal.dropEndIndex - offset;
      recoveryEnd = activeSignal.recoveryEndIndex - offset;
      // 确保索引在有效范围内
      if (dropStart < 0) dropStart = null;
      if (dropEnd < 0) dropEnd = null;
      if (recoveryEnd < 0) recoveryEnd = null;
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          TradingViewKlineWidget(
            data: displayWindow,
            dropStartIndex: dropStart,
            dropEndIndex: dropEnd,
            recoveryEndIndex: recoveryEnd,
          ),
          // 最新涨跌幅标签（右上角）
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: latestChangeColor, width: 1),
              ),
              child: Text(
                latestChangeText,
                style: TextStyle(
                  color: latestChangeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 数据计数标签（左下角）
          Positioned(
            bottom: 8,
            left: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${window.length} 根 K 线',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // 选中标记（左上角）
          if (_selectedSignal != null)
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                onTap: () => setState(() => _selectedSignal = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '已选中 #${_orchestrator.signals.indexOf(_selectedSignal!) + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.close, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 信号列表：展示 score >= 60 的信号。
  Widget _buildSignalList() {
    final signals = _orchestrator.signals;

    if (signals.isEmpty) {
      return const Center(
        child: Text(
          '暂无高评分信号',
          style: TextStyle(color: Colors.grey),
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
        color: isSelected ? Colors.blue.withAlpha(50) : Colors.grey[900],
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        shape: isSelected
            ? RoundedRectangleBorder(
                side: const BorderSide(color: Colors.blue, width: 1),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              // 评分徽章
              _ScoreBadge(score: signal.score),
              const SizedBox(width: 8),
              // 信号详情
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        '${signal.dropMagnitude.toStringAsFixed(1)}×ATR',
                        style:
                            TextStyle(color: Colors.red[300], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '回补 ${(signal.recoveryRatio * 100).toStringAsFixed(0)}%',
                        style:
                            TextStyle(color: Colors.green[300], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      _DeadCatIndicator(score: signal.deadCatRiskScore),
                    ]),
                    const SizedBox(height: 2),
                    // 共振过滤器标签
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final f in signal.confluenceFilters)
                          Chip(
                            label: Text(
                              _confluenceLabel(f),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: Colors.blueGrey[800],
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.blue, size: 16),
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
      padding: const EdgeInsets.all(12),
      color: Colors.grey[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔧 调试信息',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // 指标行
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _DebugItem(
                label: 'ATR(${_params.atrPeriod})',
                value: currentAtr != null ? currentAtr.toStringAsFixed(4) : '--',
                color: Colors.cyan,
              ),
              _DebugItem(
                label: 'RSI(${_params.rsiPeriod})',
                value: stdRsi != null ? stdRsi.toStringAsFixed(1) : '--',
                color: stdRsi != null && stdRsi < _params.rsiOversold
                    ? Colors.red
                    : Colors.cyan,
              ),
              _DebugItem(
                label: 'RSI(${_params.fastRsiPeriod})',
                value: fastRsi != null ? fastRsi.toStringAsFixed(1) : '--',
                color: fastRsi != null && fastRsi < _params.rsiOversold
                    ? Colors.red
                    : Colors.cyan,
              ),
              _DebugItem(
                label: 'swingLow',
                value: swingLowIdx != null
                    ? '#$swingLowIdx ${swingLowPrice?.toStringAsFixed(2)}'
                    : '--',
                color: Colors.orange,
              ),
              _DebugItem(
                label: '窗口',
                value: '${window.length}/${TestOrchestrator.windowSize}',
                color: Colors.grey,
              ),
            ],
          ),
          if (latestSignal != null) ...[
            const Divider(color: Colors.grey, height: 16),
            const Text(
              '最新信号共振过滤器',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: ConfluenceType.values.map((type) {
                final passed = latestSignal.confluenceFilters.contains(type);
                return Chip(
                  label: Text(
                    _confluenceLabel(type),
                    style: TextStyle(
                      fontSize: 11,
                      color: passed ? Colors.white : Colors.grey,
                    ),
                  ),
                  backgroundColor: passed ? Colors.green[700] : Colors.grey[800],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  avatar: Icon(
                    passed ? Icons.check : Icons.close,
                    size: 14,
                    color: passed ? Colors.white : Colors.grey,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontSize: 11,
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
    return Colors.grey[700]!;
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
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
          child: Icon(Icons.dangerous, color: Colors.red, size: 18),
        ),
      );
    }
    if (score >= 40) {
      return const SizedBox(
        width: 32,
        child: Tooltip(
          message: '注意死猫风险',
          child:
              Icon(Icons.warning_amber, color: Colors.orange, size: 18),
        ),
      );
    }
    return const SizedBox(
      width: 32,
      child: Icon(Icons.check_circle_outline,
          color: Colors.green, size: 18),
    );
  }
}
