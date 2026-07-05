import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:tomapp/models/alert_level.dart';
import 'package:tomapp/utils/app_navigation.dart';

/// 反弹信号通知服务——多渠道 Android 通知创建与分发。
///
/// 与现有 [NotificationService]（funding_rate_channel + pump_alerts）
/// 完全独立——各自持有 [FlutterLocalNotificationsPlugin] 实例，
/// 渠道 ID 命名空间隔离（rebound_high / rebound_med vs
/// funding_rate_channel），互不干扰。
///
/// ## 渠道分级
/// - **rebound_high**: `Importance.max` + 响铃 + 振动 + heads-up
/// - **rebound_med**: `Importance.defaultImportance` + 声音（无振动）
/// - **low**: 不创建渠道——仅看板可见，dispatch() 入口直接 return
class ReboundNotificationService {
  // ── 渠道 ID 常量 ────────────────────────────────────────
  static const String _highChannelId = 'rebound_high';
  static const String _medChannelId = 'rebound_med';

  // ── 渠道名称/描述（中文） ────────────────────────────────
  static const String _highChannelName = '反弹强信号';
  static const String _highChannelDesc = '高分反弹监控候选——响铃+震动提醒';
  static const String _medChannelName = '反弹提示';
  static const String _medChannelDesc = '中等反弹监控候选——横幅提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── 公开 API ──────────────────────────────────────────

  /// 初始化通知插件并创建 Android 渠道。
  ///
  /// **幂等性**：重复调用不重建渠道，
  /// [AndroidFlutterLocalNotificationsPlugin.createNotificationChannel]
  /// 在渠道已存在时自动跳过。
  Future<void> initialize() async {
    if (_initialized) return;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      // 非 Android 平台（iOS 测试 / 桌面）——渠道创建为 no-op
      return;
    }

    // 创建 high 渠道：Importance.max + 振动 + heads-up
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _highChannelId,
        _highChannelName,
        description: _highChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ),
    );

    // 创建 med 渠道：Importance.defaultImportance + 声音无振动
    // ignore: prefer_const_constructors
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _medChannelId,
        _medChannelName,
        description: _medChannelDesc,
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: false,
      ),
    );

    // 初始化 plugin（设置通知点击回调）
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (kDebugMode) {
          debugPrint('反弹通知点击: ${details.payload}');
        }
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          // T-05-05: payload 仅含 symbol 字符串，跳转前校验格式
          if (_isValidSymbol(payload)) {
            AppNavigation.navigateToKline(payload);
          }
        }
      },
    );

    // 请求通知权限（Android 13+ 需运行时请求；iOS 在 show 时触发）。
    // 已授权则 no-op；首次会弹系统权限对话框。
    await android.requestNotificationsPermission();

    _initialized = true;
  }

  /// 按 [AlertDecision.level] 分发通知到对应渠道。
  ///
  /// - [AlertLevel.high] → `rebound_high` 渠道（响铃+振动+heads-up）
  /// - [AlertLevel.medium] → `rebound_med` 渠道（横幅+声音）
  /// - [AlertLevel.low] → 直接 return（仅看板可见，不推送）
  Future<void> dispatch(AlertDecision decision) async {
    // low 级别不推送——仅看板可见，无需初始化通知渠道
    if (decision.level == AlertLevel.low) {
      return;
    }

    if (!_initialized) {
      await initialize();
    }

    final isHigh = decision.level == AlertLevel.high;
    final channelId = isHigh ? _highChannelId : _medChannelId;
    final channelName = isHigh ? _highChannelName : _medChannelName;
    final channelDesc = isHigh ? _highChannelDesc : _medChannelDesc;
    final importance = isHigh ? Importance.max : Importance.defaultImportance;
    final priority = isHigh ? Priority.high : Priority.defaultPriority;
    final vibrate = isHigh;
    final visibility = isHigh
        ? NotificationVisibility.public
        : NotificationVisibility.private;

    final title = _buildTitle(decision);
    final body = _buildBody(decision);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      enableVibration: vibrate,
      icon: '@mipmap/ic_launcher',
      visibility: visibility,
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      decision.symbol.hashCode,
      title,
      body,
      details,
      payload: decision.symbol,
    );
  }

  // ── 私有方法 ──────────────────────────────────────────

  /// 构造通知标题。
  ///
  /// 单周期：`"{SYMBOL} {TIMEFRAME} 反弹监控候选"`
  /// 多周期归并：`"{SYMBOL} 多周期共振 反弹监控候选"`
  String _buildTitle(AlertDecision decision) {
    if (decision.coalescedTimeframes.length > 1) {
      return '${decision.symbol} 多周期共振 反弹监控候选';
    }
    final tf = decision.coalescedTimeframes.isNotEmpty
        ? decision.coalescedTimeframes.first
        : decision.signal.timeframe;
    return '$tf ${decision.symbol} 反弹监控候选';
  }

  /// 构造通知正文。
  ///
  /// 格式：`"评分 {score} | 跌幅 {dropMagnitude}×ATR | 回补 {recoveryPercent}%"`
  String _buildBody(AlertDecision decision) {
    final signal = decision.signal;
    final recoveryPercent =
        (signal.recoveryRatio * 100).toStringAsFixed(0);
    return '评分 ${signal.score} | '
        '跌幅 ${signal.dropMagnitude.toStringAsFixed(1)}×ATR | '
        '回补 $recoveryPercent%';
  }

  /// T-05-05: 验证 symbol 格式。
  ///
  /// 仅允许大写字母+数字，长度 5-20（如 BTCUSDT）。
  /// 不匹配的 payload 拒绝跳转——防 payload 注入导致的任意导航。
  bool _isValidSymbol(String symbol) {
    final regex = RegExp(r'^[A-Z0-9]{5,20}$');
    return regex.hasMatch(symbol);
  }

  /// 供测试环境调用的内部初始化标志重置。
  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
  }
}
