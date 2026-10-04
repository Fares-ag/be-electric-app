// Lightweight schema validators. Throw Exception on invalid data.
import '../models/asset.dart';
import '../models/pm_task.dart';
import '../models/user.dart' as app_user;
import '../models/work_order.dart';

void validateUser(app_user.User user) {
  if (user.email.trim().isEmpty) {
    throw Exception('User email is required');
  }
  if (user.name.trim().isEmpty) {
    throw Exception('User name is required');
  }
  // Optional role guard (support existing roles incl. admin/requestor)
  const allowedRoles = <String>{
    'technician',
    'manager',
    'admin',
    'requestor',
  };
  if (user.role.isNotEmpty && !allowedRoles.contains(user.role)) {
    throw Exception('Invalid user role: ${user.role}');
  }
}

void validateAsset(Asset asset) {
  if (asset.name.trim().isEmpty) {
    throw Exception('Asset name is required');
  }
  if (asset.location.trim().isEmpty) {
    throw Exception('Asset location is required');
  }
  if (asset.id.trim().isEmpty) {
    throw Exception('Asset id is required');
  }
  // Normalize status
  const allowed = {'active', 'inactive'};
  if (asset.status.isNotEmpty && !allowed.contains(asset.status)) {
    throw Exception('Invalid asset status: ${asset.status}');
  }
}

void validateWorkOrder(WorkOrder wo) {
  if (wo.ticketNumber.trim().isEmpty) {
    throw Exception('Work order ticketNumber is required');
  }
  if (wo.problemDescription.trim().isEmpty) {
    throw Exception('Work order problemDescription is required');
  }
  if (wo.requestorId.trim().isEmpty) {
    throw Exception('Work order requestorId is required');
  }
  // Date ordering (when present)
  final created = wo.createdAt;
  final assigned = wo.assignedAt;
  final started = wo.startedAt;
  final completed = wo.completedAt;
  final closed = wo.closedAt;
  if (assigned != null && assigned.isBefore(created)) {
    throw Exception('assignedAt cannot be before createdAt');
  }
  if (started != null && started.isBefore(assigned ?? created)) {
    throw Exception('startedAt cannot be before assignedAt/createdAt');
  }
  if (completed != null && completed.isBefore(started ?? assigned ?? created)) {
    throw Exception('completedAt cannot be before startedAt/assignedAt/createdAt');
  }
  if (closed != null && closed.isBefore(completed ?? started ?? created)) {
    throw Exception('closedAt cannot be before completedAt/startedAt/createdAt');
  }
}

void validatePMTask(PMTask task) {
  // Legacy pm_tasks validation only — frozen schema; do not extend for Option A.
  if (task.taskName.trim().isEmpty) {
    throw Exception('PM task name is required');
  }
  if (task.frequency == PMTaskFrequency.asNeeded) {
    // interval optional
  } else {
    if (task.intervalDays <= 0) {
      throw Exception('PM task intervalDays must be > 0 for non asNeeded');
    }
  }
  // Date ordering (when present)
  final created = task.createdAt;
  final started = task.startedAt;
  final completed = task.completedAt;
  if (started != null && started.isBefore(created)) {
    throw Exception('PM startedAt cannot be before createdAt');
  }
  if (completed != null && completed.isBefore(started ?? created)) {
    throw Exception('PM completedAt cannot be before startedAt/createdAt');
  }
}




