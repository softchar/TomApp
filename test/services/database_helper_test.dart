import 'package:flutter_test/flutter_test.dart';
import 'package:tomapp/services/database_helper.dart';

void main() {
  group('DatabaseHelper', () {
    test('instance returns singleton', () {
      expect(identical(DatabaseHelper.instance, DatabaseHelper.instance), true);
    });

    // v5：新增 rebound_notifications 表（反弹通知历史）。
    // v6：新增 rebound_signals 表（看板列表信号持久化）。
    // 注：实际 migration 建表依赖 sqflite 原生，桌面 ffi 环境在本机不可用，
    // 故只断言 version 常量；建表正确性靠代码审查 + 真机首次启动验证。
    test('databaseVersion is v6（含反弹通知历史表 + 列表信号表）', () {
      expect(DatabaseHelper.currentVersion, 6);
    });
  });
}
