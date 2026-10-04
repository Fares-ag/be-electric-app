import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config/app_config.dart';
import '../config/locator.dart';
import '../repositories/cmms_repositories.dart';
import '../services/connectivity_service.dart';
import '../services/enhanced_notification_service.dart';
import '../services/hybrid_dam_service.dart';
import '../services/parts_request_service.dart';
import '../services/realtime_analytics_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/unified_data_service.dart';
import '../utils/offline_service_access.dart';
import 'asset_provider.dart';
import 'domain/cmms_domain_provider.dart';
import 'inventory_provider.dart';
import 'pm_occurrence_provider.dart';
import 'user_provider.dart';
import 'work_order_provider.dart';
import 'workflow_provider.dart';

/// Orchestrates domain provider lifecycle (init, auth, refresh).
class CmmsDataCoordinator {
  CmmsDataCoordinator({
    required WorkOrderProvider workOrders,
    required AssetProvider assets,
    required UserProvider users,
    required InventoryProvider inventory,
    required WorkflowProvider workflows,
    PmOccurrenceProvider? pmOccurrences,
    UnifiedDataService? dataService,
    SupabaseAuthService? authService,
    ConnectivityService? connectivityService,
    Future<String?> Function()? resolveSignedInUserId,
  })  : _workOrders = workOrders,
        _assets = assets,
        _users = users,
        _inventory = inventory,
        _workflows = workflows,
        _pmOccurrences = pmOccurrences,
        _dataService = dataService ?? sl<UnifiedDataService>(),
        _connectivityService = connectivityService ?? sl<ConnectivityService>() {
    final auth = authService ?? sl<SupabaseAuthService>();
    _resolveSignedInUserId = resolveSignedInUserId ??
        () => _resolveSignedInUserIdFromAuth(auth);
  }

  final WorkOrderProvider _workOrders;
  final AssetProvider _assets;
  final UserProvider _users;
  final InventoryProvider _inventory;
  final WorkflowProvider _workflows;
  final PmOccurrenceProvider? _pmOccurrences;
  final UnifiedDataService _dataService;
  final ConnectivityService _connectivityService;
  late final Future<String?> Function() _resolveSignedInUserId;

  StreamSubscription<sb.AuthState>? _authSubscription;
  VoidCallback? _connectivityListener;
  Future<void>? _initializeInFlight;
  Future<void>? _reconnectSyncInFlight;
  bool _isDisposed = false;

  List<CmmsDomainProvider> get _domainProviders => [
        _workOrders,
        _assets,
        _users,
        _inventory,
        _workflows,
      ];

  void attach() {
    _watchAuthState();
    _watchConnectivity();
    unawaited(initialize());
  }

  /// Cancels all Supabase-backed domain stream subscriptions and the work-order
  /// realtime channel. Safe to call multiple times (e.g. sign-out and dispose).
  Future<void> cancelAllRealtimeListeners() async {
    await Future.wait([
      for (final provider in _domainProviders) provider.cancelRealtimeListeners(),
    ]);
    await _pmOccurrences?.stopRealtimeListener();
    sl<EnhancedNotificationService>().stopRealtimeListener();
    sl<PartsRequestService>().stopRealtimeListener();
    sl<RealtimeAnalyticsService>().stopListening();
  }

