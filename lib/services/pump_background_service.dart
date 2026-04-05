import 'package:flutter_background_service/flutter_background_service.dart';

class PumpBackgroundService {
  static final PumpBackgroundService _instance = PumpBackgroundService._internal();
  static PumpBackgroundService get instance => _instance;

  factory PumpBackgroundService() => _instance;

  PumpBackgroundService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<bool> get isRunning async => await _service.isRunning();

  Future<void> initialize({
    required Future<void> Function(ServiceInstance service) onStart,
  }) async {
    await _service.configure(
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: (service) async {
          return true;
        },
        autoStart: false,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
        initialNotificationTitle: '----------',
        initialNotificationContent: '后台任务运行中...',
      ),
    );
  }

  Future<void> start() async {
    await _service.startService();
    // 给服务一点时间启动
    await Future.delayed(const Duration(milliseconds: 500));
    final running = await isRunning;
    if (running) {
      print('✅ PumpBackgroundService 成功启动');
    } else {
      print('❌ PumpBackgroundService 启动失败');
    }
  }

  Future<void> stop() async {
    _service.invoke('stop');
  }
}
