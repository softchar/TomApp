import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tomapp/services/database_helper.dart';
import 'package:tomapp/services/exchange_info_service.dart';

/// Service for CRUD operations on futures_symbols table
class ContractInfoService {
  static const String _tableName = 'futures_symbols';
  static const int _batchSize = 100;

  static ContractInfoService? _instance;
  final Database _db;
  final Map<String, FuturesSymbol> _cache = {};

  /// Private constructor
  ContractInfoService._internal(this._db);

  /// Singleton instance getter with async initialization
  static Future<ContractInfoService> get instance async {
    if (_instance == null) {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      _instance = ContractInfoService._internal(db);
    }
    return _instance!;
  }

  /// Convert FuturesSymbol to database row (camelCase to snake_case)
  Map<String, dynamic> _toDbRow(FuturesSymbol symbol) {
    return {
      'symbol': symbol.symbol,
      'base_asset': symbol.baseAsset,
      'quote_asset': symbol.quoteAsset,
      'status': symbol.status.value,
      'contract_type': symbol.contractType,
      'onboard_date': symbol.onBoardDate,
      'delivery_date': symbol.deliveryDate,
      'price_precision': symbol.pricePrecision,
      'quantity_precision': symbol.quantityPrecision,
      'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Convert database row to FuturesSymbol (snake_case to camelCase)
  FuturesSymbol _fromDbRow(Map<String, dynamic> row) {
    return FuturesSymbol(
      symbol: row['symbol'] as String,
      baseAsset: row['base_asset'] as String,
      quoteAsset: row['quote_asset'] as String,
      status: ContractStatusExtension.fromString(row['status'] as String),
      contractType: row['contract_type'] as String,
      onBoardDate: row['onboard_date'] as int,
      deliveryDate: row['delivery_date'] as int? ?? 0,
      pricePrecision: row['price_precision'] as int? ?? 0,
      quantityPrecision: row['quantity_precision'] as int? ?? 0,
    );
  }

  /// Batch insert/update symbols with conflict resolution
  /// Processes in batches of 100 records
  /// Returns the count of successfully processed records
  Future<int> upsertSymbols(List<FuturesSymbol> symbols) async {
    if (symbols.isEmpty) return 0;

    int successCount = 0;
    final totalSymbols = symbols.length;

    // Process in batches
    for (int i = 0; i < totalSymbols; i += _batchSize) {
      final end = (i + _batchSize < totalSymbols) ? i + _batchSize : totalSymbols;
      final batch = symbols.sublist(i, end);

      try {
        final batchWriter = _db.batch();

        for (final symbol in batch) {
          final row = _toDbRow(symbol);
          batchWriter.insert(
            _tableName,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // Update cache
          _cache[symbol.symbol] = symbol;
        }

        await batchWriter.commit(noResult: true);
        successCount += batch.length;

        if (kDebugMode) {
          print('[ContractInfoService] Batch ${i ~/ _batchSize + 1}: '
                'processed ${batch.length} symbols (${i + 1}-$end of $totalSymbols)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[ContractInfoService] Batch ${i ~/ _batchSize + 1} failed: $e');
        }
      }
    }

    if (kDebugMode) {
      print('[ContractInfoService] Upsert complete: $successCount/$totalSymbols symbols processed');
    }

    return successCount;
  }

  /// Query all symbols, ordered by updated_at DESC
  Future<List<FuturesSymbol>> getAllSymbols() async {
    try {
      final List<Map<String, dynamic>> rows = await _db.query(
        _tableName,
        orderBy: 'updated_at DESC',
      );

      final symbols = rows.map(_fromDbRow).toList();

      if (kDebugMode) {
        print('[ContractInfoService] Retrieved ${symbols.length} symbols');
      }

      return symbols;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfoService] Error getting all symbols: $e');
      }
      return [];
    }
  }

  /// Query symbols where status='TRADING'
  Future<List<FuturesSymbol>> getTradableSymbols() async {
    try {
      final List<Map<String, dynamic>> rows = await _db.query(
        _tableName,
        where: 'status = ?',
        whereArgs: ['TRADING'],
        orderBy: 'updated_at DESC',
      );

      final symbols = rows.map(_fromDbRow).toList();

      if (kDebugMode) {
        print('[ContractInfoService] Retrieved ${symbols.length} tradable symbols');
      }

      return symbols;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfoService] Error getting tradable symbols: $e');
      }
      return [];
    }
  }

  /// Get single symbol by key with in-memory cache
  Future<FuturesSymbol?> getSymbol(String symbolKey) async {
    // Check cache first
    if (_cache.containsKey(symbolKey)) {
      return _cache[symbolKey];
    }

    try {
      final List<Map<String, dynamic>> rows = await _db.query(
        _tableName,
        where: 'symbol = ?',
        whereArgs: [symbolKey],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final symbol = _fromDbRow(rows.first);
        _cache[symbolKey] = symbol;
        return symbol;
      }

      if (kDebugMode) {
        print('[ContractInfoService] Symbol not found: $symbolKey');
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfoService] Error getting symbol $symbolKey: $e');
      }
      return null;
    }
  }

  /// Get statistics: map with 'total' and 'trading' counts
  Future<Map<String, int>> getStats() async {
    try {
      // Get total count
      final totalResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName',
      );
      final total = totalResult.first['count'] as int? ?? 0;

      // Get trading count
      final tradingResult = await _db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE status = ?',
        ['TRADING'],
      );
      final trading = tradingResult.first['count'] as int? ?? 0;

      final stats = {
        'total': total,
        'trading': trading,
      };

      if (kDebugMode) {
        print('[ContractInfoService] Stats: $stats');
      }

      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfoService] Error getting stats: $e');
      }
      return {'total': 0, 'trading': 0};
    }
  }

  /// Delete all records from the table
  Future<int> clearAll() async {
    try {
      final count = await _db.delete(_tableName);
      _cache.clear();

      if (kDebugMode) {
        print('[ContractInfoService] Cleared $count records');
      }

      return count;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractInfoService] Error clearing all records: $e');
      }
      return 0;
    }
  }

  /// Clear the in-memory cache
  void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      print('[ContractInfoService] Cache cleared');
    }
  }
}
