import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/release_safety.dart';

/// Comprehensive utility to remove ALL duplicate data from Supabase
/// Keeps the newest entry for each duplicate ID
class ComprehensiveDuplicateCleanup {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Clean up all duplicates across all collections
  Future<Map<String, dynamic>> cleanupAll() async {
    if (!ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Duplicate cleanup is disabled in release builds');
    }

    debugPrint('🧹 Starting comprehensive duplicate cleanup...');

    final results = <String, dynamic>{
      'users': await _cleanupUsers(),
      'workOrders': await _cleanupWorkOrders(),
      'pmTasks': await _cleanupPMTasks(),
      'assets': await _cleanupAssets(),
      'inventory': await _cleanupInventory(),
    };

    // Calculate total
    var totalRemoved = 0;
    for (final entity in results.values) {
      totalRemoved += entity['duplicatesRemoved'] as int;
    }
    results['totalDuplicatesRemoved'] = totalRemoved;

    debugPrint('🎉 Cleanup complete! Removed $totalRemoved duplicates total');
    return results;
  }

  /// Clean up duplicate users (by email AND by id)
  Future<Map<String, int>> _cleanupUsers() async {
    debugPrint('👤 Cleaning up duplicate users...');

    final response = await _supabase.from('users').select();
    final records = response as List;
    debugPrint('   Found ${records.length} total user documents');

    // Group by actual user ID (from data, not Supabase row)
    final byUserId = <String, List<Map<String, dynamic>>>{};
    final byEmail = <String, List<Map<String, dynamic>>>{};

    for (final record in records) {
      final data = Map<String, dynamic>.from(record);
      final userId = data['id'] as String?;
      final email = data['email'] as String?;

      if (userId != null) {
        byUserId.putIfAbsent(userId, () => []).add(data);
      }
      if (email != null) {
        byEmail.putIfAbsent(email, () => []).add(data);
      }
    }

    var duplicatesRemoved = 0;

    // Remove duplicates by user ID
    for (final entry in byUserId.entries) {
      if (entry.value.length > 1) {
        duplicatesRemoved +=
            await _removeDuplicateRecords(entry.value, 'user ID: ${entry.key}');
      }
    }

    // Remove duplicates by email (keeping only newest)
    for (final entry in byEmail.entries) {
      if (entry.value.length > 1) {
        duplicatesRemoved +=
            await _removeDuplicateRecords(entry.value, 'email: ${entry.key}');
      }
    }

    final remaining = records.length - duplicatesRemoved;
    debugPrint(
        '   ✅ Removed $duplicatesRemoved duplicate users, $remaining remaining',);

    return {
      'duplicatesRemoved': duplicatesRemoved,
      'remaining': remaining,
    };
  }

  /// Clean up duplicate work orders (by id)
  Future<Map<String, int>> _cleanupWorkOrders() async {
    debugPrint('📋 Cleaning up duplicate work orders...');

    final response = await _supabase.from('work_orders').select();
    final records = response as List;
    debugPrint('   Found ${records.length} total work order documents');

    final byId = <String, List<Map<String, dynamic>>>{};

    for (final record in records) {
      final data = Map<String, dynamic>.from(record);
      final workOrderId = data['id'] as String?;

      if (workOrderId != null) {
        byId.putIfAbsent(workOrderId, () => []).add(data);
      }
    }

    var duplicatesRemoved = 0;

    for (final entry in byId.entries) {
      if (entry.value.length > 1) {
        duplicatesRemoved += await _removeDuplicateRecords(
            entry.value, 'work order ID: ${entry.key}',);
      }
    }

    final remaining = records.length - duplicatesRemoved;
    debugPrint(
        '   ✅ Removed $duplicatesRemoved duplicate work orders, $remaining remaining',);

    return {
      'duplicatesRemoved': duplicatesRemoved,
      'remaining': remaining,
    };
  }

  /// Clean up duplicate PM tasks (by id)
  Future<Map<String, int>> _cleanupPMTasks() async {
    debugPrint('🔧 Cleaning up duplicate PM tasks...');

    final response = await _supabase.from('pm_tasks').select();
    final records = response as List;
    debugPrint('   Found ${records.length} total PM task documents');

    final byId = <String, List<Map<String, dynamic>>>{};

    for (final record in records) {
      final data = Map<String, dynamic>.from(record);
      final taskId = data['id'] as String?;

      if (taskId != null) {
        byId.putIfAbsent(taskId, () => []).add(data);
      }
    }

    var duplicatesRemoved = 0;

    for (final entry in byId.entries) {
      if (entry.value.length > 1) {
        duplicatesRemoved +=
            await _removeDuplicateRecords(entry.value, 'PM task ID: ${entry.key}');
      }
    }

    final remaining = records.length - duplicatesRemoved;
    debugPrint(
        '   ✅ Removed $duplicatesRemoved duplicate PM tasks, $remaining remaining',);

    return {
      'duplicatesRemoved': duplicatesRemoved,
      'remaining': remaining,
    };
  }

