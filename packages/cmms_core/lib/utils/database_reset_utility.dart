import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/release_safety.dart';

/// Utility class to reset/clear all database data
class DatabaseResetUtility {
  /// Clear all local data from SharedPreferences
  static Future<void> clearLocalDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear data but PRESERVE guard flags to prevent sample data reinsertion
      await prefs.remove('users');
      await prefs.remove('assets');
      await prefs.remove('work_orders');
      await prefs.remove('pm_tasks');
      await prefs.remove('inventory_items');
      await prefs.remove('parts_requests');
      await prefs.remove('purchase_orders');
      await prefs.remove('workflows');

      // DO NOT clear these guard flags:
      // - users_initialized
      // - database_wiped
      // - NEVER_INSERT_SAMPLE_DATA

      debugPrint(
        '✅ Local database cleared successfully (guard flags preserved)',
      );
    } catch (e) {
      debugPrint('❌ Error clearing local database: $e');
      rethrow;
    }
  }

  /// Clear all Firestore data (WARNING: This will delete all cloud data)
  static Future<void> clearFirestoreDatabase() async {
    try {
      // Note: We can't delete all Firestore data from the client for security reasons
      // This is just a placeholder - you would need to do this from Firebase Console
      // or use Firebase Admin SDK

      debugPrint('⚠️ Firestore data should be cleared from Firebase Console');
      debugPrint(
        'Go to: Firebase Console > Firestore Database > Delete collections',
      );
    } catch (e) {
      debugPrint('❌ Error clearing Firestore: $e');
      rethrow;
    }
  }

  /// Clear all data (both local and optionally Firestore)
  static Future<void> clearAllData({bool includeFirestore = false}) async {
    if (!ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Database reset is disabled in release builds');
    }

    try {
      // Clear local database
      await clearLocalDatabase();

      // Optionally clear Firestore (just logs a warning)
      if (includeFirestore) {
        await clearFirestoreDatabase();
      }

      debugPrint('✅ Database reset complete');
    } catch (e) {
      debugPrint('❌ Error during database reset: $e');
      rethrow;
    }
  }

  /// Show a confirmation dialog before clearing data
  static Future<void> showResetConfirmationDialog(
    BuildContext context, {
    bool includeFirestore = false,
  }) async {
    if (!ReleaseSafety.allowDestructiveAdminTools) return;

    return showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Clear Database?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• All work orders'),
              const Text('• All PM tasks'),
              const Text('• All assets'),
              const Text('• All users'),
              const Text('• All inventory items'),
              const Text('• All analytics data'),
              const SizedBox(height: 16),
              if (includeFirestore)
                const Text(
                  'Note: Firestore data must be manually deleted from Firebase Console.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange,
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
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
                backgroundColor: Colors.red,
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
                            Text('Clearing database...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                try {
                  await clearAllData(includeFirestore: includeFirestore);

                  // Close loading dialog
                  if (context.mounted) {
                    Navigator.of(context).pop();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Database cleared successfully! Please restart the app.',
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 5),
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
                        content: Text('Error clearing database: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Clear Database'),
            ),
          ],
        ),
      );
  }
}
