import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset.dart';

class HyperSpeedCache {

  // In-memory cache for instant access
  static final Map<String, List<Asset>> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Cache keys
  static const String _allAssetsKey = 'hyper_speed_all_assets';
  static const String _searchResultsKey = 'hyper_speed_search_results';
  static const String _cacheTimestampKey = 'hyper_speed_cache_timestamp';

  // Cache duration (5 minutes for hyper-speed)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get cached assets instantly from memory
  List<Asset>? getCachedAssets(String key) {
    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheDuration) {
        print(
            'ðŸš€ HYPER SPEED: Loading ${_memoryCache[key]!.length} assets from memory cache',);
        return _memoryCache[key];
      } else {
        // Cache expired, remove it
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    return null;
  }

  /// Cache assets in memory for instant access
  void cacheAssets(String key, List<Asset> assets) {
    _memoryCache[key] = assets;
    _cacheTimestamps[key] = DateTime.now();
    print('ðŸš€ HYPER SPEED: Cached ${assets.length} assets in memory');
  }

  /// Get cached assets from persistent storage
  Future<List<Asset>?> getPersistentAssets(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('${key}_data');
      final timestampStr = prefs.getString('${key}_timestamp');

      if (cachedData != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          final List<dynamic> jsonList = json.decode(cachedData);
          final assets = jsonList.map((json) => Asset.fromJson(json)).toList();
          print(
              'ðŸš€ HYPER SPEED: Loading ${assets.length} assets from persistent cache',);
          return assets;
        }
      }
    } catch (e, st) {
      print('ðŸš€ HYPER SPEED: Error loading persistent cache: $e');
    }
    return null;
  }

  /// Cache assets in persistent storage
  Future<void> cachePersistentAssets(String key, List<Asset> assets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = assets.map((asset) => asset.toJson()).toList();
      await prefs.setString('${key}_data', json.encode(jsonList));
      await prefs.setString(
          '${key}_timestamp', DateTime.now().toIso8601String(),);
      print(
          'ðŸš€ HYPER SPEED: Cached ${assets.length} assets in persistent storage',);
    } catch (e, st) {
      print('ðŸš€ HYPER SPEED: Error caching persistent data: $e');
    }
  }

  /// Get all assets with hyper-speed caching
  Future<List<Asset>> getAllAssetsWithHyperSpeed() async {
    // 1. Try memory cache first (instant)
    final memoryAssets = getCachedAssets(_allAssetsKey);
    if (memoryAssets != null) {
      return memoryAssets;
    }

    // 2. Try persistent cache (very fast)
    final persistentAssets = await getPersistentAssets(_allAssetsKey);
    if (persistentAssets != null) {
      // Cache in memory for next time
      cacheAssets(_allAssetsKey, persistentAssets);
      return persistentAssets;
    }

    // 3. Return empty list if no cache available
    return [];
  }

  /// Cache all assets with hyper-speed
  Future<void> cacheAllAssetsWithHyperSpeed(List<Asset> assets) async {
    // Cache in both memory and persistent storage
    cacheAssets(_allAssetsKey, assets);
    await cachePersistentAssets(_allAssetsKey, assets);
  }

  /// Get search results with hyper-speed caching
  List<Asset>? getSearchResults(String query) {
    final key = '${_searchResultsKey}_$query';
    return getCachedAssets(key);
  }

  /// Cache search results
  void cacheSearchResults(String query, List<Asset> results) {
    final key = '${_searchResultsKey}_$query';
    cacheAssets(key, results);
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _memoryCache.clear();
    _cacheTimestamps.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('hyper_speed_')) {
          await prefs.remove(key);
        }
      }
      print('ðŸš€ HYPER SPEED: Cleared all caches');
    } catch (e, st) {
      print('ðŸš€ HYPER SPEED: Error clearing caches: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() => {
      'memory_cache_size': _memoryCache.length,
      'memory_cache_keys': _memoryCache.keys.toList(),
      'total_cached_assets':
          _memoryCache.values.fold(0, (sum, assets) => sum + assets.length),
    };
}









