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
import 'package:tomapp/services/theme_provider.dart';
import 'kline_screen.dart';

/// 测试期宽松模式开关（`flutter run --dart-define=LOOSE_PARAMS=true` 启用）。
///
/// 为前期快速观察反弹数据：切换到 [ReboundParams.looseForTesting]（大幅降低
/// 检测门槛 + 关闭共振过滤）。正式使用不传此 define 即恢复严格默认阈值。
const _looseForTesting = bool.fromEnvironment('LOOSE_PARAMS');

/// 看板列表显示门槛：仅展示评分 ≥ 此值的信号（低于的不在看板列表显示，
/// 但仍会被检测/精跟/按 high 门槛通知——此过滤仅影响列表展示）。
const _minDisplayScore = 70;

/// 信号行响应式布局决策（纯函数，无 BuildContext 依赖，单测友好）。
///
/// 按卡片内可用宽度决定是否显示止损列 / sparkline 及 sparkline 占位最小宽度，
/// 配合 [ReboundDashboardScreen] 里的 `Expanded` sparkline，保证任意屏宽（含
/// 360px）信号行永不溢出。断点锚定物理量：核心列底线 / sparkline 舒适值 / 极限值。
@visibleForTesting
class ReboundSignalLayout {
  final bool showStoploss;
  final bool showSparkline;
  final double sparklineMin;

  const ReboundSignalLayout({
    required this.showStoploss,
    required this.showSparkline,
    required this.sparklineMin,
  });

  /// 非止损固定列 + 内部间隔：symbol40 + 4 + time36 + 4 + score40 + 4 + drop56 +
  /// recovery42 + deadcat30 = 256。
  static const double _coreColumns = 256.0;
  /// 止损列 + 前导间隔：2 + 46 = 48。
  static const double _stoplossBudget = 48.0;
  /// sparkline 舒适宽（≈原 0.24×360）/ 下限 / 极限。
  static const double _sparklineComfort = 90.0;
  static const double _sparklineFloor = 56.0;
  static const double _sparklineMin = 40.0;

