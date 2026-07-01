import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/models/rebound_notification_record.dart';

void main() {
  group('ReboundNotificationRecord', () {
    test('fromRow 解析所有字段', () {
      final row = <String, Object?>{
        'id': 7,
        'symbol': 'BTCUSDT',
        'timeframe': '15m',
        'score': 85,
        'deadCatRiskScore': 10,
        'dropMagnitude': 3.2,
        'recoveryRatio': 0.75,
        'notifiedAt': 1719705600000,
      };
      final r = ReboundNotificationRecord.fromRow(row);

      expect(r.id, 7);
      expect(r.symbol, 'BTCUSDT');
      expect(r.timeframe, '15m');
      expect(r.score, 85);
      expect(r.deadCatRiskScore, 10);
      expect(r.dropMagnitude, 3.2);
      expect(r.recoveryRatio, 0.75);
      expect(r.notifiedAt.millisecondsSinceEpoch, 1719705600000);
    });
  });
}
