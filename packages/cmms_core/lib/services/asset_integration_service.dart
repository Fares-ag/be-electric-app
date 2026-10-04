import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/asset.dart';

class AssetIntegrationService {
  AssetIntegrationService();

  /// Get the base URL for the Asset Management System
  String get baseUrl => ApiConfig.assetManagementBaseUrl;

  /// Get asset data by QR code from the Asset Management System
  Future<Asset?> getAssetByQRCode(String qrCode) async {
    try {
      print('ðŸ” getAssetByQRCode - Searching for QR code: $qrCode');

      // First check local cache
      final cachedAsset = await _getCachedAsset(qrCode);
      if (cachedAsset != null) {
        print('ðŸ” Found cached asset for QR code: $qrCode');
        return cachedAsset;
      }

      // Try multiple possible endpoints for QR code lookup
      final possibleEndpoints = [
        '${ApiConfig.assetManagementBaseUrl}${ApiConfig.damGetAssetsEndpoint}?qrCode=$qrCode',
        '${ApiConfig.assetManagementBaseUrl}/getAsset/$qrCode',
        '${ApiConfig.assetManagementBaseUrl}/getAssetByQRCode/$qrCode',
        '${ApiConfig.assetManagementBaseUrl}/searchAssets?qrCode=$qrCode',
        '${ApiConfig.assetManagementBaseUrl}/searchAssets?query=$qrCode',
      ];

      for (final endpoint in possibleEndpoints) {
        print('ðŸ” Trying endpoint: $endpoint');

        final response = await http
            .get(
              Uri.parse(endpoint),
              headers: await getHeaders(),
            )
            .timeout(
              const Duration(seconds: 3),
            ); // 3 second timeout for QR search

        print('ðŸ” getAssetByQRCode - Status: ${response.statusCode}');
        print('ðŸ” getAssetByQRCode - Response: ${response.body}');

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);

          // Handle different response structures
          Asset? asset;
          if (responseData is Map && responseData.containsKey('data')) {
            asset = Asset.fromJson(responseData['data']);
          } else if (responseData is Map && responseData.containsKey('asset')) {
            asset = Asset.fromJson(responseData['asset']);
          } else if (responseData is List && responseData.isNotEmpty) {
            // If it's a list, take the first match
            asset = Asset.fromJson(responseData.first);
          } else if (responseData is Map) {
            // Try to parse as direct asset
            asset = Asset.fromJson(Map<String, dynamic>.from(responseData));
          }

          if (asset != null) {
            print('ðŸ” Successfully found asset: ${asset.name} (${asset.id})');
            // Cache the result
            await _cacheAsset(qrCode, asset);
            return asset;
          }
        }
      }

