import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tomapp/models/rebound_params.dart';
import 'package:tomapp/models/rebound_signal.dart';
import 'package:tomapp/providers/rebound_score_provider.dart';
import 'package:tomapp/services/rebound/rebound_alert_service.dart';
import 'package:tomapp/services/rebound/rebound_kline_stream_service.dart';
import 'package:tomapp/services/rebound/rebound_confluence_scorer.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/rebound_market_scanner.dart';
import 'package:tomapp/services/rebound/rebound_notification_repository.dart';
import 'package:tomapp/services/rebound/rebound_signal_repository.dart';
import 'package:tomapp/services/binance_api_service.dart';
import 'package:tomapp/services/technical_indicators.dart';
import 'package:tomapp/services/exchange_info_service.dart';
import 'kline_screen.dart';

/// 测试期宽松模式开关（`flutter run --dart-define=LOOSE_PARAMS=true` 启用）。
///
/// 为前期快速观察反弹数据：切换到 [ReboundParams.looseForTesting]（大幅降低
/// 检测门槛 + 关闭共振过滤）。正式使用不传此 define 即恢复严格默认阈值。
const _looseForTesting = bool.fromEnvironment('LOOSE_PARAMS');

/// 看板列表显示门槛：仅展示评分 ≥ 此值的信号（低于的不在看板列表显示，
/// 但仍会被检测/精跟/按 high 门槛通知——此过滤仅影响列表展示）。
const _minDisplayScore = 70;

/// 反弹监控看板页面。
///
/// 全市场 REST 轮询扫描（仅 15m 单周期，per 04-03 范围调整）+ 命中精跟，
/// 消费 [ReboundScoreProvider] 的状态，信号按评分降序排列。
/// 每行展示币种、评分、跌幅、回补%、迷你 sparkline、死猫风险标注和止损参考位。
/// 点击信号下钻到 [KlineScreen]。
class ReboundDashboardScreen extends StatefulWidget {
  const ReboundDashboardScreen({super.key});

  @override
  State<ReboundDashboardScreen> createState() =>
      _ReboundDashboardScreenState();
}

