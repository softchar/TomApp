import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/funding_rate.dart';

/// 通知服务 - 检测资费间隔变化并发送通知
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 存储上次的资费间隔信息
  final Map<String, int> _lastIntervals = {};

  bool _initialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化时区数据
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (kDebugMode) {
          print('Notification clicked: ${details.payload}');
        }
      },
    );

    _initialized = true;
  }

  /// 检查资费间隔变化并发送通知
  /// 当检测到某个合约的资费间隔变成1小时时发送通知
  Future<void> checkIntervalChanges(List<FundingRate> rates) async {
    if (!_initialized) {
      await initialize();
    }

    // 筛选出1小时间隔的合约
    final oneHourContracts = rates.where((r) => r.fundingIntervalHours == 1).toList();

    for (final rate in oneHourContracts) {
      final lastInterval = _lastIntervals[rate.symbol];

      // 如果之前不是1小时，现在是1小时，发送通知
      if (lastInterval != null && lastInterval != 1) {
        await _sendOneHourNotification(rate);
      }

      // 更新记录
      _lastIntervals[rate.symbol] = rate.fundingIntervalHours;
    }

    // 同时记录其他合约的间隔
    for (final rate in rates) {
      if (!_lastIntervals.containsKey(rate.symbol)) {
        _lastIntervals[rate.symbol] = rate.fundingIntervalHours;
      }
    }
  }

  /// 发送1小时间隔通知
  Future<void> _sendOneHourNotification(FundingRate rate) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'funding_rate_channel',
      '资费提醒',
      channelDescription: '资金费率间隔变化提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '发现1小时资费合约！',
      '${rate.symbol} 的资费间隔已变为1小时\n当前费率: ${rate.fundingRatePercent}',
      platformChannelSpecifics,
      payload: rate.symbol,
    );
  }

  /// 发送自定义通知
  Future<void> show(int id, String title, String body) async {
    if (!_initialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'funding_rate_channel',
      '资费提醒',
      channelDescription: '资金费率间隔变化提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  /// 发送测试通知
  Future<void> sendTestNotification() async {
    if (!_initialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'funding_rate_channel',
      '资费提醒',
      channelDescription: '资金费率间隔变化提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      0,
      '通知测试',
      '资费提醒功能正常工作',
      platformChannelSpecifics,
    );
  }

  /// 清除所有通知
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
