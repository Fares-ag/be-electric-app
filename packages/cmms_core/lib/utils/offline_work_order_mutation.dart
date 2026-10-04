import '../config/app_config.dart';
import '../models/work_order.dart';
import '../services/offline_queue_service.dart';
import 'offline_network.dart';
import 'offline_service_access.dart';

Future<WorkOrder> updateWorkOrderOnlineOrQueue({
  required WorkOrder workOrder,
  required Future<WorkOrder> Function(WorkOrder workOrder) onlineUpdate,
  required void Function(WorkOrder workOrder) applyOptimisticCache,
}) async {
  final localPhotoPaths = collectLocalPhotoPaths(
    completionPhotoPaths: workOrder.completionPhotoPaths,
    completionPhotoPath: workOrder.completionPhotoPath,
    photoPaths: workOrder.photoPaths,
    photoPath: workOrder.photoPath,
  );

  Future<WorkOrder> queueOffline() async {
    final optimistic = workOrder.copyWith(isOffline: true);
    applyOptimisticCache(optimistic);
    await resolveOfflineQueueService().enqueueWorkOrderUpdate(
      optimistic,
      localPhotoPaths: localPhotoPaths,
    );
    return optimistic;
  }

  if (!AppConfig.isOfflineModeEnabled) {
    return onlineUpdate(workOrder);
  }

  if (shouldEnqueueOfflineMutation(
    offlineModeEnabled: true,
    isOnline: resolveConnectivityService().isOnline,
  )) {
    return queueOffline();
  }

  try {
    return await onlineUpdate(workOrder);
  } catch (e) {
    if (shouldEnqueueOfflineMutation(
      offlineModeEnabled: true,
      isOnline: true,
      caughtError: e,
    )) {
      return queueOffline();
    }
    rethrow;
  }
}

Future<WorkOrder> completeWorkOrderOnlineOrQueue({
  required WorkOrder workOrder,
  required List<String> pendingLocalPhotoPaths,
  required Future<WorkOrder> Function(WorkOrder workOrder) onlineComplete,
  required void Function(WorkOrder workOrder) applyOptimisticCache,
}) async {
  Future<WorkOrder> queueOffline() async {
    final woForQueue = pendingLocalPhotoPaths.isNotEmpty
        ? workOrder.copyWith(
            completionPhotoPath: null,
            completionPhotoPaths: const [],
          )
        : workOrder;
    final queueData = <String, dynamic>{'workOrder': woForQueue.toMap()};
    if (pendingLocalPhotoPaths.isNotEmpty) {
      queueData['pendingPhotoFilePaths'] = pendingLocalPhotoPaths;
      if (pendingLocalPhotoPaths.length == 1) {
        queueData['pendingPhotoFilePath'] = pendingLocalPhotoPaths.first;
      }
    }
    await resolveOfflineQueueService().enqueue(
      QueuedOperation(
        id: 'complete_${workOrder.id}',
        type: OperationType.completeWorkOrder,
        data: queueData,
        createdAt: DateTime.now(),
      ),
    );
    final display = (pendingLocalPhotoPaths.isNotEmpty
            ? workOrder.copyWith(
                completionPhotoPaths: pendingLocalPhotoPaths,
                completionPhotoPath: pendingLocalPhotoPaths.first,
              )
            : workOrder)
        .copyWith(isOffline: true);
    applyOptimisticCache(display);
    return display;
  }

  final useAtomic = pendingLocalPhotoPaths.isNotEmpty ||
      (AppConfig.isOfflineModeEnabled &&
          !resolveConnectivityService().isOnline);

  if (!AppConfig.isOfflineModeEnabled) {
    return onlineComplete(workOrder);
  }

  if (useAtomic ||
      shouldEnqueueOfflineMutation(
        offlineModeEnabled: true,
        isOnline: resolveConnectivityService().isOnline,
      )) {
    if (useAtomic) return queueOffline();
  }

  try {
    return await onlineComplete(workOrder);
  } catch (e) {
    if (shouldEnqueueOfflineMutation(
      offlineModeEnabled: true,
      isOnline: true,
      caughtError: e,
    )) {
      return queueOffline();
    }
    rethrow;
  }
}
