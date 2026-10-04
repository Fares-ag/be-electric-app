import 'package:flutter/foundation.dart';

import '../config/release_safety.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../services/supabase_database_service.dart';
import '../services/unified_data_service.dart';
import '../config/locator.dart';

class OrphanCleanupReport {
  OrphanCleanupReport({
    required this.totalWorkOrders,
    required this.orphanedWorkOrders,
    required this.totalPMTasks,
    required this.orphanedPMTasks,
    required this.deletedWorkOrderIds,
    required this.deletedPMTaskIds,
  });

  final int totalWorkOrders;
  final int orphanedWorkOrders;
  final int totalPMTasks;
  final int orphanedPMTasks;
  final List<String> deletedWorkOrderIds;
  final List<String> deletedPMTaskIds;
}

class OrphanCleanupService {

  final SupabaseDatabaseService _firestore = sl<SupabaseDatabaseService>();
  UnifiedDataService get _dataService => sl<UnifiedDataService>();

  Future<OrphanCleanupReport> run({
    bool delete = false,
  }) async {
    if (delete && !ReleaseSafety.allowDestructiveAdminTools) {
      throw StateError('Orphan deletion is disabled in release builds');
    }
    if (!delete && !ReleaseSafety.showDevTools) {
      throw StateError('Orphan cleanup diagnostics are disabled in release builds');
    }

    try {
      debugPrint(
        '🧹 OrphanCleanup: Starting run (delete=$delete) – fetching datasets...',
      );
      final users = await _firestore.getAllUsers();
      final assets = await _firestore.getAllAssets();
      final workOrders = await _firestore.getAllWorkOrders();
      final pmTasks = await _firestore.getAllPMTasks();
      debugPrint(
        '🧹 OrphanCleanup: Loaded ${users.length} users, ${assets.length} assets, '
        '${workOrders.length} work orders, ${pmTasks.length} PM tasks',
      );

      final userIds = users.map((u) => u.id).toSet();
      final assetIds = assets.map((a) => a.id).toSet();

      final orphanWorkOrders = <WorkOrder>[];
      final orphanPMTasks = <PMTask>[];

      for (final workOrder in workOrders) {
        final missingUsers = <String>{};
        final missingAssets = <String>{};

        // Check requestor
        if (workOrder.requestorId.isNotEmpty &&
            !userIds.contains(workOrder.requestorId)) {
          missingUsers.add(workOrder.requestorId);
        }

        // Check primary technician
        final primaryTechId = workOrder.primaryTechnicianId;
        if (primaryTechId != null &&
            primaryTechId.isNotEmpty &&
            !userIds.contains(primaryTechId)) {
          missingUsers.add(primaryTechId);
        }

        // Check assigned technicians
        for (final techId in workOrder.assignedTechnicianIds) {
          if (techId.isNotEmpty && !userIds.contains(techId)) {
            missingUsers.add(techId);
          }
        }

        // Check asset
        final assetId = workOrder.assetId;
        if (assetId != null &&
            assetId.isNotEmpty &&
            !assetIds.contains(assetId)) {
          missingAssets.add(assetId);
        }

        if (missingUsers.isNotEmpty || missingAssets.isNotEmpty) {
          orphanWorkOrders.add(workOrder);
          if (delete) {
            debugPrint(
              '🧹 OrphanCleanup: Deleting orphaned work order ${workOrder.id} '
              '(missing users: ${missingUsers.join(', ')} '
              'missing assets: ${missingAssets.join(', ')})',
            );
            await _firestore.deleteWorkOrder(workOrder.id);
          }
        }
      }

      for (final pmTask in pmTasks) {
        final missingUsers = <String>{};
        final missingAssets = <String>{};

        // Check assigned technicians
        for (final techId in pmTask.assignedTechnicianIds) {
          if (techId.isNotEmpty && !userIds.contains(techId)) {
            missingUsers.add(techId);
          }
        }

        // Check asset (PM tasks should always have an asset)
        final assetId = pmTask.assetId;
        if (assetId.isNotEmpty && !assetIds.contains(assetId)) {
          missingAssets.add(assetId);
        }

        if (missingUsers.isNotEmpty || missingAssets.isNotEmpty) {
          orphanPMTasks.add(pmTask);
          if (delete) {
            debugPrint(
              '🧹 OrphanCleanup: Deleting orphaned PM task ${pmTask.id} '
              '(missing users: ${missingUsers.join(', ')} '
              'missing assets: ${missingAssets.join(', ')})',
            );
            await _firestore.deletePMTask(pmTask.id);
          }
        }
      }

      if (delete) {
        debugPrint('🧹 OrphanCleanup: Refreshing caches after deletions...');
        await _dataService.refreshAll();
      }

      final report = OrphanCleanupReport(
        totalWorkOrders: workOrders.length,
        orphanedWorkOrders: orphanWorkOrders.length,
        totalPMTasks: pmTasks.length,
        orphanedPMTasks: orphanPMTasks.length,
        deletedWorkOrderIds: delete
            ? orphanWorkOrders.map((w) => w.id).toList()
            : const <String>[],
        deletedPMTaskIds: delete
            ? orphanPMTasks.map((p) => p.id).toList()
            : const <String>[],
      );

      debugPrint(
        '🧹 OrphanCleanup: Finished – '
        '${report.orphanedWorkOrders}/${report.totalWorkOrders} orphaned work orders, '
        '${report.orphanedPMTasks}/${report.totalPMTasks} orphaned PM tasks. '
        'Deleted=${delete ? 'yes' : 'no'}.',
      );

      if (delete && (report.orphanedWorkOrders > 0 || report.orphanedPMTasks > 0)) {
        debugPrint(
          '🧹 OrphanCleanup: Deleted ${report.deletedWorkOrderIds.length} work orders '
          'and ${report.deletedPMTaskIds.length} PM tasks',
        );
      }

      return report;
    } catch (e, stack) {
      debugPrint('❌ OrphanCleanup: Failed – $e');
      debugPrint('$stack');
      rethrow;
    }
  }
}

