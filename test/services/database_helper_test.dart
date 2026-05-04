import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/database_helper.dart';

void main() {
  group('DatabaseHelper', () {
    test('instance returns singleton', () {
      final helper1 = DatabaseHelper.instance;
      final helper2 = DatabaseHelper.instance;
      expect(identical(helper1, helper2), true);
    });

    test('databaseVersion is defined', () {
      expect(DatabaseHelper.currentVersion, 3);
    });
  });
}
