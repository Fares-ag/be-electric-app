// Remove All Sample Data Utility
//
// This utility removes all sample data from both local storage and Firestore
// while preserving any real user data that may have been added.

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/release_safety.dart';


class RemoveAllSampleData {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Remove all sample data from the system
  static Future<Map<String, dynamic>> removeAllSampleData() async {
    if (!ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Sample data removal is disabled in release builds');
    }

    try {
      debugPrint('🧹 Starting complete sample data removal...');

      var totalRemoved = 0;
      final results = <String, int>{};

      // 1. Remove sample data from Firestore
      debugPrint('🔥 Removing sample data from Firestore...');
      final firestoreResults = await _removeFirestoreSampleData();
      results.addAll(firestoreResults);
      totalRemoved +=
          firestoreResults.values.fold(0, (sum, count) => sum + count);

      // 2. Remove sample data from local storage
      debugPrint('💾 Removing sample data from local storage...');
      final localResults = await _removeLocalSampleData();
      results.addAll(localResults);
      totalRemoved += localResults.values.fold(0, (sum, count) => sum + count);

      // 3. Set permanent block flags
      debugPrint('🛡️ Setting permanent block flags...');
      await _setPermanentBlockFlags();

      debugPrint('✅ Sample data removal complete!');
      debugPrint('📊 Total items removed: $totalRemoved');

      return {
        'success': true,
        'totalRemoved': totalRemoved,
        'details': results,
        'message': 'All sample data removed successfully',
      };
    } catch (e) {
      debugPrint('❌ Error removing sample data: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to remove sample data',
      };
    }
  }

