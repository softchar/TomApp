import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tomapp/services/binance_api_service.dart';

/// 合约状态枚举
enum ContractStatus {
  pendingTrading,    // 待上市
  trading,           // 交易中
  preDelivering,     // 预交割
  delivering,        // 交割中
  delivered,         // 已交割
  preSettle,         // 预结算
  settling,          // 结算中
  close,             // 已下架
}

/// 合约状态扩展
extension ContractStatusExtension on ContractStatus {
  String get value {
    switch (this) {
      case ContractStatus.pendingTrading: return 'PENDING_TRADING';
      case ContractStatus.trading: return 'TRADING';
      case ContractStatus.preDelivering: return 'PRE_DELIVERING';
      case ContractStatus.delivering: return 'DELIVERING';
      case ContractStatus.delivered: return 'DELIVERED';
      case ContractStatus.preSettle: return 'PRE_SETTLE';
      case ContractStatus.settling: return 'SETTLING';
      case ContractStatus.close: return 'CLOSE';
    }
  }

  bool get isTradable {
    return this == ContractStatus.trading;
  }

  static ContractStatus fromString(String status) {
    switch (status) {
      case 'PENDING_TRADING': return ContractStatus.pendingTrading;
      case 'TRADING': return ContractStatus.trading;
      case 'PRE_DELIVERING': return ContractStatus.preDelivering;
      case 'DELIVERING': return ContractStatus.delivering;
      case 'DELIVERED': return ContractStatus.delivered;
      case 'PRE_SETTLE': return ContractStatus.preSettle;
      case 'SETTLING': return ContractStatus.settling;
      case 'CLOSE': return ContractStatus.close;
      default: return ContractStatus.close;
    }
  }
}

/// 合约信息
class FuturesSymbol {
  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  final ContractStatus status;
  final String contractType;  // PERPETUAL, CURRENT_QUARTER, NEXT_QUARTER
  final int onBoardDate;
  final int deliveryDate;     // 交割日期（交割合约才有）
  final int deliveryTime;     // 交割时间（交割合约才有）
  final int pricePrecision;   // 价格精度
  final int quantityPrecision; // 数量精度

  FuturesSymbol({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    required this.status,
    required this.contractType,
    required this.onBoardDate,
    this.deliveryDate = 0,
    this.deliveryTime = 0,
    this.pricePrecision = 0,
    this.quantityPrecision = 0,
  });

  factory FuturesSymbol.fromJson(Map<String, dynamic> json) {
    return FuturesSymbol(
      symbol: json['symbol'] as String? ?? '',
      baseAsset: json['baseAsset'] as String? ?? '',
      quoteAsset: json['quoteAsset'] as String? ?? '',
      status: ContractStatusExtension.fromString(
        json['contractStatus'] as String? ?? json['status'] as String? ?? 'CLOSE'
      ),
      contractType: json['contractType'] as String? ?? '',
      onBoardDate: json['onBoardDate'] as int? ?? 0,
      deliveryDate: json['deliveryDate'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as int? ?? 0,
      pricePrecision: json['pricePrecision'] as int? ?? 0,
      quantityPrecision: json['quantityPrecision'] as int? ?? 0,
    );
  }

  /// 是否为 U 本位永续合约
  bool get isUsdtPerpetual {
    return quoteAsset == 'USDT' && contractType == 'PERPETUAL';
  }

  /// 是否可交易
  bool get isTradable => status.isTradable;

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'baseAsset': baseAsset,
      'quoteAsset': quoteAsset,
      'status': status.value,
      'contractType': contractType,
      'onBoardDate': onBoardDate,
      'deliveryDate': deliveryDate,
      'deliveryTime': deliveryTime,
      'pricePrecision': pricePrecision,
      'quantityPrecision': quantityPrecision,
    };
  }
}

/// 合约信息服务
class ExchangeInfoService extends ChangeNotifier {
  static const String _keyExchangeInfo = 'exchange_info_data';
  static const String _keyLastUpdate = 'exchange_info_last_update';
  static const Duration _updateInterval = Duration(hours: 1);

