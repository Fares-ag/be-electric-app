import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../config/locator.dart';
import '../models/asset.dart';
import '../models/pm_task.dart';
import '../models/user.dart';
import '../models/work_order.dart';
import '../repositories/cmms_repositories.dart';
import '../services/connectivity_service.dart';
import '../services/unified_data_service.dart';
import '../utils/offline_network.dart';
import '../utils/offline_service_access.dart';
import '../utils/performance_optimizer.dart';
import '../utils/requestor_company_policy.dart';
import '../utils/stream_subscription_cancel.dart';
import '../utils/technician_work_order_filter.dart';
import '../utils/work_order_ticket_number.dart';
import 'asset_provider.dart';
import 'domain/cmms_domain_provider.dart';
import 'domain/domain_deduplication.dart';
import 'domain/domain_reference_populator.dart';
import 'user_provider.dart';

class WorkOrderProvider with ChangeNotifier implements CmmsDomainProvider {
  WorkOrderProvider({
    required UserProvider users,
    required AssetProvider assets,
    UnifiedDataService? dataService,
  })  : _usersProvider = users,
        _assetsProvider = assets,
        _dataService = dataService ?? sl<UnifiedDataService>();

  final UnifiedDataService _dataService;
  final UserProvider _usersProvider;
  final AssetProvider _assetsProvider;

  bool _isDisposed = false;

  StreamSubscription<List<PMTask>>? _pmTasksSubscription;
  List<PMTask> _realtimePMTasks = [];
  List<WorkOrder>? _populatedWorkOrdersCache;

  static const int _woPageSize = 30;
  int _woNextPage = 1;
  bool _hasMoreWorkOrders = true;
  bool _isLoadingMoreWorkOrders = false;

  final Map<String, Future<void>> _refreshWorkOrderInFlight = {};

  List<WorkOrder> get workOrders => _buildWorkOrdersView();

  List<WorkOrder> _buildWorkOrdersView() {
    final missingUsers = <String>{};
    final missingAssets = <String>{};
    _populatedWorkOrdersCache ??= dedupeWorkOrders(
      populateWorkOrderReferences(
        List<WorkOrder>.from(_dataService.workOrders),
        users: _usersProvider.users,
        assets: _assetsProvider.assets,
        missingUserIds: missingUsers,
        missingAssetIds: missingAssets,
      ),
    );
    if (missingUsers.isNotEmpty || missingAssets.isNotEmpty) {
      unawaited(
        recoverMissingReferences(
          userIds: missingUsers,
          assetIds: missingAssets,
        ),
      );
    }
    return _populatedWorkOrdersCache!;
  }

  void _invalidateWorkOrdersView() {
    _populatedWorkOrdersCache = null;
  }

  void _onCanonicalWorkOrdersChanged() {
    _invalidateWorkOrdersView();
    if (!_isDisposed) {
      ChangeNotifierBatcher.batchNotify(
        () => notifyListeners(),
        batchKey: this,
      );
    }
  }

  List<PMTask> get pmTasks =>
      _realtimePMTasks.isNotEmpty ? _realtimePMTasks : _dataService.pmTasks;

  Stream<List<WorkOrder>> get workOrdersStream => _dataService.workOrdersStream;
  Stream<List<PMTask>> get pmTasksStream => _dataService.pmTasksStream;

  bool get isWorkOrdersLoading => _dataService.isWorkOrdersLoading;
  bool get isPMTasksLoading => _dataService.isPMTasksLoading;
  bool get hasMoreWorkOrders => _hasMoreWorkOrders;
  bool get isLoadingMoreWorkOrders => _isLoadingMoreWorkOrders;

  int get totalWorkOrders => workOrders.length;
  int get openWorkOrders => workOrders.where((wo) => wo.isOpen).length;
  int get inProgressWorkOrders =>
      workOrders.where((wo) => wo.isInProgress).length;
  int get completedWorkOrders =>
      workOrders.where((wo) => wo.isCompleted).length;
  int get overdueWorkOrders => workOrders.where((wo) => wo.isOverdue).length;
  int get highPriorityWorkOrders =>
      workOrders.where((wo) => wo.isHighPriority).length;

  int get totalPMTasks => pmTasks.length;
  int get pendingPMTasks => pmTasks.where((task) => task.isPending).length;
  int get inProgressPMTasks =>
      pmTasks.where((task) => task.isInProgress).length;
  int get completedPMTasks => pmTasks.where((task) => task.isCompleted).length;
  int get overduePMTasks => pmTasks.where((task) => task.isOverdue).length;