  /// 输入卡片内可用宽度，输出布局配置。
  @visibleForTesting
  static ReboundSignalLayout resolve(double availableWidth) {
    // 全列 + 舒适 sparkline（屏宽≈434+）：止损+sparkline 全显示。
    if (availableWidth >= _coreColumns + _stoplossBudget + _sparklineComfort) {
      return const ReboundSignalLayout(
          showStoploss: true, showSparkline: true, sparklineMin: _sparklineComfort);
    }
    // 裁止损，sparkline 宽裕（屏宽≈352–434，含多数 iPhone）。
    if (availableWidth >= _coreColumns + _sparklineFloor) {
      return const ReboundSignalLayout(
          showStoploss: false, showSparkline: true, sparklineMin: _sparklineFloor);
    }
    // 裁止损，sparkline 极限（屏宽≈336–352，SE/mini）。
    if (availableWidth >= _coreColumns + _sparklineMin) {
      return const ReboundSignalLayout(
          showStoploss: false, showSparkline: true, sparklineMin: _sparklineMin);
    }
    // core 都放不下最小 sparkline（屏宽<336，分屏/极小屏）：隐藏 sparkline。
    return const ReboundSignalLayout(
        showStoploss: false, showSparkline: false, sparklineMin: 0);
  }
}

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
  bool _isRetrying = false; // 错误态重试进行中（区分首启 loading，文案不同）
  bool _showHistory = false; // 通知历史面板折叠态
  String? _initError;
  String _initStatus = '正在初始化...'; // 初始化进度文案

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
    // 重试路径进入时也显示 loading，避免闪现错误态。
    if (mounted) setState(() { _isInitializing = true; _initStatus = '正在加载合约列表...'; });
    try {
      final provider = context.read<ReboundScoreProvider>();
      final api = BinanceApiService();
      final streamService = ReboundKlineStreamService(api);
      final detector = ReboundDetector(TechnicalIndicators());
      final exchangeInfo = context.read<ExchangeInfoService>();

      // 等待 ExchangeInfoService 初始化完成（加载合约列表）
      if (!exchangeInfo.isInitialized) {
        if (mounted) setState(() => _initStatus = '正在等待合约列表加载...');
        final waitStart = DateTime.now();
        while (!exchangeInfo.isInitialized &&
            DateTime.now().difference(waitStart).inSeconds < 10) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        if (!exchangeInfo.isInitialized) {
          throw Exception('合约列表加载超时，请检查网络后重试');
        }
      }

      // 检查合约列表是否为空
      var tradableCount = exchangeInfo.symbols.values
          .where((s) => s.isUsdtPerpetual && s.isTradable)
          .length;
      if (tradableCount == 0) {
        // 合约列表为空，主动从 API 拉取
        if (mounted) setState(() => _initStatus = '正在从币安获取合约列表...');
        await exchangeInfo.fetchExchangeInfo();
        tradableCount = exchangeInfo.symbols.values
            .where((s) => s.isUsdtPerpetual && s.isTradable)
            .length;
        if (tradableCount == 0) {
          throw Exception('未获取到可交易合约列表，请检查网络连接');
        }
      }

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
      if (mounted) setState(() => _initStatus = '正在启动市场扫描...');
      _scanner!.start();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e, st) {
      // 不透传原始异常给用户；完整堆栈走 debugPrint 供调试。
      debugPrint('ReboundDashboard _startAlertService 失败: $e\n$st');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = _friendlyError(e);
        });
      }
    }
  }

  /// 把任意异常映射成用户可读文案（分类集中在自此，便于未来扩展）。
  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('HandshakeException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('WebSocketChannelException') ||
        msg.contains('TimeoutException')) {
      return '市场数据连接失败';
    }
    if (msg.contains('429') || msg.contains('rate limit')) {
      return '请求过于频繁，已被限流';
    }
    if (msg.contains('合约列表')) {
      return msg.replaceAll('Exception: ', '');
    }
    if (msg.contains('未获取到')) {
      return msg.replaceAll('Exception: ', '');
    }
    return '监控服务启动失败';
  }

  /// 错误态重试：先彻底拆旧实例（必须 await stop）→ 置空引用 → 重置 flags → 重跑启动。
  //
  // R1：[ReboundAlertService.stop] 是 Future 且内部会 WS disconnect + provider.clear，
  // 必须先 await 它完成再 new 新实例，否则旧 WS 未关、新 WS 同开 → 双重订阅 → 429。
  Future<void> _retry() async {
    final oldAlert = _alertService;
    final oldScanner = _scanner;
    _alertService = null; // 先置空，防 build 期间读到半拆状态
    _scanner = null;
    if (oldAlert != null) {
      try {
        await oldAlert.stop();
      } catch (e) {
        debugPrint('ReboundDashboard 旧 alertService.stop 失败(忽略): $e');
      }
    }
    oldScanner?.stop(); // 幂等（start 有 _timer 守卫）
    if (mounted) {
      setState(() {
        _isRetrying = true;
        _initError = null;
      });
    }
    await _startAlertService();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('合约反弹监控'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            tooltip: '字段说明',
            onPressed: () => _showLegendDialog(context),
          ),
        ],
      ),
      body: (_isInitializing || _isRetrying)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                      color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    _isRetrying ? '正在重新连接...' : _initStatus,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            )
          : _initError != null
              ? _buildErrorState()
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

  /// 错误态：可读文案 + 副提示 + 重试按钮（复刻 backtest_screen 金标准，
  /// 全程用 AppColors/AppSpacing/AppTextStyles/AppRadius token）。
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.destructive, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.destructive, size: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _initError ?? '监控服务启动失败',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  '请检查网络连接后重试',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isRetrying ? null : _retry,
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.textSecondary))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_isRetrying ? '重试中...' : '重试'),
                ),
              ],
            ),
          ),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2, horizontal: AppSpacing.md),
          color: AppColors.surfaceVariant,
          child: Text(
            '全市场扫描 · 第 $round 轮 · 精跟 $tracked 个$timeStr',
            style: AppTextStyles.bodySmall,
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
              style: AppTextStyles.bodyMedium,
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
                        style: AppTextStyles.bodyMedium,
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      color: AppColors.surfaceVariant,
      child: Text(
        '监控准备中 · $count 个合约数据加载中',
        style: AppTextStyles.bodySmall,
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
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text('日志（${logs.length}）',
                      style: AppTextStyles.labelSmall),
                  const Spacer(),
                  if (logs.isNotEmpty)
                    GestureDetector(
                      onTap: provider.clearLogs,
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: AppColors.textSecondary),
                    ),
                ],
              ),
              const Divider(
                  height: 6, thickness: 0.5, color: AppColors.border),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text('暂无日志',
                            style: AppTextStyles.labelSmall))
                    : ListView.builder(
                        reverse: true,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final line = logs[logs.length - 1 - index];
                          return Text(line,
                              style: const TextStyle(
                                color: AppColors.success,
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
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showHistory = !_showHistory),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: AppSpacing.xs + 2),
                  child: Row(
                    children: [
                      const Icon(Icons.history,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text('通知历史（${history.length}）',
                          style: AppTextStyles.bodySmall),
                      const Spacer(),
                      Icon(
                          _showHistory
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppColors.textSecondary,
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
                          padding: EdgeInsets.all(AppSpacing.sm + 4),
                          child: Text('暂无通知历史',
                              style: AppTextStyles.labelSmall),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
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
                                  horizontal: AppSpacing.sm + 4, vertical: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 40,
                                      child: Text('$hh:$mm',
                                          style: const TextStyle(
                                              color: AppColors.textTertiary,
                                              fontSize: 10,
                                              fontFamily: 'monospace'))),
                                  SizedBox(
                                      width: 60,
                                      child: Text(
                                          r.symbol.replaceAll('USDT', ''),
                                          style: AppTextStyles.labelMedium
                                              .copyWith(fontWeight: FontWeight.bold))),
                                  SizedBox(
                                      width: 28,
                                      child: Text('${r.score}',
                                          style: AppTextStyles.labelSmall
                                              .copyWith(color: AppColors.success))),
                                  Text(
                                      '${r.dropMagnitude.toStringAsFixed(1)}×ATR',
                                      style: const TextStyle(
                                          color: AppColors.destructive,
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
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.xs),
              Text(desc,
                  style: AppTextStyles.bodySmall),
            ],
          ),
        );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('字段说明',
            style: TextStyle(color: AppColors.onBackground)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item('评分（圆形徽章）',
                  '反弹综合强度分 0-100，越高越强。由下跌幅度、拉回力度、速度等加权得出；≥70 金、≥40 橙、<40 灰。'),
              item('跌幅 ▼×ATR',
                  '下跌段的幅度，用 ATR（平均真实波幅）倍数表示，如 2.5×ATR。用波动率归一化，跨币可比。▼ 为下跌标记（与颜色冗余，色盲友好）。'),
              item('回补 ▲%',
                  '从反弹低点回升的比例（0-100%）。越高表示反弹力度越强、收复跌幅越多。▲ 为回升标记。'),
              item('sparkline 折线',
                  '该币最近收盘价走势（涨金跌红，无轴/网格）。一眼判断反弹形态。'),
              item('死猫风险（图标）',
                  '死猫反弹（虚假反弹）概率 0-100。≥70 红骷髅高风险、≥40 橙警告、<40 金勾较安全。基于跌幅深度、是否放量、所处支撑位等判断。'),
              item('止损参考位',
                  '反弹起点的 swing low（近期低点），作为参考止损价。跌破该位则反弹逻辑失效。窄屏会自动隐藏，可在 K 线详情页查看。'),
              const SizedBox(height: 6),
              Text(
                  '注：当前为测试期宽松参数（LOOSE_PARAMS），门槛大幅降低，候选偏多、质量偏低，正式阈值待 Phase 6 回测校准。',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.warning)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('明白了',
                style: TextStyle(color: AppColors.info)),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: const Text(
        '历史回测需打 30-50% 折扣，不构成投资建议',
        style: AppTextStyles.bodySmall,
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
        const SizedBox(height: AppSpacing.xs),
        Text(label,
            style: AppTextStyles.labelSmall),
      ],
    ),
  );
}

