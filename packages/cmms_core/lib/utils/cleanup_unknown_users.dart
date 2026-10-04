import '../models/user.dart';
import '../services/supabase_database_service.dart';
import '../config/locator.dart';

/// Utility to clean up fake "Unknown" users and duplicates from the database
class CleanupUnknownUsers {
  /// Find duplicate users by email
  static Map<String, List<User>> findDuplicates(List<User> users) {
    final emailMap = <String, List<User>>{};

    for (final user in users) {
      if (!emailMap.containsKey(user.email)) {
        emailMap[user.email] = [];
      }
      emailMap[user.email]!.add(user);
    }

    // Return only emails with duplicates
    return Map.fromEntries(
      emailMap.entries.where((entry) => entry.value.length > 1),
    );
  }

  // Local database cleanup removed - using Supabase-only architecture

  static Future<int> cleanupFromSupabase({
    bool includeDuplicates = false,
  }) async {
    print('🧹 Starting cleanup from Supabase...');
    print('   Include duplicates: $includeDuplicates');

    final firestore = sl<SupabaseDatabaseService>();
    final allUsers = await firestore.getAllUsers();
    var deletedCount = 0;

    // Track emails to keep the newest user for duplicates
    final emailTracker = <String, User>{};

    for (final user in allUsers) {
      var shouldDelete = false;

      // Check if this is an "Unknown" user
      if (user.name.contains('Unknown') ||
          user.email == 'unknown@unknown.com' ||
          user.email.contains('unknown')) {
        shouldDelete = true;
        print(
          '🗑️ Marking Unknown user for deletion: ${user.name} (${user.email})',
        );
      }

      // Check for duplicates if enabled
      if (includeDuplicates && !shouldDelete) {
        if (emailTracker.containsKey(user.email)) {
          // Duplicate found - keep the newer one
          final existingUser = emailTracker[user.email]!;
          if (user.createdAt.isAfter(existingUser.createdAt)) {
            // Current user is newer, delete the old one
            try {
              await firestore.deleteUser(existingUser.id);
              deletedCount++;
              print(
                '🗑️ Deleted older duplicate from Firestore: ${existingUser.name} (${existingUser.email})',
              );
            } catch (e, st) {
              print('❌ Failed to delete duplicate ${existingUser.id}: $e');
            }
            emailTracker[user.email] = user;
          } else {
            // Existing user is newer, delete current one
            shouldDelete = true;
            print(
              '🗑️ Marking older duplicate for deletion: ${user.name} (${user.email})',
            );
          }
        } else {
          emailTracker[user.email] = user;
        }
      }

      // Delete if marked
      if (shouldDelete) {
        try {
          await firestore.deleteUser(user.id);
          deletedCount++;
        } catch (e, st) {
          print('❌ Failed to delete user from Firestore ${user.id}: $e');
        }
      }
    }

    print('✅ Firestore cleanup complete! Deleted $deletedCount users');
    return deletedCount;
  }

  static Future<Map<String, int>> cleanupAll({
    bool includeDuplicates = false,
  }) async {
    // Using Firestore-only architecture
    final firestoreCount =
        await cleanupFromSupabase(includeDuplicates: includeDuplicates);

    return {
      'firestore': firestoreCount,
      'total': firestoreCount,
    };
  }

  /// Analyze database for duplicates without deleting
  static Future<Map<String, dynamic>> analyzeDuplicates() async {
    print('🔍 Analyzing Firestore for duplicates...');

    final firestore = sl<SupabaseDatabaseService>();
    final allUsers = await firestore.getAllUsers();
    final duplicates = findDuplicates(allUsers);

    var totalDuplicates = 0;
    for (final entry in duplicates.entries) {
      totalDuplicates += entry.value.length - 1; // -1 because we keep one
      print('📧 Email "${entry.key}" has ${entry.value.length} accounts');
      for (final user in entry.value) {
        print('   - ${user.name} (ID: ${user.id}, Created: ${user.createdAt})');
      }
    }

    return {
      'totalUsers': allUsers.length,
      'uniqueEmails': duplicates.length,
      'duplicateCount': totalDuplicates,
      'duplicates': duplicates,
    };
  }
}
