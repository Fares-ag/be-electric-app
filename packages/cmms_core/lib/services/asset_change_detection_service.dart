import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'asset_integration_service.dart';

class AssetChangeDetectionService {

  static SharedPreferences? _prefs;
  static const String _lastAssetHashKey = 'last_asset_hash';
  static const String _lastAssetCountKey = 'last_asset_count';
  static const String _lastAssetTimestampKey = 'last_asset_timestamp';

  Future<SharedPreferences> get prefs async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Check if assets have been updated since last sync
  Future<bool> hasAssetsChanged() async {
    try {
      print('ðŸ” Checking for asset changes...');

      // Get current asset metadata from API
      final currentMetadata = await getCurrentAssetMetadata();
      if (currentMetadata == null) {
        print('ðŸ” Could not get current metadata, assuming no changes');
        return false;
      }

      // Get last known metadata
      final lastMetadata = await _getLastKnownMetadata();

      // If no previous metadata, assume changes exist (first time)
      if (lastMetadata == null) {
        print('ðŸ” No previous metadata found, assets need initial sync');
        await _saveCurrentMetadata(currentMetadata);
        return true;
      }

      // Compare metadata
      final hasChanges = _compareMetadata(lastMetadata, currentMetadata);

      if (hasChanges) {
        print('ðŸ” Asset changes detected!');
        print(
          'ðŸ” Previous: ${lastMetadata['count']} assets, hash: ${lastMetadata['hash']}',
        );
        print(
          'ðŸ” Current: ${currentMetadata['count']} assets, hash: ${currentMetadata['hash']}',
        );
      } else {
        print('ðŸ” No asset changes detected');
      }

      return hasChanges;
    } catch (e, st) {
      print('ðŸ” Error checking for changes: $e');
      // On error, assume no changes to avoid unnecessary syncs
      return false;
    }
  }

  /// Get current asset metadata from API
  Future<Map<String, dynamic>?> getCurrentAssetMetadata() async {
    try {
      // Try to get a lightweight metadata endpoint first
      final metadata = await _getAssetMetadataFromAPI();
      if (metadata != null) {
        return metadata;
      }

      // Fallback: get a small sample of assets to generate metadata
      print('ðŸ” Getting asset sample for metadata generation...');
      final sampleAssets =
          await AssetIntegrationService().getAllAssets(limit: 10);

      if (sampleAssets.isEmpty) {
        return null;
      }

      // Generate metadata from sample
      final assetIds = sampleAssets.map((a) => a.id).toList();
      final assetNames = sampleAssets.map((a) => a.name).toList();
      final assetTimestamps = sampleAssets
          .map(
            (a) =>
                a.lastUpdated?.toIso8601String() ??
                a.createdAt.toIso8601String(),
          )
          .toList();

      // Create a simple hash from the sample data
      final sampleData = {
        'ids': assetIds,
        'names': assetNames,
        'timestamps': assetTimestamps,
      };

      final hash = _generateHash(jsonEncode(sampleData));

      return {
        'count': sampleAssets.length,
        'hash': hash,
        'timestamp': DateTime.now().toIso8601String(),
        'sample_size': sampleAssets.length,
        'is_sample': true,
      };
    } catch (e, st) {
      print('ðŸ” Error getting current metadata: $e');
      return null;
    }
  }

