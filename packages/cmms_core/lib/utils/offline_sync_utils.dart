import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../services/offline_queue_service.dart';

/// Immutable view of pending offline queue state for UI indicators.
class OfflineSyncSnapshot {
  const OfflineSyncSnapshot({
    required this.pendingWorkOrderIds,
    required this.pendingPMTaskIds,
    required this.totalPendingOperations,
  });

  factory OfflineSyncSnapshot.empty() => const OfflineSyncSnapshot(
        pendingWorkOrderIds: {},
        pendingPMTaskIds: {},
        totalPendingOperations: 0,
      );

  final Set<String> pendingWorkOrderIds;
  final Set<String> pendingPMTaskIds;
  final int totalPendingOperations;

  bool get hasPendingOperations => totalPendingOperations > 0;
}

/// True when [photoPath] is a local path that still needs upload/sync.
bool isOfflinePendingLocalPhoto(String? photoPath, String? uploadedPhotoUrl) =>
    photoPath != null &&
    uploadedPhotoUrl == null &&
    !OfflineQueueService.isRemoteStorageUrl(photoPath);

/// Builds [OfflineSyncSnapshot] from the persisted offline operation queue.
OfflineSyncSnapshot buildOfflineSyncSnapshot(List<QueuedOperation> queue) {
  final pendingWorkOrderIds = <String>{};
  final pendingPMTaskIds = <String>{};

  for (final op in queue) {
    switch (op.type) {
      case OperationType.createWorkOrder:
      case OperationType.updateWorkOrder:
        pendingWorkOrderIds.add(op.id);
      case OperationType.completeWorkOrder:
        final woRaw = op.data['workOrder'];
        if (woRaw is Map && woRaw['id'] is String) {
          pendingWorkOrderIds.add(woRaw['id'] as String);
        } else if (op.id.startsWith('complete_')) {
          pendingWorkOrderIds.add(op.id.substring('complete_'.length));
        }
      case OperationType.uploadPhoto:
        final workOrderId = op.data['workOrderId'] as String?;
        final pmTaskId = op.data['pmTaskId'] as String?;
        if (workOrderId != null) pendingWorkOrderIds.add(workOrderId);
        if (pmTaskId != null) pendingPMTaskIds.add(pmTaskId);
      case OperationType.assignTechnician:
        final workOrderId = op.data['workOrderId'] as String?;
        if (workOrderId != null) pendingWorkOrderIds.add(workOrderId);
      case OperationType.createPMTask:
      case OperationType.updatePMTask:
        pendingPMTaskIds.add(op.id);
      case OperationType.completePMTask:
        final pmRaw = op.data['pmTask'];
        if (pmRaw is Map && pmRaw['id'] is String) {
          pendingPMTaskIds.add(pmRaw['id'] as String);
        } else if (op.id.startsWith('complete_')) {
          pendingPMTaskIds.add(op.id.substring('complete_'.length));
        }
      case OperationType.createPartsRequest:
        break;
    }
  }

  return OfflineSyncSnapshot(
    pendingWorkOrderIds: pendingWorkOrderIds,
    pendingPMTaskIds: pendingPMTaskIds,
    totalPendingOperations: queue.length,
  );
}

  /// Collects local photo paths on a work order for pending-sync detection.
  Iterable<String> _localPhotoPaths(WorkOrder workOrder) sync* {
    if (workOrder.photoPath != null) yield workOrder.photoPath!;
    if (workOrder.photoPaths != null) {
      yield* workOrder.photoPaths!;
    }
    if (workOrder.completionPhotoPath != null) {
      yield workOrder.completionPhotoPath!;
    }
    if (workOrder.completionPhotoPaths != null) {
      yield* workOrder.completionPhotoPaths!;
    }
    if (workOrder.beforePhotoPath != null) yield workOrder.beforePhotoPath!;
    if (workOrder.afterPhotoPath != null) yield workOrder.afterPhotoPath!;
  }

bool isWorkOrderPendingSync(
  WorkOrder workOrder,
  OfflineSyncSnapshot snapshot,
) {
  if (snapshot.pendingWorkOrderIds.contains(workOrder.id)) return true;
  if (workOrder.isOffline) return true;
  for (final path in _localPhotoPaths(workOrder)) {
    if (isOfflinePendingLocalPhoto(path, null)) return true;
  }
  return false;
}

bool isPMTaskPendingSync(PMTask pmTask, OfflineSyncSnapshot snapshot) {
  if (snapshot.pendingPMTaskIds.contains(pmTask.id)) return true;
  if (pmTask.isOffline) return true;
  final history = pmTask.completionHistory;
  if (history != null && history.isNotEmpty) {
    final last = history.last;
    if (last['photoPendingSync'] == true) return true;
  }
  return false;
}