  /// Remove sample data from Supabase
  static Future<Map<String, int>> _removeFirestoreSampleData() async {
    final results = <String, int>{};

    try {
      // Define sample data patterns to remove
      final samplePatterns = {
        'work_orders': [
          'WO-00123', // Sample work order ticket number
        ],
        'pm_tasks': [
          'Monthly Conveyor Inspection', // Sample PM task name
        ],
        'users': [
          'john.smith@qauto.com', // Sample user emails
          'sarah.johnson@qauto.com',
          'technician@qauto.com',
          'manager@qauto.com',
        ],
        'assets': [
          '2025_00001', // Sample asset IDs
          '2025_00002',
          'ASSET_2025_00001',
          'ASSET_2025_00002',
        ],
      };

      // Remove sample data from each table
      for (final table in samplePatterns.keys) {
        final patterns = samplePatterns[table]!;
        var removed = 0;

        for (final pattern in patterns) {
          try {
            List<Map<String, dynamic>> records;

            if (table == 'work_orders') {
              final response = await _supabase
                  .from(table)
                  .select('id')
                  .eq('ticketNumber', pattern);
              records = (response as List).map((r) => Map<String, dynamic>.from(r)).toList();
            } else if (table == 'pm_tasks') {
              final response = await _supabase
                  .from(table)
                  .select('id')
                  .eq('taskName', pattern);
              records = (response as List).map((r) => Map<String, dynamic>.from(r)).toList();
            } else if (table == 'users') {
              final response = await _supabase
                  .from(table)
                  .select('id')
                  .eq('email', pattern);
              records = (response as List).map((r) => Map<String, dynamic>.from(r)).toList();
            } else if (table == 'assets') {
              final response = await _supabase
                  .from(table)
                  .select('id')
                  .eq('id', pattern);
              records = (response as List).map((r) => Map<String, dynamic>.from(r)).toList();
            } else {
              continue;
            }

            // Delete all matching records
            if (records.isNotEmpty) {
              final idsToDelete = records.map((r) => r['id'].toString()).toList();
              // Delete records individually as Supabase doesn't support batch delete with in_ filter
              for (final id in idsToDelete) {
                try {
                  await _supabase.from(table).delete().eq('id', id);
                  removed++;
                } catch (e) {
                  debugPrint('Error deleting $id: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error removing $pattern from $table: $e');
          }
        }

        results[table] = removed;
        debugPrint('🗑️ Removed $removed items from $table');
      }
    } catch (e) {
      debugPrint('❌ Error removing Supabase sample data: $e');
    }

    return results;
  }

  /// Remove sample data from local storage
  static Future<Map<String, int>> _removeLocalSampleData() async {
    final results = <String, int>{};

    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove sample work orders
      final workOrdersJson = prefs.getString('work_orders') ?? '[]';
      final workOrders = (workOrdersJson == '[]'
          ? []
          : (workOrdersJson.startsWith('[')
              ? (workOrdersJson.substring(1, workOrdersJson.length - 1).isEmpty
                  ? []
                  : workOrdersJson
                      .substring(1, workOrdersJson.length - 1)
                      .split(',')
                      .map((e) => e.trim())
                      .toList())
              : [workOrdersJson]));

      final originalWorkOrders = workOrders.length;
      final filteredWorkOrders = workOrders.where((wo) {
        try {
          final woData = wo.startsWith('{') ? wo : '{$wo}';
          return !woData.contains('WO-00123') &&
              !woData.contains('Loud grinding noise') &&
              !woData.contains('user_001');
        } catch (_) {
          return true; // Keep if can't parse
        }
      }).toList();

      await prefs.setString(
        'work_orders',
        filteredWorkOrders.isEmpty ? '[]' : '[${filteredWorkOrders.join(',')}]',
      );
      results['work_orders'] = originalWorkOrders - filteredWorkOrders.length;

      // Remove sample PM tasks
      final pmTasksJson = prefs.getString('pm_tasks') ?? '[]';
      final pmTasks = (pmTasksJson == '[]'
          ? []
          : (pmTasksJson.startsWith('[')
              ? (pmTasksJson.substring(1, pmTasksJson.length - 1).isEmpty
                  ? []
                  : pmTasksJson
                      .substring(1, pmTasksJson.length - 1)
                      .split(',')
                      .map((e) => e.trim())
                      .toList())
              : [pmTasksJson]));

      final originalPMTasks = pmTasks.length;
      final filteredPMTasks = pmTasks.where((pt) {
        try {
          final ptData = pt.startsWith('{') ? pt : '{$pt}';
          return !ptData.contains('Monthly Conveyor Inspection') &&
              !ptData.contains('Check belt tension') &&
              !ptData.contains('user_001');
        } catch (_) {
          return true; // Keep if can't parse
        }
      }).toList();

      await prefs.setString(
        'pm_tasks',
        filteredPMTasks.isEmpty ? '[]' : '[${filteredPMTasks.join(',')}]',
      );
      results['pm_tasks'] = originalPMTasks - filteredPMTasks.length;

      // Remove sample users
      final usersList = prefs.getStringList('users') ?? [];
      final originalUsers = usersList.length;
      final filteredUsers = usersList.where((user) {
        try {
          final userData = user.startsWith('{') ? user : '{$user}';
          return !userData.contains('john.smith@qauto.com') &&
              !userData.contains('sarah.johnson@qauto.com') &&
              !userData.contains('technician@qauto.com') &&
              !userData.contains('manager@qauto.com') &&
              !userData.contains('user_001') &&
              !userData.contains('user_002');
        } catch (_) {
          return true; // Keep if can't parse
        }
      }).toList();

      await prefs.setStringList('users', filteredUsers);
      results['users'] = originalUsers - filteredUsers.length;

      // Remove sample assets
      final assetsJson = prefs.getString('assets') ?? '[]';
      final assets = (assetsJson == '[]'
          ? []
          : (assetsJson.startsWith('[')
              ? (assetsJson.substring(1, assetsJson.length - 1).isEmpty
                  ? []
                  : assetsJson
                      .substring(1, assetsJson.length - 1)
                      .split(',')
                      .map((e) => e.trim())
                      .toList())
              : [assetsJson]));

      final originalAssets = assets.length;
      final filteredAssets = assets.where((asset) {
        try {
          final assetData = asset.startsWith('{') ? asset : '{$asset}';
          return !assetData.contains('2025_00001') &&
              !assetData.contains('2025_00002') &&
              !assetData.contains('Conveyor Belt C-03') &&
              !assetData.contains('HVAC Unit H-05') &&
              !assetData.contains('ASSET_2025_00001') &&
              !assetData.contains('ASSET_2025_00002');
        } catch (_) {
          return true; // Keep if can't parse
        }
      }).toList();

      await prefs.setString(
        'assets',
        filteredAssets.isEmpty ? '[]' : '[${filteredAssets.join(',')}]',
      );
      results['assets'] = originalAssets - filteredAssets.length;

      debugPrint('🗑️ Local storage cleanup complete');
    } catch (e) {
      debugPrint('❌ Error removing local sample data: $e');
    }

    return results;
  }

  /// Set permanent block flags to prevent sample data reinsertion
  static Future<void> _setPermanentBlockFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Set all possible block flags
      await prefs.setBool('users_initialized', true);
      await prefs.setBool('database_wiped', true);
      await prefs.setBool('NEVER_INSERT_SAMPLE_DATA', true);
      await prefs.setBool('SAMPLE_DATA_REMOVED', true);
      await prefs.setInt(
        'sample_data_removal_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('🛡️ Permanent block flags set');
    } catch (e) {
      debugPrint('❌ Error setting block flags: $e');
    }
  }

  /// Show confirmation dialog
  static Future<void> showRemovalConfirmationDialog(
    BuildContext context,
  ) async {
    if (!ReleaseSafety.allowDestructiveAdminTools) return;

    return showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cleaning_services, color: Colors.orange),
              SizedBox(width: 8),
              Text('Remove All Sample Data?'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently remove:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Sample work orders (WO-00123)'),
              Text('• Sample PM tasks (Monthly Conveyor Inspection)'),
              Text('• Sample users (john.smith@qauto.com, etc.)'),
              Text('• Sample assets (2025_00001, 2025_00002)'),
              SizedBox(height: 16),
              Text(
                'Real user data will be preserved.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This action CANNOT be undone!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop();

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Removing sample data...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  final result = await removeAllSampleData();

                  // Close loading dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();

                    // Show result
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['success']
                              ? 'Sample data removed successfully! (${result['totalRemoved']} items)'
                              : 'Error: ${result['message']}',
                        ),
                        backgroundColor:
                            result['success'] ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  // Close loading dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();

                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error removing sample data: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Remove Sample Data'),
            ),
          ],
        ),
      );
  }
}