  /// Try to get metadata from a dedicated API endpoint
  Future<Map<String, dynamic>?> _getAssetMetadataFromAPI() async {
    try {
      final headers = await AssetIntegrationService().getHeaders();
      final url = '${AssetIntegrationService().baseUrl}/getAssetMetadata';

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'count': data['totalAssets'] ?? 0,
          'hash': data['hash'] ?? '',
          'timestamp': data['lastUpdated'] ?? DateTime.now().toIso8601String(),
          'is_sample': false,
        };
      }
    } catch (e, st) {
      print('ðŸ” Metadata endpoint not available: $e');
    }
    return null;
  }

  /// Get last known metadata from local storage
  Future<Map<String, dynamic>?> _getLastKnownMetadata() async {
    try {
      final prefs = await this.prefs;
      final count = prefs.getInt(_lastAssetCountKey);
      final hash = prefs.getString(_lastAssetHashKey);
      final timestamp = prefs.getString(_lastAssetTimestampKey);

      if (count == null || hash == null || timestamp == null) {
        return null;
      }

      return {
        'count': count,
        'hash': hash,
        'timestamp': timestamp,
      };
    } catch (e, st) {
      print('ðŸ” Error getting last known metadata: $e');
      return null;
    }
  }

  /// Save current metadata to local storage
  Future<void> _saveCurrentMetadata(Map<String, dynamic> metadata) async {
    try {
      final prefs = await this.prefs;
      await prefs.setInt(_lastAssetCountKey, metadata['count'] ?? 0);
      await prefs.setString(_lastAssetHashKey, metadata['hash'] ?? '');
      await prefs.setString(
        _lastAssetTimestampKey,
        metadata['timestamp'] ?? DateTime.now().toIso8601String(),
      );
      print(
        'ðŸ” Saved current metadata: ${metadata['count']} assets, hash: ${metadata['hash']}',
      );
    } catch (e, st) {
      print('ðŸ” Error saving metadata: $e');
    }
  }

  /// Compare metadata to detect changes
  bool _compareMetadata(
    Map<String, dynamic> last,
    Map<String, dynamic> current,
  ) {
    // Check if count changed
    if (last['count'] != current['count']) {
      return true;
    }

    // Check if hash changed
    if (last['hash'] != current['hash']) {
      return true;
    }

    // Check if timestamp changed (for non-sample data)
    if (!current['is_sample'] && last['timestamp'] != current['timestamp']) {
      return true;
    }

    return false;
  }

  /// Generate a simple hash from string data
  String _generateHash(String data) => data.hashCode.toString();

  /// Update metadata after successful sync
  Future<void> updateMetadataAfterSync(Map<String, dynamic> newMetadata) async {
    await _saveCurrentMetadata(newMetadata);
    print('ðŸ” Updated metadata after successful sync');
  }

  /// Force check for changes (bypass cache)
  Future<bool> forceCheckForChanges() async {
    try {
      print('ðŸ” Force checking for asset changes...');
      final currentMetadata = await getCurrentAssetMetadata();
      if (currentMetadata == null) {
        return false;
      }

      final lastMetadata = await _getLastKnownMetadata();
      final hasChanges = lastMetadata == null ||
          _compareMetadata(lastMetadata, currentMetadata);

      if (hasChanges) {
        print('ðŸ” Force check: Changes detected');
      } else {
        print('ðŸ” Force check: No changes detected');
      }

      return hasChanges;
    } catch (e, st) {
      print('ðŸ” Error in force check: $e');
      return false;
    }
  }

  /// Get change detection info
  Future<Map<String, dynamic>> getChangeDetectionInfo() async {
    try {
      final lastMetadata = await _getLastKnownMetadata();
      final currentMetadata = await getCurrentAssetMetadata();

      return {
        'lastKnown': lastMetadata,
        'current': currentMetadata,
        'hasChanges': lastMetadata != null && currentMetadata != null
            ? _compareMetadata(lastMetadata, currentMetadata)
            : true,
        'lastCheck': DateTime.now().toIso8601String(),
      };
    } catch (e, st) {
      return {
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Clear change detection data
  Future<void> clearChangeDetectionData() async {
    try {
      final prefs = await this.prefs;
      await prefs.remove(_lastAssetHashKey);
      await prefs.remove(_lastAssetCountKey);
      await prefs.remove(_lastAssetTimestampKey);
      print('ðŸ” Cleared change detection data');
    } catch (e, st) {
      print('ðŸ” Error clearing change detection data: $e');
    }
  }
}
