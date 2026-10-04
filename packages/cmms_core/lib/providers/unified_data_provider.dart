// Backward-compatible facade over domain providers.
// New code should prefer WorkOrderProvider, AssetProvider, UserProvider,
// InventoryProvider, and WorkflowProvider directly.

import 'package:flutter/foundation.dart';

import '../models/asset.dart';
import '../models/inventory_item.dart';
import '../models/pm_task.dart';
import '../models/user.dart';
import '../models/work_order.dart';
import '../models/workflow_models.dart';
import 'asset_provider.dart';
import 'cmms_data_coordinator.dart';
import 'inventory_provider.dart';
import 'user_provider.dart';
import 'work_order_provider.dart';
import 'workflow_provider.dart';

class UnifiedDataProvider with ChangeNotifier {
  UnifiedDataProvider({
    required WorkOrderProvider workOrders,
    required AssetProvider assets,
    required UserProvider users,
    required InventoryProvider inventory,
    required WorkflowProvider workflows,
    required CmmsDataCoordinator coordinator,
  })  : _workOrders = workOrders,
        _assets = assets,
        _users = users,
        _inventory = inventory,
        _workflows = workflows,
        _coordinator = coordinator;

  final WorkOrderProvider _workOrders;
  final AssetProvider _assets;
  final UserProvider _users;
  final InventoryProvider _inventory;
  final WorkflowProvider _workflows;
  final CmmsDataCoordinator _coordinator;

  bool _isDisposed = false;

  void notifyFromDomainChange() {
    notifyListeners();
  }

  // ── Data getters ───────────────────────────────────────────────────────────

  List<WorkOrder> get workOrders => _workOrders.workOrders;
  List<PMTask> get pmTasks => _workOrders.pmTasks;
  List<User> get users => _users.users;
  List<Asset> get assets => _assets.assets;
  List<InventoryItem> get inventoryItems => _inventory.items;
  List<Workflow> get workflows => _workflows.workflows;

  Stream<List<WorkOrder>> get workOrdersStream => _workOrders.workOrdersStream;
  Stream<List<PMTask>> get pmTasksStream => _workOrders.pmTasksStream;
  Stream<List<Asset>> get assetsStream => _assets.assetsStream;
  Stream<List<User>> get usersStream => _users.usersStream;
  Stream<List<InventoryItem>> get inventoryItemsStream =>
      _inventory.inventoryItemsStream;
  Stream<List<Workflow>> get workflowsStream => _workflows.workflowsStream;

  bool get isWorkOrdersLoading => _workOrders.isWorkOrdersLoading;
  bool get isPMTasksLoading => _workOrders.isPMTasksLoading;
  bool get isUsersLoading => _users.isUsersLoading;
  bool get isAssetsLoading => _assets.isAssetsLoading;
  bool get isInventoryLoading => _inventory.isLoading;
  bool get isWorkflowsLoading => _workflows.isWorkflowsLoading;

  bool get hasMoreWorkOrders => _workOrders.hasMoreWorkOrders;
  bool get isLoadingMoreWorkOrders => _workOrders.isLoadingMoreWorkOrders;

  // ── Work order stats ───────────────────────────────────────────────────────

  int get totalWorkOrders => _workOrders.totalWorkOrders;
  int get openWorkOrders => _workOrders.openWorkOrders;
  int get inProgressWorkOrders => _workOrders.inProgressWorkOrders;
  int get completedWorkOrders => _workOrders.completedWorkOrders;
  int get completedWorkOrdersToday => _workOrders.completedWorkOrdersToday;
  int get overdueWorkOrders => _workOrders.overdueWorkOrders;
  int get highPriorityWorkOrders => _workOrders.highPriorityWorkOrders;

  // ── PM task stats ──────────────────────────────────────────────────────────

  int get totalPMTasks => _workOrders.totalPMTasks;
  int get pendingPMTasks => _workOrders.pendingPMTasks;
  int get inProgressPMTasks => _workOrders.inProgressPMTasks;
  int get completedPMTasks => _workOrders.completedPMTasks;
  int get overduePMTasks => _workOrders.overduePMTasks;
  int get duePMTasks => _workOrders.duePMTasks;

  // ── User stats ─────────────────────────────────────────────────────────────

  int get totalUsers => _users.totalUsers;
  int get technicians => _users.technicians;
  int get managers => _users.managers;
  int get admins => _users.admins;
  int get requestors => _users.requestors;

  // ── Other domain stats ─────────────────────────────────────────────────────

