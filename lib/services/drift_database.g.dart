// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_database.dart';

// ignore_for_file: type=lint
class $KlinesTable extends Klines with TableInfo<$KlinesTable, Kline> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KlinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
      'symbol', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _intervalMeta =
      const VerificationMeta('interval');
  @override
  late final GeneratedColumn<String> interval = GeneratedColumn<String>(
      'interval', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _openTimeMeta =
      const VerificationMeta('openTime');
  @override
  late final GeneratedColumn<int> openTime = GeneratedColumn<int>(
      'open_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<double> open = GeneratedColumn<double>(
      'open', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _highMeta = const VerificationMeta('high');
  @override
  late final GeneratedColumn<double> high = GeneratedColumn<double>(
      'high', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _lowMeta = const VerificationMeta('low');
  @override
  late final GeneratedColumn<double> low = GeneratedColumn<double>(
      'low', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _closeMeta = const VerificationMeta('close');
  @override
  late final GeneratedColumn<double> close = GeneratedColumn<double>(
      'close', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
      'volume', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _closeTimeMeta =
      const VerificationMeta('closeTime');
  @override
  late final GeneratedColumn<int> closeTime = GeneratedColumn<int>(
      'close_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [symbol, interval, openTime, open, high, low, close, volume, closeTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'klines';
  @override
  VerificationContext validateIntegrity(Insertable<Kline> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('symbol')) {
      context.handle(_symbolMeta,
          symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta));
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(_intervalMeta,
          interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta));
    } else if (isInserting) {
      context.missing(_intervalMeta);
    }
    if (data.containsKey('open_time')) {
      context.handle(_openTimeMeta,
          openTime.isAcceptableOrUnknown(data['open_time']!, _openTimeMeta));
    } else if (isInserting) {
      context.missing(_openTimeMeta);
    }
    if (data.containsKey('open')) {
      context.handle(
          _openMeta, open.isAcceptableOrUnknown(data['open']!, _openMeta));
    } else if (isInserting) {
      context.missing(_openMeta);
    }
    if (data.containsKey('high')) {
      context.handle(
          _highMeta, high.isAcceptableOrUnknown(data['high']!, _highMeta));
    } else if (isInserting) {
      context.missing(_highMeta);
    }
    if (data.containsKey('low')) {
      context.handle(
          _lowMeta, low.isAcceptableOrUnknown(data['low']!, _lowMeta));
    } else if (isInserting) {
      context.missing(_lowMeta);
    }
    if (data.containsKey('close')) {
      context.handle(
          _closeMeta, close.isAcceptableOrUnknown(data['close']!, _closeMeta));
    } else if (isInserting) {
      context.missing(_closeMeta);
    }
    if (data.containsKey('volume')) {
      context.handle(_volumeMeta,
          volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta));
    } else if (isInserting) {
      context.missing(_volumeMeta);
    }
    if (data.containsKey('close_time')) {
      context.handle(_closeTimeMeta,
          closeTime.isAcceptableOrUnknown(data['close_time']!, _closeTimeMeta));
    } else if (isInserting) {
      context.missing(_closeTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {symbol, interval, openTime};
  @override
  Kline map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Kline(
      symbol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}symbol'])!,
      interval: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}interval'])!,
      openTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}open_time'])!,
      open: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}open'])!,
      high: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}high'])!,
      low: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}low'])!,
      close: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}close'])!,
      volume: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}volume'])!,
      closeTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}close_time'])!,
    );
  }

  @override
  $KlinesTable createAlias(String alias) {
    return $KlinesTable(attachedDatabase, alias);
  }
}

