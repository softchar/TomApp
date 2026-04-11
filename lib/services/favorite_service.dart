import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 收藏服务 - 管理用户收藏的合约
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  static const String _favoritesKey = 'favorite_symbols';

  final Set<String> _favorites = {};
  bool _initialized = false;

  /// 初始化收藏服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList(_favoritesKey) ?? [];
      _favorites.addAll(favoritesList);
      _initialized = true;
      debugPrint('FavoriteService: 已加载 ${_favorites.length} 个收藏');
    } catch (e) {
      debugPrint('FavoriteService: 初始化失败 $e');
      _initialized = true;
    }
  }

  /// 获取所有收藏
  Set<String> get favorites => Set.unmodifiable(_favorites);

  /// 检查是否已收藏
  bool isFavorite(String symbol) {
    return _favorites.contains(symbol);
  }

  /// 添加收藏
  Future<bool> addFavorite(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favorites.add(symbol);
      await prefs.setStringList(_favoritesKey, _favorites.toList());
      debugPrint('FavoriteService: 已添加收藏 $symbol');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FavoriteService: 添加收藏失败 $e');
      return false;
    }
  }

  /// 移除收藏
  Future<bool> removeFavorite(String symbol) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favorites.remove(symbol);
      await prefs.setStringList(_favoritesKey, _favorites.toList());
      debugPrint('FavoriteService: 已移除收藏 $symbol');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FavoriteService: 移除收藏失败 $e');
      return false;
    }
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(String symbol) async {
    if (isFavorite(symbol)) {
      return await removeFavorite(symbol);
    } else {
      return await addFavorite(symbol);
    }
  }

  /// 清空所有收藏
  Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _favorites.clear();
      await prefs.remove(_favoritesKey);
      debugPrint('FavoriteService: 已清空所有收藏');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('FavoriteService: 清空收藏失败 $e');
      return false;
    }
  }

  // 用于通知监听者
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