      print('ðŸ” No asset found for QR code: $qrCode');
      return null;
    } catch (e, st) {
      print('Error fetching asset by QR code: $e');
      return null;
    }
  }

  /// Get asset data by asset ID from the Asset Management System
  Future<Asset?> getAssetById(String assetId) async {
    try {
      // First check local cache
      final cachedAsset = await _getCachedAsset(assetId);
      if (cachedAsset != null) {
        return cachedAsset;
      }

      // Fetch from API
      final asset = await _fetchAssetFromAPI(assetId);
      if (asset != null) {
        // Cache the result
        await _cacheAsset(assetId, asset);
      }

      return asset;
    } catch (e, st) {
      print('Error fetching asset by ID: $e');
      return null;
    }
  }

  /// Search assets by name, location, or department
  Future<List<Asset>> searchAssets(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.searchAssetsUrl(query)),
            headers: await getHeaders(),
          )
          .timeout(const Duration(seconds: 8)); // 8 second timeout for search

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Your API returns assets directly as an array
        if (data is List) {
          return data.map((json) => Asset.fromJson(json)).toList();
        } else if (data is Map && data.containsKey('assets')) {
          return (data['assets'] as List)
              .map((json) => Asset.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e, st) {
      print('Error searching assets: $e');
      return [];
    }
  }

  /// Test connection to the Asset Management System
  Future<bool> testConnection() async {
    try {
      print('ðŸ” Testing connection to DAM API...');
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.assetManagementBaseUrl}${ApiConfig.damHealthEndpoint}',
            ),
            headers: await getHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      print('ðŸ” Health check response: ${response.statusCode}');
      print('ðŸ” Health check body: ${response.body}');

      return response.statusCode == 200;
    } catch (e, st) {
      print('âŒ Connection test failed: $e');
      return false;
    }
  }

  /// Get all assets from the Asset Management System (with pagination)
  Future<List<Asset>> getAllAssets({int? limit}) async {
    try {
      await getHeaders();
      final allAssets = <Asset>[];
      var offset = 0;
      final pageLimit =
          limit ?? 50; // Use provided limit or default to 50 for faster loading
      var hasMore = true;

      // Use Bearer token authentication
      ApiConfig.damApiKey;
      const baseUrl =
          '${ApiConfig.assetManagementBaseUrl}${ApiConfig.damGetAssetsEndpoint}';

      print('ðŸ” Using Bearer token authentication for: $baseUrl');
      const maxTotalAssets = 10000; // Very high limit to get ALL assets

      print('ðŸ” Starting to fetch all assets with pagination...');

      while (hasMore && allAssets.length < maxTotalAssets) {
        // Use Bearer token authentication
        final url = '$baseUrl?limit=$pageLimit&offset=$offset';

        print('ðŸ” Fetching assets - Offset: $offset, Limit: $pageLimit');
        print('ðŸ” Request URL: $url');

        final response = await http
            .get(
              Uri.parse(url),
              headers: await getHeaders(),
            )
            .timeout(
              const Duration(seconds: 15),
            ); // 15 second timeout for asset loading

        print('ðŸ” getAllAssets - Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);

          // Handle different response structures
          List<dynamic> assetsData;
          if (responseData is List) {
            assetsData = responseData;
          } else if (responseData is Map && responseData.containsKey('data')) {
            assetsData = responseData['data'];
          } else if (responseData is Map &&
              responseData.containsKey('assets')) {
            assetsData = responseData['assets'];
          } else if (responseData is Map && responseData.containsKey('items')) {
            assetsData = responseData['items'];
          } else {
            // Try to find any array in the response
            final keys = responseData.keys.toList();
            print('ðŸ” Available keys: $keys');
            assetsData = [];
          }

          // Parse assets from this batch
          for (var i = 0; i < assetsData.length; i++) {
            try {
              final asset = Asset.fromJson(assetsData[i]);
              allAssets.add(asset);
            } catch (e, st) {
              print('ðŸ” Error parsing asset ${offset + i}: $e');
              if (i < 3) {
                // Only print first 3 errors to avoid spam
                print('ðŸ” Asset data: ${assetsData[i]}');
              }
            }
          }

          // Check pagination info
          if (responseData is Map && responseData.containsKey('pagination')) {
            final pagination = responseData['pagination'];
            hasMore = pagination['hasMore'] ?? false;
            print(
              'ðŸ” Pagination - hasMore: $hasMore, total: ${pagination['total']}',
            );
          } else {
            // If no pagination info, stop if we got fewer assets than requested
            hasMore = assetsData.length >= pageLimit;
            print(
              'ðŸ” No pagination info - hasMore: $hasMore (got ${assetsData.length} assets)',
            );

            // Additional safety check: if we got 0 assets, definitely stop
            if (assetsData.isEmpty) {
              hasMore = false;
              print('ðŸ” Stopping pagination - no more assets available');
            }
          }

          offset += pageLimit;
          print(
            'ðŸ” Fetched ${assetsData.length} assets in this batch. Total so far: ${allAssets.length}',
          );

          // Safety check: if we've reached the limit, stop
          if (limit != null && allAssets.length >= limit) {
            hasMore = false;
            print('ðŸ” Reached requested limit of $limit assets');
          }
        } else {
          print('ðŸ” getAllAssets - Error status: ${response.statusCode}');
          break;
        }
      }

      print('ðŸ” Successfully fetched ${allAssets.length} total assets');
      return allAssets;
    } catch (e, st) {
      print('Error fetching all assets: $e');
      return [];
    }
  }

  /// Get assets by location (using search functionality)
  Future<List<Asset>> getAssetsByLocation(String location) async {
    try {
      // Use search functionality to find assets by location
      final allAssets = await getAllAssets();
      return allAssets
          .where(
            (asset) =>
                asset.location.toLowerCase().contains(location.toLowerCase()),
          )
          .toList();
    } catch (e, st) {
      print('Error fetching assets by location: $e');
      return [];
    }
  }

  /// Get assets by department
  Future<List<Asset>> getAssetsByDepartment(String department) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getAssetsByDepartmentUrl(department)),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['assets'] as List)
            .map((json) => Asset.fromJson(json))
            .toList();
      }

      return [];
    } catch (e, st) {
      print('Error fetching assets by department: $e');
      return [];
    }
  }

  /// Get vehicle assets with maintenance information
  Future<List<Asset>> getVehicleAssets() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.assetManagementBaseUrl}/getVehicleAssets'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((json) => Asset.fromJson(json)).toList();
        } else if (data is Map && data.containsKey('assets')) {
          return (data['assets'] as List)
              .map((json) => Asset.fromJson(json))
              .toList();
        }
      }

      return [];
    } catch (e, st) {
      print('Error fetching vehicle assets: $e');
      return [];
    }
  }

  /// Get maintenance history for an asset
  Future<List<Map<String, dynamic>>> getMaintenanceHistory(
    String assetId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.assetManagementBaseUrl}/getAssetMaintenance/$assetId',
        ),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('maintenance')) {
          return List<Map<String, dynamic>>.from(data['maintenance']);
        }
      }

      return [];
    } catch (e, st) {
      print('Error fetching maintenance history: $e');
      return [];
    }
  }

  /// Create maintenance record in Asset Management System
  Future<bool> createMaintenanceRecord(
    String assetId,
    Map<String, dynamic> maintenanceData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.assetManagementBaseUrl}/addMaintenance'),
        headers: await getHeaders(),
        body: json.encode({
          ...maintenanceData,
          'vehicleId': assetId,
        }),
      );

      return response.statusCode == 200;
    } catch (e, st) {
      print('Error creating maintenance record: $e');
      return false;
    }
  }

  /// Update asset maintenance information
  Future<bool> updateAssetMaintenance(
    String assetId,
    Map<String, dynamic> maintenanceData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.assetManagementBaseUrl}/updateAssetMaintenance/$assetId',
        ),
        headers: await getHeaders(),
        body: json.encode(maintenanceData),
      );

      return response.statusCode == 200;
    } catch (e, st) {
      print('Error updating asset maintenance: $e');
      return false;
    }
  }

  /// Update asset condition
  Future<bool> updateAssetCondition(String assetId, String condition) async {
    try {
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.assetManagementBaseUrl}/updateAssetCondition/$assetId',
        ),
        headers: await getHeaders(),
        body: json.encode({'condition': condition}),
      );

      return response.statusCode == 200;
    } catch (e, st) {
      print('Error updating asset condition: $e');
      return false;
    }
  }

  /// Update asset location
  Future<bool> updateAssetLocation(String assetId, String location) async {
    try {
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.assetManagementBaseUrl}/updateAssetLocation/$assetId',
        ),
        headers: await getHeaders(),
        body: json.encode({'location': location}),
      );

      return response.statusCode == 200;
    } catch (e, st) {
      print('Error updating asset location: $e');
      return false;
    }
  }

  /// Private method to fetch asset from API
  Future<Asset?> _fetchAssetFromAPI(String identifier) async {
    final response = await http.get(
      Uri.parse(ApiConfig.getAssetByIdUrl(identifier)),
      headers: await getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Asset.fromJson(data);
    }

    return null;
  }

  /// Get authentication headers
  Future<Map<String, String>> getHeaders() async {
    // Use DAM API key for authentication
    const apiKey = ApiConfig.damApiKey;

    print('ðŸ”‘ Using DAM API key: $apiKey');

    // Use X-API-Key header (correct format for this API)
    return {
      ...ApiConfig.defaultHeaders,
      'X-API-Key': apiKey,
    };
  }

  /// Cache asset data locally
  Future<void> _cacheAsset(String key, Asset asset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString(ApiConfig.cacheKey) ?? '{}';
      final cacheMap = Map<String, dynamic>.from(json.decode(cache));

      cacheMap[key] = {
        'asset': asset.toJson(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(ApiConfig.cacheKey, json.encode(cacheMap));
    } catch (e, st) {
      print('Error caching asset: $e');
    }
  }

  /// Get cached asset data
  Future<Asset?> _getCachedAsset(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString(ApiConfig.cacheKey) ?? '{}';
      final cacheMap = Map<String, dynamic>.from(json.decode(cache));

      if (cacheMap.containsKey(key)) {
        final cachedData = cacheMap[key];
        final timestamp =
            DateTime.fromMillisecondsSinceEpoch(cachedData['timestamp']);

        // Check if cache is still valid
        if (DateTime.now().difference(timestamp) < ApiConfig.cacheExpiry) {
          return Asset.fromJson(cachedData['asset']);
        } else {
          // Remove expired cache
          cacheMap.remove(key);
          await prefs.setString(ApiConfig.cacheKey, json.encode(cacheMap));
        }
      }

      return null;
    } catch (e, st) {
      print('Error getting cached asset: $e');
      return null;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConfig.cacheKey);
    } catch (e, st) {
      print('Error clearing cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString(ApiConfig.cacheKey) ?? '{}';
      final cacheMap = Map<String, dynamic>.from(json.decode(cache));

      var validEntries = 0;
      var expiredEntries = 0;

      for (final entry in cacheMap.values) {
        final timestamp =
            DateTime.fromMillisecondsSinceEpoch(entry['timestamp']);
        if (DateTime.now().difference(timestamp) < ApiConfig.cacheExpiry) {
          validEntries++;
        } else {
          expiredEntries++;
        }
      }

      return {
        'totalEntries': cacheMap.length,
        'validEntries': validEntries,
        'expiredEntries': expiredEntries,
        'cacheSize': cache.length,
      };
    } catch (e, st) {
      print('Error getting cache stats: $e');
      return {};
    }
  }
}