  final Map<String, FuturesSymbol> _symbols = {};
  DateTime? _lastUpdateTime;
  Timer? _updateTimer;
  bool _isInitialized = false;

  Map<String, FuturesSymbol> get symbols => Map.unmodifiable(_symbols);
  DateTime? get lastUpdateTime => _lastUpdateTime;
  bool get isInitialized => _isInitialized;

  /// 单例
  static final ExchangeInfoService _instance = ExchangeInfoService._internal();
  static ExchangeInfoService get instance => _instance;
  factory ExchangeInfoService() => _instance;

  ExchangeInfoService._internal() {
    _loadFromStorage();
    _startAutoUpdate();
  }

  /// 从本地存储加载
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString(_keyExchangeInfo);
      final lastUpdateMs = prefs.getInt(_keyLastUpdate);

      if (dataJson != null) {
        final List<dynamic> data = json.decode(dataJson);
        _symbols.clear();
        for (final item in data) {
          final symbol = FuturesSymbol.fromJson(item as Map<String, dynamic>);
          _symbols[symbol.symbol] = symbol;
        }
        if (kDebugMode) {
          print('[ExchangeInfo] 从本地加载了 ${_symbols.length} 个合约信息');
        }
      }

      if (lastUpdateMs != null) {
        _lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs);
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('[ExchangeInfo] 加载本地数据失败: $e');
      }
    }
  }

  /// 保存到本地存储
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = json.encode(
        _symbols.values.map((s) => s.toJson()).toList()
      );
      await prefs.setString(_keyExchangeInfo, dataJson);
      await prefs.setInt(
        _keyLastUpdate,
        DateTime.now().millisecondsSinceEpoch
      );
      if (kDebugMode) {
        print('[ExchangeInfo] 保存了 ${_symbols.length} 个合约信息到本地');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ExchangeInfo] 保存数据失败: $e');
      }
    }
  }

  /// 从币安获取合约信息
  Future<void> fetchExchangeInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${BinanceApiService.currentBaseUrl}/fapi/v1/exchangeInfo'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['serverTime'] != null && data['symbols'] != null) {
          final List<dynamic> symbolsData = data['symbols'];
          _symbols.clear();

          for (final symbolData in symbolsData) {
            final symbol = FuturesSymbol.fromJson(symbolData);
            _symbols[symbol.symbol] = symbol;
          }

          _lastUpdateTime = DateTime.now();
          await _saveToStorage();
          notifyListeners();

          final tradingCount = _symbols.values
              .where((s) => s.isUsdtPerpetual && s.isTradable)
              .length;
          if (kDebugMode) {
            print('[ExchangeInfo] 获取成功: 总合约=${_symbols.length}, '
                  'U本位永续可交易=$tradingCount');
          }
        }
      } else {
        if (kDebugMode) {
          print('[ExchangeInfo] 获取失败: HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ExchangeInfo] 获取失败: $e');
      }
    }
  }

  /// 开始自动更新（每小时）
  void _startAutoUpdate() {
    // 立即执行一次（如果数据超过1小时或为空）
    if (_lastUpdateTime == null ||
        DateTime.now().difference(_lastUpdateTime!) > _updateInterval) {
      fetchExchangeInfo();
    }

    // 定时更新
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      fetchExchangeInfo();
    });
  }

  /// 检查合约是否可交易
  bool isSymbolTradable(String symbol) {
    final futuresSymbol = _symbols[symbol];
    if (futuresSymbol == null) {
      // 如果没有合约信息，默认允许（兼容旧逻辑）
      return true;
    }
    return futuresSymbol.isTradable;
  }

  /// 获取合约状态
  ContractStatus? getSymbolStatus(String symbol) {
    return _symbols[symbol]?.status;
  }

  /// 获取所有可交易的 U 本位永续合约
  List<String> getTradableUsdtPerpetualSymbols() {
    return _symbols.values
        .where((s) => s.isUsdtPerpetual && s.isTradable)
        .map((s) => s.symbol)
        .toList();
  }

  /// 获取合约信息
  FuturesSymbol? getSymbolInfo(String symbol) {
    return _symbols[symbol];
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
