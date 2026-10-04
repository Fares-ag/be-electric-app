import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UniversalHyperSpeedCache {

  // In-memory cache for instant access
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  // Cache duration (5 minutes for hyper-speed)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get cached data instantly from memory
  T? getCachedData<T>(String key) {
    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheDuration) {
        print('ðŸš€ HYPER SPEED: Loading $key from memory cache');
        return _memoryCache[key] as T?;
      } else {
        // Cache expired, remove it
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    return null;
  }

  /// Cache data in memory for instant access
  void cacheData<T>(String key, T data) {
    _memoryCache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    print('ðŸš€ HYPER SPEED: Cached $key in memory');
  }

  /// Get cached data from persistent storage
  Future<T?> getPersistentData<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('${key}_data');
      final timestampStr = prefs.getString('${key}_timestamp');

      if (cachedData != null && timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        if (DateTime.now().difference(timestamp) < _cacheDuration) {
          final Map<String, dynamic> jsonData = json.decode(cachedData);
          final data = fromJson(jsonData);
          print('ðŸš€ HYPER SPEED: Loading $key from persistent cache');
          return data;
        }
      }
    } catch (e, st) {
      print('ðŸš€ HYPER SPEED: Error loading persistent cache for $key: $e');
    }
    return null;
  }

  /// Cache data in persistent storage
  Future<void> cachePersistentData<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = toJson(data);
      await prefs.setString('${key}_data', json.encode(jsonData));
      await prefs.setString(
        '${key}_timestamp',
        DateTime.now().toIso8601String(),
      );
      print('ðŸš€ HYPER SPEED: Cached $key in persistent storage');
    } catch (e, st) {
      print('ðŸš€ HYPER SPEED: Error caching persistent data for $key: $e');
    }
  }

  /// Get data with hyper-speed caching (memory first, then persistent, then fallback)
  Future<T?> getDataWithHyperSpeed<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
    Future<T?> Function() fallbackLoader,
  ) async {
    // 1. Try memory cache first (instant)
    final memoryData = getCachedData<T>(key);
    if (memoryData != null) {
      return memoryData;
    }

    // 2. Try persistent cache (very fast)
    final persistentData = await getPersistentData<T>(key, fromJson);
    if (persistentData != null) {
      // Cache in memory for next time
      cacheData(key, persistentData);
      return persistentData;
    }

    // 3. Use fallback loader
    return fallbackLoader();
  }

  /// Cache data with hyper-speed (both memory and persistent)
  Future<void> cacheDataWithHyperSpeed<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    // Cache in both memory and persistent storage
    cacheData(key, data);
    await cachePersistentData(key, data, toJson);
  }

  /// Clear specific cache entry
  void clearCache(String key) {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
    print('ðŸš€ HYPER SPEED: Cleared cache for $key');
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
        'cache_hit_rate': _memoryCache.isNotEmpty
            ? '${(_memoryCache.length * 100 / (_memoryCache.length + 1)).toStringAsFixed(1)}%'
            : '0%',
      };

  /// Preload data in background
  Future<void> preloadData<T>(
    String key,
    Future<T> loader,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      print('ðŸš€ HYPER SPEED: Preloading $key in background...');
      final data = await loader;
      await cacheDataWithHyperSpeed(key, data, toJson);
      print('ðŸš€ HYPER SPEED: Preloaded $key successfully');
    } catch (e, st) {
      print('ðŸš€ HYPER SPEED: Error preloading $key: $e');
    }
  }
}



