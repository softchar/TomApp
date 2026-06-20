import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'package:tomapp/models/backtest_config.dart';
import 'package:tomapp/models/backtest_report.dart';
import 'package:tomapp/models/backtest_status.dart';
import 'package:tomapp/models/kline_data.dart';
import 'package:tomapp/services/drift_database.dart';
import 'package:tomapp/services/rebound/backtest_engine.dart';
import 'package:tomapp/services/rebound/data_import_service.dart';
import 'package:tomapp/services/rebound/rebound_detector.dart';
import 'package:tomapp/services/rebound/trade_simulator.dart';
import 'package:tomapp/services/rebound/walk_forward.dart';
import 'package:tomapp/services/technical_indicators.dart';

/// 回测状态管理 Provider（ChangeNotifier）。
///
/// 管理回测生命周期状态机 idle → running → complete|error，
/// 包含输入验证、重入守卫、进度追踪、取消和清除功能。
class BacktestProvider extends ChangeNotifier {
  // ─── 状态字段 ────────────────────────────────────────────
  BacktestStatus _status = BacktestStatus.idle;
  BacktestConfig _config = BacktestConfig.defaults();
  BacktestReport? _report;
  String? _errorMessage;
  int _currentFold = 0;
  final int _totalFolds = 3;
  int _completedCombos = 0;
  final int _totalCombos = 320;
  bool _cancelled = false;

  // ─── 公开 getter ─────────────────────────────────────────
  BacktestStatus get status => _status;
  BacktestConfig get config => _config;
  BacktestReport? get report => _report;
  String? get errorMessage => _errorMessage;
  int get currentFold => _currentFold;
  int get totalFolds => _totalFolds;
  int get completedCombos => _completedCombos;
  int get totalCombos => _totalCombos;

  // ─── 公开方法 ────────────────────────────────────────────

  /// 启动回测运行。
  ///
  /// 包含输入验证、标的获取、数据导入、Walk-Forward 参数扫描。
  /// running 状态下重复调用会被重入守卫拦截。
  Future<void> runBacktest() async {
    // 重入守卫：正在运行时忽略重复调用
    if (_status == BacktestStatus.running) {
      debugPrint('[BacktestProvider] 回测已在运行中，忽略重复调用');
      return;
    }

    // 输入验证：起始日期必须早于结束日期
    if (_config.startDate.isAfter(_config.endDate) ||
        _config.startDate.isAtSameMomentAs(_config.endDate)) {
      _status = BacktestStatus.error;
      _errorMessage = '起始日期必须早于结束日期';
      notifyListeners();
      return;
    }

    // 输入验证：日期范围最多 365 天
    if (_config.endDate.difference(_config.startDate).inDays > 365) {
      _status = BacktestStatus.error;
      _errorMessage = '回测时间范围最多 365 天';
      notifyListeners();
      return;
    }

    // 输入验证：起始日期不早于 2020-01-01
    if (_config.startDate.isBefore(DateTime(2020, 1, 1))) {
      _status = BacktestStatus.error;
      _errorMessage = '起始日期不能早于 2020-01-01';
      notifyListeners();
      return;
    }

    _status = BacktestStatus.running;
    _cancelled = false;
    _report = null;
    _errorMessage = null;
    _currentFold = 0;
    _completedCombos = 0;
    notifyListeners();

    AppDatabase? db;
    try {
      // 获取标的列表：若为空则从 Binance 拉取 Top-100
      if (_config.symbols.isEmpty) {
        final symbols =
            await DataImportService().fetchTopSymbols(count: 100);
        _config = _config.copyWith(symbols: symbols);
        notifyListeners();
      }

      // 数据导入：连接 drift 数据库并导入历史 K 线
      final dbPath = p.join(await getDatabasesPath(), 'tomapp.db');
      db = AppDatabase(NativeDatabase(File(dbPath)));

      final insertedCount = await DataImportService().importHistoricalData(
        db: db,
        config: _config,
      );

      if (_cancelled) {
        _status = BacktestStatus.idle;
        notifyListeners();
        await db.close();
        db = null; // 防止 finally 块 double-close（CR-01）
        return;
      }

      if (insertedCount == 0) {
        _status = BacktestStatus.error;
        _errorMessage = '未获取到任何历史 K 线数据';
        notifyListeners();
        await db.close();
        db = null; // 防止 finally 块 double-close（CR-01）
        return;
      }

      // 从数据库读取 K 线数据（仅 15m 周期）
      final allKlines = <KlineData>[];
      for (final symbol in _config.symbols) {
        if (_cancelled) {
          _status = BacktestStatus.idle;
          notifyListeners();
          await db!.close();
          db = null; // 防止 finally 块 double-close（CR-01）
          return;
        }

        final rows = await (db!.select(db.klines)
              ..where((t) => t.symbol.equals(symbol))
              ..where((t) => t.interval.equals('15m'))
              ..orderBy([(t) => OrderingTerm(expression: t.openTime)]))
            .get();

        for (final row in rows) {
          allKlines.add(KlineData(
            time: DateTime.fromMillisecondsSinceEpoch(row.openTime),
            open: row.open,
            high: row.high,
            low: row.low,
            close: row.close,
            volume: row.volume,
          ));
        }
      }

      await db!.close();
      db = null;

      if (_cancelled) {
        _status = BacktestStatus.idle;
        notifyListeners();
        return;
      }

      if (allKlines.isEmpty) {
        _status = BacktestStatus.error;
        _errorMessage = '未获取到任何历史 K 线数据';
        notifyListeners();
        return;
      }

      // 按时间排序
      allKlines.sort((a, b) => a.time.compareTo(b.time));

      // 构建参数网格并运行 Walk-Forward
      final walkForward = WalkForward();
      final paramGrid = walkForward.buildParamGrid();

      final detector = ReboundDetector(TechnicalIndicators());
      final tradeSimulator = TradeSimulator();
      final engine = BacktestEngine(
        detector: detector,
        tradeSimulator: tradeSimulator,
      );

      final folds = await walkForward.runWalkForward(
        allKlines: allKlines,
        paramGrid: paramGrid,
        engine: engine,
        config: _config,
      );

      if (_cancelled) {
        _status = BacktestStatus.idle;
        notifyListeners();
        return;
      }

      // 聚合 Out-of-Sample 指标
      _report = walkForward.aggregateOutOfSample(folds, _config);
      _status = BacktestStatus.complete;
      notifyListeners();
    } on Exception catch (e) {
      _status = BacktestStatus.error;
      _errorMessage = '${e.runtimeType}: $e';
      notifyListeners();
    } finally {
      await db?.close();
    }
  }

  /// 取消正在运行的回测。
  ///
  /// 设置 _cancelled 标记，引擎在每次 fold 组合完成后检查并提前终止。
  void cancelBacktest() {
    if (_status == BacktestStatus.running) {
      _cancelled = true;
    }
  }

  /// 清除回测结果。
  ///
  /// 仅在 complete 或 error 状态下可清除；running 时忽略。
  void clearResults() {
    if (_status == BacktestStatus.running) return;
    _report = null;
    _errorMessage = null;
    _status = BacktestStatus.idle;
    _currentFold = 0;
    _completedCombos = 0;
    notifyListeners();
  }

  /// 更新回测配置。
  ///
  /// 仅在非 running 状态下允许修改。
  void updateConfig(BacktestConfig newConfig) {
    if (_status == BacktestStatus.running) return;
    _config = newConfig;
    notifyListeners();
  }
}
