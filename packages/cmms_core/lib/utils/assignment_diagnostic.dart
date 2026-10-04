import 'package:flutter/material.dart';
import '../services/unified_data_service.dart';
import '../config/locator.dart';

/// Diagnostic tool for troubleshooting technician assignment issues
class AssignmentDiagnostic {
  static Future<Map<String, dynamic>> runDiagnostics() async {
    final dataService = sl<UnifiedDataService>();
    final diagnostics = <String, dynamic>{};

    try {
      // 1. Check users and technicians
      final allUsers = dataService.users;
      final technicians = allUsers
          .where((user) => user.role.toLowerCase() == 'technician')
          .toList();

      diagnostics['totalUsers'] = allUsers.length;
      diagnostics['totalTechnicians'] = technicians.length;
      diagnostics['techniciansList'] = technicians
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'email': t.email,
                'role': t.role,
              },)
          .toList();

      // 2. Check user roles distribution
      final roleDistribution = <String, int>{};
      for (final user in allUsers) {
        final role = user.role.toLowerCase();
        roleDistribution[role] = (roleDistribution[role] ?? 0) + 1;
      }
      diagnostics['roleDistribution'] = roleDistribution;

      // 3. Check work orders
      final allWorkOrders = dataService.workOrders;
      final assignedWorkOrders = allWorkOrders
          .where((wo) => wo.assignedTechnicianIds.isNotEmpty)
          .toList();
      final unassignedWorkOrders =
          allWorkOrders.where((wo) => wo.assignedTechnicianIds.isEmpty).toList();

      diagnostics['totalWorkOrders'] = allWorkOrders.length;
      diagnostics['assignedWorkOrders'] = assignedWorkOrders.length;
      diagnostics['unassignedWorkOrders'] = unassignedWorkOrders.length;

      // 4. Check for orphaned assignments (assigned to non-existent technicians)
      final orphanedAssignments = <Map<String, dynamic>>[];
      for (final wo in assignedWorkOrders) {
        final missingIds = wo.assignedTechnicianIds
            .where(
              (techId) => !technicians.any((t) => t.id == techId),
            )
            .toList();
        if (missingIds.isNotEmpty) {
          orphanedAssignments.add({
            'workOrderId': wo.id,
            'ticketNumber': wo.ticketNumber,
            'assignedTechnicianIds': wo.assignedTechnicianIds,
            'missingTechnicianIds': missingIds,
            'status': wo.status.name,
          });
        }
      }
      diagnostics['orphanedAssignments'] = orphanedAssignments;

      // 5. Check PM tasks
      final allPMTasks = dataService.pmTasks;
      final assignedPMTasks = allPMTasks
          .where((pm) => pm.assignedTechnicianIds.isNotEmpty)
          .toList();
      final unassignedPMTasks =
          allPMTasks.where((pm) => pm.assignedTechnicianIds.isEmpty).toList();

      diagnostics['totalPMTasks'] = allPMTasks.length;
      diagnostics['assignedPMTasks'] = assignedPMTasks.length;
      diagnostics['unassignedPMTasks'] = unassignedPMTasks.length;

      // 6. Check for orphaned PM task assignments
      final orphanedPMAssignments = <Map<String, dynamic>>[];
      for (final pm in assignedPMTasks) {
        final missingIds = pm.assignedTechnicianIds
            .where(
              (techId) => !technicians.any((t) => t.id == techId),
            )
            .toList();
        if (missingIds.isNotEmpty) {
          orphanedPMAssignments.add({
            'pmTaskId': pm.id,
            'taskName': pm.taskName,
            'assignedTechnicianIds': pm.assignedTechnicianIds,
            'missingTechnicianIds': missingIds,
            'status': pm.status.name,
          });
        }
      }
      diagnostics['orphanedPMAssignments'] = orphanedPMAssignments;

      // 7. Check technician workload distribution
      final technicianWorkload = <String, Map<String, dynamic>>{};
      for (final technician in technicians) {
        final woCount =
            allWorkOrders.where((wo) => wo.hasTechnician(technician.id)).length;
        final pmCount =
            allPMTasks.where((pm) => pm.hasTechnician(technician.id)).length;

        technicianWorkload[technician.id] = {
          'name': technician.name,
          'email': technician.email,
          'workOrders': woCount,
          'pmTasks': pmCount,
          'totalTasks': woCount + pmCount,
        };
      }
      diagnostics['technicianWorkload'] = technicianWorkload;

      debugPrint('ðŸ” === ASSIGNMENT DIAGNOSTIC REPORT ===');
      debugPrint('ðŸ“Š Total Users: ${diagnostics['totalUsers']}');
      debugPrint('ðŸ‘¨â€ðŸ”§ Total Technicians: ${diagnostics['totalTechnicians']}');
      debugPrint('ðŸ“‹ Role Distribution: ${diagnostics['roleDistribution']}');
      debugPrint('ðŸ”§ Total Work Orders: ${diagnostics['totalWorkOrders']}');
      debugPrint('  - Assigned: ${diagnostics['assignedWorkOrders']}');
      debugPrint('  - Unassigned: ${diagnostics['unassignedWorkOrders']}');
      debugPrint('  - Orphaned: ${orphanedAssignments.length}');
      debugPrint('ðŸ—“ï¸ Total PM Tasks: ${diagnostics['totalPMTasks']}');
      debugPrint('  - Assigned: ${diagnostics['assignedPMTasks']}');
      debugPrint('  - Unassigned: ${diagnostics['unassignedPMTasks']}');
      debugPrint('  - Orphaned: ${orphanedPMAssignments.length}');
      debugPrint('=====================================');

      if (technicians.isEmpty) {
        debugPrint('âš ï¸ WARNING: No technicians found in the system!');
        debugPrint('   Possible causes:');
        debugPrint('   1. No users with role "technician" exist');
        debugPrint(
            '   2. Role field has different casing (e.g., "Technician" vs "technician")',);
        debugPrint("   3. Users haven't loaded from Firestore yet");
      }

      if (orphanedAssignments.isNotEmpty) {
        debugPrint(
            'âš ï¸ WARNING: ${orphanedAssignments.length} work orders assigned to non-existent technicians!',);
      }

      if (orphanedPMAssignments.isNotEmpty) {
        debugPrint(
            'âš ï¸ WARNING: ${orphanedPMAssignments.length} PM tasks assigned to non-existent technicians!',);
      }

      return diagnostics;
    } catch (e, st) {
      debugPrint('âŒ Error running assignment diagnostics: $e');
      diagnostics['error'] = e.toString();
      return diagnostics;
    }
  }
}


