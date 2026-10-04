import 'package:flutter/material.dart';

import '../config/release_safety.dart';
import '../providers/unified_data_provider.dart';
import '../services/supabase_database_service.dart';
import '../config/locator.dart';

/// Diagnostic tool to show all user IDs and their assignments
class UserIdDiagnostic {
  static Future<Map<String, dynamic>> analyzeUserIds() async {
    try {
      // Get all users from Firestore
      final localUsers = await sl<SupabaseDatabaseService>().getAllUsers();

      final results = <String, dynamic>{
        'totalUsers': localUsers.length,
        'users': [],
        'technicians': [],
        'admins': [],
        'managers': [],
      };

      for (final user in localUsers) {
        final userInfo = {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'role': user.role,
        };

        results['users'].add(userInfo);

        if (user.role == 'technician') {
          results['technicians'].add(userInfo);
        } else if (user.role == 'admin') {
          results['admins'].add(userInfo);
        } else if (user.role == 'manager') {
          results['managers'].add(userInfo);
        }
      }

      return results;
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> analyzeAssignments(
    UnifiedDataProvider provider,
  ) async {
    try {
      final workOrders = provider.workOrders;
      final pmTasks = provider.pmTasks;

      // Count assignments by technician ID
      final woAssignments = <String, int>{};
      final pmAssignments = <String, int>{};

      for (final wo in workOrders) {
        for (final techId in wo.assignedTechnicianIds) {
          if (techId.isEmpty) continue;
          woAssignments[techId] = (woAssignments[techId] ?? 0) + 1;
        }
      }

      for (final pm in pmTasks) {
        for (final techId in pm.assignedTechnicianIds) {
          if (techId.isEmpty) continue;
          pmAssignments[techId] = (pmAssignments[techId] ?? 0) + 1;
        }
      }

      return {
        'workOrderAssignments': woAssignments,
        'pmTaskAssignments': pmAssignments,
        'totalWorkOrders': workOrders.length,
        'totalPMTasks': pmTasks.length,
        'assignedWorkOrders': woAssignments.values.fold(0, (a, b) => a + b),
        'assignedPMTasks': pmAssignments.values.fold(0, (a, b) => a + b),
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  static Future<void> showDiagnosticDialog(
    BuildContext context,
    UnifiedDataProvider provider,
  ) async {
    if (!ReleaseSafety.showDevTools) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing user IDs and assignments...'),
          ],
        ),
      ),
    );

    final userResults = await analyzeUserIds();
    final assignmentResults = await analyzeAssignments(provider);

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 User ID Diagnostic Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Users Section
              Text(
                '👥 Total Users: ${userResults['totalUsers']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Technicians
              Text(
                '🔧 Technicians (${(userResults['technicians'] as List).length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(userResults['technicians'] as List).map(
                (tech) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    '• ${tech['name']} (ID: ${tech['id']})\n  ${tech['email']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Admins
              Text(
                '👑 Admins (${(userResults['admins'] as List).length}):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(userResults['admins'] as List).map(
                (admin) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    '• ${admin['name']} (ID: ${admin['id']})\n  ${admin['email']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Assignments
              const Divider(),
              const Text(
                '📊 Work Order Assignments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Total: ${assignmentResults['totalWorkOrders']}, Assigned: ${assignmentResults['assignedWorkOrders']}',
                style: const TextStyle(fontSize: 12),
              ),
              ...(assignmentResults['workOrderAssignments'] as Map<String, int>)
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '• ${entry.key}: ${entry.value} work orders',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              const SizedBox(height: 12),

              const Text(
                '📅 PM Task Assignments:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Total: ${assignmentResults['totalPMTasks']}, Assigned: ${assignmentResults['assignedPMTasks']}',
                style: const TextStyle(fontSize: 12),
              ),
              ...(assignmentResults['pmTaskAssignments'] as Map<String, int>)
                  .entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '• ${entry.key}: ${entry.value} PM tasks',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
