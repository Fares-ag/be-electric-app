import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/release_safety.dart';

/// Emergency duplicate killer - removes all duplicates and blocks sample data
class KillDuplicatesNow {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Nuclear option: Delete ALL data and block sample data forever
  static Future<Map<String, dynamic>> killEverythingAndBlock() async {
    if (!ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Nuclear option is disabled in release builds');
    }

    try {
      debugPrint(
        '☢️ NUCLEAR OPTION: Killing all data and blocking sample data...',
      );

      // 1. Delete ALL Supabase tables
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

      var totalDeleted = 0;
      for (final collection in collections) {
        final count = await _nukeCollection(collection);
        totalDeleted += count;
      }

      // 2. Clear ALL local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Set PERMANENT block flags
      await prefs.setBool('users_initialized', true); // Block sample users
      await prefs.setBool('database_wiped', true); // Wipe flag
      await prefs.setBool('NEVER_INSERT_SAMPLE_DATA', true); // PERMANENT BLOCK
      await prefs.setInt(
        'wipe_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('☢️ Nuked $totalDeleted documents from Supabase');
      debugPrint('🛡️ Sample data insertion PERMANENTLY BLOCKED');
      debugPrint('✅ Database is now completely empty');

      return {
        'success': true,
        'totalDeleted': totalDeleted,
        'message': 'All data deleted. Sample data PERMANENTLY blocked.',
      };
    } catch (e) {
      debugPrint('❌ Error in nuclear option: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Nuke a table (delete ALL documents)
  static Future<int> _nukeCollection(String table) async {
    try {
      debugPrint('☢️ Nuking table: $table');

      // Get all records
      final response = await _supabase.from(table).select('id');
      final records = response as List;
      
      if (records.isEmpty) {
        return 0;
      }

      // Delete all records by IDs
      final idsToDelete = records
          .map((r) => (r as Map<String, dynamic>)['id'])
          .toList();
      
      if (idsToDelete.isNotEmpty) {
        // Delete records individually as Supabase doesn't support batch delete with in_ filter
        for (final id in idsToDelete) {
          try {
            await _supabase.from(table).delete().eq('id', id);
          } catch (e) {
            debugPrint('Error deleting $id: $e');
          }
        }
      }
      
      debugPrint('✅ Nuked ${records.length} docs from $table');
      return records.length;
    } catch (e) {
      debugPrint('❌ Error nuking $table: $e');
      return 0;
    }
  }

  /// Show nuclear option dialog
  static Future<void> showNuclearOptionDialog(BuildContext context) async {
    if (!ReleaseSafety.allowDestructiveAdminTools) return;

    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => AlertDialog(
          backgroundColor: Colors.red.shade900,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.yellow, size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '☢️ NUCLEAR OPTION',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            decoration: BoxDecoration(
              color: Colors.black87,
              border: Border.all(color: Colors.yellow, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ THIS IS THE MOST EXTREME OPTION!',
                    style: TextStyle(
                      color: Colors.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildNukeItem('🗑️ DELETE ALL Firestore data'),
                  _buildNukeItem('🗑️ DELETE ALL local storage'),
                  _buildNukeItem('🛡️ PERMANENTLY block sample data'),
                  _buildNukeItem('🚫 NEVER auto-insert users again'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.warning_amber,
                            color: Colors.yellow, size: 48,),
                        SizedBox(height: 8),
                        Text(
                          'NO UNDO! NO RECOVERY!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'You will have a COMPLETELY EMPTY database.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _executeNuclearOption(context);
              },
              child: const Text(
                '☢️ NUKE IT ALL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
  }

  static Widget _buildNukeItem(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );

  static Future<void> _executeNuclearOption(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: Colors.black87,
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
                    '☢️ NUKING DATABASE...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Deleting everything...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // Execute nuclear option
      final results = await killEverythingAndBlock();

      // Close loading
      if (context.mounted) {
        Navigator.of(context).pop();

        if (results['success'] == true) {
          // Show success
          _showSuccessDialog(
            context,
            totalDeleted: results['totalDeleted'] as int,
          );
        } else {
          // Show error
          _showErrorDialog(context, error: results['error'] as String);
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(context, error: e.toString());
      }
    }
  }

  static void _showSuccessDialog(
    BuildContext context, {
    required int totalDeleted,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade900,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '✅ DATABASE NUKED!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully deleted $totalDeleted documents!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '✅ All Firestore data deleted',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '✅ All local storage cleared',
                style: TextStyle(color: Colors.white),
              ),
              const Text(
                '🛡️ Sample data PERMANENTLY blocked',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'RESTART THE APP NOW!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Press R in your terminal for full restart',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  static void _showErrorDialog(BuildContext context, {required String error}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text('Failed to nuke database:\n$error'),
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
