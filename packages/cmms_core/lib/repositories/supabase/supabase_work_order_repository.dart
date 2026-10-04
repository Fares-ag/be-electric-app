import 'package:image_picker/image_picker.dart';

import '../../models/pm_task.dart';
import '../../models/work_order.dart';
import '../../services/supabase_database_service.dart';
import '../../services/supabase_storage_service.dart';
import '../work_order_repository.dart';
import '../../config/locator.dart';

/// Supabase-backed [WorkOrderRepository] — delegates to existing services.
class SupabaseWorkOrderRepository implements WorkOrderRepository {
  SupabaseWorkOrderRepository({
    SupabaseDatabaseService? database,
    SupabaseStorageService? storage,
  })  : _database = database ?? sl<SupabaseDatabaseService>(),
        _storage = storage ?? sl<SupabaseStorageService>();

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;

  @override
  Future<void> initialize() => _database.initialize();

  @override
  Future<bool> testConnection() => _database.testConnection();

  @override
  Future<String> createWorkOrder(WorkOrder workOrder) =>
      _database.createWorkOrder(workOrder);

  @override
  Future<void> updateWorkOrder(String workOrderId, WorkOrder workOrder) =>
      _database.updateWorkOrder(workOrderId, workOrder);

  @override
  Future<void> deleteWorkOrder(String workOrderId) =>
      _database.deleteWorkOrder(workOrderId);

  @override
  Future<WorkOrder?> getWorkOrder(String workOrderId) =>
      _database.getWorkOrder(workOrderId);

  @override
  Future<List<WorkOrder>> getAllWorkOrders() => _database.getAllWorkOrders();

  @override
  Future<List<WorkOrder>> getWorkOrdersPage({
    required int page,
    required int pageSize,
  }) =>
      _database.getWorkOrdersPage(page: page, pageSize: pageSize);

  @override
  Future<List<WorkOrder>> getWorkOrdersByTechnician(String technicianId) =>
      _database.getWorkOrdersByTechnician(technicianId);

  @override
  Future<List<WorkOrder>> getWorkOrdersByRequestor(String requestorId) =>
      _database.getWorkOrdersByRequestor(requestorId);

  @override
  Future<List<WorkOrder>> getWorkOrdersByAsset(String assetId) =>
      _database.getWorkOrdersByAsset(assetId);

  @override
  Future<List<WorkOrder>> queryWorkOrders({
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? assignedTechnicianId,
    String? assetId,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _database.queryWorkOrders(
        status: status,
        priority: priority,
        assignedTechnicianId: assignedTechnicianId,
        assetId: assetId,
        startDate: startDate,
        endDate: endDate,
      );

  @override
  Future<String> createPMTask(PMTask pmTask) => _database.createPMTask(pmTask);

  @override
  Future<void> updatePMTask(String pmTaskId, PMTask pmTask) =>
      _database.updatePMTask(pmTaskId, pmTask);

  @override
  Future<void> deletePMTask(String pmTaskId) =>
      _database.deletePMTask(pmTaskId);

  @override
  Future<List<PMTask>> getAllPMTasks() => _database.getAllPMTasks();

  @override
  Future<List<PMTask>> queryPMTasks({
    PMTaskStatus? status,
    String? assignedTechnicianId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDueStart,
    DateTime? nextDueEnd,
  }) =>
      _database.queryPMTasks(
        status: status,
        assignedTechnicianId: assignedTechnicianId,
        startDate: startDate,
        endDate: endDate,
        nextDueStart: nextDueStart,
        nextDueEnd: nextDueEnd,
      );

  @override
  Future<String?> uploadWorkOrderPhoto({
    required XFile photoFile,
    required String workOrderId,
  }) =>
      _storage.uploadWorkOrderPhoto(
        photoFile: photoFile,
        workOrderId: workOrderId,
      );

  @override
  Future<String?> uploadFile({
    required XFile file,
    required String fileName,
    String? folder,
  }) =>
      _storage.uploadFile(file: file, fileName: fileName, folder: folder);

  @override
  Future<String?> uploadSignature({
    required XFile signatureFile,
    required String workOrderId,
    required String signatureType,
  }) =>
      _storage.uploadSignature(
        signatureFile: signatureFile,
        workOrderId: workOrderId,
        signatureType: signatureType,
      );

  @override
  Future<String?> uploadCompletionPhoto({
    required XFile photoFile,
    required String workOrderId,
    required String photoType,
  }) =>
      _storage.uploadCompletionPhoto(
        photoFile: photoFile,
        workOrderId: workOrderId,
        photoType: photoType,
      );

  @override
  Future<String?> uploadPMTaskCompletionPhoto({
    required XFile photoFile,
    required String pmTaskId,
  }) =>
      _storage.uploadPMTaskCompletionPhoto(
        photoFile: photoFile,
        pmTaskId: pmTaskId,
      );
}
