import '../config/app_config.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../services/offline_queue_service.dart';
import 'offline_network.dart';
import 'offline_service_access.dart';

Future<PMTask> updatePMTaskOnlineOrQueue({
  required PMTask pmTask,
  required Future<PMTask> Function(PMTask pmTask) onlineUpdate,
  required void Function(PMTask pmTask) applyOptimisticCache,
}) async {
  Future<PMTask> queueOffline() async {
    final optimistic = pmTask.copyWith(isOffline: true);
    applyOptimisticCache(optimistic);
    await resolveOfflineQueueService().enqueue(
      QueuedOperation(
        id: pmTask.id,
        type: OperationType.updatePMTask,
        data: optimistic.toMap(),
        createdAt: DateTime.now(),
      ),
    );
    return optimistic;
  }

  if (!AppConfig.isOfflineModeEnabled) {
    return onlineUpdate(pmTask);
  }

  if (shouldEnqueueOfflineMutation(
    offlineModeEnabled: true,
    isOnline: resolveConnectivityService().isOnline,
  )) {
    return queueOffline();
  }

  try {
    return await onlineUpdate(pmTask);
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

Future<PMTask> createPMTaskOnlineOrQueue({
  required PMTask pmTask,
  required Future<PMTask> Function(PMTask pmTask) onlineCreate,
  required void Function(PMTask pmTask) applyOptimisticCache,
}) async {
  Future<PMTask> queueOffline() async {
    final optimistic = pmTask.copyWith(isOffline: true);
    applyOptimisticCache(optimistic);
    await resolveOfflineQueueService().enqueue(
      QueuedOperation(
        id: pmTask.id,
        type: OperationType.createPMTask,
        data: optimistic.toMap(),
        createdAt: DateTime.now(),
      ),
    );
    return optimistic;
  }

  if (!AppConfig.isOfflineModeEnabled) {
    return onlineCreate(pmTask);
  }

  if (shouldEnqueueOfflineMutation(
    offlineModeEnabled: true,
    isOnline: resolveConnectivityService().isOnline,
  )) {
    return queueOffline();
  }

  try {
    return await onlineCreate(pmTask);
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

Future<WorkOrder> createWorkOrderOnlineOrQueue({
  required WorkOrder workOrder,
  required Future<WorkOrder> Function(WorkOrder workOrder) onlineCreate,
  required void Function(WorkOrder workOrder) applyOptimisticCache,
  List<String>? localPhotoPaths,
}) async {
  Future<WorkOrder> queueOffline() async {
    final optimistic = workOrder.copyWith(isOffline: true);
    applyOptimisticCache(optimistic);
    final queueData = <String, dynamic>{'workOrder': optimistic.toMap()};
    if (localPhotoPaths != null && localPhotoPaths.isNotEmpty) {
      queueData['pendingPhotoFilePaths'] = localPhotoPaths;
    }
    await resolveOfflineQueueService().enqueue(
      QueuedOperation(
        id: workOrder.id,
        type: OperationType.createWorkOrder,
        data: queueData,
        createdAt: DateTime.now(),
      ),
    );
    return optimistic;
  }

  if (!AppConfig.isOfflineModeEnabled) {
    return onlineCreate(workOrder);
  }

  if (shouldEnqueueOfflineMutation(
    offlineModeEnabled: true,
    isOnline: resolveConnectivityService().isOnline,
  )) {
    return queueOffline();
  }

  try {
    return await onlineCreate(workOrder);
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
