import '../../models/pm_task.dart';
import '../../models/user.dart';
import '../../models/work_order.dart';

List<WorkOrder> dedupeWorkOrders(List<WorkOrder> list) {
  final byId = <String, WorkOrder>{};
  for (final wo in list) {
    final existing = byId[wo.id];
    final existingUpdatedAt = existing?.updatedAt ?? existing?.createdAt;
    final currentUpdatedAt = wo.updatedAt;
    if (existing == null ||
        (existingUpdatedAt == null) ||
        currentUpdatedAt.isAfter(existingUpdatedAt)) {
      byId[wo.id] = wo;
    }
  }

  final byTicket = <String, WorkOrder>{};
  for (final wo in byId.values) {
    final key = wo.ticketNumber;
    final existing = byTicket[key];
    final existingUpdatedAt = existing?.updatedAt ?? existing?.createdAt;
    final currentUpdatedAt = wo.updatedAt;
    if (existing == null ||
        (existingUpdatedAt == null) ||
        currentUpdatedAt.isAfter(existingUpdatedAt)) {
      byTicket[key] = wo;
    }
  }

  return byTicket.values.toList();
}

List<PMTask> dedupePMTasks(List<PMTask> list) {
  final byId = <String, PMTask>{};
  for (final pm in list) {
    final existing = byId[pm.id];
    var shouldReplace = existing == null;
    if (!shouldReplace) {
      final existingTime = existing.updatedAt ?? existing.createdAt;
      final currentTime = pm.updatedAt ?? pm.createdAt;
      shouldReplace = currentTime.isAfter(existingTime);
    }
    if (shouldReplace) {
      byId[pm.id] = pm;
    }
  }

  final byComposite = <String, PMTask>{};
  for (final pm in byId.values) {
    final composite =
        '${pm.taskName.toLowerCase()}|${pm.assetId}|${pm.nextDueDate?.toIso8601String() ?? ''}';
    final existing = byComposite[composite];
    var shouldReplace = existing == null;
    if (!shouldReplace) {
      final existingTime = existing.updatedAt ?? existing.createdAt;
      final currentTime = pm.updatedAt ?? pm.createdAt;
      shouldReplace = currentTime.isAfter(existingTime);
    }
    if (shouldReplace) {
      byComposite[composite] = pm;
    }
  }

  return byComposite.values.toList();
}

List<User> dedupeUsers(List<User> list) {
  final byEmail = <String, User>{};
  for (final u in list) {
    final emailKey = (u.email.isNotEmpty ? u.email : u.workEmail ?? '')
        .toLowerCase()
        .trim();
    final key = emailKey.isNotEmpty ? emailKey : u.id;
    final existing = byEmail[key];
    if (existing == null ||
        ((u.updatedAt ?? u.createdAt)
            .isAfter(existing.updatedAt ?? existing.createdAt))) {
      byEmail[key] = u;
    }
  }
  return byEmail.values.toList();
}
