import '../models/pm_task.dart';
import '../models/work_order.dart';

/// Picks the cache winner when merging a REST refresh with an existing row.
WorkOrder pickWorkOrderCacheWinner(WorkOrder existing, WorkOrder incoming) {
  if (existing.isCompleted && !incoming.isCompleted) return existing;
  if (existing.status == WorkOrderStatus.inProgress &&
      (incoming.status == WorkOrderStatus.open ||
          incoming.status == WorkOrderStatus.assigned)) {
    return existing;
  }
  if (existing.isOffline && !incoming.isOffline) return incoming;
  if (existing.updatedAt.isAfter(incoming.updatedAt)) return existing;
  return incoming;
}

List<WorkOrder> mergeWorkOrderCacheLists(
  List<WorkOrder> existing,
  List<WorkOrder> incoming,
) {
  final merged = <String, WorkOrder>{for (final wo in existing) wo.id: wo};
  for (final wo in incoming) {
    final prior = merged[wo.id];
    merged[wo.id] =
        prior == null ? wo : pickWorkOrderCacheWinner(prior, wo);
  }
  return merged.values.toList();
}

PMTask pickPMTaskCacheWinner(PMTask existing, PMTask incoming) {
  final existingHistory = existing.completionHistory?.length ?? 0;
  final incomingHistory = incoming.completionHistory?.length ?? 0;
  if (existingHistory > incomingHistory) return existing;
  final existingTime = existing.updatedAt ?? existing.createdAt;
  final incomingTime = incoming.updatedAt ?? incoming.createdAt;
  if (existingTime.isAfter(incomingTime)) return existing;
  return incoming;
}

List<PMTask> mergePMTaskCacheLists(
  List<PMTask> existing,
  List<PMTask> incoming,
) {
  final merged = <String, PMTask>{for (final pm in existing) pm.id: pm};
  for (final pm in incoming) {
    final prior = merged[pm.id];
    merged[pm.id] = prior == null ? pm : pickPMTaskCacheWinner(prior, pm);
  }
  return merged.values.toList();
}
