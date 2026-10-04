// Unified Data Service - Single source of truth for all data operations
// This service ensures data consistency across all screens and providers

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Hide gotrue's `User` so it doesn't shadow our own `models/user.dart` `User`.
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';

import '../models/asset.dart';
import '../models/inventory_item.dart';
import '../models/pm_task.dart';
import '../models/user.dart';
import '../models/work_order.dart';
import '../models/workflow_models.dart';
import '../utils/deterministic_id_generator.dart';
import '../utils/offline_cache_merge.dart';
import '../utils/offline_network.dart';
import '../utils/offline_pm_task_mutation.dart';
import '../utils/offline_service_access.dart';
import '../utils/offline_work_order_mutation.dart';
import '../utils/technician_work_order_filter.dart';
import '../utils/work_order_cache_sync.dart';
import '../repositories/cmms_repositories.dart';
import 'connectivity_service.dart';
import 'hybrid_dam_service.dart';
import 'realtime_supabase_service.dart';
import '../config/locator.dart';

class UnifiedDataService {

  // Cache for all data
  List<WorkOrder> _workOrders = [];
  List<PMTask> _pmTasks = [];
  List<User> _users = [];
  List<Asset> _assets = [];
  List<InventoryItem> _inventoryItems = [];
  List<Workflow> _workflows = [];

  // Loading states
  bool _isWorkOrdersLoading = false;
  bool _isPMTasksLoading = false;
  bool _isUsersLoading = false;
  bool _isAssetsLoading = false;
  bool _isInventoryLoading = false;
  bool _isWorkflowsLoading = false;
  bool _isHealingWorkOrders = false;
  final Set<String> _pendingUserFetches = <String>{};
  final Set<String> _pendingAssetFetches = <String>{};
  /// Users that returned null/Forbidden from get_user_by_id (e.g. other roles
  /// under RPC gate). Skip re-fetch so recoverMissingReferences cannot loop.
  final Set<String> _unreadableUserIds = <String>{};

  // Single-flight + per-user init guard so duplicate initialize() callers (bootstrap,
  // ComprehensiveCMMSService, UnifiedDataProvider, post-login refresh) don't trigger
  // multiple parallel full data loads. Pre-auth callers no-op so we don't burn round
  // trips that RLS would reject anyway.
  Future<void>? _initInFlight;
  String? _initializedForUserId;

  // Canonical work-order cache is [_workOrders]. Realtime merges here only.
  bool _workOrderRealtimeListening = false;
  VoidCallback? _workOrdersChangedCallback;

  // Getters
  List<WorkOrder> get workOrders => _workOrders;
  List<PMTask> get pmTasks => _pmTasks;
  List<User> get users => _users;
  List<Asset> get assets => _assets;
  List<InventoryItem> get inventoryItems => _inventoryItems;
  List<Workflow> get workflows => _workflows;
  Future<WorkOrder> _loadWorkOrder(String workOrderId) async {
    try {
      return _workOrders.firstWhere((wo) => wo.id == workOrderId);
    } on StateError {
      // Load from Supabase
      final fetched = await CmmsRepositories.workOrders.getWorkOrder(
        workOrderId,
      );
      if (fetched != null) {
        await _upsertWorkOrderInCache(fetched);
        return fetched;
      }

      await _healWorkOrdersFromSupabase(missingWorkOrderId: workOrderId);

      try {
        return _workOrders.firstWhere((wo) => wo.id == workOrderId);
      } on StateError {
        throw StateError('Work order $workOrderId not found');
      }
    }
  }

  Future<void> _upsertWorkOrderInCache(WorkOrder workOrder) async {
    upsertWorkOrderInCache(workOrder);
  }

  /// Public upsert for provider-driven cache hydration (no network write).
  void upsertWorkOrderInCache(WorkOrder workOrder) {
    final index = _workOrders.indexWhere((wo) => wo.id == workOrder.id);
    if (index == -1) {
      _workOrders.add(workOrder);
    } else {
      _workOrders[index] =
          pickWorkOrderCacheWinner(_workOrders[index], workOrder);
    }
    _workOrdersChangedCallback?.call();
  }

  Future<void> _healWorkOrdersFromSupabase({
    String? missingWorkOrderId,
  }) async {
    if (_isHealingWorkOrders) {
      debugPrint(
        '⏳ UnifiedDataService: Auto-heal already running; skipping duplicate request',
      );
      return;
    }

    _isHealingWorkOrders = true;
    try {
      final reason = missingWorkOrderId != null
          ? ' (missing $missingWorkOrderId)'
          : '';
      debugPrint('🩺 UnifiedDataService: Auto-healing work orders$reason...');

      final remoteOrders =
          await CmmsRepositories.workOrders.getAllWorkOrders();
      if (remoteOrders.isEmpty) {
        debugPrint('⚠️ UnifiedDataService: Supabase returned 0 work orders');
        return;
      }

      final merged = <String, WorkOrder>{
        for (final wo in _workOrders) wo.id: wo,
      };
      for (final remote in remoteOrders) {
        merged[remote.id] = remote;
      }
      _workOrders = merged.values.toList();

      // No local DB persistence - Supabase is the source of truth

      _populateReferences();
      debugPrint(
        '✅ UnifiedDataService: Auto-heal refreshed ${remoteOrders.length} work orders from Supabase',
      );
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Auto-heal failed: $e');
    } finally {
      _isHealingWorkOrders = false;
    }
  }


  bool get isWorkOrdersLoading => _isWorkOrdersLoading;
  bool get isPMTasksLoading => _isPMTasksLoading;
  bool get isUsersLoading => _isUsersLoading;
  bool get isAssetsLoading => _isAssetsLoading;
  bool get isInventoryLoading => _isInventoryLoading;
  bool get isWorkflowsLoading => _isWorkflowsLoading;

  // ============================================================================
  // REAL-TIME FIRESTORE STREAMS - Direct UI Connection
  // ============================================================================

  /// Get real-time stream of work orders from Supabase
  Stream<List<WorkOrder>> get workOrdersStream =>
      sl<RealtimeSupabaseService>().getWorkOrdersStream();

  /// Get real-time stream of PM tasks from Supabase
  Stream<List<PMTask>> get pmTasksStream =>
      sl<RealtimeSupabaseService>().getPMTasksStream();

  /// Get real-time stream of assets from Supabase
  Stream<List<Asset>> get assetsStream =>
      sl<RealtimeSupabaseService>().getAssetsStream();

  /// Get real-time stream of users from Supabase
  Stream<List<User>> get usersStream =>
      sl<RealtimeSupabaseService>().getUsersStream();

  /// Get real-time stream of inventory items from Supabase
  Stream<List<InventoryItem>> get inventoryItemsStream =>
      sl<RealtimeSupabaseService>().getInventoryItemsStream();

  /// Get real-time stream of workflows from Supabase
  Stream<List<Workflow>> get workflowsStream =>
      sl<RealtimeSupabaseService>().getWorkflowsStream();

  /// Get real-time stream of work orders for a specific technician
  Stream<List<WorkOrder>> getWorkOrdersByTechnicianStream(
    String technicianId,
  ) =>
      sl<RealtimeSupabaseService>()
          .getWorkOrdersByTechnicianStream(technicianId);

  /// Get real-time stream of PM tasks for a specific technician
  Stream<List<PMTask>> getPMTasksByTechnicianStream(String technicianId) =>
      sl<RealtimeSupabaseService>()
          .getPMTasksByTechnicianStream(technicianId);

  /// Get real-time stream of a single work order
  Stream<WorkOrder?> getWorkOrderStream(String workOrderId) =>
      sl<RealtimeSupabaseService>().getWorkOrderStream(workOrderId);

  /// Get real-time stream of a single PM task
  Stream<PMTask?> getPMTaskStream(String pmTaskId) =>
      sl<RealtimeSupabaseService>().getPMTaskStream(pmTaskId);

  /// Get real-time stream of a single asset
  Stream<Asset?> getAssetStream(String assetId) =>
      sl<RealtimeSupabaseService>().getAssetStream(assetId);

  /// Get real-time stream of a single workflow
  Stream<Workflow?> getWorkflowStream(String workflowId) =>
      sl<RealtimeSupabaseService>().getWorkflowStream(workflowId);

  /// Get real-time stream of workflows for a specific user
  Stream<List<Workflow>> getWorkflowsByUserStream(String userId) =>
      sl<RealtimeSupabaseService>().getWorkflowsByUserStream(userId);

  /// Get real-time stream of pending approvals for a specific user
  Stream<List<Workflow>> getPendingApprovalsByUserStream(String userId) =>
      sl<RealtimeSupabaseService>().getPendingApprovalsByUserStream(userId);

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  static const _woSurfaceCachePrefix = 'technician_wo_surface_cache_';
  static const _pmSurfaceCachePrefix = 'technician_pm_surface_cache_';

  bool get _isDeviceOffline => !kIsWeb && !sl<ConnectivityService>().isOnline;

