import 'package:image_picker/image_picker.dart';

import '../models/pm_task.dart';
import '../models/work_order.dart';

/// Work-order aggregate persistence and related maintenance task / file uploads.
abstract class WorkOrderRepository {
  Future<void> initialize();
  Future<bool> testConnection();

  Future<String> createWorkOrder(WorkOrder workOrder);
  Future<void> updateWorkOrder(String workOrderId, WorkOrder workOrder);
  Future<void> deleteWorkOrder(String workOrderId);
  Future<WorkOrder?> getWorkOrder(String workOrderId);
  Future<List<WorkOrder>> getAllWorkOrders();
  Future<List<WorkOrder>> getWorkOrdersPage({
    required int page,
    required int pageSize,
  });
  Future<List<WorkOrder>> getWorkOrdersByTechnician(String technicianId);
  Future<List<WorkOrder>> getWorkOrdersByRequestor(String requestorId);
  Future<List<WorkOrder>> getWorkOrdersByAsset(String assetId);
  Future<List<WorkOrder>> queryWorkOrders({
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? assignedTechnicianId,
    String? assetId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<String> createPMTask(PMTask pmTask);
  Future<void> updatePMTask(String pmTaskId, PMTask pmTask);
  Future<void> deletePMTask(String pmTaskId);
  Future<List<PMTask>> getAllPMTasks();
  Future<List<PMTask>> queryPMTasks({
    PMTaskStatus? status,
    String? assignedTechnicianId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDueStart,
    DateTime? nextDueEnd,
  });

  Future<String?> uploadWorkOrderPhoto({
    required XFile photoFile,
    required String workOrderId,
  });
  Future<String?> uploadFile({
    required XFile file,
    required String fileName,
    String? folder,
  });
  Future<String?> uploadSignature({
    required XFile signatureFile,
    required String workOrderId,
    required String signatureType,
  });
  Future<String?> uploadCompletionPhoto({
    required XFile photoFile,
    required String workOrderId,
    required String photoType,
  });
  Future<String?> uploadPMTaskCompletionPhoto({
    required XFile photoFile,
    required String pmTaskId,
  });
}
