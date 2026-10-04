import '../../models/asset.dart';
import '../../models/pm_task.dart';
import '../../models/user.dart';
import '../../models/work_order.dart';

List<WorkOrder> populateWorkOrderReferences(
  List<WorkOrder> workOrders, {
  required List<Asset> assets,
  required List<User> users,
  Set<String>? missingUserIds,
  Set<String>? missingAssetIds,
}) {
  final populatedWorkOrders = <WorkOrder>[];

  for (final workOrder in workOrders) {
    var updatedWorkOrder = workOrder;

    if (updatedWorkOrder.asset == null &&
        (updatedWorkOrder.assetId?.isNotEmpty ?? false)) {
      try {
        final asset = assets.firstWhere(
          (a) => a.id == updatedWorkOrder.assetId,
        );
        updatedWorkOrder = updatedWorkOrder.copyWith(asset: asset);
      } catch (e) {
        final assetId = updatedWorkOrder.assetId;
        if (assetId != null && assetId.isNotEmpty) {
          missingAssetIds?.add(assetId);
        }
      }
    }

    if (updatedWorkOrder.assignedTechnicianIds.isNotEmpty) {
      final technicians = <User>[];
      for (final techId in updatedWorkOrder.assignedTechnicianIds) {
        try {
          technicians.add(users.firstWhere((u) => u.id == techId));
        } catch (e) {
          missingUserIds?.add(techId);
        }
      }
      if (technicians.isNotEmpty) {
        updatedWorkOrder =
            updatedWorkOrder.copyWith(assignedTechnicians: technicians);
      }
    }

    if (updatedWorkOrder.requestor == null &&
        updatedWorkOrder.requestorId.isNotEmpty) {
      try {
        final requestor = users.firstWhere(
          (u) => u.id == updatedWorkOrder.requestorId,
        );
        updatedWorkOrder = updatedWorkOrder.copyWith(requestor: requestor);
      } catch (e) {
        if (updatedWorkOrder.requestorId.isNotEmpty) {
          missingUserIds?.add(updatedWorkOrder.requestorId);
        }
      }
    }

    populatedWorkOrders.add(updatedWorkOrder);
  }

  return populatedWorkOrders;
}

List<PMTask> populatePMTaskReferences(
  List<PMTask> pmTasks, {
  required List<Asset> assets,
  required List<User> users,
  Set<String>? missingUserIds,
  Set<String>? missingAssetIds,
}) {
  final populatedPMTasks = <PMTask>[];

  for (final pmTask in pmTasks) {
    var updatedPMTask = pmTask;

    if (updatedPMTask.asset == null && updatedPMTask.assetId.isNotEmpty) {
      try {
        final asset = assets.firstWhere((a) => a.id == updatedPMTask.assetId);
        updatedPMTask = updatedPMTask.copyWith(asset: asset);
      } catch (e) {
        if (updatedPMTask.assetId.isNotEmpty) {
          missingAssetIds?.add(updatedPMTask.assetId);
        }
      }
    }

    if (updatedPMTask.createdBy == null &&
        updatedPMTask.createdById != null &&
        updatedPMTask.createdById!.isNotEmpty) {
      try {
        final creator = users.firstWhere(
          (u) => u.id == updatedPMTask.createdById,
        );
        updatedPMTask = updatedPMTask.copyWith(createdBy: creator);
      } catch (_) {}
    }

    if (updatedPMTask.assignedTechnicianIds.isNotEmpty) {
      final technicians = <User>[];
      for (final techId in updatedPMTask.assignedTechnicianIds) {
        try {
          technicians.add(users.firstWhere((u) => u.id == techId));
        } catch (e) {
          missingUserIds?.add(techId);
        }
      }
      if (technicians.isNotEmpty) {
        updatedPMTask =
            updatedPMTask.copyWith(assignedTechnicians: technicians);
      }
    }

    populatedPMTasks.add(updatedPMTask);
  }

  return populatedPMTasks;
}