  int get totalAssets => _assets.assets.length;
  int get totalInventory => _inventory.totalInventory;
  int get lowStockItems => _inventory.lowStockItems;
  int get totalWorkflows => _workflows.totalWorkflows;
  int get pendingApprovalWorkflows => _workflows.pendingApprovalWorkflows;
  int get approvedWorkflows => _workflows.approvedWorkflows;
  int get completedWorkflows => _workflows.completedWorkflows;
  int get overdueWorkflows => _workflows.overdueWorkflows;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize() => _coordinator.initialize();

  Future<void> refreshAll() async {
    await _coordinator.refreshAll();
      notifyListeners();
  }

  /// Technician shell: reload WO/PM/users/assets (faster than [refreshAll]).
  Future<bool> refreshTechnicianSurface() {
    final existing = _refreshTechnicianSurfaceInFlight;
    if (existing != null) return existing;
    final refresh = _refreshTechnicianSurfaceImpl();
    _refreshTechnicianSurfaceInFlight = refresh;
    refresh.whenComplete(() {
      if (_refreshTechnicianSurfaceInFlight == refresh) {
        _refreshTechnicianSurfaceInFlight = null;
      }
    });
    return refresh;
  }

  Future<bool>? _refreshTechnicianSurfaceInFlight;

  Future<bool> _refreshTechnicianSurfaceImpl() async {
    try {
      await _workOrders.refreshTechnicianSurface();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('UnifiedDataProvider: Error refreshTechnicianSurface: $e');
      return false;
    }
  }

  /// Cache-only work order update used when queueing offline completion.
  Future<WorkOrder> applyLocalWorkOrderUpdate(WorkOrder workOrder) =>
      _workOrders.applyLocalWorkOrderUpdate(workOrder);

  /// Cache-only PM task update used when queueing offline completion.
  Future<PMTask> applyLocalPMTaskUpdate(PMTask pmTask) =>
      _workOrders.applyLocalPMTaskUpdate(pmTask);

  Future<void> loadRequestorWorkOrders(String requestorId) async {
    await _workOrders.loadRequestorWorkOrders(requestorId);
  }

  Future<void> refreshWorkOrder(String workOrderId) =>
      _workOrders.refreshWorkOrder(workOrderId);

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  // ── Work order queries ─────────────────────────────────────────────────────

  List<WorkOrder> getWorkOrdersByTechnician(String technicianId) =>
      _workOrders.getWorkOrdersByTechnician(technicianId);

  List<PMTask> getPMTasksByTechnician(String technicianId) =>
      _workOrders.getPMTasksByTechnician(technicianId);

  List<User> getTechnicians() => _users.getTechnicians();
  List<User> getManagers() => _users.getManagers();
  List<User> getAdmins() => _users.getAdmins();

  List<WorkOrder> getWorkOrdersByStatus(dynamic status) =>
      _workOrders.getWorkOrdersByStatus(status);

  List<WorkOrder> getWorkOrdersByPriority(dynamic priority) =>
      _workOrders.getWorkOrdersByPriority(priority);

  List<WorkOrder> getWorkOrdersByRequestor(String requestorId) =>
      _workOrders.getWorkOrdersByRequestor(requestorId);

  List<WorkOrder> getOverdueWorkOrders() => _workOrders.getOverdueWorkOrders();

  List<PMTask> getOverduePMTasks() => _workOrders.getOverduePMTasks();

  List<PMTask> getPMTasksByStatus(PMTaskStatus status) =>
      _workOrders.getPMTasksByStatus(status);

  List<InventoryItem> getLowStockItems({double? threshold}) =>
      _inventory.getLowStockItems(threshold: threshold);

  List<InventoryItem> getInventoryByCategory(String category) =>
      _inventory.getInventoryByCategory(category);

  Map<String, dynamic> getTechnicianPerformance(String technicianId) =>
      _workOrders.getTechnicianPerformance(technicianId);

  Map<String, dynamic> getTechnicianDashboardData(String technicianId) {
    final performance = getTechnicianPerformance(technicianId);
    final technicianPMTasks = performance['pmTasks'] as List<PMTask>;
    return {
      ...performance,
      'pmTaskStats': {
      'total': technicianPMTasks.length,
        'pending': technicianPMTasks
            .where((task) => task.status.toString().contains('pending'))
            .length,
        'inProgress': technicianPMTasks
            .where((task) => task.status.toString().contains('inProgress'))
            .length,
        'completed': technicianPMTasks
            .where((task) => task.status.toString().contains('completed'))
            .length,
      },
    };
  }

  WorkOrder? getWorkOrderById(String id) => _workOrders.getWorkOrderById(id);
  User? getUserById(String id) => _users.getUserById(id);
  User? getUserByEmail(String email) => _users.getUserByEmail(email);

