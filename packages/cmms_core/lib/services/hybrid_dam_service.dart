// Hybrid DAM Service - Automatically tries the best connection method
// First attempts direct Supabase, then falls back to optimized API
// This solves permission issues by using the best available method

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../config/service_locator.dart';
import '../models/asset.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_service_access.dart';
import 'simple_asset_mapper.dart';

class HybridDamService {
  SupabaseClient? _supabase;
  bool _isInitialized = false;
  String _connectionMethod = 'none';
  List<Asset> _cachedAssets = [];
  DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Persistent disk cache so cold-starts and offline sessions can render assets.
  static const String _diskCacheAssetsKey = 'be_assets_disk_v1';
  static const String _diskCacheTimestampKey = 'be_assets_disk_ts_v1';
  bool _diskCacheHydrated = false;

  /// Dedup concurrent network fetches so only one round-trip is in flight.
  Future<List<Asset>>? _inFlightFetch;

  /// Current connection method being used
  String get connectionMethod => _connectionMethod;

  List<Asset> get cachedAssets => List<Asset>.unmodifiable(_cachedAssets);

  bool get isCacheFresh =>
      _cachedAssets.isNotEmpty &&
      _lastCacheTime != null &&
      DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;

  /// Initialize the hybrid service
  Future<void> initialize() async {
    try {
      _supabase = Supabase.instance.client;

      if (await _tryDirectSupabase()) {
        _connectionMethod = 'direct_supabase';
        _isInitialized = true;
        return;
      }

      if (await _tryApiConnection()) {
        _connectionMethod = 'api_fallback';
        _isInitialized = true;
        debugPrint('Hybrid DAM: API fallback connection established');
        return;
      }

      _isInitialized = false;
      _connectionMethod = 'none';
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: Initialization failed: $e');
      _isInitialized = false;
      _connectionMethod = 'none';
    }
  }

  /// Try direct Supabase connection
  Future<bool> _tryDirectSupabase() async {
    try {
      if (_supabase == null) return false;
      await _supabase!.from('assets').select().limit(1);
      return true;
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: Direct Supabase failed: $e');
      return false;
    }
  }

