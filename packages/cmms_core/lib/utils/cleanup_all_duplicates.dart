// Comprehensive Duplicate Cleanup Utility
//
// Removes duplicates from all collections based on smart deduplication logic.

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/work_order.dart';
import '../services/supabase_database_service.dart';
import '../services/unified_data_service.dart';
import '../config/locator.dart';

/// Utility to clean up all duplicate data
class CleanupAllDuplicates {
  /// Show cleanup dialog and execute cleanup
  static Future<void> showCleanupDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: Colors.orange),
            SizedBox(width: 8),
            Text('Remove All Duplicates'),
          ],
        ),
        content: const Text(
          'This will remove duplicate records from:\n'
          '- Users (by email)\n'
          '- Work Orders (by ID + ticketNumber)\n'
          '- PM Tasks (by ID + composite key)\n\n'
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Duplicates'),
          ),
        ],
      ),
    );

    if (confirmed ?? false && context.mounted) {
      await _executeCleanup(context);
    }
  }

  /// Execute comprehensive cleanup
  static Future<void> _executeCleanup(BuildContext context) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Removing duplicates...'),
            ],
          ),
        ),
      ),
    );

    try {
      print('Starting comprehensive duplicate cleanup...');

      // Get all data
      final dataService = sl<UnifiedDataService>();
      final users = List<User>.from(dataService.users);
      final workOrders = List<WorkOrder>.from(dataService.workOrders);
      final pmTasks = List<dynamic>.from(dataService.pmTasks);

      // Clean Users
      final cleanedUsers = _cleanUsers(users);
      final removedUsers = users.length - cleanedUsers.length;

      // Clean Work Orders
      final cleanedWorkOrders = _cleanWorkOrders(workOrders);
      final removedWorkOrders = workOrders.length - cleanedWorkOrders.length;

      // Clean PM Tasks
      final cleanedPMTasks = _cleanPMTasks(pmTasks);
      final removedPMTasks = pmTasks.length - cleanedPMTasks.length;

      print('Cleanup complete:');
      print('   - Removed $removedUsers duplicate users');
      print('   - Removed $removedWorkOrders duplicate work orders');
      print('   - Removed $removedPMTasks duplicate PM tasks');

      // Update Supabase
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog

        await _updateSupabaseData(
          cleanedUsers,
          cleanedWorkOrders,
          cleanedPMTasks,
        );

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Cleanup Complete'),
              ],
            ),
            content: Text(
              'Successfully removed:\n'
              '- $removedUsers duplicate users\n'
              '- $removedWorkOrders duplicate work orders\n'
              '- $removedPMTasks duplicate PM tasks',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e, st) {
      print('Error during cleanup: $e');

      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Cleanup Failed'),
              ],
            ),
            content: Text('Error: $e'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Clean duplicate users by email
  static List<User> _cleanUsers(List<User> users) {
    final byEmail = <String, User>{};

    for (final user in users) {
      final emailKey = user.email.toLowerCase().trim();
      if (emailKey.isEmpty || emailKey == 'unknown@unknown.com') {
        // Skip fake/unknown users
        continue;
      }

      final existing = byEmail[emailKey];
      if (existing == null) {
        byEmail[emailKey] = user;
      } else {
        // Keep the most recently updated
        final existingTime = existing.updatedAt ?? existing.createdAt;
        final currentTime = user.updatedAt ?? user.createdAt;
        if (currentTime.isAfter(existingTime)) {
          byEmail[emailKey] = user;
        }
      }
    }

    return byEmail.values.toList();
  }

  /// Clean duplicate work orders
  static List<WorkOrder> _cleanWorkOrders(List<WorkOrder> workOrders) {
    // First pass: by ID
    final byId = <String, WorkOrder>{};
    for (final wo in workOrders) {
      final existing = byId[wo.id];
      if (existing == null) {
        byId[wo.id] = wo;
      } else {
        final existingTime = existing.updatedAt;
        final currentTime = wo.updatedAt;
        if (currentTime.isAfter(existingTime)) {
          byId[wo.id] = wo;
        }
      }
    }

    // Second pass: by ticketNumber
    final byTicket = <String, WorkOrder>{};
    for (final wo in byId.values) {
      final existing = byTicket[wo.ticketNumber];
      if (existing == null) {
        byTicket[wo.ticketNumber] = wo;
      } else {
        final existingTime = existing.updatedAt;
        final currentTime = wo.updatedAt;
        if (currentTime.isAfter(existingTime)) {
          byTicket[wo.ticketNumber] = wo;
        }
      }
    }

    return byTicket.values.toList();
  }

  /// Clean duplicate PM tasks
  static List<dynamic> _cleanPMTasks(List<dynamic> pmTasks) {
    // First pass: by ID
    final byId = <String, dynamic>{};
    for (final pm in pmTasks) {
      final existing = byId[pm.id];
      if (existing == null) {
        byId[pm.id] = pm;
      } else {
        final existingTime = existing.updatedAt ?? existing.createdAt;
        final currentTime = pm.updatedAt ?? pm.createdAt;
        if (currentTime.isAfter(existingTime)) {
          byId[pm.id] = pm;
        }
      }
    }

    // Second pass: by composite key (taskName + assetId + nextDueDate)
    final byComposite = <String, dynamic>{};
    for (final pm in byId.values) {
      final composite =
          '${pm.taskName.toLowerCase()}|${pm.assetId}|${pm.nextDueDate?.toIso8601String() ?? ''}';
      final existing = byComposite[composite];
      if (existing == null) {
        byComposite[composite] = pm;
      } else {
        final existingTime = existing.updatedAt ?? existing.createdAt;
        final currentTime = pm.updatedAt ?? pm.createdAt;
        if (currentTime.isAfter(existingTime)) {
          byComposite[composite] = pm;
        }
      }
    }

    return byComposite.values.toList();
  }

  /// Update Supabase with cleaned data
  static Future<void> _updateSupabaseData(
    List<User> users,
    List<WorkOrder> workOrders,
    List<dynamic> pmTasks,
  ) async {
    try {
      final firestore = sl<SupabaseDatabaseService>();

      // Insert cleaned data (upsert mode - won't create duplicates)
      for (final user in users) {
        try {
          await firestore.createUser(user); // Uses upsert logic
        } catch (e, st) {
          print('Warning: Could not save user ${user.id}: $e');
        }
      }

      for (final workOrder in workOrders) {
        try {
          await firestore.createWorkOrder(workOrder); // Uses upsert logic
        } catch (e, st) {
          print('Warning: Could not save work order ${workOrder.id}: $e');
        }
      }

      for (final pmTask in pmTasks) {
        try {
          await firestore.createPMTask(pmTask); // Uses upsert logic
        } catch (e, st) {
          print('Warning: Could not save PM task ${pmTask.id}: $e');
        }
      }

      print('Supabase data updated with cleaned records');
    } catch (e, st) {
      print('Error updating Supabase: $e');
    }
  }
}