class Kline extends DataClass implements Insertable<Kline> {
  final String symbol;
  final String interval;
  final int openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final int closeTime;
  const Kline(
      {required this.symbol,
      required this.interval,
      required this.openTime,
      required this.open,
      required this.high,
      required this.low,
      required this.close,
      required this.volume,
      required this.closeTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['symbol'] = Variable<String>(symbol);
    map['interval'] = Variable<String>(interval);
    map['open_time'] = Variable<int>(openTime);
    map['open'] = Variable<double>(open);
    map['high'] = Variable<double>(high);
    map['low'] = Variable<double>(low);
    map['close'] = Variable<double>(close);
    map['volume'] = Variable<double>(volume);
    map['close_time'] = Variable<int>(closeTime);
    return map;
  }

  KlinesCompanion toCompanion(bool nullToAbsent) {
    return KlinesCompanion(
      symbol: Value(symbol),
      interval: Value(interval),
      openTime: Value(openTime),
      open: Value(open),
      high: Value(high),
      low: Value(low),
      close: Value(close),
      volume: Value(volume),
      closeTime: Value(closeTime),
    );
  }

  factory Kline.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Kline(
      symbol: serializer.fromJson<String>(json['symbol']),
      interval: serializer.fromJson<String>(json['interval']),
      openTime: serializer.fromJson<int>(json['openTime']),
      open: serializer.fromJson<double>(json['open']),
      high: serializer.fromJson<double>(json['high']),
      low: serializer.fromJson<double>(json['low']),
      close: serializer.fromJson<double>(json['close']),
      volume: serializer.fromJson<double>(json['volume']),
      closeTime: serializer.fromJson<int>(json['closeTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'symbol': serializer.toJson<String>(symbol),
      'interval': serializer.toJson<String>(interval),
      'openTime': serializer.toJson<int>(openTime),
      'open': serializer.toJson<double>(open),
      'high': serializer.toJson<double>(high),
      'low': serializer.toJson<double>(low),
      'close': serializer.toJson<double>(close),
      'volume': serializer.toJson<double>(volume),
      'closeTime': serializer.toJson<int>(closeTime),
    };
  }

  Kline copyWith(
          {String? symbol,
          String? interval,
          int? openTime,
          double? open,
          double? high,
          double? low,
          double? close,
          double? volume,
          int? closeTime}) =>
      Kline(
        symbol: symbol ?? this.symbol,
        interval: interval ?? this.interval,
        openTime: openTime ?? this.openTime,
        open: open ?? this.open,
        high: high ?? this.high,
        low: low ?? this.low,
        close: close ?? this.close,
        volume: volume ?? this.volume,
        closeTime: closeTime ?? this.closeTime,
      );
  Kline copyWithCompanion(KlinesCompanion data) {
    return Kline(
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      interval: data.interval.present ? data.interval.value : this.interval,
      openTime: data.openTime.present ? data.openTime.value : this.openTime,
      open: data.open.present ? data.open.value : this.open,
      high: data.high.present ? data.high.value : this.high,
      low: data.low.present ? data.low.value : this.low,
      close: data.close.present ? data.close.value : this.close,
      volume: data.volume.present ? data.volume.value : this.volume,
      closeTime: data.closeTime.present ? data.closeTime.value : this.closeTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Kline(')
          ..write('symbol: $symbol, ')
          ..write('interval: $interval, ')
          ..write('openTime: $openTime, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume, ')
          ..write('closeTime: $closeTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      symbol, interval, openTime, open, high, low, close, volume, closeTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Kline &&
          other.symbol == this.symbol &&
          other.interval == this.interval &&
          other.openTime == this.openTime &&
          other.open == this.open &&
          other.high == this.high &&
          other.low == this.low &&
          other.close == this.close &&
          other.volume == this.volume &&
          other.closeTime == this.closeTime);
}

class KlinesCompanion extends UpdateCompanion<Kline> {
  final Value<String> symbol;
  final Value<String> interval;
  final Value<int> openTime;
  final Value<double> open;
  final Value<double> high;
  final Value<double> low;
  final Value<double> close;
  final Value<double> volume;
  final Value<int> closeTime;
  final Value<int> rowid;
  const KlinesCompanion({
    this.symbol = const Value.absent(),
    this.interval = const Value.absent(),
    this.openTime = const Value.absent(),
    this.open = const Value.absent(),
    this.high = const Value.absent(),
    this.low = const Value.absent(),
    this.close = const Value.absent(),
    this.volume = const Value.absent(),
    this.closeTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KlinesCompanion.insert({
    required String symbol,
    required String interval,
    required int openTime,
    required double open,
    required double high,
    required double low,
    required double close,
    required double volume,
    required int closeTime,
    this.rowid = const Value.absent(),
  })  : symbol = Value(symbol),
        interval = Value(interval),
        openTime = Value(openTime),
        open = Value(open),
        high = Value(high),
        low = Value(low),
        close = Value(close),
        volume = Value(volume),
        closeTime = Value(closeTime);
  static Insertable<Kline> custom({
    Expression<String>? symbol,
    Expression<String>? interval,
    Expression<int>? openTime,
    Expression<double>? open,
    Expression<double>? high,
    Expression<double>? low,
    Expression<double>? close,
    Expression<double>? volume,
    Expression<int>? closeTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (symbol != null) 'symbol': symbol,
      if (interval != null) 'interval': interval,
      if (openTime != null) 'open_time': openTime,
      if (open != null) 'open': open,
      if (high != null) 'high': high,
      if (low != null) 'low': low,
      if (close != null) 'close': close,
      if (volume != null) 'volume': volume,
      if (closeTime != null) 'close_time': closeTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KlinesCompanion copyWith(
      {Value<String>? symbol,
      Value<String>? interval,
      Value<int>? openTime,
      Value<double>? open,
      Value<double>? high,
      Value<double>? low,
      Value<double>? close,
      Value<double>? volume,
      Value<int>? closeTime,
      Value<int>? rowid}) {
    return KlinesCompanion(
      symbol: symbol ?? this.symbol,
      interval: interval ?? this.interval,
      openTime: openTime ?? this.openTime,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      closeTime: closeTime ?? this.closeTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (interval.present) {
      map['interval'] = Variable<String>(interval.value);
    }
    if (openTime.present) {
      map['open_time'] = Variable<int>(openTime.value);
    }
    if (open.present) {
      map['open'] = Variable<double>(open.value);
    }
    if (high.present) {
      map['high'] = Variable<double>(high.value);
    }
    if (low.present) {
      map['low'] = Variable<double>(low.value);
    }
    if (close.present) {
      map['close'] = Variable<double>(close.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (closeTime.present) {
      map['close_time'] = Variable<int>(closeTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KlinesCompanion(')
          ..write('symbol: $symbol, ')
          ..write('interval: $interval, ')
          ..write('openTime: $openTime, ')
          ..write('open: $open, ')
          ..write('high: $high, ')
          ..write('low: $low, ')
          ..write('close: $close, ')
          ..write('volume: $volume, ')
          ..write('closeTime: $closeTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BacktestRunsTable extends BacktestRuns
    with TableInfo<$BacktestRunsTable, BacktestRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BacktestRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _paramsMeta = const VerificationMeta('params');
  @override
  late final GeneratedColumn<String> params = GeneratedColumn<String>(
      'params', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
      'started_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statsMeta = const VerificationMeta('stats');
  @override
  late final GeneratedColumn<String> stats = GeneratedColumn<String>(
      'stats', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, params, startedAt, stats];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backtest_runs';
  @override
  VerificationContext validateIntegrity(Insertable<BacktestRun> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('params')) {
      context.handle(_paramsMeta,
          params.isAcceptableOrUnknown(data['params']!, _paramsMeta));
    } else if (isInserting) {
      context.missing(_paramsMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('stats')) {
      context.handle(
          _statsMeta, stats.isAcceptableOrUnknown(data['stats']!, _statsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BacktestRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BacktestRun(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      params: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}params'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      stats: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stats']),
    );
  }

  @override
  $BacktestRunsTable createAlias(String alias) {
    return $BacktestRunsTable(attachedDatabase, alias);
  }
}

class BacktestRun extends DataClass implements Insertable<BacktestRun> {
  final int id;
  final String params;
  final int startedAt;
  final String? stats;
  const BacktestRun(
      {required this.id,
      required this.params,
      required this.startedAt,
      this.stats});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['params'] = Variable<String>(params);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || stats != null) {
      map['stats'] = Variable<String>(stats);
    }
    return map;
  }

  BacktestRunsCompanion toCompanion(bool nullToAbsent) {
    return BacktestRunsCompanion(
      id: Value(id),
      params: Value(params),
      startedAt: Value(startedAt),
      stats:
          stats == null && nullToAbsent ? const Value.absent() : Value(stats),
    );
  }

  factory BacktestRun.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BacktestRun(
      id: serializer.fromJson<int>(json['id']),
      params: serializer.fromJson<String>(json['params']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      stats: serializer.fromJson<String?>(json['stats']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'params': serializer.toJson<String>(params),
      'startedAt': serializer.toJson<int>(startedAt),
      'stats': serializer.toJson<String?>(stats),
    };
  }

  BacktestRun copyWith(
          {int? id,
          String? params,
          int? startedAt,
          Value<String?> stats = const Value.absent()}) =>
      BacktestRun(
        id: id ?? this.id,
        params: params ?? this.params,
        startedAt: startedAt ?? this.startedAt,
        stats: stats.present ? stats.value : this.stats,
      );
  BacktestRun copyWithCompanion(BacktestRunsCompanion data) {
    return BacktestRun(
      id: data.id.present ? data.id.value : this.id,
      params: data.params.present ? data.params.value : this.params,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      stats: data.stats.present ? data.stats.value : this.stats,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BacktestRun(')
          ..write('id: $id, ')
          ..write('params: $params, ')
          ..write('startedAt: $startedAt, ')
          ..write('stats: $stats')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, params, startedAt, stats);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BacktestRun &&
          other.id == this.id &&
          other.params == this.params &&
          other.startedAt == this.startedAt &&
          other.stats == this.stats);
}

class BacktestRunsCompanion extends UpdateCompanion<BacktestRun> {
  final Value<int> id;
  final Value<String> params;
  final Value<int> startedAt;
  final Value<String?> stats;
  const BacktestRunsCompanion({
    this.id = const Value.absent(),
    this.params = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.stats = const Value.absent(),
  });
  BacktestRunsCompanion.insert({
    this.id = const Value.absent(),
    required String params,
    required int startedAt,
    this.stats = const Value.absent(),
  })  : params = Value(params),
        startedAt = Value(startedAt);
  static Insertable<BacktestRun> custom({
    Expression<int>? id,
    Expression<String>? params,
    Expression<int>? startedAt,
    Expression<String>? stats,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (params != null) 'params': params,
      if (startedAt != null) 'started_at': startedAt,
      if (stats != null) 'stats': stats,
    });
  }

  BacktestRunsCompanion copyWith(
      {Value<int>? id,
      Value<String>? params,
      Value<int>? startedAt,
      Value<String?>? stats}) {
    return BacktestRunsCompanion(
      id: id ?? this.id,
      params: params ?? this.params,
      startedAt: startedAt ?? this.startedAt,
      stats: stats ?? this.stats,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (params.present) {
      map['params'] = Variable<String>(params.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (stats.present) {
      map['stats'] = Variable<String>(stats.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BacktestRunsCompanion(')
          ..write('id: $id, ')
          ..write('params: $params, ')
          ..write('startedAt: $startedAt, ')
          ..write('stats: $stats')
          ..write(')'))
        .toString();
  }
}

class $BacktestTradesTable extends BacktestTrades
    with TableInfo<$BacktestTradesTable, BacktestTrade> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BacktestTradesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<int> runId = GeneratedColumn<int>(
      'run_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES backtest_runs (id) ON DELETE CASCADE'));
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
      'symbol', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entryTimeMeta =
      const VerificationMeta('entryTime');
  @override
  late final GeneratedColumn<int> entryTime = GeneratedColumn<int>(
      'entry_time', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _entryPriceMeta =
      const VerificationMeta('entryPrice');
  @override
  late final GeneratedColumn<double> entryPrice = GeneratedColumn<double>(
      'entry_price', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _exitTimeMeta =
      const VerificationMeta('exitTime');
  @override
  late final GeneratedColumn<int> exitTime = GeneratedColumn<int>(
      'exit_time', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _exitPriceMeta =
      const VerificationMeta('exitPrice');
  @override
  late final GeneratedColumn<double> exitPrice = GeneratedColumn<double>(
      'exit_price', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
      'side', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pnlMeta = const VerificationMeta('pnl');
  @override
  late final GeneratedColumn<double> pnl = GeneratedColumn<double>(
      'pnl', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _rMultipleMeta =
      const VerificationMeta('rMultiple');
  @override
  late final GeneratedColumn<double> rMultiple = GeneratedColumn<double>(
      'r_multiple', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        runId,
        symbol,
        entryTime,
        entryPrice,
        exitTime,
        exitPrice,
        side,
        pnl,
        rMultiple
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backtest_trades';
  @override
  VerificationContext validateIntegrity(Insertable<BacktestTrade> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
          _runIdMeta, runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta));
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(_symbolMeta,
          symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta));
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('entry_time')) {
      context.handle(_entryTimeMeta,
          entryTime.isAcceptableOrUnknown(data['entry_time']!, _entryTimeMeta));
    } else if (isInserting) {
      context.missing(_entryTimeMeta);
    }
    if (data.containsKey('entry_price')) {
      context.handle(
          _entryPriceMeta,
          entryPrice.isAcceptableOrUnknown(
              data['entry_price']!, _entryPriceMeta));
    } else if (isInserting) {
      context.missing(_entryPriceMeta);
    }
    if (data.containsKey('exit_time')) {
      context.handle(_exitTimeMeta,
          exitTime.isAcceptableOrUnknown(data['exit_time']!, _exitTimeMeta));
    }
    if (data.containsKey('exit_price')) {
      context.handle(_exitPriceMeta,
          exitPrice.isAcceptableOrUnknown(data['exit_price']!, _exitPriceMeta));
    }
    if (data.containsKey('side')) {
      context.handle(
          _sideMeta, side.isAcceptableOrUnknown(data['side']!, _sideMeta));
    } else if (isInserting) {
      context.missing(_sideMeta);
    }
    if (data.containsKey('pnl')) {
      context.handle(
          _pnlMeta, pnl.isAcceptableOrUnknown(data['pnl']!, _pnlMeta));
    } else if (isInserting) {
      context.missing(_pnlMeta);
    }
    if (data.containsKey('r_multiple')) {
      context.handle(_rMultipleMeta,
          rMultiple.isAcceptableOrUnknown(data['r_multiple']!, _rMultipleMeta));
    } else if (isInserting) {
      context.missing(_rMultipleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BacktestTrade map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BacktestTrade(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      runId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}run_id'])!,
      symbol: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}symbol'])!,
      entryTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entry_time'])!,
      entryPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}entry_price'])!,
      exitTime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}exit_time']),
      exitPrice: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}exit_price']),
      side: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}side'])!,
      pnl: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}pnl'])!,
      rMultiple: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}r_multiple'])!,
    );
  }

  @override
  $BacktestTradesTable createAlias(String alias) {
    return $BacktestTradesTable(attachedDatabase, alias);
  }
}

class BacktestTrade extends DataClass implements Insertable<BacktestTrade> {
  final int id;
  final int runId;
  final String symbol;
  final int entryTime;
  final double entryPrice;
  final int? exitTime;
  final double? exitPrice;
  final String side;
  final double pnl;
  final double rMultiple;
  const BacktestTrade(
      {required this.id,
      required this.runId,
      required this.symbol,
      required this.entryTime,
      required this.entryPrice,
      this.exitTime,
      this.exitPrice,
      required this.side,
      required this.pnl,
      required this.rMultiple});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_id'] = Variable<int>(runId);
    map['symbol'] = Variable<String>(symbol);
    map['entry_time'] = Variable<int>(entryTime);
    map['entry_price'] = Variable<double>(entryPrice);
    if (!nullToAbsent || exitTime != null) {
      map['exit_time'] = Variable<int>(exitTime);
    }
    if (!nullToAbsent || exitPrice != null) {
      map['exit_price'] = Variable<double>(exitPrice);
    }
    map['side'] = Variable<String>(side);
    map['pnl'] = Variable<double>(pnl);
    map['r_multiple'] = Variable<double>(rMultiple);
    return map;
  }

  BacktestTradesCompanion toCompanion(bool nullToAbsent) {
    return BacktestTradesCompanion(
      id: Value(id),
      runId: Value(runId),
      symbol: Value(symbol),
      entryTime: Value(entryTime),
      entryPrice: Value(entryPrice),
      exitTime: exitTime == null && nullToAbsent
          ? const Value.absent()
          : Value(exitTime),
      exitPrice: exitPrice == null && nullToAbsent
          ? const Value.absent()
          : Value(exitPrice),
      side: Value(side),
      pnl: Value(pnl),
      rMultiple: Value(rMultiple),
    );
  }

  factory BacktestTrade.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BacktestTrade(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<int>(json['runId']),
      symbol: serializer.fromJson<String>(json['symbol']),
      entryTime: serializer.fromJson<int>(json['entryTime']),
      entryPrice: serializer.fromJson<double>(json['entryPrice']),
      exitTime: serializer.fromJson<int?>(json['exitTime']),
      exitPrice: serializer.fromJson<double?>(json['exitPrice']),
      side: serializer.fromJson<String>(json['side']),
      pnl: serializer.fromJson<double>(json['pnl']),
      rMultiple: serializer.fromJson<double>(json['rMultiple']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<int>(runId),
      'symbol': serializer.toJson<String>(symbol),
      'entryTime': serializer.toJson<int>(entryTime),
      'entryPrice': serializer.toJson<double>(entryPrice),
      'exitTime': serializer.toJson<int?>(exitTime),
      'exitPrice': serializer.toJson<double?>(exitPrice),
      'side': serializer.toJson<String>(side),
      'pnl': serializer.toJson<double>(pnl),
      'rMultiple': serializer.toJson<double>(rMultiple),
    };
  }

  BacktestTrade copyWith(
          {int? id,
          int? runId,
          String? symbol,
          int? entryTime,
          double? entryPrice,
          Value<int?> exitTime = const Value.absent(),
          Value<double?> exitPrice = const Value.absent(),
          String? side,
          double? pnl,
          double? rMultiple}) =>
      BacktestTrade(
        id: id ?? this.id,
        runId: runId ?? this.runId,
        symbol: symbol ?? this.symbol,
        entryTime: entryTime ?? this.entryTime,
        entryPrice: entryPrice ?? this.entryPrice,
        exitTime: exitTime.present ? exitTime.value : this.exitTime,
        exitPrice: exitPrice.present ? exitPrice.value : this.exitPrice,
        side: side ?? this.side,
        pnl: pnl ?? this.pnl,
        rMultiple: rMultiple ?? this.rMultiple,
      );
  BacktestTrade copyWithCompanion(BacktestTradesCompanion data) {
    return BacktestTrade(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      entryTime: data.entryTime.present ? data.entryTime.value : this.entryTime,
      entryPrice:
          data.entryPrice.present ? data.entryPrice.value : this.entryPrice,
      exitTime: data.exitTime.present ? data.exitTime.value : this.exitTime,
      exitPrice: data.exitPrice.present ? data.exitPrice.value : this.exitPrice,
      side: data.side.present ? data.side.value : this.side,
      pnl: data.pnl.present ? data.pnl.value : this.pnl,
      rMultiple: data.rMultiple.present ? data.rMultiple.value : this.rMultiple,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BacktestTrade(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('symbol: $symbol, ')
          ..write('entryTime: $entryTime, ')
          ..write('entryPrice: $entryPrice, ')
          ..write('exitTime: $exitTime, ')
          ..write('exitPrice: $exitPrice, ')
          ..write('side: $side, ')
          ..write('pnl: $pnl, ')
          ..write('rMultiple: $rMultiple')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, runId, symbol, entryTime, entryPrice,
      exitTime, exitPrice, side, pnl, rMultiple);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BacktestTrade &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.symbol == this.symbol &&
          other.entryTime == this.entryTime &&
          other.entryPrice == this.entryPrice &&
          other.exitTime == this.exitTime &&
          other.exitPrice == this.exitPrice &&
          other.side == this.side &&
          other.pnl == this.pnl &&
          other.rMultiple == this.rMultiple);
}

class BacktestTradesCompanion extends UpdateCompanion<BacktestTrade> {
  final Value<int> id;
  final Value<int> runId;
  final Value<String> symbol;
  final Value<int> entryTime;
  final Value<double> entryPrice;
  final Value<int?> exitTime;
  final Value<double?> exitPrice;
  final Value<String> side;
  final Value<double> pnl;
  final Value<double> rMultiple;
  const BacktestTradesCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.symbol = const Value.absent(),
    this.entryTime = const Value.absent(),
    this.entryPrice = const Value.absent(),
    this.exitTime = const Value.absent(),
    this.exitPrice = const Value.absent(),
    this.side = const Value.absent(),
    this.pnl = const Value.absent(),
    this.rMultiple = const Value.absent(),
  });
  BacktestTradesCompanion.insert({
    this.id = const Value.absent(),
    required int runId,
    required String symbol,
    required int entryTime,
    required double entryPrice,
    this.exitTime = const Value.absent(),
    this.exitPrice = const Value.absent(),
    required String side,
    required double pnl,
    required double rMultiple,
  })  : runId = Value(runId),
        symbol = Value(symbol),
        entryTime = Value(entryTime),
        entryPrice = Value(entryPrice),
        side = Value(side),
        pnl = Value(pnl),
        rMultiple = Value(rMultiple);
  static Insertable<BacktestTrade> custom({
    Expression<int>? id,
    Expression<int>? runId,
    Expression<String>? symbol,
    Expression<int>? entryTime,
    Expression<double>? entryPrice,
    Expression<int>? exitTime,
    Expression<double>? exitPrice,
    Expression<String>? side,
    Expression<double>? pnl,
    Expression<double>? rMultiple,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (symbol != null) 'symbol': symbol,
      if (entryTime != null) 'entry_time': entryTime,
      if (entryPrice != null) 'entry_price': entryPrice,
      if (exitTime != null) 'exit_time': exitTime,
      if (exitPrice != null) 'exit_price': exitPrice,
      if (side != null) 'side': side,
      if (pnl != null) 'pnl': pnl,
      if (rMultiple != null) 'r_multiple': rMultiple,
    });
  }

  BacktestTradesCompanion copyWith(
      {Value<int>? id,
      Value<int>? runId,
      Value<String>? symbol,
      Value<int>? entryTime,
      Value<double>? entryPrice,
      Value<int?>? exitTime,
      Value<double?>? exitPrice,
      Value<String>? side,
      Value<double>? pnl,
      Value<double>? rMultiple}) {
    return BacktestTradesCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      symbol: symbol ?? this.symbol,
      entryTime: entryTime ?? this.entryTime,
      entryPrice: entryPrice ?? this.entryPrice,
      exitTime: exitTime ?? this.exitTime,
      exitPrice: exitPrice ?? this.exitPrice,
      side: side ?? this.side,
      pnl: pnl ?? this.pnl,
      rMultiple: rMultiple ?? this.rMultiple,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<int>(runId.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (entryTime.present) {
      map['entry_time'] = Variable<int>(entryTime.value);
    }
    if (entryPrice.present) {
      map['entry_price'] = Variable<double>(entryPrice.value);
    }
    if (exitTime.present) {
      map['exit_time'] = Variable<int>(exitTime.value);
    }
    if (exitPrice.present) {
      map['exit_price'] = Variable<double>(exitPrice.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (pnl.present) {
      map['pnl'] = Variable<double>(pnl.value);
    }
    if (rMultiple.present) {
      map['r_multiple'] = Variable<double>(rMultiple.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BacktestTradesCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('symbol: $symbol, ')
          ..write('entryTime: $entryTime, ')
          ..write('entryPrice: $entryPrice, ')
          ..write('exitTime: $exitTime, ')
          ..write('exitPrice: $exitPrice, ')
          ..write('side: $side, ')
          ..write('pnl: $pnl, ')
          ..write('rMultiple: $rMultiple')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $KlinesTable klines = $KlinesTable(this);
  late final $BacktestRunsTable backtestRuns = $BacktestRunsTable(this);
  late final $BacktestTradesTable backtestTrades = $BacktestTradesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [klines, backtestRuns, backtestTrades];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('backtest_runs',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('backtest_trades', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$KlinesTableCreateCompanionBuilder = KlinesCompanion Function({
  required String symbol,
  required String interval,
  required int openTime,
  required double open,
  required double high,
  required double low,
  required double close,
  required double volume,
  required int closeTime,
  Value<int> rowid,
});
typedef $$KlinesTableUpdateCompanionBuilder = KlinesCompanion Function({
  Value<String> symbol,
  Value<String> interval,
  Value<int> openTime,
  Value<double> open,
  Value<double> high,
  Value<double> low,
  Value<double> close,
  Value<double> volume,
  Value<int> closeTime,
  Value<int> rowid,
});

class $$KlinesTableFilterComposer
    extends Composer<_$AppDatabase, $KlinesTable> {
  $$KlinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get openTime => $composableBuilder(
      column: $table.openTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get open => $composableBuilder(
      column: $table.open, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get high => $composableBuilder(
      column: $table.high, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get low => $composableBuilder(
      column: $table.low, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get close => $composableBuilder(
      column: $table.close, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get volume => $composableBuilder(
      column: $table.volume, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get closeTime => $composableBuilder(
      column: $table.closeTime, builder: (column) => ColumnFilters(column));
}

class $$KlinesTableOrderingComposer
    extends Composer<_$AppDatabase, $KlinesTable> {
  $$KlinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get interval => $composableBuilder(
      column: $table.interval, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get openTime => $composableBuilder(
      column: $table.openTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get open => $composableBuilder(
      column: $table.open, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get high => $composableBuilder(
      column: $table.high, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get low => $composableBuilder(
      column: $table.low, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get close => $composableBuilder(
      column: $table.close, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get volume => $composableBuilder(
      column: $table.volume, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get closeTime => $composableBuilder(
      column: $table.closeTime, builder: (column) => ColumnOrderings(column));
}

class $$KlinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KlinesTable> {
  $$KlinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get openTime =>
      $composableBuilder(column: $table.openTime, builder: (column) => column);

  GeneratedColumn<double> get open =>
      $composableBuilder(column: $table.open, builder: (column) => column);

  GeneratedColumn<double> get high =>
      $composableBuilder(column: $table.high, builder: (column) => column);

  GeneratedColumn<double> get low =>
      $composableBuilder(column: $table.low, builder: (column) => column);

  GeneratedColumn<double> get close =>
      $composableBuilder(column: $table.close, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<int> get closeTime =>
      $composableBuilder(column: $table.closeTime, builder: (column) => column);
}

class $$KlinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KlinesTable,
    Kline,
    $$KlinesTableFilterComposer,
    $$KlinesTableOrderingComposer,
    $$KlinesTableAnnotationComposer,
    $$KlinesTableCreateCompanionBuilder,
    $$KlinesTableUpdateCompanionBuilder,
    (Kline, BaseReferences<_$AppDatabase, $KlinesTable, Kline>),
    Kline,
    PrefetchHooks Function()> {
  $$KlinesTableTableManager(_$AppDatabase db, $KlinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KlinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KlinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KlinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> symbol = const Value.absent(),
            Value<String> interval = const Value.absent(),
            Value<int> openTime = const Value.absent(),
            Value<double> open = const Value.absent(),
            Value<double> high = const Value.absent(),
            Value<double> low = const Value.absent(),
            Value<double> close = const Value.absent(),
            Value<double> volume = const Value.absent(),
            Value<int> closeTime = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              KlinesCompanion(
            symbol: symbol,
            interval: interval,
            openTime: openTime,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            closeTime: closeTime,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String symbol,
            required String interval,
            required int openTime,
            required double open,
            required double high,
            required double low,
            required double close,
            required double volume,
            required int closeTime,
            Value<int> rowid = const Value.absent(),
          }) =>
              KlinesCompanion.insert(
            symbol: symbol,
            interval: interval,
            openTime: openTime,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            closeTime: closeTime,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KlinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KlinesTable,
    Kline,
    $$KlinesTableFilterComposer,
    $$KlinesTableOrderingComposer,
    $$KlinesTableAnnotationComposer,
    $$KlinesTableCreateCompanionBuilder,
    $$KlinesTableUpdateCompanionBuilder,
    (Kline, BaseReferences<_$AppDatabase, $KlinesTable, Kline>),
    Kline,
    PrefetchHooks Function()>;
typedef $$BacktestRunsTableCreateCompanionBuilder = BacktestRunsCompanion
    Function({
  Value<int> id,
  required String params,
  required int startedAt,
  Value<String?> stats,
});
typedef $$BacktestRunsTableUpdateCompanionBuilder = BacktestRunsCompanion
    Function({
  Value<int> id,
  Value<String> params,
  Value<int> startedAt,
  Value<String?> stats,
});

final class $$BacktestRunsTableReferences
    extends BaseReferences<_$AppDatabase, $BacktestRunsTable, BacktestRun> {
  $$BacktestRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BacktestTradesTable, List<BacktestTrade>>
      _backtestTradesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.backtestTrades,
              aliasName: $_aliasNameGenerator(
                  db.backtestRuns.id, db.backtestTrades.runId));

  $$BacktestTradesTableProcessedTableManager get backtestTradesRefs {
    final manager = $$BacktestTradesTableTableManager($_db, $_db.backtestTrades)
        .filter((f) => f.runId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_backtestTradesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$BacktestRunsTableFilterComposer
    extends Composer<_$AppDatabase, $BacktestRunsTable> {
  $$BacktestRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get params => $composableBuilder(
      column: $table.params, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stats => $composableBuilder(
      column: $table.stats, builder: (column) => ColumnFilters(column));

  Expression<bool> backtestTradesRefs(
      Expression<bool> Function($$BacktestTradesTableFilterComposer f) f) {
    final $$BacktestTradesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.backtestTrades,
        getReferencedColumn: (t) => t.runId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BacktestTradesTableFilterComposer(
              $db: $db,
              $table: $db.backtestTrades,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BacktestRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $BacktestRunsTable> {
  $$BacktestRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get params => $composableBuilder(
      column: $table.params, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stats => $composableBuilder(
      column: $table.stats, builder: (column) => ColumnOrderings(column));
}

class $$BacktestRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BacktestRunsTable> {
  $$BacktestRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get stats =>
      $composableBuilder(column: $table.stats, builder: (column) => column);

  Expression<T> backtestTradesRefs<T extends Object>(
      Expression<T> Function($$BacktestTradesTableAnnotationComposer a) f) {
    final $$BacktestTradesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.backtestTrades,
        getReferencedColumn: (t) => t.runId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BacktestTradesTableAnnotationComposer(
              $db: $db,
              $table: $db.backtestTrades,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$BacktestRunsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BacktestRunsTable,
    BacktestRun,
    $$BacktestRunsTableFilterComposer,
    $$BacktestRunsTableOrderingComposer,
    $$BacktestRunsTableAnnotationComposer,
    $$BacktestRunsTableCreateCompanionBuilder,
    $$BacktestRunsTableUpdateCompanionBuilder,
    (BacktestRun, $$BacktestRunsTableReferences),
    BacktestRun,
    PrefetchHooks Function({bool backtestTradesRefs})> {
  $$BacktestRunsTableTableManager(_$AppDatabase db, $BacktestRunsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BacktestRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BacktestRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BacktestRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> params = const Value.absent(),
            Value<int> startedAt = const Value.absent(),
            Value<String?> stats = const Value.absent(),
          }) =>
              BacktestRunsCompanion(
            id: id,
            params: params,
            startedAt: startedAt,
            stats: stats,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String params,
            required int startedAt,
            Value<String?> stats = const Value.absent(),
          }) =>
              BacktestRunsCompanion.insert(
            id: id,
            params: params,
            startedAt: startedAt,
            stats: stats,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BacktestRunsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({backtestTradesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (backtestTradesRefs) db.backtestTrades
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (backtestTradesRefs)
                    await $_getPrefetchedData<BacktestRun, $BacktestRunsTable,
                            BacktestTrade>(
                        currentTable: table,
                        referencedTable: $$BacktestRunsTableReferences
                            ._backtestTradesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$BacktestRunsTableReferences(db, table, p0)
                                .backtestTradesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.runId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$BacktestRunsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BacktestRunsTable,
    BacktestRun,
    $$BacktestRunsTableFilterComposer,
    $$BacktestRunsTableOrderingComposer,
    $$BacktestRunsTableAnnotationComposer,
    $$BacktestRunsTableCreateCompanionBuilder,
    $$BacktestRunsTableUpdateCompanionBuilder,
    (BacktestRun, $$BacktestRunsTableReferences),
    BacktestRun,
    PrefetchHooks Function({bool backtestTradesRefs})>;
typedef $$BacktestTradesTableCreateCompanionBuilder = BacktestTradesCompanion
    Function({
  Value<int> id,
  required int runId,
  required String symbol,
  required int entryTime,
  required double entryPrice,
  Value<int?> exitTime,
  Value<double?> exitPrice,
  required String side,
  required double pnl,
  required double rMultiple,
});
typedef $$BacktestTradesTableUpdateCompanionBuilder = BacktestTradesCompanion
    Function({
  Value<int> id,
  Value<int> runId,
  Value<String> symbol,
  Value<int> entryTime,
  Value<double> entryPrice,
  Value<int?> exitTime,
  Value<double?> exitPrice,
  Value<String> side,
  Value<double> pnl,
  Value<double> rMultiple,
});

final class $$BacktestTradesTableReferences
    extends BaseReferences<_$AppDatabase, $BacktestTradesTable, BacktestTrade> {
  $$BacktestTradesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $BacktestRunsTable _runIdTable(_$AppDatabase db) =>
      db.backtestRuns.createAlias(
          $_aliasNameGenerator(db.backtestTrades.runId, db.backtestRuns.id));

  $$BacktestRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<int>('run_id')!;

    final manager = $$BacktestRunsTableTableManager($_db, $_db.backtestRuns)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BacktestTradesTableFilterComposer
    extends Composer<_$AppDatabase, $BacktestTradesTable> {
  $$BacktestTradesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entryTime => $composableBuilder(
      column: $table.entryTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get entryPrice => $composableBuilder(
      column: $table.entryPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get exitTime => $composableBuilder(
      column: $table.exitTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get exitPrice => $composableBuilder(
      column: $table.exitPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get side => $composableBuilder(
      column: $table.side, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get pnl => $composableBuilder(
      column: $table.pnl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rMultiple => $composableBuilder(
      column: $table.rMultiple, builder: (column) => ColumnFilters(column));

  $$BacktestRunsTableFilterComposer get runId {
    final $$BacktestRunsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.runId,
        referencedTable: $db.backtestRuns,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BacktestRunsTableFilterComposer(
              $db: $db,
              $table: $db.backtestRuns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BacktestTradesTableOrderingComposer
    extends Composer<_$AppDatabase, $BacktestTradesTable> {
  $$BacktestTradesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get symbol => $composableBuilder(
      column: $table.symbol, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entryTime => $composableBuilder(
      column: $table.entryTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get entryPrice => $composableBuilder(
      column: $table.entryPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get exitTime => $composableBuilder(
      column: $table.exitTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get exitPrice => $composableBuilder(
      column: $table.exitPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get side => $composableBuilder(
      column: $table.side, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get pnl => $composableBuilder(
      column: $table.pnl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rMultiple => $composableBuilder(
      column: $table.rMultiple, builder: (column) => ColumnOrderings(column));

  $$BacktestRunsTableOrderingComposer get runId {
    final $$BacktestRunsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.runId,
        referencedTable: $db.backtestRuns,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BacktestRunsTableOrderingComposer(
              $db: $db,
              $table: $db.backtestRuns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BacktestTradesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BacktestTradesTable> {
  $$BacktestTradesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<int> get entryTime =>
      $composableBuilder(column: $table.entryTime, builder: (column) => column);

  GeneratedColumn<double> get entryPrice => $composableBuilder(
      column: $table.entryPrice, builder: (column) => column);

  GeneratedColumn<int> get exitTime =>
      $composableBuilder(column: $table.exitTime, builder: (column) => column);

  GeneratedColumn<double> get exitPrice =>
      $composableBuilder(column: $table.exitPrice, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<double> get pnl =>
      $composableBuilder(column: $table.pnl, builder: (column) => column);

  GeneratedColumn<double> get rMultiple =>
      $composableBuilder(column: $table.rMultiple, builder: (column) => column);

  $$BacktestRunsTableAnnotationComposer get runId {
    final $$BacktestRunsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.runId,
        referencedTable: $db.backtestRuns,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$BacktestRunsTableAnnotationComposer(
              $db: $db,
              $table: $db.backtestRuns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BacktestTradesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BacktestTradesTable,
    BacktestTrade,
    $$BacktestTradesTableFilterComposer,
    $$BacktestTradesTableOrderingComposer,
    $$BacktestTradesTableAnnotationComposer,
    $$BacktestTradesTableCreateCompanionBuilder,
    $$BacktestTradesTableUpdateCompanionBuilder,
    (BacktestTrade, $$BacktestTradesTableReferences),
    BacktestTrade,
    PrefetchHooks Function({bool runId})> {
  $$BacktestTradesTableTableManager(
      _$AppDatabase db, $BacktestTradesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BacktestTradesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BacktestTradesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BacktestTradesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> runId = const Value.absent(),
            Value<String> symbol = const Value.absent(),
            Value<int> entryTime = const Value.absent(),
            Value<double> entryPrice = const Value.absent(),
            Value<int?> exitTime = const Value.absent(),
            Value<double?> exitPrice = const Value.absent(),
            Value<String> side = const Value.absent(),
            Value<double> pnl = const Value.absent(),
            Value<double> rMultiple = const Value.absent(),
          }) =>
              BacktestTradesCompanion(
            id: id,
            runId: runId,
            symbol: symbol,
            entryTime: entryTime,
            entryPrice: entryPrice,
            exitTime: exitTime,
            exitPrice: exitPrice,
            side: side,
            pnl: pnl,
            rMultiple: rMultiple,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int runId,
            required String symbol,
            required int entryTime,
            required double entryPrice,
            Value<int?> exitTime = const Value.absent(),
            Value<double?> exitPrice = const Value.absent(),
            required String side,
            required double pnl,
            required double rMultiple,
          }) =>
              BacktestTradesCompanion.insert(
            id: id,
            runId: runId,
            symbol: symbol,
            entryTime: entryTime,
            entryPrice: entryPrice,
            exitTime: exitTime,
            exitPrice: exitPrice,
            side: side,
            pnl: pnl,
            rMultiple: rMultiple,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BacktestTradesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (runId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.runId,
                    referencedTable:
                        $$BacktestTradesTableReferences._runIdTable(db),
                    referencedColumn:
                        $$BacktestTradesTableReferences._runIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BacktestTradesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BacktestTradesTable,
    BacktestTrade,
    $$BacktestTradesTableFilterComposer,
    $$BacktestTradesTableOrderingComposer,
    $$BacktestTradesTableAnnotationComposer,
    $$BacktestTradesTableCreateCompanionBuilder,
    $$BacktestTradesTableUpdateCompanionBuilder,
    (BacktestTrade, $$BacktestTradesTableReferences),
    BacktestTrade,
    PrefetchHooks Function({bool runId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$KlinesTableTableManager get klines =>
      $$KlinesTableTableManager(_db, _db.klines);
  $$BacktestRunsTableTableManager get backtestRuns =>
      $$BacktestRunsTableTableManager(_db, _db.backtestRuns);
  $$BacktestTradesTableTableManager get backtestTrades =>
      $$BacktestTradesTableTableManager(_db, _db.backtestTrades);
}
