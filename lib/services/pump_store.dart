import 'package:flutter/foundation.dart';
import 'package:tomapp/models/pump_model.dart';

class PumpStore extends ChangeNotifier {
  final List<PumpModel> _pumps = [];
  static const int _maxPumps = 50;

  List<PumpModel> get pumps => List.unmodifiable(_pumps);

  void addPump(PumpModel pump) {
    _pumps.add(pump);

    if (_pumps.length > _maxPumps) {
      _pumps.removeAt(0);
    }

    notifyListeners();
  }

  void clear() {
    _pumps.clear();
    notifyListeners();
  }

  int todayPumpCount(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _pumps.where((p) {
      return p.triggerTime.isAfter(startOfDay) && p.triggerTime.isBefore(endOfDay);
    }).length;
  }
}
