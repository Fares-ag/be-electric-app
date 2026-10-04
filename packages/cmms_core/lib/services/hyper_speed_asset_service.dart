import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/asset.dart';
import 'hyper_speed_cache.dart';

class HyperSpeedAssetService {

  final HyperSpeedCache _cache = HyperSpeedCache();

  // Concurrent request management
  final Map<String, Future<List<Asset>>> _ongoingRequests = {};

  /// Get all assets with hyper-speed (cached first, then API)
  Future<List<Asset>> getAllAssets({int? limit}) async {
    final cacheKey =
        limit != null ? 'all_assets_$limit' : 'all_assets_complete';

    // Check if there's already an ongoing request for this key
    if (_ongoingRequests.containsKey(cacheKey)) {
      debugPrint('🚀 HYPER SPEED: Waiting for ongoing request...');
      return _ongoingRequests[cacheKey]!;
    }

    // Start new request
    final future = _getAllAssetsInternal(limit);
    _ongoingRequests[cacheKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _ongoingRequests.remove(cacheKey);
    }
  }

  Future<List<Asset>> _getAllAssetsInternal(int? limit) async {
    // 1. Try cache first (instant)
    final cachedAssets = await _cache.getAllAssetsWithHyperSpeed();
    if (cachedAssets.isNotEmpty) {
      debugPrint(
        '🚀 HYPER SPEED: Returning ${cachedAssets.length} cached assets instantly',
      );
      return limit != null ? cachedAssets.take(limit).toList() : cachedAssets;
    }

    // 2. Load from API with aggressive optimization
    debugPrint(
      '🚀 HYPER SPEED: Loading from API with hyper-speed optimization...',
    );
    final apiAssets = await _loadFromApiWithHyperSpeed(limit);

    // 3. Cache the results for next time
    if (apiAssets.isNotEmpty) {
      await _cache.cacheAllAssetsWithHyperSpeed(apiAssets);
    }

    return apiAssets;
  }

  /// Load assets from API with hyper-speed optimization
  Future<List<Asset>> _loadFromApiWithHyperSpeed(int? limit) async {
    try {
      final headers = await _getHeaders();
      final allAssets = <Asset>[];
      var offset = 0;
      const pageLimit = 50; // Larger page size for fewer requests
      const maxTotalAssets = 10000; // Very high limit to get ALL assets

      debugPrint(
        '🚀 HYPER SPEED: Starting optimized API loading for ALL assets...',
      );

      while (allAssets.length < maxTotalAssets &&
          (limit == null || allAssets.length < limit)) {
        final url = ApiConfig.buildUrl(
          ApiConfig.getAllAssets,
          queryParams: {
            'limit': pageLimit.toString(),
            'offset': offset.toString(),
          },
        );

        // Use shorter timeout for hyper-speed
        final response = await http
            .get(
              Uri.parse(url),
              headers: headers,
            )
            .timeout(const Duration(seconds: 3)); // Very short timeout

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          var assetsData = <dynamic>[];

          // Handle different response structures
          if (responseData is List) {
            assetsData = responseData;
          } else if (responseData is Map) {
            if (responseData.containsKey('data')) {
              assetsData = responseData['data'] ?? [];
            } else if (responseData.containsKey('assets')) {
              assetsData = responseData['assets'] ?? [];
            } else if (responseData.containsKey('items')) {
              assetsData = responseData['items'] ?? [];
            }
          }

          // Parse assets quickly
          for (final assetData in assetsData) {
            try {
              final asset = Asset.fromJson(assetData);
              allAssets.add(asset);

              // Stop if we've reached the limit
              if (limit != null && allAssets.length >= limit) break;
            } catch (e, st) {
              // Skip invalid assets for speed
              continue;
            }
          }

          // Stop if we got fewer assets than requested
          if (assetsData.length < pageLimit) {
            break;
          }

          offset += pageLimit;
        } else {
          debugPrint(
            '🚀 HYPER SPEED: API error ${response.statusCode}, stopping',
          );
          break;
        }
      }

      debugPrint('🚀 HYPER SPEED: Loaded ${allAssets.length} assets from API');
      return allAssets;
    } on Exception catch (e, st) {
      debugPrint('🚀 HYPER SPEED: API loading error: $e');
      return [];
    }
  }

  /// Search assets with hyper-speed caching
  Future<List<Asset>> searchAssets(String query, {int limit = 20}) async {
    if (query.length < 2) return [];

    // 1. Try cache first
    final cachedResults = _cache.getSearchResults(query);
    if (cachedResults != null) {
      debugPrint(
        '🚀 HYPER SPEED: Returning ${cachedResults.length} cached search results',
      );
      return cachedResults;
    }

    // 2. Search in cached assets first (instant)
    final allCachedAssets = await _cache.getAllAssetsWithHyperSpeed();
    if (allCachedAssets.isNotEmpty) {
      final filteredAssets = allCachedAssets
          .where(
            (asset) =>
                asset.name.toLowerCase().contains(query.toLowerCase()) ||
                asset.id.toLowerCase().contains(query.toLowerCase()) ||
                (asset.location.toLowerCase().contains(query.toLowerCase())) ||
                (asset.department
                        ?.toLowerCase()
                        .contains(query.toLowerCase()) ??
                    false),
          )
          .take(limit)
          .toList();

      if (filteredAssets.isNotEmpty) {
        _cache.cacheSearchResults(query, filteredAssets);
        debugPrint(
          '🚀 HYPER SPEED: Found ${filteredAssets.length} assets in cache',
        );
        return filteredAssets;
      }
    }

    // 3. Search via API if needed
    return _searchViaApi(query, limit);
  }

  /// Search via API
  Future<List<Asset>> _searchViaApi(String query, int limit) async {
    try {
      final headers = await _getHeaders();
      final url = ApiConfig.buildUrl(
        ApiConfig.searchAssets,
        queryParams: {
          'q': query,
          'limit': limit.toString(),
        },
      );

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        var assetsData = <dynamic>[];

        if (responseData is List) {
          assetsData = responseData;
        } else if (responseData is Map) {
          assetsData = responseData['data'] ?? responseData['assets'] ?? [];
        }

        final assets = assetsData.map((data) => Asset.fromJson(data)).toList();
        _cache.cacheSearchResults(query, assets);

        debugPrint(
          '🚀 HYPER SPEED: Found ${assets.length} assets via API search',
        );
        return assets;
      }
    } on Exception catch (e, st) {
      debugPrint('🚀 HYPER SPEED: API search error: $e');
    }

    return [];
  }

  /// Get headers for API requests
  Future<Map<String, String>> _getHeaders() async => {
        'Content-Type': 'application/json',
        'X-API-Key': 'cmms-maintenance',
      };

  /// Preload assets in background for hyper-speed
  Future<void> preloadAssets() async {
    debugPrint('🚀 HYPER SPEED: Starting background preload of ALL assets...');

    // Load ALL assets in background without blocking UI
    Timer(const Duration(milliseconds: 100), () async {
      try {
        final assets = await getAllAssets(); // No limit = ALL assets
        debugPrint(
          '🚀 HYPER SPEED: Preloaded ${assets.length} assets in background',
        );
      } catch (e, st) {
        debugPrint('🚀 HYPER SPEED: Background preload error: $e');
      }
    });
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _cache.clearAllCaches();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() => _cache.getCacheStats();
}