  Map<String, dynamic> getDashboardStats() => {
        'totalWorkOrders': totalWorkOrders,
        'openWorkOrders': openWorkOrders,
        'inProgressWorkOrders': inProgressWorkOrders,
        'completedWorkOrders': completedWorkOrders,
        'overdueWorkOrders': overdueWorkOrders,
        'highPriorityWorkOrders': highPriorityWorkOrders,
        'totalPMTasks': totalPMTasks,
        'pendingPMTasks': pendingPMTasks,
        'duePMTasks': duePMTasks,
        'overduePMTasks': overduePMTasks,
        'completedPMTasks': completedPMTasks,
        'completedWorkOrdersToday': completedWorkOrdersToday,
        'totalUsers': totalUsers,
        'technicians': technicians,
        'totalAssets': totalAssets,
        'totalInventory': totalInventory,
        'lowStockItems': lowStockItems,
        'totalWorkflows': totalWorkflows,
        'pendingApprovalWorkflows': pendingApprovalWorkflows,
        'approvedWorkflows': approvedWorkflows,
        'completedWorkflows': completedWorkflows,
        'overdueWorkflows': overdueWorkflows,
      };

  // ── Work order mutations ───────────────────────────────────────────────────

  Future<String> createWorkOrder({
    required String problemDescription,
    required String requestorId,
    String? assetId,
    Asset? asset,
    String? location,
    String? photoPath,
    List<String>? photoPaths,
    WorkOrderPriority priority = WorkOrderPriority.medium,
    RepairCategory? category,
    List<String>? assignedTechnicianIds,
    String? requestorName,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
  }) =>
      _workOrders.createWorkOrder(
        problemDescription: problemDescription,
        requestorId: requestorId,
        assetId: assetId,
        asset: asset,
        location: location,
        photoPath: photoPath,
        photoPaths: photoPaths,
        priority: priority,
        category: category,
        assignedTechnicianIds: assignedTechnicianIds,
        requestorName: requestorName,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        notes: notes,
      );

  Future<WorkOrder> updateWorkOrder(WorkOrder workOrder) =>
      _workOrders.updateWorkOrder(workOrder);

  Future<WorkOrder> completeWorkOrder(
    WorkOrder workOrder, {
    List<String> pendingLocalPhotoPaths = const [],
  }) =>
      _workOrders.completeWorkOrder(
        workOrder,
        pendingLocalPhotoPaths: pendingLocalPhotoPaths,
      );

  void updateCachedWorkOrder(WorkOrder workOrder) =>
      _workOrders.updateCachedWorkOrder(workOrder);

  Future<void> loadMoreWorkOrders() => _workOrders.loadMoreWorkOrders();

  Future<void> deleteWorkOrder(String workOrderId) =>
      _workOrders.deleteWorkOrder(workOrderId);

  Future<WorkOrder> reopenWorkOrder({
    required String workOrderId,
    required String currentUserId,
    required String reason,
    String? editedDescription,
    int maxReopenCount = 3,
  }) =>
      _workOrders.reopenWorkOrder(
        workOrderId: workOrderId,
        currentUserId: currentUserId,
        reason: reason,
        editedDescription: editedDescription,
        maxReopenCount: maxReopenCount,
      );

  Future<void> assignTechnicianToWorkOrder(
    String workOrderId,
    String technicianId,
  ) =>
      _workOrders.assignTechnicianToWorkOrder(workOrderId, technicianId);

  Future<void> updateWorkOrderTechnicians(
    String workOrderId,
    List<String> technicianIds,
  ) =>
      _workOrders.updateWorkOrderTechnicians(workOrderId, technicianIds);

  Future<void> unassignTechnicianFromWorkOrder(
    String workOrderId, {
    String? technicianId,
  }) =>
      _workOrders.unassignTechnicianFromWorkOrder(
        workOrderId,
        technicianId: technicianId,
      );

  Future<void> assignTechnician(String workOrderId, String technicianId) =>
      assignTechnicianToWorkOrder(workOrderId, technicianId);

  Future<void> unassignTechnician(
    String workOrderId, {
    String? technicianId,
  }) =>
      unassignTechnicianFromWorkOrder(workOrderId, technicianId: technicianId);

  Future<WorkOrder> pauseWorkOrder(String workOrderId, String reason) =>
      _workOrders.pauseWorkOrder(workOrderId, reason);

  Future<WorkOrder> resumeWorkOrder(String workOrderId) =>
      _workOrders.resumeWorkOrder(workOrderId);

  // ── User mutations ─────────────────────────────────────────────────────────

  Future<String> createUser(User user) => _users.createUser(user);
  Future<void> updateUser(User user) => _users.updateUser(user);

  Future<void> deleteUser(
    String userId, {
    String? currentUserRole,
    String? currentUserId,
  }) =>
      _users.deleteUser(
        userId,
        currentUserRole: currentUserRole,
        currentUserId: currentUserId,
      );