  Future<String?> _surfaceCacheUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user_id');
  }

  String _woSurfaceCacheKey(String userId) => '$_woSurfaceCachePrefix$userId';
  String _pmSurfaceCacheKey(String userId) => '$_pmSurfaceCachePrefix$userId';

  Future<void> _persistWorkOrdersSurfaceCache() async {
    if (kIsWeb || _workOrders.isEmpty) return;
    try {
      final userId = await _surfaceCacheUserId();
      if (userId == null || userId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_workOrders.map((wo) => wo.toMap()).toList());
      await prefs.setString(_woSurfaceCacheKey(userId), payload);
    } catch (e) {
      debugPrint(
        '⚠️ UnifiedDataService: Failed to persist WO surface cache: $e',
      );
    }
  }

  Future<void> _persistPMTasksSurfaceCache() async {
    if (kIsWeb || _pmTasks.isEmpty) return;
    try {
      final userId = await _surfaceCacheUserId();
      if (userId == null || userId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_pmTasks.map((pm) => pm.toMap()).toList());
      await prefs.setString(_pmSurfaceCacheKey(userId), payload);
    } catch (e) {
      debugPrint(
        '⚠️ UnifiedDataService: Failed to persist PM surface cache: $e',
      );
    }
  }

  Future<void> _restoreWorkOrdersSurfaceCache() async {
    if (kIsWeb) return;
    try {
      final userId = await _surfaceCacheUserId();
      if (userId == null || userId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_woSurfaceCacheKey(userId));
      if (cacheJson == null || cacheJson.isEmpty) return;

      final list = jsonDecode(cacheJson) as List<dynamic>;
      final restored = list
          .map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _workOrders = mergeWorkOrderCacheLists(_workOrders, restored);
      debugPrint(
        '📦 UnifiedDataService: Restored ${_workOrders.length} work orders '
        'from local surface cache',
      );
    } catch (e) {
      debugPrint(
        '⚠️ UnifiedDataService: Failed to restore WO surface cache: $e',
      );
    }
  }

  Future<void> _restorePMTasksSurfaceCache() async {
    if (kIsWeb) return;
    try {
      final userId = await _surfaceCacheUserId();
      if (userId == null || userId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_pmSurfaceCacheKey(userId));
      if (cacheJson == null || cacheJson.isEmpty) return;

      final list = jsonDecode(cacheJson) as List<dynamic>;
      final restored = list
          .map((e) => PMTask.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      _pmTasks = mergePMTaskCacheLists(_pmTasks, restored);
      debugPrint(
        '📦 UnifiedDataService: Restored ${_pmTasks.length} PM tasks '
        'from local surface cache',
      );
    } catch (e) {
      debugPrint(
        '⚠️ UnifiedDataService: Failed to restore PM surface cache: $e',
      );
    }
  }

  Future<void> _mergeQueuedWorkOrdersIntoCache() async {
    try {
      final snapshots =
          await resolveOfflineQueueService().workOrderSnapshotsFromQueue();
      if (snapshots.isEmpty) return;
      _workOrders = mergeWorkOrderCacheLists(_workOrders, snapshots);
      debugPrint(
        '📦 UnifiedDataService: Merged ${snapshots.length} queued work order '
        'snapshot(s) into cache',
      );
    } catch (e) {
      debugPrint(
        '⚠️ UnifiedDataService: Failed to merge queued work orders: $e',
      );
    }
  }

  Future<void> _mergeQueuedPMTasksIntoCache() async {
    try {
      final snapshots =
          await resolveOfflineQueueService().pmTaskSnapshotsFromQueue();
      if (snapshots.isEmpty) return;
      _pmTasks = mergePMTaskCacheLists(_pmTasks, snapshots);
      debugPrint(
        '📦 UnifiedDataService: Merged ${snapshots.length} queued PM task '
        'snapshot(s) into cache',
      );
    } catch (e) {
      debugPrint(
        '⚠️ UnifiedDataService: Failed to merge queued PM tasks: $e',
      );
    }
  }

  Future<void> _clearSurfaceCachesForCurrentUser() async {
    if (kIsWeb) return;
    try {
      final userId = await _surfaceCacheUserId();
      if (userId == null || userId.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_woSurfaceCacheKey(userId));
      await prefs.remove(_pmSurfaceCacheKey(userId));
    } catch (e) {
      debugPrint('⚠️ UnifiedDataService: Failed to clear surface caches: $e');
    }
  }

  /// Work orders, PM tasks, users, and assets only — skips inventory/workflows
  /// for faster technician UX.
  Future<void> refreshTechnicianSurface() async {
    debugPrint(
      '🔄 UnifiedDataService: refreshTechnicianSurface (WO/PM/users/assets)...',
    );
    try {
      if (_isDeviceOffline) {
        debugPrint(
          '📦 UnifiedDataService: refreshTechnicianSurface (offline cache hydrate)',
        );
        await Future.wait([
          _loadWorkOrders(),
          _loadPMTasks(),
        ]);
      } else {
        await Future.wait([
          _loadWorkOrders(),
          _loadPMTasks(),
          _loadUsers(),
          _loadAssets(),
        ]);
      }
      _populateReferences();
      _workOrdersChangedCallback?.call();
      debugPrint('✅ UnifiedDataService: refreshTechnicianSurface complete');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: refreshTechnicianSurface error: $e');
      rethrow;
    }
  }

  /// Applies a work-order snapshot to the in-memory cache only (no network I/O).
  Future<WorkOrder> applyWorkOrderToCache(WorkOrder workOrder) async {
    final populated = _populateWorkOrderReferences(workOrder);
    final existingIndex =
        _workOrders.indexWhere((wo) => wo.id == populated.id);
    if (existingIndex == -1) {
      _workOrders.add(populated);
    } else {
      _workOrders[existingIndex] = populated;
    }
    _workOrdersChangedCallback?.call();
    unawaited(_persistWorkOrdersSurfaceCache());
    return populated;
  }

  /// Applies a PM-task snapshot to the in-memory cache only (no network I/O).
  Future<PMTask> applyPMTaskToCache(PMTask pmTask) async {
    final populated = _populatePMTaskReferences(pmTask);
    final existingIndex = _pmTasks.indexWhere((pt) => pt.id == populated.id);
    if (existingIndex == -1) {
      _pmTasks.add(populated);
    } else {
      _pmTasks[existingIndex] = populated;
    }
    unawaited(_persistPMTasksSurfaceCache());
    return populated;
  }

  /// Initialize all data services and load data.
  ///
  /// Idempotent: returns the in-flight future if a load is already running,
  /// no-ops if data is already loaded for the current user. Pre-auth calls
  /// short-circuit so RLS-protected queries aren't fired with no session.
  /// Pass [force] = true to bypass the cache (used by [refreshAll]).
  Future<void> initialize({bool force = false}) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Fast path: already loaded for this user.
    if (!force &&
        _initializedForUserId != null &&
        _initializedForUserId == currentUserId) {
      return;
    }

    // Coalesce concurrent callers to a single load.
    if (_initInFlight != null) {
      return _initInFlight;
    }

    // Skip wasted RLS-rejected requests when there is no session yet. The
    // provider re-runs initialize() once Supabase emits a signedIn auth event.
    if (currentUserId == null) {
      debugPrint('⏭️  UnifiedDataService: Skipping initial load (no auth user)');
      return;
    }

    _initInFlight = _runInitialize(currentUserId);
    try {
      await _initInFlight;
    } finally {
      _initInFlight = null;
    }
  }

  Future<void> _runInitialize(String userId) async {
    debugPrint('🔄 UnifiedDataService: Initializing all data services...');

    try {
      await CmmsRepositories.workOrders.initialize();

      await Future.wait([
        _loadWorkOrders(),
        _loadPMTasks(),
        _loadUsers(),
        _loadAssets(),
        _loadInventory(),
        _loadWorkflows(),
      ]);

      _populateReferences();
      _initializedForUserId = userId;

      debugPrint(
        '✅ UnifiedDataService: All data loaded successfully from Supabase',
      );
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error initializing: $e');
      rethrow;
    }
  }

  /// Reset the per-user cache marker (used on sign-out / user switch).
  void resetInitialization() {
    purgeUserSession();
  }

  /// Clears all user-scoped in-memory caches after logout.
  void purgeUserSession() {
    stopWorkOrderRealtimeListener();
    _initializedForUserId = null;
    _workOrders = [];
    _pmTasks = [];
    _users = [];
    _assets = [];
    _inventoryItems = [];
    _workflows = [];
    _unreadableUserIds.clear();
    _pendingUserFetches.clear();
    _pendingAssetFetches.clear();
    unawaited(_clearSurfaceCachesForCurrentUser());
    debugPrint('🧹 UnifiedDataService: user-scoped caches purged');
  }

  /// Load the first page of work orders from Supabase.
  /// The provider loads additional pages on demand via [appendWorkOrderPage].
  Future<void> _loadWorkOrders() async {
    _isWorkOrdersLoading = true;
    try {
      if (_isDeviceOffline) {
        debugPrint(
          '📦 UnifiedDataService: Offline — restoring work orders from surface cache',
        );
        await _restoreWorkOrdersSurfaceCache();
        await _mergeQueuedWorkOrdersIntoCache();
        return;
      }

      final fetched = await CmmsRepositories.workOrders
          .getWorkOrdersPage(page: 0, pageSize: 30);
      _workOrders = mergeWorkOrderCacheLists(_workOrders, fetched);
      await _mergeQueuedWorkOrdersIntoCache();
      unawaited(_persistWorkOrdersSurfaceCache());
      debugPrint('📋 UnifiedDataService: Loaded ${_workOrders.length} '
          'work orders (page 0) from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading work orders: $e');
      if (!kIsWeb) {
        await _restoreWorkOrdersSurfaceCache();
        await _mergeQueuedWorkOrdersIntoCache();
      } else {
        _workOrders = [];
      }
    } finally {
      _isWorkOrdersLoading = false;
    }
  }

  /// Append a page of work orders to the cache (called by provider on scroll).
  /// Returns the number of newly added rows.
  Future<int> appendWorkOrderPage(int page, {int pageSize = 30}) async {
    try {
      final rows = await CmmsRepositories.workOrders
          .getWorkOrdersPage(page: page, pageSize: pageSize);
      if (rows.isEmpty) return 0;
      final existing = {for (final wo in _workOrders) wo.id: wo};
      int added = 0;
      for (final wo in rows) {
        if (!existing.containsKey(wo.id)) {
          existing[wo.id] = wo;
          added++;
        } else {
          existing[wo.id] = wo; // keep server version authoritative
        }
      }
      _workOrders = existing.values.toList();
      debugPrint('📋 UnifiedDataService: Appended $added new work orders '
          '(page $page)');
      return rows.length; // caller uses this to detect last page
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading work orders page $page: $e');
      return 0;
    }
  }

  /// Loads all work orders for one requestor (used by requestor status screens).
  Future<void> loadWorkOrdersForRequestor(String requestorId) async {
    if (requestorId.isEmpty) return;

    _isWorkOrdersLoading = true;
    try {
      _workOrders = await CmmsRepositories.workOrders
          .getWorkOrdersByRequestor(requestorId);
      debugPrint(
        '📋 UnifiedDataService: Loaded ${_workOrders.length} work orders '
        'for requestor $requestorId',
      );
      _workOrdersChangedCallback?.call();
    } catch (e, st) {
      debugPrint(
        '❌ UnifiedDataService: Error loading requestor work orders: $e',
      );
      rethrow;
    } finally {
      _isWorkOrdersLoading = false;
    }
  }

  /// Merge a single realtime work-order event into the canonical cache.
  void applyWorkOrderRealtimeEvent(WorkOrderChangeEvent event) {
    _workOrders = applyWorkOrderChange(_workOrders, event);
    _workOrdersChangedCallback?.call();
  }

  /// Subscribe to incremental work-order changes (single listener site).
  void startWorkOrderRealtimeListener({VoidCallback? onChanged}) {
    if (_workOrderRealtimeListening) {
      _workOrdersChangedCallback = onChanged;
      return;
    }
    _workOrdersChangedCallback = onChanged;
    sl<RealtimeSupabaseService>().listenToWorkOrderChanges(
      applyWorkOrderRealtimeEvent,
    );
    _workOrderRealtimeListening = true;
    debugPrint('✅ UnifiedDataService: work_orders realtime listener started');
  }

  void stopWorkOrderRealtimeListener() {
    if (!_workOrderRealtimeListening) return;
    sl<RealtimeSupabaseService>().stopListeningToWorkOrderChanges();
    _workOrderRealtimeListening = false;
    _workOrdersChangedCallback = null;
    debugPrint('🔥 UnifiedDataService: work_orders realtime listener stopped');
  }

  /// @deprecated Realtime events merge via [applyWorkOrderRealtimeEvent].
  void syncRealtimeWorkOrders(List<WorkOrder> realtimeOrders) {
    _workOrders = applyRealtimeWorkOrderSnapshot(realtimeOrders);
    _workOrdersChangedCallback?.call();
  }

  /// Load PM tasks from Supabase
  Future<void> _loadPMTasks() async {
    _isPMTasksLoading = true;
    try {
      if (_isDeviceOffline) {
        debugPrint(
          '📦 UnifiedDataService: Offline — restoring PM tasks from surface cache',
        );
        await _restorePMTasksSurfaceCache();
        await _mergeQueuedPMTasksIntoCache();
        return;
      }

      final fetched = await CmmsRepositories.workOrders.getAllPMTasks();
      _pmTasks = mergePMTaskCacheLists(_pmTasks, fetched);
      await _mergeQueuedPMTasksIntoCache();
      unawaited(_persistPMTasksSurfaceCache());
      debugPrint(
        '📋 UnifiedDataService: Loaded ${_pmTasks.length} PM tasks from Supabase',
      );
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading PM tasks: $e');
      if (!kIsWeb) {
        await _restorePMTasksSurfaceCache();
        await _mergeQueuedPMTasksIntoCache();
      } else {
        _pmTasks = [];
      }
    } finally {
      _isPMTasksLoading = false;
    }
  }

  /// Load users from Supabase
  Future<void> _loadUsers() async {
    _isUsersLoading = true;
    try {
      _users = await CmmsRepositories.users.getAllUsers();
      debugPrint('👥 UnifiedDataService: Loaded ${_users.length} users from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading users: $e');
      _users = []; // Initialize empty list on error
    } finally {
      _isUsersLoading = false;
    }
  }

  /// Load assets from Supabase
  Future<void> _loadAssets() async {
    _isAssetsLoading = true;
    try {
      _assets = await CmmsRepositories.assets.getAllAssets();
      debugPrint('🏭 UnifiedDataService: Loaded ${_assets.length} assets from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading assets: $e');
      _assets = []; // Initialize empty list on error
    } finally {
      _isAssetsLoading = false;
    }
  }

  /// Load inventory from Supabase
  Future<void> _loadInventory() async {
    _isInventoryLoading = true;
    try {
      _inventoryItems =
          await CmmsRepositories.inventory.getAllInventoryItems();
      debugPrint(
        '📦 UnifiedDataService: Loaded ${_inventoryItems.length} inventory items from Supabase',
      );
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading inventory: $e');
      _inventoryItems = []; // Initialize empty list on error
    } finally {
      _isInventoryLoading = false;
    }
  }

  /// Ensure specific users are loaded into cache.
  /// Returns true only when at least one user was newly added/updated.
  Future<bool> ensureUsersLoaded(Set<String> userIds) async {
    final targets = userIds
        .where((id) => id.isNotEmpty)
        .where((id) => !_users.any((user) => user.id == id))
        .where((id) => !_unreadableUserIds.contains(id))
        .where((id) => !_pendingUserFetches.contains(id))
        .toList();
    if (targets.isEmpty) return false;

    _pendingUserFetches.addAll(targets);
    var loadedAny = false;
    try {
      debugPrint(
        '🔎 UnifiedDataService: Fetching ${targets.length} missing user(s)...',
      );
      for (final id in targets) {
        try {
          final fetchedUser =
              await CmmsRepositories.users.getUserById(id);
          if (fetchedUser != null) {
            _unreadableUserIds.remove(id);
            final existingIndex = _users.indexWhere((user) => user.id == id);
            if (existingIndex != -1) {
              _users[existingIndex] = fetchedUser;
            } else {
              _users.add(fetchedUser);
            }
            loadedAny = true;
            // No local DB persistence - Supabase is the source of truth
            debugPrint(
              '✅ UnifiedDataService: Loaded user ${fetchedUser.name} ($id)',
            );
          } else {
            // null covers missing rows and RPC Forbidden (get_user_by_id).
            _unreadableUserIds.add(id);
            debugPrint(
              '⚠️ UnifiedDataService: User $id not readable (missing or RLS); '
              'skipping further fetches',
            );
          }
        } catch (e, st) {
          _unreadableUserIds.add(id);
          debugPrint('❌ UnifiedDataService: Error fetching user $id: $e');
        }
      }
      if (loadedAny) {
        _populateReferences();
      }
      return loadedAny;
    } finally {
      _pendingUserFetches.removeAll(targets);
    }
  }

  /// Ensure specific assets are loaded into cache.
  /// Returns true only when at least one asset was newly added/updated.
  Future<bool> ensureAssetsLoaded(Set<String> assetIds) async {
    final targets = assetIds
        .where((id) => id.isNotEmpty)
        .where((id) => !_assets.any((asset) => asset.id == id))
        .where((id) => !_pendingAssetFetches.contains(id))
        .toList();
    if (targets.isEmpty) return false;

    _pendingAssetFetches.addAll(targets);
    var loadedAny = false;
    try {
      debugPrint(
        '🔎 UnifiedDataService: Fetching ${targets.length} missing asset(s)...',
      );
      for (final id in targets) {
        try {
          // First try the 'assets' collection
          var fetchedAsset = await CmmsRepositories.assets.getAsset(
            id,
          );
          
          // If not found, try the 'items' collection (DAM system)
          if (fetchedAsset == null) {
            debugPrint(
              '⚠️ UnifiedDataService: Asset $id not found in assets collection, trying items collection...',
            );
            fetchedAsset = await _getAssetFromItemsCollection(id);
          }
          
          if (fetchedAsset != null) {
            final existingIndex = _assets.indexWhere((asset) => asset.id == id);
            if (existingIndex != -1) {
              _assets[existingIndex] = fetchedAsset;
            } else {
              _assets.add(fetchedAsset);
            }
            loadedAny = true;
            // No local DB persistence - Supabase is the source of truth
            debugPrint(
              '✅ UnifiedDataService: Loaded asset ${fetchedAsset.name} ($id)',
            );
          } else {
            debugPrint('⚠️ UnifiedDataService: Asset $id not found in Supabase (checked both assets and items collections)');
          }
        } catch (e, st) {
          debugPrint('❌ UnifiedDataService: Error fetching asset $id: $e');
        }
      }
      if (loadedAny) {
        _populateReferences();
      }
      return loadedAny;
    } finally {
      _pendingAssetFetches.removeAll(targets);
    }
  }

  /// Get asset from the 'items' collection (DAM system)
  Future<Asset?> _getAssetFromItemsCollection(String assetId) async {
    try {
      // Use the HybridDamService which has access to the 'items' collection
      final hybridService = sl<HybridDamService>();
      await hybridService.initialize();
      final allAssets = await hybridService.getAllAssets();
      final asset = allAssets.firstWhere(
        (a) => a.id == assetId,
        orElse: () => throw StateError('Asset not found'),
      );
      return asset;
    } catch (e, st) {
      debugPrint('⚠️ UnifiedDataService: Error fetching asset $assetId from items collection: $e');
      return null;
    }
  }

  /// Validate that referenced users/assets exist (fetching them if possible)
  /// Assets are optional (for general maintenance), so missing assets only log a warning.
  /// When [requireUsers] is false (WO updates), unreadable users under get_user_by_id
  /// (technicians cannot read requestors) only warn — DB FKs/triggers remain authoritative.
  Future<void> validateReferences({
    Set<String>? userIds,
    Set<String>? assetIds,
    bool requireUsers = true,
  }) async {
    final missingUsers = <String>{};
    final missingAssets = <String>{};

    if (userIds != null && userIds.isNotEmpty) {
      await ensureUsersLoaded(userIds);
      for (final id in userIds) {
        if (id.isEmpty) continue;
        final exists = _users.any((user) => user.id == id);
        if (!exists) {
          missingUsers.add(id);
        }
      }
    }

    if (assetIds != null && assetIds.isNotEmpty) {
      await ensureAssetsLoaded(assetIds);
      for (final id in assetIds) {
        if (id.isEmpty) continue;
        final exists = _assets.any((asset) => asset.id == id);
        if (!exists) {
          missingAssets.add(id);
        }
      }
    }

    // Log warning for missing assets (they're optional for general maintenance)
    if (missingAssets.isNotEmpty) {
      debugPrint(
        '⚠️ UnifiedDataService: Asset(s) not found: ${missingAssets.join(', ')}. '
        'Work order will be created without asset reference (general maintenance).',
      );
    }

    if (missingUsers.isEmpty) return;

    if (!requireUsers) {
      debugPrint(
        '⚠️ UnifiedDataService: User(s) not readable in cache: '
        '${missingUsers.join(', ')}. Proceeding (update path; RPC/RLS may block '
        'cross-role profile reads).',
      );
      return;
    }

    final buffer = StringBuffer('Reference validation failed:');
    buffer.write(' missing users: ${missingUsers.join(', ')};');
    if (missingAssets.isNotEmpty) {
      buffer.write(' missing assets: ${missingAssets.join(', ')} (optional);');
    }
    throw Exception(buffer.toString());
  }

  /// Populate cross-references between entities
  void _populateReferences() {
    debugPrint('🔗 UnifiedDataService: Populating cross-references...');

    // Populate asset references in work orders
    for (var i = 0; i < _workOrders.length; i++) {
      final workOrder = _workOrders[i];
      if (workOrder.asset == null && (workOrder.assetId?.isNotEmpty ?? false)) {
        final asset = _assets.firstWhere(
          (a) => a.id == workOrder.assetId,
          orElse: () => Asset(
            id: workOrder.assetId!,
            name: 'Unknown Asset',
            location: '',
            status: 'unknown',
            category: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        _workOrders[i] = workOrder.copyWith(asset: asset);
      }

      // Populate technician references
      if (workOrder.assignedTechnicianIds.isNotEmpty) {
        final technicians = <User>[];
        for (final techId in workOrder.assignedTechnicianIds) {
          try {
            final technician = _users.firstWhere(
              (u) => u.id == techId,
            );
            technicians.add(technician);
          } catch (e, st) {
            debugPrint('⚠️ Technician $techId not found for work order ${workOrder.id}');
          }
        }
        if (technicians.isNotEmpty) {
          _workOrders[i] =
              _workOrders[i].copyWith(assignedTechnicians: technicians);
        }
      }

      // Populate requestor references
      if (workOrder.requestor == null && workOrder.requestorId.isNotEmpty) {
        try {
          final requestor = _users.firstWhere(
            (u) => u.id == workOrder.requestorId,
          );
          _workOrders[i] = _workOrders[i].copyWith(requestor: requestor);
        } catch (e, st) {
          // User not found - leave as null instead of creating fake user
          debugPrint(
            '⚠️ Requestor ${workOrder.requestorId} not found for work order ${workOrder.id}',
          );
        }
      }
    }

    // Populate asset references in PM tasks
    for (var i = 0; i < _pmTasks.length; i++) {
      final pmTask = _pmTasks[i];
      if (pmTask.assetId.isNotEmpty) {
        final asset = _assets.firstWhere(
          (a) => a.id == pmTask.assetId,
          orElse: () => Asset(
            id: pmTask.assetId,
            name: 'Unknown Asset',
            location: '',
            status: 'unknown',
            category: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        // Update the PM task with asset name and location
        _pmTasks[i] = pmTask.copyWith(
          assetName: asset.name,
          assetLocation: asset.location,
        );
      }

      // Populate technician references (assignedTechnicians collection)
      if (pmTask.assignedTechnicianIds.isNotEmpty) {
        final technicians = <User>[];
        for (final techId in pmTask.assignedTechnicianIds) {
          try {
            final technician = _users.firstWhere(
              (u) => u.id == techId,
            );
            technicians.add(technician);
          } catch (e, st) {
            debugPrint(
              '⚠️ Technician $techId not found for PM task ${pmTask.id}',
            );
          }
        }
        if (technicians.isNotEmpty) {
          _pmTasks[i] = _pmTasks[i].copyWith(
            assignedTechnicians: technicians,
          );
        }
      }
    }

    debugPrint('✅ UnifiedDataService: Cross-references populated');
  }

  /// Refresh all data
  Future<void> refreshAll() async {
    debugPrint('🔄 UnifiedDataService: Refreshing all data...');
    await initialize(force: true);
  }

  // ============================================================================
  // FILTERED QUERIES (Server-first with local fallback)
  // ============================================================================
  Future<List<WorkOrder>> queryWorkOrders({
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? assignedTechnicianId,
    String? assetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Query directly from Supabase
    return await CmmsRepositories.workOrders.queryWorkOrders(
      status: status,
      priority: priority,
      assignedTechnicianId: assignedTechnicianId,
      assetId: assetId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<PMTask>> queryPMTasks({
    PMTaskStatus? status,
    String? assignedTechnicianId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDueStart,
    DateTime? nextDueEnd,
  }) async {
    // Query directly from Supabase
    return await CmmsRepositories.workOrders.queryPMTasks(
      status: status,
      assignedTechnicianId: assignedTechnicianId,
      startDate: startDate,
      endDate: endDate,
      nextDueStart: nextDueStart,
      nextDueEnd: nextDueEnd,
    );
  }

  /// Get work orders by technician
  List<WorkOrder> getWorkOrdersByTechnician(String technicianId) =>
      workOrdersAssignedToTechnician(_workOrders, technicianId);

  /// Get PM tasks by technician
  List<PMTask> getPMTasksByTechnician(String technicianId) => _pmTasks
      .where((task) => task.assignedTechnicianIds.contains(technicianId))
      .toList();

  /// Get technicians only
  List<User> getTechnicians() =>
      _users.where((user) => user.role == 'technician').toList();

  /// Create work order and update cache (DUAL-WRITE: Local + Supabase)
  Future<String> createWorkOrder(WorkOrder workOrder) async {
    try {
      final woWithId = await _prepareWorkOrderForCreate(workOrder);
      final localPhotoPaths = collectLocalPhotoPaths(
        photoPaths: woWithId.photoPaths,
        photoPath: woWithId.photoPath,
      );

      await createWorkOrderOnlineOrQueue(
        workOrder: woWithId,
        localPhotoPaths: localPhotoPaths.isNotEmpty ? localPhotoPaths : null,
        applyOptimisticCache: upsertWorkOrderInCache,
        onlineCreate: _createWorkOrderOnline,
      );

      return woWithId.id;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error creating work order: $e');
      rethrow;
    }
  }

  Future<WorkOrder> _prepareWorkOrderForCreate(WorkOrder workOrder) async {
    final userRefs = <String>{};
    if (workOrder.requestorId.isNotEmpty) {
      userRefs.add(workOrder.requestorId);
    }
    userRefs.addAll(workOrder.assignedTechnicianIds);
    if ((workOrder.primaryTechnicianId ?? '').isNotEmpty) {
      userRefs.add(workOrder.primaryTechnicianId!);
    }
    final assetRefs = <String>{};
    final assetId = workOrder.assetId;
    if (assetId != null && assetId.isNotEmpty) {
      assetRefs.add(assetId);
    }
    await validateReferences(
      userIds: userRefs,
      assetIds: assetRefs,
    );

    String generatedId;
    if (workOrder.ticketNumber.isNotEmpty &&
        RegExp(r'^WO-\d{4}-\d{5}$').hasMatch(workOrder.ticketNumber)) {
      generatedId = workOrder.ticketNumber;
    } else {
      generatedId = DeterministicIdGenerator.generateWorkOrderId(
        idempotencyKey: workOrder.idempotencyKey,
        ticketNumber: workOrder.ticketNumber,
        requestorId: workOrder.requestorId,
        createdAt: workOrder.createdAt,
      );
      if (!RegExp(r'^WO-\d{4}-\d{5}$').hasMatch(workOrder.ticketNumber)) {
        workOrder = workOrder.copyWith(ticketNumber: generatedId);
      }
    }
    final id = workOrder.id.isNotEmpty ? workOrder.id : generatedId;
    return workOrder.id == id ? workOrder : workOrder.copyWith(id: id);
  }

  Future<WorkOrder> _createWorkOrderOnline(WorkOrder workOrder) async {
    await CmmsRepositories.workOrders.createWorkOrder(workOrder);
    upsertWorkOrderInCache(workOrder);
    debugPrint(
      '✅ UnifiedDataService: Created work order ${workOrder.ticketNumber} in Supabase',
    );
    return workOrder;
  }

  /// Update work order and update cache (DUAL-WRITE: Local + Supabase)
  /// Populate references for a single work order
  WorkOrder _populateWorkOrderReferences(WorkOrder workOrder) {
    var updatedWorkOrder = workOrder;

    // Populate asset reference
    if (updatedWorkOrder.asset == null &&
        (updatedWorkOrder.assetId?.isNotEmpty ?? false)) {
      try {
        final asset = _assets.firstWhere(
          (a) => a.id == updatedWorkOrder.assetId,
        );
        updatedWorkOrder = updatedWorkOrder.copyWith(asset: asset);
      } catch (e, st) {
        debugPrint('⚠️ Asset ${updatedWorkOrder.assetId} not found');
      }
    }

    // Populate assigned technician references
    if (updatedWorkOrder.assignedTechnicianIds.isNotEmpty) {
      final technicians = <User>[];
      for (final techId in updatedWorkOrder.assignedTechnicianIds) {
        try {
          final technician = _users.firstWhere(
            (u) => u.id == techId,
          );
          technicians.add(technician);
        } catch (e, st) {
          debugPrint('⚠️ Technician $techId not found for WO ${updatedWorkOrder.id}');
        }
      }
      if (technicians.isNotEmpty) {
        updatedWorkOrder =
            updatedWorkOrder.copyWith(assignedTechnicians: technicians);
      }
    }

    // Populate requestor reference
    if (updatedWorkOrder.requestor == null &&
        updatedWorkOrder.requestorId.isNotEmpty) {
      try {
        final requestor = _users.firstWhere(
          (u) => u.id == updatedWorkOrder.requestorId,
        );
        updatedWorkOrder = updatedWorkOrder.copyWith(requestor: requestor);
      } catch (e, st) {
        debugPrint('⚠️ Requestor ${updatedWorkOrder.requestorId} not found');
      }
    }

    return updatedWorkOrder;
  }

  PMTask _populatePMTaskReferences(PMTask pmTask) {
    var updatedPMTask = pmTask;

    // Populate asset reference
    if (updatedPMTask.asset == null &&
        updatedPMTask.assetId.isNotEmpty) {
      try {
        final asset = _assets.firstWhere(
          (a) => a.id == updatedPMTask.assetId,
        );
        updatedPMTask = updatedPMTask.copyWith(asset: asset);
      } catch (e, st) {
        debugPrint('⚠️ Asset ${updatedPMTask.assetId} not found for PM task ${updatedPMTask.id}');
      }
    }

    // Populate assigned technician references
    if (updatedPMTask.assignedTechnicianIds.isNotEmpty) {
      final technicians = <User>[];
      for (final techId in updatedPMTask.assignedTechnicianIds) {
        try {
          final technician = _users.firstWhere(
            (u) => u.id == techId,
          );
          technicians.add(technician);
        } catch (e, st) {
          debugPrint('⚠️ Technician $techId not found for PM task ${updatedPMTask.id}');
        }
      }
      if (technicians.isNotEmpty) {
        updatedPMTask =
            updatedPMTask.copyWith(assignedTechnicians: technicians);
      }
    }

    return updatedPMTask;
  }

  Future<WorkOrder> updateWorkOrder(WorkOrder workOrder) async {
    return updateWorkOrderOnlineOrQueue(
      workOrder: workOrder,
      applyOptimisticCache: upsertWorkOrderInCache,
      onlineUpdate: _updateWorkOrderOnline,
    );
  }

  /// Atomic work-order completion with optional deferred photo upload.
  Future<WorkOrder> completeWorkOrder(
    WorkOrder workOrder, {
    List<String> pendingLocalPhotoPaths = const [],
  }) async {
    return completeWorkOrderOnlineOrQueue(
      workOrder: workOrder,
      pendingLocalPhotoPaths: pendingLocalPhotoPaths,
      applyOptimisticCache: upsertWorkOrderInCache,
      onlineComplete: _updateWorkOrderOnline,
    );
  }

  Future<WorkOrder> _updateWorkOrderOnline(WorkOrder workOrder) async {
    try {
      final userRefs = <String>{};
      if (workOrder.requestorId.isNotEmpty) {
        userRefs.add(workOrder.requestorId);
      }
      userRefs.addAll(workOrder.assignedTechnicianIds);
      if ((workOrder.primaryTechnicianId ?? '').isNotEmpty) {
        userRefs.add(workOrder.primaryTechnicianId!);
      }
      final assetRefs = <String>{};
      final assetId = workOrder.assetId;
      if (assetId != null && assetId.isNotEmpty) {
        assetRefs.add(assetId);
      }
      // Soft user check: technicians cannot load requestor profiles via
      // get_user_by_id (admin/self only). Start Work must not hard-fail on that.
      await validateReferences(
        userIds: userRefs,
        assetIds: assetRefs,
        requireUsers: false,
      );

      final updatedWorkOrder = _populateWorkOrderReferences(workOrder);

      await CmmsRepositories.workOrders
          .updateWorkOrder(updatedWorkOrder.id, updatedWorkOrder);
      final index =
          _workOrders.indexWhere((wo) => wo.id == updatedWorkOrder.id);
      if (index != -1) {
        _workOrders[index] = updatedWorkOrder;
      } else {
        _workOrders.add(updatedWorkOrder);
      }
      debugPrint(
        '✅ UnifiedDataService: Updated work order ${updatedWorkOrder.ticketNumber} in Supabase',
      );

      return updatedWorkOrder;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error updating work order: $e');
      rethrow;
    }
  }

  /// Delete work order from Supabase
  Future<void> deleteWorkOrder(String workOrderId) async {
    try {
      // Delete from Supabase
      await CmmsRepositories.workOrders.deleteWorkOrder(workOrderId);
      _workOrders.removeWhere((wo) => wo.id == workOrderId);
      debugPrint('✅ UnifiedDataService: Deleted work order $workOrderId from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error deleting work order: $e');
      rethrow;
    }
  }

  /// Create asset and update cache (DUAL-WRITE: Local + Supabase)
  Future<String> createAsset(Asset asset) async {
    try {
      // 1. Ensure stable ID
      final assetId = asset.id.isNotEmpty ? asset.id : const Uuid().v4();
      final assetWithId =
          asset.id == assetId ? asset : asset.copyWith(id: assetId);

      // Write directly to Supabase
      await CmmsRepositories.assets.createAsset(assetWithId);
      _assets.add(assetWithId);
      debugPrint('✅ UnifiedDataService: Created asset ${asset.name} in Supabase');

      return assetId;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error creating asset: $e');
      rethrow;
    }
  }

  /// Update asset in Supabase and refresh local cache
  Future<void> updateAsset(String assetId, Asset asset) async {
    try {
      await CmmsRepositories.assets.updateAsset(assetId, asset);
      final idx = _assets.indexWhere((a) => a.id == assetId);
      if (idx != -1) {
        _assets[idx] = asset;
      }
      debugPrint('OK UnifiedDataService: Updated asset  in Supabase');
    } catch (e, st) {
      debugPrint('ERR UnifiedDataService: Error updating asset: ');
      rethrow;
    }
  }

  /// Delete asset from Supabase
  Future<void> deleteAsset(String assetId) async {
    try {
      // Delete from Supabase
      await CmmsRepositories.assets.deleteAsset(assetId);
      _assets.removeWhere((asset) => asset.id == assetId);
      debugPrint('✅ UnifiedDataService: Deleted asset $assetId from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error deleting asset: $e');
      rethrow;
    }
  }

  /// Create user and update cache
  Future<String> createUser(User user) async {
    try {
      // Create in Supabase
      final userId = await CmmsRepositories.users.createUser(user);
      _users.add(user.copyWith(id: userId));
      debugPrint('✅ UnifiedDataService: Created user ${user.name} in Supabase');

      return userId;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error creating user: $e');
      rethrow;
    }
  }

  /// Delete user and update cache
  /// Deletes from Supabase
  Future<void> deleteUser(String userId) async {
    try {
      // Remove from cache first
      _users.removeWhere((u) => u.id == userId);
      
      // Delete from Supabase
      await CmmsRepositories.users.deleteUser(userId);
      debugPrint('✅ UnifiedDataService: Deleted user $userId from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error deleting user: $e');
      rethrow;
    }
  }

  /// Update user and update cache
  Future<void> updateUser(User user) async {
    try {
      await CmmsRepositories.users.updateUser(user.id, user);
      final index = _users.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _users[index] = user;
      }
      debugPrint('✅ UnifiedDataService: Updated user ${user.name} in Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error updating user: $e');
      rethrow;
    }
  }

  /// Assign technician to work order (adds to existing list)
  Future<void> assignTechnicianToWorkOrder(
    String workOrderId,
    String technicianId,
  ) async {
    try {
      final workOrder = await _loadWorkOrder(workOrderId);
      final updatedIds = <String>[
        ...workOrder.assignedTechnicianIds.where((id) => id != technicianId),
        technicianId,
      ];
      await updateWorkOrderTechnicianAssignments(workOrderId, updatedIds);
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error assigning technician: $e');
      rethrow;
    }
  }

  /// Replace the technician roster for a work order
  Future<void> updateWorkOrderTechnicianAssignments(
    String workOrderId,
    List<String> technicianIds,
  ) async {
    try {
      final workOrder = await _loadWorkOrder(workOrderId);
      final uniqueIds = <String>[];
      final seen = <String>{};
      for (final id in technicianIds) {
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        uniqueIds.add(id);
      }

      if (uniqueIds.isNotEmpty) {
        await validateReferences(userIds: uniqueIds.toSet());
      }

      final assignedUsers = _users
          .where((user) => uniqueIds.contains(user.id))
          .toList(growable: false);

      final effortMinutes =
          Map<String, int>.from(workOrder.technicianEffortMinutes ?? {});
      effortMinutes.removeWhere((key, _) => !uniqueIds.contains(key));
      for (final id in uniqueIds) {
        effortMinutes.putIfAbsent(id, () => 0);
      }

      var newStatus = workOrder.status;
      if (uniqueIds.isEmpty) {
        if (workOrder.status == WorkOrderStatus.assigned) {
          newStatus = WorkOrderStatus.open;
        }
      } else if (workOrder.status == WorkOrderStatus.open) {
        newStatus = WorkOrderStatus.assigned;
      }

      final updatedWorkOrder = workOrder.copyWith(
        primaryTechnicianId: uniqueIds.isNotEmpty ? uniqueIds.first : null,
        assignedTechnicianIds: uniqueIds,
        assignedTechnicians: assignedUsers,
        technicianEffortMinutes:
            effortMinutes.isEmpty ? null : Map<String, int>.from(effortMinutes),
        assignedAt:
            uniqueIds.isNotEmpty ? (workOrder.assignedAt ?? DateTime.now()) : null,
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      await updateWorkOrder(updatedWorkOrder);
      debugPrint(
        '✅ UnifiedDataService: Updated technician roster (${uniqueIds.length}) for work order $workOrderId',
      );
    } catch (e, st) {
      debugPrint(
        '❌ UnifiedDataService: Error updating work order technicians: $e',
      );
      rethrow;
    }
  }

  /// Unassign technician from work order
  Future<void> unassignTechnicianFromWorkOrder(
    String workOrderId, {
    String? technicianId,
  }) async {
    try {
      final workOrder = await _loadWorkOrder(workOrderId);
      final updatedIds = technicianId == null
          ? <String>[]
          : workOrder.assignedTechnicianIds
              .where((id) => id != technicianId)
              .toList();
      await updateWorkOrderTechnicianAssignments(workOrderId, updatedIds);
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error unassigning technician: $e');
      rethrow;
    }
  }

  /// Assign technician to PM task
  Future<void> assignTechnicianToPMTask(
    String pmTaskId,
    String technicianId,
  ) async {
    try {
      final pmTask = _pmTasks.firstWhere((pm) => pm.id == pmTaskId);
      final updatedIds = <String>[
        ...pmTask.assignedTechnicianIds.where((id) => id != technicianId),
        technicianId,
      ];
      await updatePMTaskTechnicianAssignments(pmTaskId, updatedIds);
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error assigning technician to PM task: $e');
      rethrow;
    }
  }

  Future<void> updatePMTaskTechnicianAssignments(
    String pmTaskId,
    List<String> technicianIds,
  ) async {
    try {
      final pmTask = _pmTasks.firstWhere((pm) => pm.id == pmTaskId);
      final uniqueIds = <String>[];
      final seen = <String>{};
      for (final id in technicianIds) {
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        uniqueIds.add(id);
      }

      if (uniqueIds.isNotEmpty) {
        await validateReferences(userIds: uniqueIds.toSet());
      }

      final assignedUsers = _users
          .where((user) => uniqueIds.contains(user.id))
          .toList(growable: false);

      final effortMinutes =
          Map<String, int>.from(pmTask.technicianEffortMinutes ?? {});
      effortMinutes.removeWhere((key, _) => !uniqueIds.contains(key));
      for (final id in uniqueIds) {
        effortMinutes.putIfAbsent(id, () => 0);
      }

      var newStatus = pmTask.status;
      if (uniqueIds.isEmpty) {
        if (pmTask.status == PMTaskStatus.inProgress) {
          newStatus = PMTaskStatus.pending;
        }
      } else if (pmTask.status == PMTaskStatus.pending) {
        newStatus = PMTaskStatus.inProgress;
      }

      final updatedPMTask = pmTask.copyWith(
        primaryTechnicianId: uniqueIds.isNotEmpty ? uniqueIds.first : null,
        assignedTechnicianIds: uniqueIds,
        assignedTechnicians: assignedUsers,
        technicianEffortMinutes:
            effortMinutes.isEmpty ? null : Map<String, int>.from(effortMinutes),
        status: newStatus,
        startedAt: uniqueIds.isNotEmpty
            ? (pmTask.startedAt ?? DateTime.now())
            : null,
      );

      await updatePMTask(updatedPMTask);
      debugPrint(
        '✅ UnifiedDataService: Updated technician roster (${uniqueIds.length}) for PM task $pmTaskId',
      );
    } catch (e, st) {
      debugPrint(
        '❌ UnifiedDataService: Error updating PM task technicians: $e',
      );
      rethrow;
    }
  }

  /// Unassign technician from PM task
  Future<void> unassignTechnicianFromPMTask(
    String pmTaskId, {
    String? technicianId,
  }) async {
    try {
      final pmTask = _pmTasks.firstWhere((pm) => pm.id == pmTaskId);
      final updatedIds = technicianId == null
          ? <String>[]
          : pmTask.assignedTechnicianIds
              .where((id) => id != technicianId)
              .toList();
      await updatePMTaskTechnicianAssignments(pmTaskId, updatedIds);
    } catch (e, st) {
      debugPrint(
        '❌ UnifiedDataService: Error unassigning technician from PM task: $e',
      );
      rethrow;
    }
  }

  /// Create PM task
  Future<PMTask> createPMTask({
    required String taskName,
    required String description,
    required String checklistJson,
    required PMTaskFrequency frequency,
    required DateTime nextDue,
    String assetId = '', // Optional - can be empty for general PM tasks
    Asset? asset, // Pass full asset object if available
    List<String>? assignedTechnicianIds,
    String? createdById, // Track who created this PM task
  }) async {
    try {
      // Get the asset to populate name and location
      // Use passed asset if available, otherwise look it up
      final assignedIds = (assignedTechnicianIds ?? <String>[])
          .where((id) => id.isNotEmpty)
          .toList();
      
      // Only validate asset reference if assetId is provided
      final assetRefs = assetId.isNotEmpty ? {assetId} : <String>{};
      await validateReferences(
        userIds: assignedIds.toSet(),
        assetIds: assetRefs,
      );

      // Only look up asset if assetId is provided
      if (assetId.isNotEmpty && asset == null) {
        asset = _assets.firstWhere(
          (a) => a.id == assetId,
          orElse: () => Asset(
            id: assetId,
            name: 'Unknown Asset',
            location: '',
            status: 'unknown',
            category: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      List<User>? assignedTechnicians;
      if (assignedIds.isNotEmpty) {
        assignedTechnicians = _users
            .where((user) => assignedIds.contains(user.id))
            .toList();
      }

      // Generate PM task ID - use assetId if provided, otherwise use 'GENERAL'
      final assetPrefix = assetId.isNotEmpty ? assetId : 'GENERAL';
      final pmIdBase =
          'PM-${assetPrefix}-${taskName}-${DateTime.now().millisecondsSinceEpoch}';
      final pmDocId =
          DeterministicIdGenerator.normalizeDocumentId(pmIdBase.toUpperCase());

      // Debug: Print checklist JSON to verify it's being passed
      debugPrint('📋 UnifiedDataService: Creating PM task with checklist: $checklistJson');
      
      final pmTask = PMTask(
        id: pmDocId.isNotEmpty ? pmDocId : const Uuid().v4(),
        taskName: taskName,
        assetId: assetId,
        assetName: asset?.name, // Populate asset name if asset exists
        assetLocation: asset?.location, // Populate asset location if asset exists
        description: description,
        checklist: checklistJson,
        frequency: frequency,
        intervalDays: _getIntervalDays(frequency),
        nextDueDate: nextDue,
        primaryTechnicianId: assignedIds.isNotEmpty ? assignedIds.first : null,
        assignedTechnicianIds: assignedIds,
        assignedTechnicians: assignedTechnicians,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdById: createdById, // Store who created this PM task
      );
      
      // Debug: Verify checklist was set on PMTask
      debugPrint('📋 UnifiedDataService: PMTask checklist after creation: ${pmTask.checklist}');

      return createPMTaskOnlineOrQueue(
        pmTask: pmTask,
        applyOptimisticCache: (task) {
          final populated = _populatePMTaskReferences(task);
          final index = _pmTasks.indexWhere((pt) => pt.id == populated.id);
          if (index != -1) {
            _pmTasks[index] = populated;
          } else {
            _pmTasks.add(populated);
          }
        },
        onlineCreate: _createPMTaskOnline,
      );
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error creating PM task: $e');
      rethrow;
    }
  }

  Future<PMTask> _createPMTaskOnline(PMTask pmTask) async {
    await CmmsRepositories.workOrders.createPMTask(pmTask);
    final populated = _populatePMTaskReferences(pmTask);
    final index = _pmTasks.indexWhere((pt) => pt.id == populated.id);
    if (index != -1) {
      _pmTasks[index] = populated;
    } else {
      _pmTasks.add(populated);
    }
    final primaryAssigned = pmTask.assignedTechnicians?.isNotEmpty ?? false
        ? pmTask.assignedTechnicians!.first.name
        : null;
    debugPrint(
      primaryAssigned != null
          ? '✅ UnifiedDataService: Created PM task ${pmTask.taskName} assigned to $primaryAssigned in Supabase'
          : '✅ UnifiedDataService: Created PM task ${pmTask.taskName} (unassigned) in Supabase',
    );
    return populated;
  }

  /// Update PM task (DUAL-WRITE: Local + Supabase)
  Future<PMTask> updatePMTask(PMTask pmTask) async {
    return updatePMTaskOnlineOrQueue(
      pmTask: pmTask,
      applyOptimisticCache: (task) {
        final populated = _populatePMTaskReferences(task);
        final index = _pmTasks.indexWhere((pt) => pt.id == populated.id);
        if (index != -1) {
          _pmTasks[index] = populated;
        } else {
          _pmTasks.add(populated);
        }
      },
      onlineUpdate: _updatePMTaskOnline,
    );
  }

  Future<PMTask> _updatePMTaskOnline(PMTask pmTask) async {
    try {
      final populatedPMTask = _populatePMTaskReferences(pmTask);

      await CmmsRepositories.workOrders
          .updatePMTask(populatedPMTask.id, populatedPMTask);
      final index = _pmTasks.indexWhere((pt) => pt.id == populatedPMTask.id);
      if (index != -1) {
        _pmTasks[index] = populatedPMTask;
      } else {
        _pmTasks.add(populatedPMTask);
      }
      debugPrint(
        '✅ UnifiedDataService: Updated PM task ${populatedPMTask.taskName} in Supabase',
      );

      return populatedPMTask;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error updating PM task: $e');
      rethrow;
    }
  }

  /// Delete PM task from Supabase
  Future<void> deletePMTask(String pmTaskId) async {
    try {
      // Delete from Supabase
      await CmmsRepositories.workOrders.deletePMTask(pmTaskId);
      _pmTasks.removeWhere((pt) => pt.id == pmTaskId);
      debugPrint('✅ UnifiedDataService: Deleted PM task $pmTaskId from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error deleting PM task: $e');
      rethrow;
    }
  }

  /// Helper method to get interval days based on frequency
  int _getIntervalDays(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return 1;
      case PMTaskFrequency.weekly:
        return 7;
      case PMTaskFrequency.monthly:
        return 30;
      case PMTaskFrequency.quarterly:
        return 90;
      case PMTaskFrequency.semiAnnually:
        return 180;
      case PMTaskFrequency.annually:
        return 365;
      case PMTaskFrequency.asNeeded:
        return 0;
    }
  }

  /// Get dashboard statistics
  Map<String, dynamic> getDashboardStats() {
    final now = DateTime.now();
    // Calculate 30 days ago for filtering
    now.subtract(const Duration(days: 30));

    return {
      'totalWorkOrders': _workOrders.length,
      'openWorkOrders': _workOrders.where((wo) => wo.isOpen).length,
      'inProgressWorkOrders': _workOrders.where((wo) => wo.isInProgress).length,
      'completedWorkOrders': _workOrders.where((wo) => wo.isCompleted).length,
      'overdueWorkOrders': _workOrders.where((wo) => wo.isOverdue).length,
      'highPriorityWorkOrders':
          _workOrders.where((wo) => wo.isHighPriority).length,
      'totalPMTasks': _pmTasks.length,
      'pendingPMTasks': _pmTasks
          .where((task) => task.status.toString().contains('pending'))
          .length,
      'completedPMTasks': _pmTasks
          .where((task) => task.status.toString().contains('completed'))
          .length,
      'totalUsers': _users.length,
      'technicians': _users.where((user) => user.role == 'technician').length,
      'totalAssets': _assets.length,
      'totalInventory': _inventoryItems.length,
      'lowStockItems':
          _inventoryItems.where((item) => item.quantity <= 10).length,
      'totalWorkflows': _workflows.length,
      'pendingApprovalWorkflows':
          _workflows.where((w) => w.isPendingApproval).length,
      'approvedWorkflows': _workflows.where((w) => w.isApproved).length,
      'completedWorkflows': _workflows.where((w) => w.isCompleted).length,
      'overdueWorkflows': _workflows.where((w) => w.isOverdue).length,
    };
  }

  /// Get technician-specific dashboard data
  Map<String, dynamic> getTechnicianDashboardData(String technicianId) {
    final technicianWorkOrders = getWorkOrdersByTechnician(technicianId);
    final technicianPMTasks = getPMTasksByTechnician(technicianId);

    return {
      'workOrders': technicianWorkOrders,
      'pmTasks': technicianPMTasks,
      'workOrderStats': {
        'total': technicianWorkOrders.length,
        'open': technicianWorkOrders.where((wo) => wo.isOpen).length,
        'inProgress':
            technicianWorkOrders.where((wo) => wo.isInProgress).length,
        'completed': technicianWorkOrders.where((wo) => wo.isCompleted).length,
        'overdue': technicianWorkOrders.where((wo) => wo.isOverdue).length,
      },
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

  /// Pause a work order with reason (DUAL-WRITE: Local + Supabase)
  Future<WorkOrder> pauseWorkOrder(String workOrderId, String reason) async {
    try {
      final workOrder = _workOrders.firstWhere((wo) => wo.id == workOrderId);
      final updatedWorkOrder = workOrder.copyWith(
        isPaused: true,
        pausedAt: DateTime.now(),
        pauseReason: reason,
        pauseHistory: [
          ...(workOrder.pauseHistory ?? []),
          {
            'pausedAt': DateTime.now().toIso8601String(),
            'reason': reason,
          },
        ],
        updatedAt: DateTime.now(),
      );

      final result = await updateWorkOrder(updatedWorkOrder);
      debugPrint(
        '⏸️ UnifiedDataService: Paused work order ${workOrder.ticketNumber} with reason: $reason',
      );

      return result;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error pausing work order: $e');
      rethrow;
    }
  }

  /// Resume a paused work order (DUAL-WRITE: Local + Supabase)
  Future<WorkOrder> resumeWorkOrder(String workOrderId) async {
    try {
      final workOrder = _workOrders.firstWhere((wo) => wo.id == workOrderId);
      final updatedWorkOrder = workOrder.copyWith(
        isPaused: false,
        resumedAt: DateTime.now(),
        pauseHistory: [
          ...(workOrder.pauseHistory ?? []),
          {
            'resumedAt': DateTime.now().toIso8601String(),
          },
        ],
        updatedAt: DateTime.now(),
      );

      final result = await updateWorkOrder(updatedWorkOrder);
      debugPrint(
        '▶️ UnifiedDataService: Resumed work order ${workOrder.ticketNumber}',
      );

      return result;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error resuming work order: $e');
      rethrow;
    }
  }

  /// Pause a PM task with reason (DUAL-WRITE: Local + Supabase)
  Future<PMTask> pausePMTask(String pmTaskId, String reason) async {
    try {
      final pmTask = _pmTasks.firstWhere((pt) => pt.id == pmTaskId);
      final updatedPMTask = pmTask.copyWith(
        isPaused: true,
        pausedAt: DateTime.now(),
        pauseReason: reason,
        pauseHistory: [
          ...(pmTask.pauseHistory ?? []),
          {
            'pausedAt': DateTime.now().toIso8601String(),
            'reason': reason,
          },
        ],
        updatedAt: DateTime.now(),
      );

      final result = await updatePMTask(updatedPMTask);
      debugPrint(
        '⏸️ UnifiedDataService: Paused PM task ${pmTask.taskName} with reason: $reason',
      );

      return result;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error pausing PM task: $e');
      rethrow;
    }
  }

  /// Resume a paused PM task (DUAL-WRITE: Local + Supabase)
  Future<PMTask> resumePMTask(String pmTaskId) async {
    try {
      final pmTask = _pmTasks.firstWhere((pt) => pt.id == pmTaskId);
      final updatedPMTask = pmTask.copyWith(
        isPaused: false,
        resumedAt: DateTime.now(),
        pauseHistory: [
          ...(pmTask.pauseHistory ?? []),
          {
            'resumedAt': DateTime.now().toIso8601String(),
          },
        ],
        updatedAt: DateTime.now(),
      );

      final result = await updatePMTask(updatedPMTask);
      debugPrint(
        '▶️ UnifiedDataService: Resumed PM task ${pmTask.taskName}',
      );

      return result;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error resuming PM task: $e');
      rethrow;
    }
  }

  // ============================================================================
  // WORKFLOW OPERATIONS (DUAL-WRITE: Local + Supabase)
  // ============================================================================

  /// Load workflows from database
  Future<void> _loadWorkflows() async {
    _isWorkflowsLoading = true;
    try {
      _workflows = await CmmsRepositories.workflows.getAllWorkflows();
      debugPrint('📋 UnifiedDataService: Loaded ${_workflows.length} workflows from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error loading workflows: $e');
      _workflows = []; // Initialize empty list on error
    } finally {
      _isWorkflowsLoading = false;
    }
  }

  /// Create workflow in Supabase
  Future<String> createWorkflow(Workflow workflow) async {
    try {
      // Create directly in Supabase
      final workflowId = await CmmsRepositories.workflows.createWorkflow(workflow);
      _workflows.add(workflow);
      debugPrint('✅ UnifiedDataService: Created workflow ${workflow.title} in Supabase');

      return workflowId;
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error creating workflow: $e');
      rethrow;
    }
  }

  /// Update workflow (DUAL-WRITE: Local + Supabase)
  Future<void> updateWorkflow(Workflow workflow) async {
    try {
      // Update Supabase directly
      await CmmsRepositories.workflows
          .updateWorkflow(workflow.id, workflow);
      final index = _workflows.indexWhere((w) => w.id == workflow.id);
      if (index != -1) {
        _workflows[index] = workflow;
      }
      debugPrint('✅ UnifiedDataService: Updated workflow ${workflow.title} in Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error updating workflow: $e');
      rethrow;
    }
  }

  /// Delete workflow (DUAL-WRITE: Local + Supabase)
  Future<void> deleteWorkflow(String workflowId) async {
    try {
      // Delete from Supabase
      await CmmsRepositories.workflows.deleteWorkflow(workflowId);
      _workflows.removeWhere((w) => w.id == workflowId);
      debugPrint('✅ UnifiedDataService: Deleted workflow $workflowId from Supabase');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error deleting workflow: $e');
      rethrow;
    }
  }

  /// Get workflow by ID
  Workflow? getWorkflowById(String workflowId) {
    try {
      return _workflows.firstWhere((w) => w.id == workflowId);
    } catch (e, st) {
      return null;
    }
  }

  /// Get workflows by status
  List<Workflow> getWorkflowsByStatus(WorkflowStatus status) =>
      _workflows.where((w) => w.status == status).toList();

  /// Get workflows by type
  List<Workflow> getWorkflowsByType(WorkflowType type) =>
      _workflows.where((w) => w.type == type).toList();

  /// Get workflows created by user
  List<Workflow> getWorkflowsByCreator(String userId) =>
      _workflows.where((w) => w.createdByUserId == userId).toList();

  /// Get workflows assigned to user
  List<Workflow> getWorkflowsByAssignee(String userId) =>
      _workflows.where((w) => w.assignedToUserId == userId).toList();

  /// Get pending approvals for user
  List<Workflow> getPendingApprovalsForUser(String userId) => _workflows
      .where((w) =>
          w.status == WorkflowStatus.pendingApproval &&
          (w.approvers.contains(userId) || w.currentApprover == userId),)
      .toList();

  /// Get overdue workflows
  List<Workflow> getOverdueWorkflows() =>
      _workflows.where((w) => w.isOverdue).toList();

  /// Approve workflow (DUAL-WRITE: Local + Supabase)
  Future<void> approveWorkflow({
    required String workflowId,
    required String approverId,
    required String approverName,
    required String approverRole,
    String? comments,
  }) async {
    try {
      final workflow = _workflows.firstWhere((w) => w.id == workflowId);

      // Add to approval history
      final approvalHistory = List<Map<String, dynamic>>.from(
        workflow.approvalHistory,
      );
      approvalHistory.add({
        'approverId': approverId,
        'approverName': approverName,
        'approverRole': approverRole,
        'action': 'approve',
        'comments': comments,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Update workflow
      final updatedWorkflow = workflow.copyWith(
        approvalHistory: approvalHistory,
        status: WorkflowStatus.approved,
        updatedAt: DateTime.now(),
      );

      await updateWorkflow(updatedWorkflow);
      debugPrint('✅ UnifiedDataService: Approved workflow ${workflow.title}');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error approving workflow: $e');
      rethrow;
    }
  }

  /// Reject workflow (DUAL-WRITE: Local + Supabase)
  Future<void> rejectWorkflow({
    required String workflowId,
    required String rejectorId,
    required String rejectorName,
    required String rejectorRole,
    required String reason,
  }) async {
    try {
      final workflow = _workflows.firstWhere((w) => w.id == workflowId);

      // Add to approval history
      final approvalHistory = List<Map<String, dynamic>>.from(
        workflow.approvalHistory,
      );
      approvalHistory.add({
        'approverId': rejectorId,
        'approverName': rejectorName,
        'approverRole': rejectorRole,
        'action': 'reject',
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Update workflow
      final updatedWorkflow = workflow.copyWith(
        approvalHistory: approvalHistory,
        status: WorkflowStatus.rejected,
        rejectionReason: reason,
        updatedAt: DateTime.now(),
      );

      await updateWorkflow(updatedWorkflow);
      debugPrint('✅ UnifiedDataService: Rejected workflow ${workflow.title}');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error rejecting workflow: $e');
      rethrow;
    }
  }

  /// Complete workflow (DUAL-WRITE: Local + Supabase)
  Future<void> completeWorkflow({
    required String workflowId,
    required String completedBy,
    String? comments,
  }) async {
    try {
      final workflow = _workflows.firstWhere((w) => w.id == workflowId);

      // Update workflow
      final updatedWorkflow = workflow.copyWith(
        status: WorkflowStatus.completed,
        completedAt: DateTime.now(),
        completedBy: completedBy,
        updatedAt: DateTime.now(),
        actualDuration:
            workflow.createdAt.difference(DateTime.now()).inMinutes.abs(),
      );

      await updateWorkflow(updatedWorkflow);
      debugPrint('✅ UnifiedDataService: Completed workflow ${workflow.title}');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error completing workflow: $e');
      rethrow;
    }
  }

  /// Cancel workflow (DUAL-WRITE: Local + Supabase)
  Future<void> cancelWorkflow({
    required String workflowId,
    required String cancelledBy,
    required String reason,
  }) async {
    try {
      final workflow = _workflows.firstWhere((w) => w.id == workflowId);

      // Update workflow
      final updatedWorkflow = workflow.copyWith(
        status: WorkflowStatus.cancelled,
        cancellationReason: reason,
        completedAt: DateTime.now(),
        completedBy: cancelledBy,
        updatedAt: DateTime.now(),
      );

      await updateWorkflow(updatedWorkflow);
      debugPrint('✅ UnifiedDataService: Cancelled workflow ${workflow.title}');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error cancelling workflow: $e');
      rethrow;
    }
  }

  /// Escalate workflow (DUAL-WRITE: Local + Supabase)
  Future<void> escalateWorkflow({
    required String workflowId,
    required String escalatedBy,
    String? reason,
  }) async {
    try {
      final workflow = _workflows.firstWhere((w) => w.id == workflowId);

      // Update escalation path
      final escalationPath = List<String>.from(workflow.escalationPath);
      escalationPath.add(
        'Escalated by $escalatedBy at ${DateTime.now().toIso8601String()}${reason != null ? ": $reason" : ""}',
      );

      // Update workflow
      final updatedWorkflow = workflow.copyWith(
        status: WorkflowStatus.escalated,
        escalationPath: escalationPath,
        updatedAt: DateTime.now(),
      );

      await updateWorkflow(updatedWorkflow);
      debugPrint('✅ UnifiedDataService: Escalated workflow ${workflow.title}');
    } catch (e, st) {
      debugPrint('❌ UnifiedDataService: Error escalating workflow: $e');
      rethrow;
    }
  }

  /// Refresh workflows from database
  Future<void> refreshWorkflows() async {
    await _loadWorkflows();
  }
}