  int get completedWorkOrdersToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return workOrders.where((wo) {
      if (!wo.isCompleted || wo.completedAt == null) return false;
      final completedDate = DateTime(
        wo.completedAt!.year,
        wo.completedAt!.month,
        wo.completedAt!.day,
      );
      return completedDate.isAtSameMomentAs(today);
    }).length;
  }

  int get duePMTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return pmTasks.where((task) {
      if (!task.isPending && !task.isOverdue) return false;
      if (task.nextDueDate == null) return false;
      final dueDate = DateTime(
        task.nextDueDate!.year,
        task.nextDueDate!.month,
        task.nextDueDate!.day,
      );
      return dueDate.isBefore(today) || dueDate.isAtSameMomentAs(today);
    }).length;
  }

  @override
  void clearCache() {
    _invalidateWorkOrdersView();
    _realtimePMTasks = [];
    resetPagination();
  }

  void seedFromService() {
    _invalidateWorkOrdersView();
  }

  /// Reload WO/PM/users/assets via the unified data service surface refresh.
  Future<void> refreshTechnicianSurface() async {
    if (_isDisposed) return;
    try {
      await _dataService.refreshTechnicianSurface();
      _invalidateWorkOrdersView();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('WorkOrderProvider: refreshTechnicianSurface error: $e');
      rethrow;
    }
  }

  /// Cache-only work order update used when queueing offline completion.
  Future<WorkOrder> applyLocalWorkOrderUpdate(WorkOrder workOrder) async {
    final updated = await _dataService.applyWorkOrderToCache(workOrder);
    _invalidateWorkOrdersView();
    notifyListeners();
    return updated;
  }

  /// Cache-only PM task update used when queueing offline completion.
  Future<PMTask> applyLocalPMTaskUpdate(PMTask pmTask) async {
    final updated = await _dataService.applyPMTaskToCache(pmTask);
    final index = _realtimePMTasks.indexWhere((pm) => pm.id == updated.id);
    if (index == -1) {
      _realtimePMTasks.add(updated);
    } else {
      _realtimePMTasks[index] = updated;
    }
    notifyListeners();
    return updated;
  }

  void resetPagination() {
    _woNextPage = 1;
    _hasMoreWorkOrders = true;
    _isLoadingMoreWorkOrders = false;
  }

  void repopulateReferences() {
    _invalidateWorkOrdersView();
    if (_realtimePMTasks.isNotEmpty) {
      _realtimePMTasks = populatePMTaskReferences(
        _realtimePMTasks,
        users: _usersProvider.users,
        assets: _assetsProvider.assets,
      );
    }
    notifyListeners();
  }

  Future<void> recoverMissingReferences({
    Set<String>? userIds,
    Set<String>? assetIds,
  }) async {
    final futures = <Future<bool>>[];
    if (userIds != null && userIds.isNotEmpty) {
      futures.add(_dataService.ensureUsersLoaded(userIds));
    }
    if (assetIds != null && assetIds.isNotEmpty) {
      futures.add(_dataService.ensureAssetsLoaded(assetIds));
    }
    if (futures.isEmpty) return;

    try {
      final results = await Future.wait(futures);
      // Only rebuild when something new landed — otherwise missing requestor
      // profiles under get_user_by_id Forbidden spam an infinite recover loop.
      if (results.any((loaded) => loaded)) {
        repopulateReferences();
      }
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error recovering references: $e');
    }
  }

  @override
  Future<void> cancelRealtimeListeners() async {
    _dataService.stopWorkOrderRealtimeListener();
    await cancelStreamSubscriptions([_pmTasksSubscription]);
    _pmTasksSubscription = null;
  }

  @override
  Future<void> startRealtimeListeners() async {
    if (_isDisposed) return;
    await cancelRealtimeListeners();
    if (_isDisposed) return;

    _dataService.startWorkOrderRealtimeListener(
      onChanged: _onCanonicalWorkOrdersChanged,
    );

    _pmTasksSubscription = _dataService.pmTasksStream.listen(
      (pmTasks) {
        final missingUsers = <String>{};
        final missingAssets = <String>{};
        _realtimePMTasks = populatePMTaskReferences(
          dedupePMTasks(pmTasks),
          users: _usersProvider.users,
          assets: _assetsProvider.assets,
          missingUserIds: missingUsers,
          missingAssetIds: missingAssets,
        );
        if (!_isDisposed) {
          ChangeNotifierBatcher.batchNotify(
            () => notifyListeners(),
            batchKey: this,
          );
        }

        if (missingUsers.isNotEmpty || missingAssets.isNotEmpty) {
          unawaited(
            recoverMissingReferences(
              userIds: missingUsers,
              assetIds: missingAssets,
            ),
          );
        }
      },
      onError: (error) {
        debugPrint('❌ PM tasks stream error: $error');
      },
    );
  }

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
  }) async {
    try {
      const uuid = Uuid();
      final now = DateTime.now();
      final workOrderId = uuid.v4();

      final ticketNumber = buildWorkOrderTicketNumber(
        createdAt: now,
        workOrderId: workOrderId,
      );

      List<String> uploadedPhotoUrls = [];
      final photosToUpload =
          photoPaths ?? (photoPath != null ? [photoPath] : <String>[]);
      final offlineMode = AppConfig.isOfflineModeEnabled;
      final isOnline = sl<ConnectivityService>().isOnline;

      if (photosToUpload.isNotEmpty) {
        if (offlineMode && !isOnline) {
          uploadedPhotoUrls = List<String>.from(photosToUpload);
        } else {
          final storageService = CmmsRepositories.workOrders;
          for (int i = 0; i < photosToUpload.length; i++) {
            try {
              final photoUrl = photosToUpload[i];
              if (photoUrl.startsWith('http://') ||
                  photoUrl.startsWith('https://')) {
                uploadedPhotoUrls.add(photoUrl);
              } else {
                final photoFile = XFile(photoUrl);
                final uploadedUrl = await storageService.uploadWorkOrderPhoto(
                  photoFile: photoFile,
                  workOrderId: workOrderId,
                );
                if (uploadedUrl != null) {
                  uploadedPhotoUrls.add(uploadedUrl);
                }
              }
            } catch (e, st) {
              debugPrint('⚠️ Failed to upload photo $i to Supabase Storage: $e');
              if (offlineMode && isLikelyNetworkError(e)) {
                uploadedPhotoUrls.add(photosToUpload[i]);
              }
            }
          }
        }
      }

      final finalPhotoPath =
          uploadedPhotoUrls.isNotEmpty ? uploadedPhotoUrls.first : null;

      if (asset == null && assetId != null) {
        asset = _assetsProvider.assets.firstWhere(
          (a) => a.id == assetId,
          orElse: () => Asset(
            id: assetId!,
            name: 'Unknown Asset',
            location: '',
            status: 'unknown',
            category: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final requestor = await _resolveRequestorForSubmit(requestorId);

      final requestorRole = requestor.role.toLowerCase();
      var companyId = requestor.companyId;
      if (requestorRole == 'technician') {
        final fromAsset = asset?.companyId?.trim();
        if (fromAsset != null && fromAsset.isNotEmpty) {
          companyId = fromAsset;
        } else {
          // Individual or unassigned charger — do not inherit staff account company.
          companyId = null;
        }
      }
      final companyGate = validateRequestorCompanyAssignment(
        role: requestor.role,
        companyId: companyId,
      );
      if (!companyGate.allowed) {
        throw StateError(companyGate.userMessage!);
      }

      final assignedIds = <String>[];
      List<User>? assignedTechnicians;

      void addTechnician(String? id) {
        if (id != null && id.isNotEmpty && !assignedIds.contains(id)) {
          assignedIds.add(id);
        }
      }

      if (requestorRole == 'admin' || requestorRole == 'manager') {
        if (assignedTechnicianIds != null) {
          for (final techId in assignedTechnicianIds) {
            addTechnician(techId);
          }
        }
      } else if (requestorRole == 'technician') {
        if (assignedTechnicianIds != null) {
          for (final techId in assignedTechnicianIds) {
            addTechnician(techId);
          }
        }
        addTechnician(requestorId);
      }

      if (assignedIds.isNotEmpty) {
        assignedTechnicians = _usersProvider.users
            .where((user) => assignedIds.contains(user.id))
            .toList();
      }

      final workOrder = WorkOrder(
        id: workOrderId,
        ticketNumber: ticketNumber,
        assetId: assetId,
        asset: asset,
        location: location,
        companyId: companyId,
        problemDescription: problemDescription,
        photoPath: finalPhotoPath,
        photoPaths: uploadedPhotoUrls.isNotEmpty ? uploadedPhotoUrls : null,
        requestorId: requestorId,
        requestor: requestor,
        requestorName: requestorName ?? customerName,
        primaryTechnicianId: assignedIds.isNotEmpty ? assignedIds.first : null,
        assignedTechnicianIds: assignedIds,
        assignedTechnicians: assignedTechnicians,
        assignedAt: assignedIds.isNotEmpty ? now : null,
        status: assignedIds.isNotEmpty
            ? WorkOrderStatus.assigned
            : WorkOrderStatus.open,
        priority: priority,
        category: category,
        notes: notes,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        createdAt: now,
        isOffline: uploadedPhotoUrls.isNotEmpty &&
            uploadedPhotoUrls.any((p) => !p.startsWith('http')),
        updatedAt: now,
      );

      final id = await _dataService.createWorkOrder(workOrder);
      _invalidateWorkOrdersView();
      notifyListeners();
      return id;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error creating work order: $e');
      rethrow;
    }
  }

  /// Requestor apps cannot call [get_users_list] (admin/manager only), so the
  /// in-memory user cache is often empty. Load the signed-in requestor by id.
  Future<User> _resolveRequestorForSubmit(String requestorId) async {
    final cached = _usersProvider.getUserById(requestorId);
    if (cached != null &&
        cached.companyId != null &&
        cached.companyId!.trim().isNotEmpty) {
      return cached;
    }

    final fetched = await CmmsRepositories.users.getUserById(requestorId);
    if (fetched != null) {
      return fetched;
    }

    throw StateError(
      'Could not load your user profile. Sign out and sign in again, '
      'then retry.',
    );
  }

  /// Offline enqueue lives in [UnifiedDataService.updateWorkOrder] so HEAD
  /// (provider → service) and WIP facades share one choke point.
  Future<WorkOrder> updateWorkOrder(WorkOrder workOrder) async {
    try {
      final updatedWorkOrder = await _dataService.updateWorkOrder(workOrder);
      _invalidateWorkOrdersView();
      notifyListeners();
      return updatedWorkOrder;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error updating work order: $e');
      rethrow;
    }
  }

  Future<WorkOrder> completeWorkOrder(
    WorkOrder workOrder, {
    List<String> pendingLocalPhotoPaths = const [],
  }) async {
    try {
      final updatedWorkOrder = await _dataService.completeWorkOrder(
        workOrder,
        pendingLocalPhotoPaths: pendingLocalPhotoPaths,
      );
      _invalidateWorkOrdersView();
      notifyListeners();
      return updatedWorkOrder;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error completing work order: $e');
      rethrow;
    }
  }

  void updateCachedWorkOrder(WorkOrder workOrder) {
    _dataService.upsertWorkOrderInCache(workOrder);
    _invalidateWorkOrdersView();
    notifyListeners();
  }

  /// Fetches one work order from the repository and merges it into the cache.
  /// Concurrent calls for the same id share a single in-flight request.
  Future<void> refreshWorkOrder(String workOrderId) async {
    if (_isDisposed || workOrderId.isEmpty) return;

    final inFlight = _refreshWorkOrderInFlight[workOrderId];
    if (inFlight != null) return inFlight;

    final future = _runRefreshWorkOrder(workOrderId);
    _refreshWorkOrderInFlight[workOrderId] = future;
    try {
      await future;
    } finally {
      if (_refreshWorkOrderInFlight[workOrderId] == future) {
        _refreshWorkOrderInFlight.remove(workOrderId);
      }
    }
  }

  Future<void> _runRefreshWorkOrder(String workOrderId) async {
    try {
      if (await resolveOfflineQueueService()
          .hasPendingMutationForWorkOrder(workOrderId)) {
        debugPrint(
          'WorkOrderProvider: Skipping refreshWorkOrder $workOrderId '
          '— pending offline queue mutation',
        );
        return;
      }

      final fetched =
          await CmmsRepositories.workOrders.getWorkOrder(workOrderId);
      if (fetched == null) {
        debugPrint(
          'WorkOrderProvider: refreshWorkOrder — not found: $workOrderId',
        );
        return;
      }

      _dataService.upsertWorkOrderInCache(fetched);
      _invalidateWorkOrdersView();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('WorkOrderProvider: refreshWorkOrder error: $e');
      rethrow;
    }
  }

  Future<void> loadMoreWorkOrders() async {
    if (_isLoadingMoreWorkOrders || !_hasMoreWorkOrders || _isDisposed) return;
    _isLoadingMoreWorkOrders = true;
    try {
      final fetched = await _dataService.appendWorkOrderPage(
        _woNextPage,
        pageSize: _woPageSize,
      );
      if (fetched < _woPageSize) {
        _hasMoreWorkOrders = false;
      }
      _woNextPage++;
      _invalidateWorkOrdersView();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: loadMoreWorkOrders error: $e');
    } finally {
      _isLoadingMoreWorkOrders = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Loads the full work-order list for a requestor account.
  Future<void> loadRequestorWorkOrders(String requestorId) async {
    if (_isDisposed || requestorId.isEmpty) return;

    try {
      await _dataService.loadWorkOrdersForRequestor(requestorId);
      _hasMoreWorkOrders = false;
      _woNextPage = 1;
      _invalidateWorkOrdersView();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('WorkOrderProvider: loadRequestorWorkOrders error: $e');
      rethrow;
    }
  }

  Future<void> deleteWorkOrder(String workOrderId) async {
    try {
      await _dataService.deleteWorkOrder(workOrderId);
      _invalidateWorkOrdersView();
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error deleting work order: $e');
      rethrow;
    }
  }

  Future<WorkOrder> reopenWorkOrder({
    required String workOrderId,
    required String currentUserId,
    required String reason,
    String? editedDescription,
    int maxReopenCount = 3,
  }) async {
    try {
      final fetchedWorkOrder =
          await CmmsRepositories.workOrders.getWorkOrder(workOrderId);
      if (fetchedWorkOrder == null) {
        throw Exception('Work order not found');
      }

      final workOrder = fetchedWorkOrder;
      _dataService.upsertWorkOrderInCache(workOrder);
      _invalidateWorkOrdersView();

      if (workOrder.status != WorkOrderStatus.completed &&
          workOrder.status != WorkOrderStatus.closed &&
          workOrder.status != WorkOrderStatus.cancelled) {
        throw Exception(
          'Only completed, closed, or cancelled work orders can be reopened. Current status: ${workOrder.status.name}',
        );
      }
      if (workOrder.reopenCount >= maxReopenCount) {
        throw Exception(
          'This work order has already been reopened ${workOrder.reopenCount} time(s). Maximum allowed: $maxReopenCount',
        );
      }
      if (workOrder.requestorId != currentUserId) {
        throw Exception(
          'Only the requestor who created this work order can reopen it',
        );
      }

      final now = DateTime.now();
      final previousCompletionDate = workOrder.completedAt ?? workOrder.closedAt;
      final previousStatus = workOrder.status;
      final updatedWorkOrder = workOrder.copyWith(
        status: WorkOrderStatus.reopened,
        assignedTechnicianIds: <String>[],
        primaryTechnicianId: null,
        assignedTechnicians: null,
        assignedAt: null,
        startedAt: null,
        completedAt: null,
        closedAt: null,
        problemDescription: editedDescription ?? workOrder.problemDescription,
        reopenedAt: now,
        reopenedBy: currentUserId,
        reopenReason: reason,
        reopenCount: workOrder.reopenCount + 1,
        previousCompletionDate: previousCompletionDate,
        previousStatus: previousStatus,
        updatedAt: now,
        isPaused: false,
        pausedAt: null,
        pauseReason: null,
        resumedAt: null,
        workDurationSeconds: null,
      );

      final reopenedWorkOrder = await _dataService.updateWorkOrder(
        updatedWorkOrder,
      );

      _invalidateWorkOrdersView();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 100));
      return reopenedWorkOrder;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error reopening work order: $e');
      rethrow;
    }
  }

  Future<void> assignTechnicianToWorkOrder(
    String workOrderId,
    String technicianId,
  ) async {
    try {
      await _dataService.assignTechnicianToWorkOrder(workOrderId, technicianId);
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error assigning technician: $e');
      rethrow;
    }
  }

  Future<void> updateWorkOrderTechnicians(
    String workOrderId,
    List<String> technicianIds,
  ) async {
    try {
      await _dataService.updateWorkOrderTechnicianAssignments(
        workOrderId,
        technicianIds,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error updating technicians: $e');
      rethrow;
    }
  }

  Future<void> unassignTechnicianFromWorkOrder(
    String workOrderId, {
    String? technicianId,
  }) async {
    try {
      await _dataService.unassignTechnicianFromWorkOrder(
        workOrderId,
        technicianId: technicianId,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error unassigning technician: $e');
      rethrow;
    }
  }

  Future<void> assignTechnician(String workOrderId, String technicianId) =>
      assignTechnicianToWorkOrder(workOrderId, technicianId);

  Future<void> unassignTechnician(
    String workOrderId, {
    String? technicianId,
  }) =>
      unassignTechnicianFromWorkOrder(workOrderId, technicianId: technicianId);

  /// Creates a legacy `pm_tasks` row.
  ///
  /// **Freeze policy:** maintenance-only. Admin/manager legacy create path;
  /// new schedules should use React admin + `pm_schedules` when Option A is ON.
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
  }) async {
    try {
      final finalAssignedIds = <String>[];
      if (assignedTechnicianIds != null) {
        finalAssignedIds
            .addAll(assignedTechnicianIds.where((id) => id.isNotEmpty));
      }

      if (finalAssignedIds.isEmpty && createdById != null) {
        final creator = _usersProvider.users.firstWhere(
          (u) => u.id == createdById,
          orElse: () => User(
            id: createdById,
            email: '',
            name: 'Unknown User',
            role: 'requestor',
            createdAt: DateTime.now(),
          ),
        );
        if (creator.role == 'technician') {
          finalAssignedIds.add(createdById);
        }
      }

      final createdPMTask = await _dataService.createPMTask(
        taskName: taskName,
        assetId: assetId,
        asset: asset,
        description: description,
        checklistJson: checklistJson,
        frequency: frequency,
        nextDue: nextDue,
        assignedTechnicianIds: finalAssignedIds,
        createdById: createdById,
      );

      final populatedList = populatePMTaskReferences(
        [createdPMTask],
        users: _usersProvider.users,
        assets: _assetsProvider.assets,
      );
      final populated =
          populatedList.isNotEmpty ? populatedList.first : createdPMTask;

      final existingIndex =
          _realtimePMTasks.indexWhere((pm) => pm.id == populated.id);
      if (existingIndex != -1) {
        _realtimePMTasks[existingIndex] = populated;
      } else {
        _realtimePMTasks.add(populated);
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error creating PM task: $e');
      rethrow;
    }
  }

  Future<PMTask> updatePMTask(PMTask pmTask) async {
    try {
      final updatedPMTask = await _dataService.updatePMTask(pmTask);
      final index = _realtimePMTasks.indexWhere((pm) => pm.id == pmTask.id);
      if (index != -1) {
        _realtimePMTasks[index] = updatedPMTask;
      } else {
        _realtimePMTasks.add(updatedPMTask);
      }
      notifyListeners();
      return updatedPMTask;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error updating PM task: $e');
      rethrow;
    }
  }

  Future<void> deletePMTask(String pmTaskId) async {
    try {
      await _dataService.deletePMTask(pmTaskId);
      _realtimePMTasks.removeWhere((pm) => pm.id == pmTaskId);
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error deleting PM task: $e');
      rethrow;
    }
  }

  Future<void> assignPMTaskTechnician(
    String pmTaskId,
    String technicianId,
  ) async {
    try {
      await _dataService.assignTechnicianToPMTask(pmTaskId, technicianId);
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error assigning PM task technician: $e');
      rethrow;
    }
  }

  Future<void> updatePMTaskTechnicians(
    String pmTaskId,
    List<String> technicianIds,
  ) async {
    try {
      await _dataService.updatePMTaskTechnicianAssignments(
        pmTaskId,
        technicianIds,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error updating PM task technicians: $e');
      rethrow;
    }
  }

  Future<void> unassignPMTaskTechnician(
    String pmTaskId, {
    String? technicianId,
  }) async {
    try {
      await _dataService.unassignTechnicianFromPMTask(
        pmTaskId,
        technicianId: technicianId,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error unassigning PM task technician: $e');
      rethrow;
    }
  }

  Future<WorkOrder> pauseWorkOrder(String workOrderId, String reason) async {
    try {
      final updatedWorkOrder =
          await _dataService.pauseWorkOrder(workOrderId, reason);
      _invalidateWorkOrdersView();
      notifyListeners();
      return updatedWorkOrder;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error pausing work order: $e');
      rethrow;
    }
  }

  Future<WorkOrder> resumeWorkOrder(String workOrderId) async {
    try {
      final updatedWorkOrder = await _dataService.resumeWorkOrder(workOrderId);
      _invalidateWorkOrdersView();
      notifyListeners();
      return updatedWorkOrder;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error resuming work order: $e');
      rethrow;
    }
  }

  Future<PMTask> pausePMTask(String pmTaskId, String reason) async {
    try {
      final updatedPMTask = await _dataService.pausePMTask(pmTaskId, reason);
      final realtimeIndex = _realtimePMTasks.indexWhere((pm) => pm.id == pmTaskId);
      if (realtimeIndex != -1) {
        _realtimePMTasks[realtimeIndex] = updatedPMTask;
      }
      notifyListeners();
      return updatedPMTask;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error pausing PM task: $e');
      rethrow;
    }
  }

  Future<PMTask> resumePMTask(String pmTaskId) async {
    try {
      final updatedPMTask = await _dataService.resumePMTask(pmTaskId);
      final realtimeIndex = _realtimePMTasks.indexWhere((pm) => pm.id == pmTaskId);
      if (realtimeIndex != -1) {
        _realtimePMTasks[realtimeIndex] = updatedPMTask;
      }
      notifyListeners();
      return updatedPMTask;
    } catch (e, st) {
      debugPrint('WorkOrderProvider: Error resuming PM task: $e');
      rethrow;
    }
  }

  List<WorkOrder> getWorkOrdersByTechnician(String technicianId) =>
      workOrdersAssignedToTechnician(workOrders, technicianId);

  List<PMTask> getPMTasksByTechnician(String technicianId) =>
      pmTasks.where((task) => task.hasTechnician(technicianId)).toList();

  List<WorkOrder> getWorkOrdersByStatus(dynamic status) {
    final target = status is WorkOrderStatus
        ? status.name
        : status is String
            ? status.toLowerCase()
            : null;
    if (target == null) return const <WorkOrder>[];
    return workOrders
        .where((wo) => wo.status.name.toLowerCase() == target)
        .toList();
  }

  List<WorkOrder> getWorkOrdersByPriority(dynamic priority) {
    final target = priority is WorkOrderPriority
        ? priority.name
        : priority is String
            ? priority.toLowerCase()
            : null;
    if (target == null) return const <WorkOrder>[];
    return workOrders
        .where((wo) => wo.priority.name.toLowerCase() == target)
        .toList();
  }

  List<WorkOrder> getWorkOrdersByRequestor(String requestorId) =>
      workOrders.where((wo) => wo.requestorId == requestorId).toList();

  List<WorkOrder> getOverdueWorkOrders() =>
      workOrders.where((wo) => wo.isOverdue).toList();

  List<PMTask> getOverduePMTasks() => pmTasks
      .where((task) => task.status == PMTaskStatus.overdue || task.isOverdue)
      .toList();

  List<PMTask> getPMTasksByStatus(PMTaskStatus status) =>
      pmTasks.where((task) => task.status == status).toList();

  WorkOrder? getWorkOrderById(String id) {
    try {
      return workOrders.firstWhere((wo) => wo.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> getTechnicianPerformance(String technicianId) {
    final technicianWorkOrders = getWorkOrdersByTechnician(technicianId);
    final technicianPMTasks = getPMTasksByTechnician(technicianId);

    return {
      'workOrders': technicianWorkOrders,
      'pmTasks': technicianPMTasks,
      'workOrderStats': {
        'total': technicianWorkOrders.length,
        'completed': technicianWorkOrders.where((wo) => wo.isCompleted).length,
        'inProgress':
            technicianWorkOrders.where((wo) => wo.isInProgress).length,
        'overdue': technicianWorkOrders.where((wo) => wo.isOverdue).length,
      },
      'pmTaskStats': {
        'total': technicianPMTasks.length,
        'completed': technicianPMTasks.where((task) => task.isCompleted).length,
        'inProgress':
            technicianPMTasks.where((task) => task.isInProgress).length,
        'overdue': technicianPMTasks.where((task) => task.isOverdue).length,
      },
    };
  }

  @override
  void dispose() {
    _isDisposed = true;
    ChangeNotifierBatcher.cancel(this);
    unawaited(cancelRealtimeListeners());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