class _ReboundDashboardScreenState extends State<ReboundDashboardScreen> {
  ReboundAlertService? _alertService;
  ReboundMarketScanner? _scanner;
  ReboundNotificationRepository? _notificationRepository;
  bool _isInitializing = true;
  bool _showHistory = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAlertService());
  }

  @override
  void dispose() {
    _scanner?.stop();
    _alertService?.stop();
    super.dispose();
  }

  /// 按需启动全市场扫描 + 精跟编排（per 04-03：scanner REST 轮询全市场，
  /// 命中标的再由 alertService 动态精跟；看板启动避免 app 启动建全量 WS）。
  Future<void> _startAlertService() async {
    try {
      final provider = context.read<ReboundScoreProvider>();
      final api = BinanceApiService();
      final streamService = ReboundKlineStreamService(api);
      final detector = ReboundDetector(TechnicalIndicators());
      final exchangeInfo = context.read<ExchangeInfoService>();

      _notificationRepository = ReboundNotificationRepository();
      final signalRepository = ReboundSignalRepository();
      provider.setSignalRepository(signalRepository);
      _alertService = ReboundAlertService(
        streamService: streamService,
        detector: detector,
        provider: provider,
        notificationRepository: _notificationRepository,
      );

      // 全市场 REST 轮询扫描器：symbolsProvider 读 ExchangeInfo 全部 USDT 永续可交易合约（无截断）。
      // timeframes 用默认 monitoredTimeframes（仅 15m，per 04-03 决策 D8）。
      _scanner = ReboundMarketScanner(
        fetchKlines: ({required symbol, required interval, required limit}) =>
            api.getRecentKlines(
                symbol: symbol, interval: interval, limit: limit),
        detector: detector,
        symbolsProvider: () async {
          final all = exchangeInfo.symbols;
          return all.values
              .where((s) => s.isUsdtPerpetual && s.isTradable)
              .map((s) => s.symbol)
              .toList();
        },
        // 测试期宽松参数（LOOSE_PARAMS=true 时启用，方便快速看到反弹数据）
        params: _looseForTesting
            ? ReboundParams.looseForTesting
            : const ReboundParams(),
        // 扫描进度 → Provider 扫描状态字段（供横幅显示）；onProgress 为 final，构造时注入。
        onProgress: (p) {
          if (!mounted) return;
          provider.updateScanState(
            round: p.round,
            trackedCount: _alertService!.trackedCount,
            lastScanTime: p.lastScanTime,
          );
        },
        // 扫描命中的反弹信号立即写入 Provider，让看板即时显示——
        // 否则要等 WS 精跟收到下一根 15m 收盘 K 线（可能数分钟）才会出现信号。
        // WS 精跟后续通过 handleClosedKline 用实时价刷新 + 补 sparkline 数据。
        onScanComplete: (result) {
          if (!mounted) return;
          var count = 0;
          for (final symEntry in result.signalsBySymbolTf.entries) {
            // 与 handleClosedKline 一致：应用跨周期共振加分（单周期 mtf=0；
            // 多周期恢复时两路径同分，避免 UI 得分闪烁，per 04-REVIEW WR-07）
            final mtfScore =
                ReboundConfluenceScorer.scoreMultiTimeframe(symEntry.value);
            for (final tfEntry in symEntry.value.entries) {
              final signal = tfEntry.value;
              if (signal != null) {
                final enriched = mtfScore > 0
                    ? signal.copyWith(
                        score: (signal.score + mtfScore).clamp(0, 100))
                    : signal;
                // 扫描命中写入 Provider（持久化）；通知由 provider 进列表跃迁自动触发。
                provider.upsert(symEntry.key, tfEntry.key, enriched,
                    persist: true);
                count++;
              }
            }
          }
          provider.addLog(
              '第 ${result.round} 轮完成 · 命中 ${result.hitSymbols.length} · 写入 $count 信号');
        },
      );

      _alertService!.attachScanner(_scanner!);
      await _alertService!.start([]); // 空初始，精跟集合由 scanner 命中驱动
      // 从持久化恢复列表信号（app 重启后列表不丢失）
      await provider.loadSignals(signalRepository.queryListed);
      // 加载历史通知（持久化 → 内存 → 历史区域）
      await provider.loadNotificationHistory(
          _notificationRepository!.queryRecent);
      provider.addLog('扫描器已启动 · 全市场 15m 轮询中（首轮约 40-50s）');
      _scanner!.start();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            tooltip: '字段说明',
            onPressed: () => _showLegendDialog(context),
          ),
        ],
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
                    _buildScanBanner(),
                    Expanded(child: _buildSignalList()),
                    _buildHistoryPanel(),
                    _buildLogPanel(),
                    _buildRiskWarning(),
                  ],
                ),
    );
  }

  /// 扫描状态横幅：扫描轮次 / 精跟数量 / 最后扫描时间。
  Widget _buildScanBanner() {
    return Consumer<ReboundScoreProvider>(
      builder: (context, provider, _) {
        final round = provider.scanRound;
        final tracked = provider.trackedCount;
        final lastScan = provider.lastScanTime;
        final timeStr = lastScan == null
            ? ''
            : ' · ${lastScan.hour.toString().padLeft(2, '0')}:${lastScan.minute.toString().padLeft(2, '0')}';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: Colors.grey[850],
          child: Text(
            '全市场扫描 · 第 $round 轮 · 精跟 $tracked 个$timeStr',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  /// 15m 单页信号列表（去周期 Tab，per 04-03 范围调整）。
  Widget _buildSignalList() {
    return Consumer<ReboundScoreProvider>(
      builder: (context, provider, _) {
        final signals =
            provider.getSignalsForTimeframe('15m', minScore: _minDisplayScore);
        final warmingCount = provider.warmingUpSymbols.length;

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
      },
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

  /// 调试日志面板（测试期）：底部固定高度，倒序显示最新日志，可清空。
  Widget _buildLogPanel() {
    return Consumer<ReboundScoreProvider>(
      builder: (context, provider, _) {
        final logs = provider.logs;
        return Container(
          height: 140,
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('日志（${logs.length}）',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 11)),
                  const Spacer(),
                  if (logs.isNotEmpty)
                    GestureDetector(
                      onTap: provider.clearLogs,
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: Colors.grey),
                    ),
                ],
              ),
              const Divider(height: 6, thickness: 0.5, color: Colors.grey),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text('暂无日志',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 11)))
                    : ListView.builder(
                        reverse: true,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final line = logs[logs.length - 1 - index];
                          return Text(line,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ));
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 通知历史面板（可折叠）：展示已推送的通知记录（时间、币种、评分、跌幅）。
  Widget _buildHistoryPanel() {
    return Consumer<ReboundScoreProvider>(
      builder: (context, provider, _) {
        final history = provider.notificationHistory;
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border:
                Border(top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
          ),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showHistory = !_showHistory),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('通知历史（${history.length}）',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const Spacer(),
                      Icon(
                          _showHistory
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.grey,
                          size: 18),
                    ],
                  ),
                ),
              ),
              if (_showHistory)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: history.isEmpty
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('暂无通知历史',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 6),
                          itemCount: history.length,
                          itemBuilder: (context, i) {
                            final r = history[i];
                            final hh = r.notifiedAt.hour
                                .toString()
                                .padLeft(2, '0');
                            final mm = r.notifiedAt.minute
                                .toString()
                                .padLeft(2, '0');
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 40,
                                      child: Text('$hh:$mm',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              fontFamily: 'monospace'))),
                                  SizedBox(
                                      width: 60,
                                      child: Text(
                                          r.symbol.replaceAll('USDT', ''),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.bold))),
                                  SizedBox(
                                      width: 28,
                                      child: Text('${r.score}',
                                          style: TextStyle(
                                              color: Colors.green[300],
                                              fontSize: 11))),
                                  Text(
                                      '${r.dropMagnitude.toStringAsFixed(1)}×ATR',
                                      style: TextStyle(
                                          color: Colors.red[300],
                                          fontSize: 10)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 字段说明对话框：解释每行各元素的含义与计算方式。
  void _showLegendDialog(BuildContext context) {
    Widget item(String title, String desc) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('字段说明', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item('评分（圆形徽章）',
                  '反弹综合强度分 0-100，越高越强。由下跌幅度、拉回力度、速度等加权得出；≥70 深绿、≥40 橙、<40 灰。'),
              item('跌幅 ×ATR',
                  '下跌段的幅度，用 ATR（平均真实波幅）倍数表示，如 2.5×ATR。用波动率归一化，跨币可比。'),
              item('回补%',
                  '从反弹低点回升的比例（0-100%）。越高表示反弹力度越强、收复跌幅越多。'),
              item('sparkline 折线',
                  '该币最近收盘价走势（涨绿跌红，无轴/网格）。一眼判断反弹形态。'),
              item('死猫风险（图标）',
                  '死猫反弹（虚假反弹）概率 0-100。≥70 红骷髅高风险、≥40 橙警告、<40 绿勾较安全。基于跌幅深度、是否放量、所处支撑位等判断。'),
              item('止损参考位',
                  '反弹起点的 swing low（近期低点），作为参考止损价。跌破该位则反弹逻辑失效。'),
              const SizedBox(height: 6),
              const Text(
                  '注：当前为测试期宽松参数（LOOSE_PARAMS），门槛大幅降低，候选偏多、质量偏低，正式阈值待 Phase 6 回测校准。',
                  style: TextStyle(color: Colors.orange, fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('明白了', style: TextStyle(color: Colors.blue)),
          ),
        ],
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
/// 带小标签的字段列（值 + 下方小灰字标签），让每行各数值自解释。
Widget _labeled(Widget child, String label, double width) {
  return SizedBox(
    width: width,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        child,
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
      ],
    ),
  );
}

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 币种
              SizedBox(
                width: 40,
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
              // 触发时间（K 线收盘时间）
              SizedBox(
                width: 36,
                child: Text(
                  '${signal.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${signal.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 4),
              // 评分
              _labeled(_ScoreBadge(score: signal.score), '评分', 40),
              const SizedBox(width: 4),
              // 跌幅
              _labeled(
                Text('${signal.dropMagnitude.toStringAsFixed(1)}×ATR',
                    style: TextStyle(color: Colors.red[300], fontSize: 12)),
                '跌幅',
                50,
              ),
              // 回补%
              _labeled(
                Text('${(signal.recoveryRatio * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: Colors.green[300], fontSize: 12)),
                '回补',
                38,
              ),
              // 死猫风险
              _labeled(
                  _DeadCatIndicator(score: signal.deadCatRiskScore), '死猫', 30),
              const SizedBox(width: 2),
              // 止损参考位
              _labeled(
                Text(signal.swingLowPrice.toStringAsFixed(3),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                '止损',
                46,
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
