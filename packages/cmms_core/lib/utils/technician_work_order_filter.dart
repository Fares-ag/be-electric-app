import '../models/work_order.dart';

/// Work orders visible to a field technician in dashboard / list scopes.
///
/// Uses assignment only (`assignedTechnicianIds` contains [technicianId]).
/// Does not include work orders where the user is only the requestor — that
/// scope is for requestor screens and admin views.
List<WorkOrder> workOrdersAssignedToTechnician(
  Iterable<WorkOrder> workOrders,
  String technicianId,
) {
  if (technicianId.isEmpty) {
    return const [];
  }
  return workOrders
      .where((wo) => wo.hasTechnician(technicianId))
      .toList(growable: false);
}

/// Resolves which work orders [WorkOrderListScreen] should show.
///
/// Technician scope uses assignment only. Requestor and admin/manager scopes
/// are unchanged.
List<WorkOrder> workOrdersForRoleListView({
  required Iterable<WorkOrder> workOrders,
  required String userId,
  required String userRole,
  required bool isTechnicianView,
}) {
  if (isTechnicianView || userRole == 'technician') {
    return workOrdersAssignedToTechnician(workOrders, userId);
  }
  if (userRole == 'requestor') {
    return workOrders
        .where((wo) => wo.requestorId == userId)
        .toList(growable: false);
  }
  return workOrders.toList(growable: false);
}
