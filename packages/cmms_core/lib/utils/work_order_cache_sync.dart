import '../models/work_order.dart';
import '../services/realtime_supabase_service.dart';

/// Applies a single incremental realtime event to the canonical work-order list.
List<WorkOrder> applyWorkOrderChange(
  List<WorkOrder> current,
  WorkOrderChangeEvent event,
) {
  final byId = {for (final wo in current) wo.id: wo};

  switch (event.type) {
    case WorkOrderChangeType.delete:
      final id = event.deletedId;
      if (id != null && id.isNotEmpty) {
        byId.remove(id);
      }
    case WorkOrderChangeType.insert:
    case WorkOrderChangeType.update:
      final workOrder = event.workOrder;
      if (workOrder != null) {
        byId[workOrder.id] = workOrder;
      }
  }

  return byId.values.toList();
}

/// @deprecated Use [applyWorkOrderChange] for incremental merges.
/// Kept for backward compatibility during migration.
List<WorkOrder> applyRealtimeWorkOrderSnapshot(
  List<WorkOrder> realtimeSnapshot,
) =>
    List<WorkOrder>.from(realtimeSnapshot);
