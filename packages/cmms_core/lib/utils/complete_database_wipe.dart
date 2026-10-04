import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/release_safety.dart';

/// Complete database wipe utility - deletes ALL data from Supabase and local storage
class CompleteDatabaseWipe {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Delete all documents from a Supabase table
  static Future<int> _deleteCollection(String tableName) async {
    try {
      debugPrint('🗑️ Deleting table: $tableName');

      // Get all records first
      final response = await _supabase.from(tableName).select('id');
      final records = response as List;
      debugPrint('📊 Found ${records.length} documents in $tableName');
      
      if (records.isEmpty) {
        debugPrint('ℹ️ Table $tableName is already empty');
        return 0;
      }

      // Delete in batches (Supabase doesn't have batch operations, so delete individually)
      const batchLimit = 100;
      var totalDeleted = 0;
      
      for (var i = 0; i < records.length; i += batchLimit) {
        final end = (i + batchLimit < records.length) 
            ? i + batchLimit 
            : records.length;
        
        final idsToDelete = records.sublist(i, end)
            .map((r) => (r as Map<String, dynamic>)['id'])
            .toList();
        
        if (idsToDelete.isNotEmpty) {
          // Delete records individually as Supabase doesn't support batch delete with in_ filter
          for (final id in idsToDelete) {
            try {
              await _supabase.from(tableName).delete().eq('id', id);
              totalDeleted++;
            } catch (e, st) {
              debugPrint('Error deleting $id: $e');
            }
          }
          debugPrint('✅ Deleted batch: $totalDeleted/${records.length} documents');
        }
      }

      debugPrint('✅ Successfully deleted $totalDeleted documents from $tableName');
      return totalDeleted;
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting table $tableName: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Wipe all Supabase tables
  static Future<Map<String, int>> wipeFirestore() async {
    debugPrint('🗑️ Starting Supabase database wipe...');

    final results = <String, int>{};

    // List of all collections to delete (CORRECT FIRESTORE PATHS!)
    final collections = [
      'work_orders',
      'pm_tasks',
      'assets',
      'users',
      'inventory_items',
      'workflows',
      'notifications',
      'parts_requests',
      'purchase_orders',
    ];

    for (final collection in collections) {
      final count = await _deleteCollection(collection);
      results[collection] = count;
    }

    debugPrint('✅ Supabase wipe complete!');
    return results;
  }

  /// Clear local storage (SharedPreferences)
  static Future<void> clearLocalStorage() async {
    try {
      debugPrint('🗑️ Clearing local storage...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // CRITICAL: Set flag to prevent sample data re-insertion!
      await prefs.setBool('users_initialized', true);
      await prefs.setBool('database_wiped', true);
      await prefs.setInt(
        'wipe_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('✅ Local storage cleared');
      debugPrint('🛡️ Sample data insertion BLOCKED');
    } catch (e, st) {
      debugPrint('❌ Error clearing local storage: $e');
      rethrow;
    }
  }

  /// Complete database wipe (Firestore + Local Storage)
  static Future<Map<String, dynamic>> wipeEverything() async {
    if (!ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Complete database wipe is disabled in release builds');
    }

    try {
      debugPrint('🗑️🗑️🗑️ STARTING COMPLETE DATABASE WIPE 🗑️🗑️🗑️');

      // 1. Wipe Firestore
      final firestoreResults = await wipeFirestore();

      // 2. Clear local storage
      await clearLocalStorage();

      // Calculate totals
      var totalDeleted = 0;
      firestoreResults.forEach((key, count) {
        totalDeleted += count;
      });

      debugPrint('🎉 COMPLETE DATABASE WIPE FINISHED!');
      debugPrint('📊 Total documents deleted: $totalDeleted');

      return {
        'success': true,
        'firestoreResults': firestoreResults,
        'totalDeleted': totalDeleted,
      };
    } catch (e, st) {
      debugPrint('❌ Error during complete database wipe: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Show confirmation dialog and execute wipe
  static Future<void> showWipeConfirmationDialog(BuildContext context) async {
    if (!ReleaseSafety.allowDestructiveAdminTools) return;

    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '⚠️ DANGER ZONE',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will PERMANENTLY DELETE ALL DATA from:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDeleteItem('🔧 All Work Orders'),
                _buildDeleteItem('📅 All PM Tasks'),
                _buildDeleteItem('🏭 All Assets'),
                _buildDeleteItem('👥 All Users'),
                _buildDeleteItem('📦 All Inventory Items'),
                _buildDeleteItem('🔄 All Workflows'),
                _buildDeleteItem('🔔 All Notifications'),
                _buildDeleteItem('📝 All Parts Requests'),
                _buildDeleteItem('💰 All Purchase Orders'),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'THIS ACTION CANNOT BE UNDONE!',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'All data will be deleted from both Firestore and local storage.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _executeWipe(context);
              },
              child: const Text(
                'DELETE EVERYTHING',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
  }

  static Widget _buildDeleteItem(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );

  static Future<void> _executeWipe(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Deleting all data...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This may take a moment.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // Execute the wipe
      final results = await wipeEverything();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        if (results['success'] == true) {
          // Show success dialog with results
          _showResultsDialog(
            context,
            success: true,
            totalDeleted: results['totalDeleted'] as int,
            firestoreResults: results['firestoreResults'] as Map<String, int>,
          );
        } else {
          // Show error dialog
          _showResultsDialog(
            context,
            success: false,
            error: results['error'] as String,
          );
        }
      }
    } catch (e, st) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show error dialog
        _showResultsDialog(
          context,
          success: false,
          error: e.toString(),
        );
      }
    }
  }

  static void _showResultsDialog(
    BuildContext context, {
    required bool success,
    int? totalDeleted,
    Map<String, int>? firestoreResults,
    String? error,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                success ? 'Database Wiped!' : 'Wipe Failed',
                style: TextStyle(
                  color: success ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        content: success
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Successfully deleted $totalDeleted documents!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Deleted from collections:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...firestoreResults!.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• ${entry.key}: ${entry.value} docs'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please restart the app to see the changes.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
