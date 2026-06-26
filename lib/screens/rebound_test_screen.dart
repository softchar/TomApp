import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'package:tomapp/services/test/test_data_generator.dart';
import 'package:tomapp/services/test/test_orchestrator.dart';

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
      ),
      body: Column(
        children: [
          _buildControlBar(),
          Expanded(flex: 3, child: _buildCandlestickChart()),
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
          // 第二行：参数调整 Slider
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

  /// CandlestickChart 展示最近 50 根 K 线。
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

    // 计算最新信号的高亮范围
    int? dropStartIdx;
    int? dropEndIdx;
    int? recoveryEndIdx;
    if (_orchestrator.signals.isNotEmpty) {
      final signal = _orchestrator.signals.first;
      // 信号索引是基于信号生成时的 window 位置
      // 当 window 滚动后，需要转换为当前 window 的索引
      // 信号的索引是绝对位置，window 通过 removeAt(0) 滚动
      // 偏移量 = 当前 window 长度 - 信号生成时的 window 长度
      // 简化：只在信号时间戳在当前 window 范围内时高亮
      final offset = window.length - (signal.recoveryEndIndex + 1);
      final dsIdx = signal.dropStartIndex - offset;
      final deIdx = signal.dropEndIndex - offset;
      final reIdx = signal.recoveryEndIndex - offset;

      if (dsIdx >= 0 && reIdx < window.length) {
        dropStartIdx = dsIdx;
        dropEndIdx = deIdx;
        recoveryEndIdx = reIdx;
      }
    }

    final spots = <CandlestickSpot>[];
    for (int i = 0; i < window.length; i++) {
      final k = window[i];
      spots.add(CandlestickSpot(
        x: i.toDouble(),
        open: k.open,
        high: k.high,
        low: k.low,
        close: k.close,
      ));
    }

    final minY = window.map((k) => k.low).reduce(min) * 0.99;
    final maxY = window.map((k) => k.high).reduce(max) * 1.01;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: CandlestickChart(
        CandlestickChartData(
          candlestickSpots: spots,
          candlestickPainter: DefaultCandlestickPainter(
            candlestickStyleProvider: (spot, index) {
              Color color;
              if (dropStartIdx != null &&
                  dropEndIdx != null &&
                  index >= dropStartIdx &&
                  index <= dropEndIdx) {
                color = Colors.red.shade700; // 下跌段
              } else if (dropEndIdx != null &&
                  recoveryEndIdx != null &&
                  index > dropEndIdx &&
                  index <= recoveryEndIdx) {
                color = Colors.green.shade700; // 拉回段
              } else {
                color = spot.isUp
                    ? Colors.green.shade700
                    : Colors.red.shade700;
              }
              return CandlestickStyle(
                lineColor: color,
                lineWidth: 1.5,
                bodyStrokeColor: color,
                bodyStrokeWidth: 0,
                bodyFillColor: color,
                bodyWidth: 8,
                bodyRadius: 1,
              );
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 5,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.shade800, width: 0.5),
          ),
          minY: minY,
          maxY: maxY,
        ),
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

  /// 单行信号卡片。
  Widget _buildSignalRow(ReboundSignal signal) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            // 时间戳
            Text(
              '${signal.timestamp.hour}:${signal.timestamp.minute.toString().padLeft(2, '0')}:${signal.timestamp.second.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
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
      return SizedBox(
        width: 32,
        child: Tooltip(
          message: '死猫反弹高风险',
          child: Icon(Icons.dangerous, color: Colors.red, size: 18),
        ),
      );
    }
    if (score >= 40) {
      return SizedBox(
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
