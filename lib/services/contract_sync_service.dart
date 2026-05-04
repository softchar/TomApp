import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tomapp/services/exchange_info_service.dart';
import 'package:tomapp/services/contract_info_service.dart';

/// Sync status enumeration
enum SyncStatus {
  idle,
  syncing,
  error,
}

/// Contract sync orchestrator service
/// Coordinates periodic sync between ExchangeInfoService and ContractInfoService
class ContractSyncService {
  // Private fields
  Timer? _timer;
  SyncStatus _status = SyncStatus.idle;
  bool _syncLock = false;
  final Duration _syncInterval = const Duration(hours: 1);

  // Polling constants
  static const int _maxInitAttempts = 50;
  static const Duration _initPollInterval = Duration(milliseconds: 100);

  // Singleton pattern
  static ContractSyncService? _instance;

  /// Private constructor
  ContractSyncService._internal();

  /// Singleton instance getter
  static ContractSyncService get instance {
    _instance ??= ContractSyncService._internal();
    return _instance!;
  }

  /// Get current sync status
  SyncStatus get status => _status;

  /// Check if sync is currently running
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Start periodic sync
  /// Returns true if sync was started, false if already running
  Future<bool> startSync() async {
    if (isRunning) {
      if (kDebugMode) {
        print('[ContractSyncService] Sync already running, ignoring start request');
      }
      return false;
    }

    if (kDebugMode) {
      print('[ContractSyncService] Starting sync service with interval: $_syncInterval');
    }

    // Immediately perform first sync
    await performSync();

    // Start periodic timer
    _timer = Timer.periodic(_syncInterval, (_) {
      performSync();
    });

    return true;
  }

  /// Stop periodic sync
  void stopSync() {
    if (kDebugMode) {
      print('[ContractSyncService] Stopping sync service');
    }

    _timer?.cancel();
    _timer = null;
    _status = SyncStatus.idle;
  }

  /// Perform sync operation
  /// Coordinates fetching from ExchangeInfoService and storing via ContractInfoService
  Future<void> performSync() async {
    // Check if already syncing (use lock to prevent concurrent execution)
    if (_syncLock) {
      if (kDebugMode) {
        print('[ContractSyncService] Already syncing, skipping this cycle');
      }
      return;
    }

    _syncLock = true;
    _status = SyncStatus.syncing;

    try {
      if (kDebugMode) {
        print('[ContractSyncService] Starting sync cycle...');
      }

      // Wait for ExchangeInfoService initialization
      final exchangeInfoService = ExchangeInfoService.instance;
      if (!exchangeInfoService.isInitialized) {
        if (kDebugMode) {
          print('[ContractSyncService] Waiting for ExchangeInfoService initialization...');
        }

        // Poll for initialization
        for (int i = 0; i < _maxInitAttempts; i++) {
          await Future.delayed(_initPollInterval);
          if (exchangeInfoService.isInitialized) {
            if (kDebugMode) {
              print('[ContractSyncService] ExchangeInfoService initialized after ${i * 100}ms');
            }
            break;
          }

          if (i == _maxInitAttempts - 1) {
            if (kDebugMode) {
              print('[ContractSyncService] ExchangeInfoService not initialized after ${_maxInitAttempts * _initPollInterval.inMilliseconds}ms, aborting sync');
            }
            _status = SyncStatus.error;
            _syncLock = false;
            return;
          }
        }
      }

      // Get symbols from ExchangeInfoService
      final symbols = exchangeInfoService.symbols.values.toList();

      if (kDebugMode) {
        print('[ContractSyncService] Retrieved ${symbols.length} symbols from ExchangeInfoService');
      }

      // Store via ContractInfoService
      final contractInfoService = await ContractInfoService.instance;
      final storedCount = await contractInfoService.upsertSymbols(symbols);

      // Get and log stats
      final stats = await contractInfoService.getStats();

      if (kDebugMode) {
        print('[ContractSyncService] Sync complete: '
              'stored=$storedCount, '
              'total_in_db=${stats['total']}, '
              'trading=${stats['trading']}');
      }

      _status = SyncStatus.idle;
    } catch (e) {
      if (kDebugMode) {
        print('[ContractSyncService] Sync failed: $e');
      }
      _status = SyncStatus.error;
    } finally {
      _syncLock = false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopSync();
  }
}
