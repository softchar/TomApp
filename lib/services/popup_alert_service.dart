import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/funding_rate.dart';
import '../services/binance_api_service.dart';

/// 定时通知服务 - 在整点检查资费间隔变化，如果变成1小时则发送通知
/// 每个整点检查一次，如果发现变化则每隔10秒通知一次，共5次
/// 支持后台运行
class PopupAlertService {
  static final PopupAlertService _instance = PopupAlertService._internal();
  factory PopupAlertService() => _instance;
  PopupAlertService._internal();

  final BinanceApiService _apiService = BinanceApiService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 存储上次的资费间隔信息
  final Map<String, int> _lastIntervals = {};

  // 定时器：用于计算到下一个整点的时间
  Timer? _scheduleTimer;

  bool _initialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化时区数据
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (kDebugMode) {
          print('[PopupAlertService] Notification clicked: ${details.payload}');
        }
      },
    );

    _initialized = true;
    _scheduleNextHourCheck();
  }

  /// 安排下一次整点检查
  void _scheduleNextHourCheck() {
    // 计算到下一个整点的时间
    final now = DateTime.now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final delay = nextHour.difference(now);

    _scheduleTimer?.cancel();
    _scheduleTimer = Timer(delay, () {
      // 到达整点，执行检查
      _performHourlyCheck();
      // 安排下一次检查
      _scheduleNextHourCheck();
    });

    print('[PopupAlertService] 已安排下次检查: ${nextHour.hour}:00 (等待 ${delay.inMinutes} 分钟)');
  }

  /// 执行整点检查
  Future<void> _performHourlyCheck() async {
    print('[PopupAlertService] 开始整点检查...');
    try {
      final rates = await _apiService.getUSDTFuturesRates();
      final oneHourContracts = <FundingRate>[];

      for (final rate in rates) {
        final lastInterval = _lastIntervals[rate.symbol];

        // 如果之前不是1小时，现在是1小时，需要通知
        if (rate.fundingIntervalHours == 1 &&
            lastInterval != null &&
            lastInterval != 1) {
          oneHourContracts.add(rate);
          print('[PopupAlertService] 发现变化: ${rate.symbol} 从 $lastInterval 小时变为 1 小时');
        }

        // 更新记录
        _lastIntervals[rate.symbol] = rate.fundingIntervalHours;
      }

      // 如果有需要提醒的合约，开始通知序列
      if (oneHourContracts.isNotEmpty) {
        _scheduleNotificationSequence(oneHourContracts);
      } else {
        print('[PopupAlertService] 没有发现资费间隔变化');
      }
    } catch (e) {
      print('[PopupAlertService] 检查失败: $e');
    }
  }

  /// 安排通知序列（每隔10秒通知一次，共5次）
  void _scheduleNotificationSequence(List<FundingRate> alerts) {
    print('[PopupAlertService] 开始安排通知序列，共 ${alerts.length} 个合约需要提醒');

    // 对每个需要提醒的合约，安排5次通知
    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      final baseTime = DateTime.now();

      for (int j = 0; j < 5; j++) {
        final notificationTime = baseTime.add(Duration(seconds: j * 10));
        final notificationId = _generateNotificationId(alert.symbol, j);

        _scheduleNotification(
          id: notificationId,
          title: '资费提醒 #${j + 1}/5',
          body: '${alert.symbol} 资费间隔已变为1小时！\n当前费率: ${alert.fundingRatePercent}',
          scheduledTime: notificationTime,
          payload: alert.symbol,
        );

        print('[PopupAlertService] 已安排通知: ${alert.symbol} #${j + 1}/5 at ${notificationTime.second}秒');
      }
    }
  }

  /// 生成唯一的通知ID
  int _generateNotificationId(String symbol, int index) {
    // 使用symbol的hashCode和index组合生成唯一ID
    return symbol.hashCode * 10 + index;
  }

  /// 安排单个通知
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'funding_rate_alert_channel',
      '资费变化提醒',
      channelDescription: '资金费率间隔变化时的重要提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print('[PopupAlertService] 已安排通知 #$id: $title');
  }

  /// 手动触发检查（用于测试）
  Future<void> testCheck() async {
    print('[PopupAlertService] 手动触发检查');
    await _performHourlyCheck();
  }

  /// 停止服务
  void dispose() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
  }
}