  void dispose() {
    _isDisposed = true;
    _initializeInFlight = null;
    _reconnectSyncInFlight = null;
    if (_connectivityListener != null) {
      _connectivityService.removeListener(_connectivityListener!);
      _connectivityListener = null;
    }
    unawaited(cancelAllRealtimeListeners());
    _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> initialize() async {
    if (_initializeInFlight != null) {
      return _initializeInFlight!;
    }

    _initializeInFlight = _runInitialize();
    try {
      await _initializeInFlight;
    } finally {
      _initializeInFlight = null;
    }
  }

  Future<void> _runInitialize() async {
    if (_isDisposed) return;

    try {
      if (_isColdStartOffline) {
        debugPrint(
          '📦 CmmsDataCoordinator: Cold start offline — hydrating surface cache',
        );
        await _dataService.refreshTechnicianSurface();
      }

      await _dataService.initialize();
      _workOrders.seedFromService();

      await Future.wait([
        _workOrders.startRealtimeListeners(),
        _assets.startRealtimeListeners(),
        _users.startRealtimeListeners(),
        _inventory.startRealtimeListeners(),
        _workflows.startRealtimeListeners(),
        if (_pmOccurrences?.isEnabled ?? false) _initializePmOccurrences(),
      ]);

      await _startSharedRealtimeListeners();

      _workOrders.repopulateReferences();
      debugPrint('✅ CmmsDataCoordinator: Domain providers initialized');

      if (sl<ConnectivityService>().isOnline) {
        unawaited(sl<HybridDamService>().prefetch());
      }

      await _drainOfflineQueueOnColdStartIfNeeded();
    } catch (e, st) {
      debugPrint('CmmsDataCoordinator: Error initializing: $e');
    }
  }

  /// If the app was killed offline and relaunched online, drain pending ops.
  Future<void> _drainOfflineQueueOnColdStartIfNeeded() async {
    if (_isDisposed || !AppConfig.isOfflineModeEnabled) return;
    if (!_connectivityService.isOnline) return;

    final queue = resolveOfflineQueueService();
    if (!queue.isInitialized) {
      await queue.initialize();
    }
    if (queue.pendingCount == 0) return;

    debugPrint(
      '📦 CmmsDataCoordinator: Cold start online — draining '
      '${queue.pendingCount} queued operation(s)',
    );
    await _onReconnectSync();
  }

  /// Notifications + parts_requests channels (Admin ↔ Technician field loop).
  Future<void> _startSharedRealtimeListeners() async {
    final userId = await _resolveSignedInUserId();
    if (userId == null || userId.isEmpty) return;

    sl<EnhancedNotificationService>().startRealtimeListener(userId);
    sl<PartsRequestService>().startRealtimeListener();
  }

  Future<void> refreshAll() async {
    try {
      _workOrders.resetPagination();
      await _dataService.refreshAll();
      _workOrders.seedFromService();
      _workOrders.repopulateReferences();
      _inventory.syncFromRealtime();
    } catch (e, st) {
      debugPrint('CmmsDataCoordinator: Error refreshing: $e');
    }
  }

  void _watchAuthState() {
    try {
      _authSubscription = sb.Supabase.instance.client.auth.onAuthStateChange
          .listen((event) {
        switch (event.event) {
          case sb.AuthChangeEvent.signedIn:
            unawaited(initialize());
            break;
          case sb.AuthChangeEvent.signedOut:
          case sb.AuthChangeEvent.userDeleted:
            unawaited(_handleSignedOut());
            break;
          case sb.AuthChangeEvent.tokenRefreshed:
          case sb.AuthChangeEvent.userUpdated:
            break;
          default:
            break;
        }
      });
    } catch (e, st) {
      debugPrint('⚠️ CmmsDataCoordinator: auth listener setup failed: $e');
    }
  }

  Future<void> _handleSignedOut() async {
    await purgeUserSession();
  }

  /// Purges user-scoped caches, cancels realtime listeners, and resets UDS.
  Future<void> purgeUserSession() async {
    _initializeInFlight = null;
    _reconnectSyncInFlight = null;
    await cancelAllRealtimeListeners();
    for (final provider in _domainProviders) {
      provider.clearCache();
    }
    _pmOccurrences?.clearCache();
    _workOrders.resetPagination();
    _dataService.purgeUserSession();
  }

  bool get _isColdStartOffline =>
      !kIsWeb &&
      AppConfig.isOfflineModeEnabled &&
      !_connectivityService.isOnline;

  void _watchConnectivity() {
    var wasOnline = _connectivityService.isOnline;
    _connectivityListener = () {
      if (_isDisposed) return;
      final isOnline = _connectivityService.isOnline;
      if (!wasOnline && isOnline && AppConfig.isOfflineModeEnabled) {
        unawaited(_onReconnectSync());
      }
      wasOnline = isOnline;
    };
    _connectivityService.addListener(_connectivityListener!);
  }

  Future<void> _onReconnectSync() async {
    if (_reconnectSyncInFlight != null) {
      return _reconnectSyncInFlight;
    }

    _reconnectSyncInFlight = _runReconnectSync();
    try {
      await _reconnectSyncInFlight;
    } finally {
      _reconnectSyncInFlight = null;
    }
  }

  Future<void> _runReconnectSync() async {
    if (_isDisposed) return;

    try {
      debugPrint(
        '🔄 CmmsDataCoordinator: Reconnect — processQueue then refreshTechnicianSurface',
      );
      await resolveOfflineQueueService().processQueue();
      if (_isDisposed) return;

      await _dataService.refreshTechnicianSurface();
      if (_isDisposed) return;

      _workOrders.seedFromService();
      _workOrders.repopulateReferences();
      debugPrint('✅ CmmsDataCoordinator: Reconnect sync complete');
    } catch (e, st) {
      debugPrint('CmmsDataCoordinator: Reconnect sync failed: $e');
    }
  }

  Future<void> _initializePmOccurrences() async {
    final provider = _pmOccurrences;
    if (provider == null || !provider.isEnabled) {
      return;
    }

    try {
      final userId = await _resolveSignedInUserId();
      if (userId == null || userId.isEmpty) {
        return;
      }

      var user = _users.getUserById(userId);
      if (user == null) {
        try {
          user = await CmmsRepositories.users.getUserById(userId);
        } catch (_) {
          user = null;
        }
      }
      if (user?.role == 'requestor') {
        await provider.loadCompanyOccurrences(user!.companyId);
        await provider.startRealtimeListener(
          userId: userId,
          companyId: user.companyId,
          isRequestor: true,
        );
        return;
      }

      await provider.loadAssignedOccurrences(userId);
      await provider.startRealtimeListener(
        userId: userId,
        isRequestor: false,
      );
    } on Exception catch (e) {
      debugPrint('CmmsDataCoordinator: PM occurrence load failed: $e');
    }
  }

  /// Loads PM occurrences through the coordinator path (tests / isolated startup).
  @visibleForTesting
  Future<void> initializePmOccurrencesForTesting() => _initializePmOccurrences();

  static Future<String?> _resolveSignedInUserIdFromAuth(
    SupabaseAuthService authService,
  ) async {
    if (!authService.isSignedIn) {
      return null;
    }
    final appUser = await authService.getCurrentAppUser();
    return appUser?.id;
  }

  /// Test hook for sign-out lifecycle without Supabase auth wiring.
  @visibleForTesting
  Future<void> resetSessionStateForTesting() => purgeUserSession();
}
