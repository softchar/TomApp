import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/funding_rate.dart';
import '../services/binance_api_service.dart';

/// 定时通知服务 - 每分钟检查资费，对1小时资费间隔的合约发送通知
/// 每分钟检查一次，找出所有1小时资费间隔的合约并发送系统通知
/// 支持后台运行
class PopupAlertService {
  static final PopupAlertService _instance = PopupAlertService._internal();
  factory PopupAlertService() => _instance;
  PopupAlertService._internal();

  final BinanceApiService _apiService = BinanceApiService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 定时器：每分钟执行一次
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
    _scheduleNextMinuteCheck();
  }

  /// 安排下一次每分钟检查
  void _scheduleNextMinuteCheck() {
    _scheduleTimer?.cancel();
    // 每分钟执行一次
    _scheduleTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _performMinuteCheck();
    });

    print('[PopupAlertService] 已启动每分钟检查任务');
  }

  /// 执行每分钟检查
  Future<void> _performMinuteCheck() async {
    print('[PopupAlertService] 开始每分钟检查... ${DateTime.now().toLocal()}');
    try {
      final rates = await _apiService.getUSDTFuturesRates();
      final oneHourContracts = <FundingRate>[];

      // 找出所有1小时资费间隔的合约
      for (final rate in rates) {
        if (rate.fundingIntervalHours == 1) {
          oneHourContracts.add(rate);
        }
      }

      // 如果有1小时资费合约，发送通知
      if (oneHourContracts.isNotEmpty) {
        _sendOneHourContractNotifications(oneHourContracts);
      } else {
        print('[PopupAlertService] 当前没有1小时资费间隔的合约');
      }
    } catch (e) {
      print('[PopupAlertService] 检查失败: $e');
    }
  }

  /// 发送1小时资费合约通知
  void _sendOneHourContractNotifications(List<FundingRate> contracts) {
    print('[PopupAlertService] 发送 ${contracts.length} 个1小时资费合约通知');

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

    // 为每个合约发送通知
    for (int i = 0; i < contracts.length; i++) {
      final contract = contracts[i];
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000 + i;

      _notifications.show(
        notificationId,
        '1小时资费合约 [${i + 1}/${contracts.length}]',
        '${contract.symbol}\n费率: ${contract.fundingRatePercent} | 标记费率: ${contract.markPrice}',
        platformChannelSpecifics,
        payload: contract.symbol,
      );

      print('[PopupAlertService] 已发送通知: ${contract.symbol} 费率 ${contract.fundingRatePercent}');
    }
  }

  /// 手动触发检查（用于测试）
  Future<void> testCheck() async {
    print('[PopupAlertService] 手动触发检查');
    await _performMinuteCheck();
  }

  /// 停止服务
  void dispose() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
  }
}
