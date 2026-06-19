import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/providers/rebound_score_provider.dart';
import 'package:tomapp/services/rebound/rebound_alert_service.dart';
import 'package:tomapp/services/rebound/rebound_kline_stream_service.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/binance_api_service.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'package:tomapp/services/exchange_info_service.dart';
import 'kline_screen.dart';

/// 反弹监控看板页面。
///
/// 按周期分 Tab（15m/1h/4h/1d），消费 [ReboundScoreProvider] 的状态，
/// 信号按评分降序排列。每行展示币种、评分、跌幅、回补%、迷你 sparkline、
/// 死猫风险标注和止损参考位。点击信号下钻到 [KlineScreen]。
class ReboundDashboardScreen extends StatefulWidget {
  const ReboundDashboardScreen({super.key});

  @override
  State<ReboundDashboardScreen> createState() =>
      _ReboundDashboardScreenState();
}

class _ReboundDashboardScreenState extends State<ReboundDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReboundAlertService? _alertService;
  bool _isInitializing = true;
  String? _initError;

  static const _timeframes = ['15m', '1h', '4h', '1d'];
  static const _tfLabels = ['15m', '1h', '4h', '1d'];

  /// 默认监控的 Top 20 USDT 永续合约。
  static const _defaultSymbols = [
    'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT', 'XRPUSDT',
    'DOGEUSDT', 'ADAUSDT', 'AVAXUSDT', 'DOTUSDT', 'LINKUSDT',
    'MATICUSDT', 'UNIUSDT', 'ATOMUSDT', 'LTCUSDT', 'FILUSDT',
    'APTUSDT', 'ARBUSDT', 'OPUSDT', 'NEARUSDT', 'TIAUSDT',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _timeframes.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAlertService());
  }

  @override
  void dispose() {
    _alertService?.stop();
    _tabController.dispose();
    super.dispose();
  }

  /// 按需启动 ReboundAlertService（per Phase 3 设计：由看板启动，避免 app 启动时建立 1600 路 WS）。
  Future<void> _startAlertService() async {
    try {
      final provider = context.read<ReboundScoreProvider>();
      final streamService = ReboundKlineStreamService(BinanceApiService());
      final detector = ReboundDetector(TechnicalIndicators());
      _alertService = ReboundAlertService(
        streamService: streamService,
        detector: detector,
        provider: provider,
      );

      // 尝试从 ExchangeInfoService 获取 USDT 永续合约列表
      List<String> symbols;
      try {
        final exchangeInfo = context.read<ExchangeInfoService>();
        final allSymbols = exchangeInfo.symbols;
        if (allSymbols.isNotEmpty) {
          symbols = allSymbols.values
              .where((s) => s.isUsdtPerpetual && s.isTradable)
              .map((s) => s.symbol)
              .toList();
          // 限制最多 50 个，避免 WS 连接过多
          if (symbols.length > 50) {
            symbols = symbols.sublist(0, 50);
          }
        } else {
          symbols = _defaultSymbols;
        }
      } catch (_) {
        symbols = _defaultSymbols;
      }

      await _alertService!.start(symbols);
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = '启动监控失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('合约反弹监控'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    '正在连接市场数据...',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : _initError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      Text(_initError!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildTabBar(),
                    Expanded(child: _buildTabBarView()),
                    _buildRiskWarning(),
                  ],
                ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[900],
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: _tfLabels
            .map((tf) => Tab(text: tf))
            .toList(),
      ),
    );
  }

  Widget _buildTabBarView() {
    return Consumer<ReboundScoreProvider>(
      builder: (context, provider, _) {
        final warmingCount = provider.warmingUpSymbols.length;

        return TabBarView(
          controller: _tabController,
          children: _timeframes.map((tf) {
            final signals = provider.getSignalsForTimeframe(tf);
            return _buildTabContent(tf, signals, warmingCount);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTabContent(
      String tf, List<ReboundSignal> signals, int warmingCount) {
    if (signals.isEmpty && warmingCount == 0) {
      return const Center(
        child: Text(
          '暂无监控候选',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return Column(
      children: [
        if (warmingCount > 0) _buildWarmUpBanner(warmingCount),
        Expanded(
          child: signals.isEmpty
              ? const Center(
                  child: Text(
                    '暂无监控候选',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  itemCount: signals.length,
                  itemBuilder: (context, index) =>
                      _SignalRow(signal: signals[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildWarmUpBanner(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[850],
      child: Text(
        '监控准备中 · $count 个合约数据加载中',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRiskWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: const Text(
        '历史回测需打 30-50% 折扣，不构成投资建议',
        style: TextStyle(color: Colors.grey, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 单行信号卡片。
class _SignalRow extends StatelessWidget {
  final ReboundSignal signal;

  const _SignalRow({required this.signal});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToKline(context),
      child: Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              // 币种
              SizedBox(
                width: 56,
                child: Text(
                  signal.symbol.replaceAll('USDT', ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // 评分
              _ScoreBadge(score: signal.score),
              const SizedBox(width: 6),
              // 跌幅
              SizedBox(
                width: 52,
                child: Text(
                  '${signal.dropMagnitude.toStringAsFixed(1)}×ATR',
                  style: TextStyle(color: Colors.red[300], fontSize: 12),
                ),
              ),
              // 回补%
              SizedBox(
                width: 42,
                child: Text(
                  '${(signal.recoveryRatio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.green[300], fontSize: 12),
                ),
              ),
              // 死猫风险
              _DeadCatIndicator(score: signal.deadCatRiskScore),
              const SizedBox(width: 4),
              // 止损参考位
              SizedBox(
                width: 52,
                child: Text(
                  '止损 ${signal.swingLowPrice.toStringAsFixed(3)}',
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              // 迷你 sparkline
              _MiniSparkline(
                symbol: signal.symbol,
                timeframe: signal.timeframe,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToKline(BuildContext context) {
    // 计算高亮窗口时间戳
    final tfMs = _tfDurationMs(signal.timeframe);
    final totalKlines = signal.recoveryEndIndex - signal.dropStartIndex + 1;
    final highlightStartMs =
        signal.timestamp.millisecondsSinceEpoch - totalKlines * tfMs;
    final highlightEndMs = signal.timestamp.millisecondsSinceEpoch;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KlineScreen(
        symbol: signal.symbol,
        defaultInterval: signal.timeframe,
        highlightStartMs: highlightStartMs,
        highlightEndMs: highlightEndMs,
      ),
    ));
  }

  static int _tfDurationMs(String tf) {
    switch (tf) {
      case '15m':
        return 900000;
      case '1h':
        return 3600000;
      case '4h':
        return 14400000;
      case '1d':
        return 86400000;
      default:
        return 3600000;
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
          child: Icon(Icons.warning_amber, color: Colors.orange, size: 18),
        ),
      );
    }
    // score < 40: 低风险，显示绿色勾（或不显示）
    return const SizedBox(
      width: 32,
      child: Icon(Icons.check_circle_outline,
          color: Colors.green, size: 18),
    );
  }
}

/// 迷你 sparkline 折线图。
class _MiniSparkline extends StatelessWidget {
  final String symbol;
  final String timeframe;

  const _MiniSparkline({
    required this.symbol,
    required this.timeframe,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.24,
      height: 40,
      child: Consumer<ReboundScoreProvider>(
        builder: (context, provider, _) {
          final closes = provider.getRecentCloses(symbol, timeframe);
          if (closes == null || closes.length < 2) {
            return const SizedBox(width: 60, height: 40);
          }

          final isUp = closes.last > closes.first;
          final lineColor = isUp ? Colors.green : Colors.red;
          final minY = closes.reduce((a, b) => a < b ? a : b) * 0.995;
          final maxY = closes.reduce((a, b) => a > b ? a : b) * 1.005;

          final spots = <FlSpot>[];
          for (var i = 0; i < closes.length; i++) {
            spots.add(FlSpot(i.toDouble(), closes[i]));
          }

          return LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 1.2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
            duration: Duration.zero,
          );
        },
      ),
    );
  }
}