  /// Clean up duplicate assets (by id)
  Future<Map<String, int>> _cleanupAssets() async {
    debugPrint('🏗️ Cleaning up duplicate assets...');

    final response = await _supabase.from('assets').select();
    final records = response as List;
    debugPrint('   Found ${records.length} total asset documents');

    final byId = <String, List<Map<String, dynamic>>>{};

    for (final record in records) {
      final data = Map<String, dynamic>.from(record);
      final assetId = data['id'] as String?;

      if (assetId != null) {
        byId.putIfAbsent(assetId, () => []).add(data);
      }
    }

    var duplicatesRemoved = 0;

    for (final entry in byId.entries) {
      if (entry.value.length > 1) {
        duplicatesRemoved +=
            await _removeDuplicateRecords(entry.value, 'asset ID: ${entry.key}');
      }
    }

    final remaining = records.length - duplicatesRemoved;
    debugPrint(
        '   ✅ Removed $duplicatesRemoved duplicate assets, $remaining remaining',);

    return {
      'duplicatesRemoved': duplicatesRemoved,
      'remaining': remaining,
    };
  }

  /// Clean up duplicate inventory items (by id)
  Future<Map<String, int>> _cleanupInventory() async {
    debugPrint('📦 Cleaning up duplicate inventory items...');

    final response = await _supabase.from('inventory_items').select();
    final records = response as List;
    debugPrint('   Found ${records.length} total inventory documents');

    final byId = <String, List<Map<String, dynamic>>>{};

    for (final record in records) {
      final data = Map<String, dynamic>.from(record);
      final itemId = data['id'] as String?;

      if (itemId != null) {
        byId.putIfAbsent(itemId, () => []).add(data);
      }
    }

    var duplicatesRemoved = 0;

    for (final entry in byId.entries) {
      if (entry.value.length > 1) {
        duplicatesRemoved += await _removeDuplicateRecords(
            entry.value, 'inventory ID: ${entry.key}',);
      }
    }

    final remaining = records.length - duplicatesRemoved;
    debugPrint(
        '   ✅ Removed $duplicatesRemoved duplicate inventory items, $remaining remaining',);

    return {
      'duplicatesRemoved': duplicatesRemoved,
      'remaining': remaining,
    };
  }

  /// Helper: Remove duplicate records, keeping the newest
  Future<int> _removeDuplicateRecords(
    List<Map<String, dynamic>> records,
    String identifier,
  ) async {
    if (records.length <= 1) return 0;

    // Sort by updatedAt or createdAt (newest first)
    records.sort((a, b) {
      final aDate = _getLatestDate(a);
      final bDate = _getLatestDate(b);

      return bDate.compareTo(aDate); // Newest first
    });

    // Keep first (newest), delete rest
    final toDelete = records.sublist(1);
    debugPrint(
        '   🗑️  Removing ${toDelete.length} duplicates for $identifier',);

    final idsToDelete = toDelete
        .where((r) => r['id'] != null)
        .map((r) => r['id'].toString())
        .toList();

    if (idsToDelete.isNotEmpty) {
      try {
        // Determine table name from identifier context
        String tableName = 'users'; // default
        if (identifier.contains('work order')) {
          tableName = 'work_orders';
        } else if (identifier.contains('PM task')) {
          tableName = 'pm_tasks';
        } else if (identifier.contains('asset')) {
          tableName = 'assets';
        } else if (identifier.contains('inventory')) {
          tableName = 'inventory_items';
        }

        // Delete records individually as Supabase doesn't support batch delete with in_ filter
        for (final id in idsToDelete) {
          try {
            await _supabase.from(tableName).delete().eq('id', id);
          } catch (e, st) {
            debugPrint('Error deleting $id: $e');
          }
        }
      } catch (e, st) {
        debugPrint('   ❌ Failed to delete duplicates: $e');
      }
    }

    return toDelete.length;
  }

  /// Helper: Get the latest date from updatedAt or createdAt
  DateTime _getLatestDate(Map<String, dynamic> data) {
    try {
      // Try updatedAt first
      if (data['updatedAt'] != null) {
        final updatedAt = data['updatedAt'];
        if (updatedAt is String) return DateTime.parse(updatedAt);
      }

      // Fallback to createdAt
      if (data['createdAt'] != null) {
        final createdAt = data['createdAt'];
        if (createdAt is String) return DateTime.parse(createdAt);
      }
    } catch (e, st) {
      // Ignore parsing errors
    }

    // Default to very old date if no valid date found
    return DateTime(2000);
  }
}