  // ── PM task mutations ──────────────────────────────────────────────────────

  Future<void> createPMTask({
    required String taskName,
    String assetId = '',
    required String description,
    required String checklistJson,
    required PMTaskFrequency frequency,
    required DateTime nextDue,
    Asset? asset,
    List<String>? assignedTechnicianIds,
    String? createdById,
  }) =>
      _workOrders.createPMTask(
        taskName: taskName,
        assetId: assetId,
        description: description,
        checklistJson: checklistJson,
        frequency: frequency,
        nextDue: nextDue,
        asset: asset,
        assignedTechnicianIds: assignedTechnicianIds,
        createdById: createdById,
      );

  Future<PMTask> updatePMTask(PMTask pmTask) =>
      _workOrders.updatePMTask(pmTask);

  Future<void> deletePMTask(String pmTaskId) =>
      _workOrders.deletePMTask(pmTaskId);

  Future<void> assignPMTaskTechnician(
    String pmTaskId,
    String technicianId,
  ) =>
      _workOrders.assignPMTaskTechnician(pmTaskId, technicianId);

  Future<void> updatePMTaskTechnicians(
    String pmTaskId,
    List<String> technicianIds,
  ) =>
      _workOrders.updatePMTaskTechnicians(pmTaskId, technicianIds);

  Future<void> unassignPMTaskTechnician(
    String pmTaskId, {
    String? technicianId,
  }) =>
      _workOrders.unassignPMTaskTechnician(
        pmTaskId,
        technicianId: technicianId,
      );

  Future<PMTask> pausePMTask(String pmTaskId, String reason) =>
      _workOrders.pausePMTask(pmTaskId, reason);

  Future<PMTask> resumePMTask(String pmTaskId) =>
      _workOrders.resumePMTask(pmTaskId);

  // ── Workflow mutations ───────────────────────────────────────────────────────

  Future<String> createWorkflow(Workflow workflow) =>
      _workflows.createWorkflowRecord(workflow);

  Future<void> updateWorkflow(Workflow workflow) =>
      _workflows.updateWorkflowRecord(workflow);

  Future<void> deleteWorkflow(String workflowId) =>
      _workflows.deleteWorkflowRecord(workflowId);

  Workflow? getWorkflowById(String workflowId) =>
      _workflows.getWorkflowById(workflowId);

  List<Workflow> getWorkflowsByStatus(WorkflowStatus status) =>
      _workflows.getWorkflowsByStatus(status);

  List<Workflow> getWorkflowsByType(WorkflowType type) =>
      _workflows.getWorkflowsByType(type);

  List<Workflow> getWorkflowsByCreator(String userId) =>
      _workflows.getWorkflowsByCreator(userId);

  List<Workflow> getWorkflowsByAssignee(String userId) =>
      _workflows.getWorkflowsByAssignee(userId);

  List<Workflow> getPendingApprovalsForUser(String userId) =>
      _workflows.getPendingApprovalsForUserId(userId);

  List<Workflow> getOverdueWorkflows() => _workflows.getOverdueWorkflows();

  Future<void> approveWorkflow({
    required String workflowId,
    required String approverId,
    required String approverName,
    required String approverRole,
    String? comments,
  }) =>
      _workflows.approveWorkflowRecord(
        workflowId: workflowId,
        approverId: approverId,
        approverName: approverName,
        approverRole: approverRole,
        comments: comments,
      );

  Future<void> rejectWorkflow({
    required String workflowId,
    required String rejectorId,
    required String rejectorName,
    required String rejectorRole,
    required String reason,
  }) =>
      _workflows.rejectWorkflowRecord(
        workflowId: workflowId,
        rejectorId: rejectorId,
        rejectorName: rejectorName,
        rejectorRole: rejectorRole,
        reason: reason,
      );

  Future<void> completeWorkflow({
    required String workflowId,
    required String completedBy,
    String? comments,
  }) =>
      _workflows.completeWorkflowRecord(
        workflowId: workflowId,
        completedBy: completedBy,
        comments: comments,
      );

  Future<void> cancelWorkflow({
    required String workflowId,
    required String cancelledBy,
    required String reason,
  }) =>
      _workflows.cancelWorkflowRecord(
        workflowId: workflowId,
        cancelledBy: cancelledBy,
        reason: reason,
      );

  Future<void> escalateWorkflow({
    required String workflowId,
    required String escalatedBy,
    String? reason,
  }) =>
      _workflows.escalateWorkflowRecord(
        workflowId: workflowId,
        escalatedBy: escalatedBy,
        reason: reason,
      );

  Future<void> refreshWorkflows() => _workflows.refreshWorkflows();
}
