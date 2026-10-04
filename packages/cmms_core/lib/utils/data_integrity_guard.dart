import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Data Integrity Guard - Prevents duplicate and fake data
class DataIntegrityGuard {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check for duplicate emails before creating a user
  static Future<bool> isEmailUnique(String email) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('email', email.toLowerCase().trim())
          .limit(1);

      return (response as List).isEmpty;
    } catch (e, st) {
      debugPrint('âŒ Error checking email uniqueness: $e');
      return false;
    }
  }

  /// Check for duplicate work order ticket numbers
  static Future<bool> isTicketNumberUnique(String ticketNumber) async {
    try {
      final response = await _supabase
          .from('work_orders')
          .select('id')
          .eq('ticketNumber', ticketNumber)
          .limit(1);

      return (response as List).isEmpty;
    } catch (e, st) {
      debugPrint('âŒ Error checking ticket number uniqueness: $e');
      return false;
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate user data before creation
  static Map<String, dynamic> validateUserData({
    required String email,
    required String name,
    required String role,
  }) {
    final errors = <String>[];

    // Check email format
    if (!isValidEmail(email)) {
      errors.add('Invalid email format');
    }

    // Check for "unknown" email (prevent fake users)
    if (email.toLowerCase().contains('unknown')) {
      errors.add('Cannot use "unknown" in email address');
    }

    // Check name
    if (name.trim().isEmpty || name.toLowerCase() == 'unknown') {
      errors.add('Invalid or empty name');
    }

    // Check role
    final validRoles = ['admin', 'manager', 'technician', 'requestor'];
    if (!validRoles.contains(role.toLowerCase())) {
      errors.add(
          'Invalid role. Must be: admin, manager, technician, or requestor',);
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  /// Prevent duplicate document creation
  static Future<bool> canCreateDocument({
    required String collection,
    required String fieldName,
    required dynamic fieldValue,
  }) async {
    try {
      final response = await _supabase
          .from(collection)
          .select('id')
          .eq(fieldName, fieldValue)
          .limit(1);

      return (response as List).isEmpty;
    } catch (e, st) {
      debugPrint('âŒ Error checking document uniqueness: $e');
      return false;
    }
  }

  /// Remove "unknown" entries from any collection
  static Future<int> removeUnknownEntries(String collection) async {
    try {
      debugPrint('ðŸ§¹ Removing "unknown" entries from $collection...');

      final response = await _supabase.from(collection).select();
      final records = response as List;
      var count = 0;
      final idsToDelete = <String>[];

      for (final record in records) {
        final data = Map<String, dynamic>.from(record);

        // Check for "unknown" patterns
        final isUnknown = data.values.any((value) {
          if (value is String) {
            return value.toLowerCase().contains('unknown@unknown.com') ||
                value.toLowerCase() == 'unknown user' ||
                value.toLowerCase() == 'unknown';
          }
          return false;
        });

        if (isUnknown && data['id'] != null) {
          idsToDelete.add(data['id'].toString());
          count++;
        }
      }

      if (idsToDelete.isNotEmpty) {
        // Delete records individually as Supabase doesn't support batch delete with in_ filter
        for (final id in idsToDelete) {
          try {
            await _supabase.from(collection).delete().eq('id', id);
          } catch (e, st) {
            debugPrint('Error deleting $id: $e');
          }
        }
      }
      debugPrint('âœ… Removed $count "unknown" entries from $collection');

      return count;
    } catch (e, st) {
      debugPrint('âŒ Error removing unknown entries: $e');
      return 0;
    }
  }

  /// Remove duplicate documents by a specific field
  static Future<int> removeDuplicatesByField({
    required String collection,
    required String fieldName,
  }) async {
    try {
      debugPrint('ðŸ§¹ Removing duplicates from $collection by $fieldName...');

      final response = await _supabase
          .from(collection)
          .select()
          .order(fieldName)
          .order('createdAt', ascending: false);

      final records = await response as List;
      final seen = <dynamic>{};
      final idsToDelete = <String>[];

      for (final record in records) {
        final data = Map<String, dynamic>.from(record);
        final fieldValue = data[fieldName];

        if (seen.contains(fieldValue)) {
          // This is a duplicate - mark for deletion
          if (data['id'] != null) {
            idsToDelete.add(data['id'].toString());
          }
        } else {
          // First occurrence - keep it
          seen.add(fieldValue);
        }
      }

      if (idsToDelete.isNotEmpty) {
        // Delete records individually as Supabase doesn't support batch delete with in_ filter
        for (final id in idsToDelete) {
          try {
            await _supabase.from(collection).delete().eq('id', id);
          } catch (e, st) {
            debugPrint('Error deleting $id: $e');
          }
        }
      }
      
      final count = idsToDelete.length;
      debugPrint('âœ… Removed $count duplicates from $collection');

      return count;
    } catch (e, st) {
      debugPrint('âŒ Error removing duplicates: $e');
      return 0;
    }
  }

  /// Run full integrity check
  static Future<Map<String, dynamic>> runIntegrityCheck() async {
    debugPrint('ðŸ” Running data integrity check...');

    final results = <String, dynamic>{};

    // Check for unknown entries
    results['unknownUsers'] = await _countUnknownEntries('users');
    results['unknownWorkOrders'] = await _countUnknownEntries('work_orders');
    results['unknownPMTasks'] = await _countUnknownEntries('pm_tasks');

    // Check for duplicates
    results['duplicateEmails'] = await _countDuplicates('users', 'email');
    results['duplicateTickets'] =
        await _countDuplicates('work_orders', 'ticketNumber');

    final totalIssues = (results['unknownUsers'] as int) +
        (results['unknownWorkOrders'] as int) +
        (results['unknownPMTasks'] as int) +
        (results['duplicateEmails'] as int) +
        (results['duplicateTickets'] as int);

    results['totalIssues'] = totalIssues;
    results['isClean'] = totalIssues == 0;

    debugPrint('âœ… Integrity check complete: $totalIssues issues found');

    return results;
  }

  static Future<int> _countUnknownEntries(String table) async {
    try {
      final response = await _supabase.from(table).select();
      final records = response as List;
      var count = 0;

      for (final record in records) {
        final data = Map<String, dynamic>.from(record);
        final isUnknown = data.values.any((value) {
          if (value is String) {
            return value.toLowerCase().contains('unknown');
          }
          return false;
        });

        if (isUnknown) count++;
      }

      return count;
    } catch (e, st) {
      return 0;
    }
  }

  static Future<int> _countDuplicates(
      String table, String fieldName,) async {
    try {
      final response = await _supabase.from(table).select();
      final records = response as List;
      final values = <dynamic>{};
      var duplicates = 0;

      for (final record in records) {
        final data = Map<String, dynamic>.from(record);
        final value = data[fieldName];
        if (values.contains(value)) {
          duplicates++;
        } else {
          values.add(value);
        }
      }

      return duplicates;
    } catch (e, st) {
      return 0;
    }
  }

  /// Clean all integrity issues
  static Future<Map<String, int>> cleanAllIssues() async {
    debugPrint('ðŸ§¹ Cleaning all data integrity issues...');

    final results = <String, int>{};

    // Remove unknown entries
    results['unknownUsersRemoved'] = await removeUnknownEntries('users');
    results['unknownWorkOrdersRemoved'] =
        await removeUnknownEntries('work_orders');
    results['unknownPMTasksRemoved'] = await removeUnknownEntries('pm_tasks');

    // Remove duplicates
    results['duplicateEmailsRemoved'] = await removeDuplicatesByField(
      collection: 'users',
      fieldName: 'email',
    );
    results['duplicateTicketsRemoved'] = await removeDuplicatesByField(
      collection: 'work_orders',
      fieldName: 'ticketNumber',
    );

    debugPrint('ðŸŽ‰ Integrity cleanup complete!');

    return results;
  }
}