class _SignalRow extends StatelessWidget {
  final ReboundSignal signal;

  const _SignalRow({required this.signal});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 按卡内可用宽度决定列裁剪；sparkline 用 Expanded 填充剩余空间，
        // 结构性保证任意屏宽（含 360px）不溢出（per ReboundSignalLayout.resolve）。
        final layout = ReboundSignalLayout.resolve(constraints.maxWidth);
        return GestureDetector(
          onTap: () => _navigateToKline(context),
          child: Card(
            color: AppColors.surface,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2, horizontal: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 币种
                  SizedBox(
                    width: 40,
                    child: Text(
                      signal.symbol.replaceAll('USDT', ''),
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // 触发时间（K 线收盘时间）
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${signal.timestamp.hour.toString().padLeft(2, '0')}:'
                      '${signal.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // 评分
                  _labeled(_ScoreBadge(score: signal.score), '评分', 40),
                  const SizedBox(width: AppSpacing.xs),
                  // 跌幅（▼ 形状冗余 + 红色，色盲友好）
                  _labeled(
                    Text('▼${signal.dropMagnitude.toStringAsFixed(1)}×ATR',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.destructive),
                        softWrap: false,
                        overflow: TextOverflow.fade),
                    '跌幅',
                    56,
                  ),
                  // 回补%（▲ 形状冗余 + 金色，色盲友好）
                  _labeled(
                    Text('▲${(signal.recoveryRatio * 100).toStringAsFixed(0)}%',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.success),
                        softWrap: false,
                        overflow: TextOverflow.fade),
                    '回补',
                    42,
                  ),
                  // 死猫风险（图标本身即形状冗余）
                  _labeled(
                      _DeadCatIndicator(score: signal.deadCatRiskScore), '死猫', 30),
                  // 止损参考位（窄屏裁剪；K 线详情页仍可见）
                  if (layout.showStoploss) ...[
                    const SizedBox(width: 2),
                    _labeled(
                      Text(signal.swingLowPrice.toStringAsFixed(3),
                          style: AppTextStyles.labelSmall
                              .copyWith(fontSize: 10)),
                      '止损',
                      46,
                    ),
                  ],
                  // 弹性区：sparkline 用 Expanded 填充剩余空间（永不溢出、永不塌缩）；
                  // 无 sparkline 档用 Spacer 把核心列左对齐。
                  if (layout.showSparkline)
                    Expanded(
                      child: _MiniSparkline(
                        symbol: signal.symbol,
                        timeframe: signal.timeframe,
                        placeholderWidth: layout.sparklineMin,
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToKline(BuildContext context) {
    // 计算高亮窗口时间戳
    final tfMs = _tfDurationMs(signal.timeframe);
    final totalKlines = signal.recoveryEndIndex - signal.dropStartIndex + 1;
    final highlightStartMs =
        signal.timestamp.millisecondsSinceEpoch - totalKlines * tfMs;
    final highlightEndMs = signal.timestamp.millisecondsSinceEpoch;
    // 下跌段结束（swing low）时间戳 → 作为红下跌/绿回补两段标注的分界。
    final highlightDropEndMs = highlightStartMs +
        (signal.dropEndIndex - signal.dropStartIndex + 1) * tfMs;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KlineScreen(
        symbol: signal.symbol,
        defaultInterval: signal.timeframe,
        highlightStartMs: highlightStartMs,
        highlightDropEndMs: highlightDropEndMs,
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
    if (score >= 70) return AppColors.success; // 金（强）
    if (score >= 40) return AppColors.warning; // 橙（中）
    return AppColors.textDisabled; // 灰（弱）
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
        style: AppTextStyles.bodySmall
            .copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 死猫反弹风险标注（三档不同图标，形状冗余天然存在）。
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
          child: Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
        ),
      );
    }
    // score < 40: 低风险，显示金色勾
    return const SizedBox(
      width: 32,
      child: Icon(Icons.check_circle_outline,
          color: AppColors.success, size: 18),
    );
  }
}

/// 迷你 sparkline 折线图。
///
/// 宽度由父级（[ReboundDashboardScreen] 信号行的 `Expanded`）决定——本组件用
/// `width: double.infinity` 填满父约束，故随屏宽自适应、永不溢出。
/// [placeholderWidth] 仅用于 closes 数据不足时的空态占位，防该列塌缩。
class _MiniSparkline extends StatelessWidget {
  final String symbol;
  final String timeframe;
  final double placeholderWidth;

  const _MiniSparkline({
    required this.symbol,
    required this.timeframe,
    this.placeholderWidth = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      width: double.infinity,
      child: Consumer<ReboundScoreProvider>(
        builder: (context, provider, _) {
          final closes = provider.getRecentCloses(symbol, timeframe);
          if (closes == null || closes.length < 2) {
            return SizedBox(width: placeholderWidth, height: 40);
          }

          final isUp = closes.last > closes.first;
          final lineColor =
              isUp ? AppColors.success : AppColors.destructive;
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