  /// Try API connection
  Future<bool> _tryApiConnection() async {
    try {
      debugPrint('Hybrid DAM: Attempting API connection...');

      const url =
          '${ApiConfig.assetManagementBaseUrl}${ApiConfig.damGetAssetsEndpoint}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': ApiConfig.damApiKey,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('Hybrid DAM: API connection successful');
        return true;
      }

      debugPrint('Hybrid DAM: API connection failed: ${response.statusCode}');
      return false;
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: API connection error: $e');
      return false;
    }
  }

  bool get _isOnline {
    if (!getIt.isRegistered<ConnectivityService>()) return true;
    return resolveConnectivityService().isOnline;
  }

  /// Get all assets using the best available method.
  ///
  /// Serves in-memory / disk cache immediately when offline or while a
  /// background refresh runs.
  Future<List<Asset>> getAllAssets({int? limit, bool forceRefresh = false}) async {
    if (!_diskCacheHydrated) {
      await _hydrateFromDiskCache();
    }

    if (!_isOnline) {
      return _applyLimit(_cachedAssets, limit);
    }

    if (!forceRefresh && _cachedAssets.isNotEmpty) {
      if (!isCacheFresh || _connectionMethod == 'none') {
        unawaited(_refreshInBackground());
      }
      return _applyLimit(_cachedAssets, limit);
    }

    try {
      final assets = await _fetchFromNetworkDeduped(forceRefresh: forceRefresh);
      return _applyLimit(assets, limit);
    } catch (e) {
      debugPrint('Hybrid DAM: Error getting assets: $e');
      return _applyLimit(_cachedAssets, limit);
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      await _fetchFromNetworkDeduped();
    } catch (e) {
      debugPrint('Hybrid DAM: Background refresh failed: $e');
    }
  }

  Future<List<Asset>> _fetchFromNetworkDeduped({bool forceRefresh = false}) {
    final existing = _inFlightFetch;
    if (existing != null) {
      return existing;
    }

    final fresh = _fetchFromNetwork(forceRefresh: forceRefresh);
    _inFlightFetch = fresh;
    fresh.whenComplete(() {
      _inFlightFetch = null;
    });
    return fresh;
  }

  Future<List<Asset>> _fetchFromNetwork({bool forceRefresh = false}) async {
    if (!_isInitialized || forceRefresh) {
      await initialize();
      _isInitialized = true;
    }

    if (_connectionMethod == 'none') {
      return _cachedAssets;
    }

    List<Asset> assets;
    if (_connectionMethod == 'direct_supabase') {
      assets = await _getAssetsFromSupabase();
    } else if (_connectionMethod == 'api_fallback') {
      assets = await _getAssetsFromApi();
    } else {
      return _cachedAssets;
    }

    assets = _activeAssetsOnly(assets);
    if (assets.isNotEmpty) {
      _commitCache(assets);
    }
    return assets;
  }

  /// Warm asset disk cache after technician auth (non-blocking).
  Future<void> prefetch() async {
    try {
      if (!_diskCacheHydrated) {
        await _hydrateFromDiskCache();
      }
      if (!_isOnline) return;
      await _fetchFromNetworkDeduped();
    } catch (e) {
      debugPrint('Hybrid DAM: prefetch skipped: $e');
    }
  }

  List<Asset> _activeAssetsOnly(List<Asset> assets) =>
      assets.where((asset) => asset.status.toLowerCase() == 'active').toList();

  List<Asset> _applyLimit(List<Asset> source, int? limit) {
    if (limit == null || limit <= 0 || source.length <= limit) return source;
    return source.take(limit).toList();
  }

  Future<void> _hydrateFromDiskCache() async {
    _diskCacheHydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_diskCacheAssetsKey);
      final tsMs = prefs.getInt(_diskCacheTimestampKey);
      if (raw == null || raw.isEmpty) return;

      final list = jsonDecode(raw) as List<dynamic>;
      final restored = <Asset>[];
      for (final entry in list) {
        try {
          restored.add(
            Asset.fromJson(Map<String, dynamic>.from(entry as Map)),
          );
        } catch (_) {
          // Skip malformed entries — disk cache is best-effort.
        }
      }
      if (restored.isEmpty) return;

      _cachedAssets = restored;
      _lastCacheTime =
          tsMs != null ? DateTime.fromMillisecondsSinceEpoch(tsMs) : null;
      debugPrint(
        'Hybrid DAM: Hydrated ${restored.length} asset(s) from disk cache',
      );
    } catch (e) {
      debugPrint('Hybrid DAM: Disk cache hydration failed: $e');
    }
  }

  Future<void> _persistToDiskCache(List<Asset> assets, DateTime ts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(assets.map((a) => a.toJson()).toList());
      await prefs.setString(_diskCacheAssetsKey, encoded);
      await prefs.setInt(_diskCacheTimestampKey, ts.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Hybrid DAM: Disk cache write failed: $e');
    }
  }

  void _commitCache(List<Asset> assets) {
    _cachedAssets = assets;
    _lastCacheTime = DateTime.now();
    unawaited(_persistToDiskCache(assets, _lastCacheTime!));
  }

  /// Get assets from direct Supabase with full details
  Future<List<Asset>> _getAssetsFromSupabase({int? limit}) async {
    try {
      debugPrint(
        'Hybrid DAM: Fetching from direct Supabase with full details...',
      );

      if (_supabase == null) {
        throw Exception('Supabase client not initialized');
      }
      var queryBuilder = _supabase!.from('assets').select();
      if (limit != null) {
        queryBuilder = queryBuilder.limit(limit) as dynamic;
      }

      final response = await queryBuilder;
      final records = response as List;

      return records
          .map((record) {
            final data = Map<String, dynamic>.from(record);
            return _convertFirestoreAssetToCMMSAsset(data);
          })
          .toList();
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: Direct Supabase error: $e');
      return [];
    }
  }

  /// Get assets from API
  Future<List<Asset>> _getAssetsFromApi({int? limit}) async {
    try {
      debugPrint('Hybrid DAM: Fetching from API...');

      const url =
          '${ApiConfig.assetManagementBaseUrl}${ApiConfig.damGetAssetsEndpoint}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-API-Key': ApiConfig.damApiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> assetsData;

        if (data is List) {
          assetsData = data;
        } else if (data['assets'] != null) {
          assetsData = data['assets'] as List;
        } else if (data['data'] != null) {
          assetsData = data['data'] as List;
        } else {
          assetsData = [data];
        }

        var assets = assetsData
            .map(
              (item) =>
                  _convertApiAssetToCMMSAsset(item as Map<String, dynamic>),
            )
            .toList();

        if (limit != null) {
          assets = assets.take(limit).toList();
        }

        debugPrint('Hybrid DAM: API returned ${assets.length} assets');
        return assets;
      }

      debugPrint('Hybrid DAM: API error: ${response.statusCode}');
      return [];
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: API error: $e');
      return [];
    }
  }

  Asset _convertFirestoreAssetToCMMSAsset(Map<String, dynamic> firestoreAsset) =>
      SimpleAssetMapper.mapToCMMSAsset(firestoreAsset);

  Asset _convertApiAssetToCMMSAsset(Map<String, dynamic> apiAsset) =>
      SimpleAssetMapper.mapToCMMSAsset(apiAsset);

  Asset? _findCachedAsset(bool Function(Asset asset) test) {
    for (final asset in _cachedAssets) {
      if (test(asset)) return asset;
    }
    return null;
  }

  /// Search assets using the current connection method
  Future<List<Asset>> searchAssets(String query) async {
    try {
      final allAssets = await getAllAssets();
      return allAssets
          .where(
            (asset) =>
                asset.name.toLowerCase().contains(query.toLowerCase()) ||
                asset.location.toLowerCase().contains(query.toLowerCase()) ||
                (asset.category?.toLowerCase().contains(query.toLowerCase()) ??
                    false) ||
                (asset.serialNumber
                        ?.toLowerCase()
                        .contains(query.toLowerCase()) ??
                    false),
          )
          .toList();
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: Search error: $e');
      return [];
    }
  }

  /// Get asset by ID using the current connection method with full details
  Future<Asset?> getAssetById(String id) async {
    try {
      debugPrint('Hybrid DAM: Getting asset by ID: $id');

      if (!_diskCacheHydrated) {
        await _hydrateFromDiskCache();
      }

      final cached = _findCachedAsset((asset) => asset.id == id);
      if (!_isOnline) {
        return cached;
      }

      if (_connectionMethod == 'direct_supabase') {
        if (_supabase == null) {
          throw Exception('Supabase client not initialized');
        }
        final response = await _supabase!
            .from('assets')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          final data = Map<String, dynamic>.from(response);
          return _convertFirestoreAssetToCMMSAsset(data);
        }
      }

      final allAssets = await getAllAssets();
      return allAssets.firstWhere(
        (asset) => asset.id == id,
        orElse: () => cached ?? (throw Exception('Asset not found')),
      );
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: Get asset by ID error: $e');
      return _findCachedAsset((asset) => asset.id == id);
    }
  }

  /// Get asset by QR code using the current connection method with full details
  Future<Asset?> getAssetByQRCode(String qrCode) async {
    try {
      debugPrint('Hybrid DAM: Getting asset by QR code: $qrCode');

      if (!_diskCacheHydrated) {
        await _hydrateFromDiskCache();
      }

      final cached = _findCachedAsset(
        (asset) =>
            asset.qrCode == qrCode ||
            asset.qrCodeId == qrCode ||
            asset.id == qrCode,
      );
      if (!_isOnline) {
        return cached;
      }

      if (_connectionMethod == 'direct_supabase') {
        debugPrint('Searching in Supabase table "assets" for: $qrCode');

        if (_supabase == null) {
          throw Exception('Supabase client not initialized');
        }

        final qrResponse = await _supabase!
            .from('assets')
            .select()
            .eq('qrCode', qrCode)
            .limit(1)
            .maybeSingle();

        if (qrResponse != null) {
          final data = Map<String, dynamic>.from(qrResponse);
          return _convertFirestoreAssetToCMMSAsset(data);
        }

        final altQrResponse = await _supabase!
            .from('assets')
            .select()
            .eq('qr_code', qrCode)
            .limit(1)
            .maybeSingle();

        if (altQrResponse != null) {
          final data = Map<String, dynamic>.from(altQrResponse);
          return _convertFirestoreAssetToCMMSAsset(data);
        }

        final idResponse = await _supabase!
            .from('assets')
            .select()
            .eq('id', qrCode)
            .limit(1)
            .maybeSingle();

        if (idResponse != null) {
          final data = Map<String, dynamic>.from(idResponse);
          return _convertFirestoreAssetToCMMSAsset(data);
        }

        debugPrint('No asset found in Supabase with any of the search methods');
      }

      final allAssets = await getAllAssets();
      return allAssets.firstWhere(
        (asset) =>
            asset.qrCode == qrCode ||
            asset.qrCodeId == qrCode ||
            asset.id == qrCode,
        orElse: () => cached ?? (throw Exception('Asset not found')),
      );
    } on Exception catch (e) {
      debugPrint('Hybrid DAM: Get asset by QR code error: $e');
      return _findCachedAsset(
        (asset) =>
            asset.qrCode == qrCode ||
            asset.qrCodeId == qrCode ||
            asset.id == qrCode,
      );
    }
  }

  /// Get connection status and performance info
  Map<String, dynamic> getConnectionInfo() => {
        'connectionMethod': _connectionMethod,
        'isInitialized': _isInitialized,
        'cachedAssetsCount': _cachedAssets.length,
        'lastCacheTime': _lastCacheTime?.toIso8601String(),
        'cacheAge': _lastCacheTime != null
            ? DateTime.now().difference(_lastCacheTime!).inSeconds
            : null,
        'diskCacheHydrated': _diskCacheHydrated,
      };

  /// Clear in-memory cache
  void clearCache() {
    _cachedAssets.clear();
    _lastCacheTime = null;
    debugPrint('Hybrid DAM: Cache cleared');
  }

  /// Clears the persistent SharedPreferences asset snapshot.
  Future<void> clearDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_diskCacheAssetsKey);
      await prefs.remove(_diskCacheTimestampKey);
      _diskCacheHydrated = false;
      debugPrint('Hybrid DAM: Disk cache cleared');
    } catch (e) {
      debugPrint('Hybrid DAM: Disk cache clear failed: $e');
    }
  }

  /// Clears memory + disk caches (logout / session purge).
  Future<void> clearAllCaches() async {
    clearCache();
    await clearDiskCache();
  }
}
