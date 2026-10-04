import 'package:flutter/foundation.dart';

import '../config/locator.dart';
import '../providers/cmms_data_coordinator.dart';
import '../providers/inventory_provider.dart';
import '../providers/workflow_provider.dart';
import '../utils/offline_service_access.dart';
import 'hybrid_dam_service.dart';
import 'realtime_supabase_service.dart';
import 'unified_data_service.dart';

/// Coordinates teardown of user-scoped in-memory state when auth ends.
///
/// Lifecycle ownership:
/// - [AuthProvider] owns *when* a session ends (logout / remote sign-out).
/// - [CmmsDataCoordinator] owns domain realtime listeners and provider caches.
/// - [UnifiedDataService] owns REST-backed entity caches (WO, PM, users, etc.).
/// - [InventoryProvider] / [WorkflowProvider] own filtered UI snapshots.
///
/// Provider instances register here at construction time so [AuthProvider] can
/// purge without needing a [BuildContext].
class SessionPurgeService {
  SessionPurgeService._();

  static CmmsDataCoordinator? _coordinator;
  static InventoryProvider? _inventoryProvider;
  static WorkflowProvider? _workflowProvider;

  static void bindCoordinator(CmmsDataCoordinator coordinator) {
    _coordinator = coordinator;
  }

  static void unbindCoordinator(CmmsDataCoordinator coordinator) {
    if (identical(_coordinator, coordinator)) {
      _coordinator = null;
    }
  }

  static void bindInventoryProvider(InventoryProvider provider) {
    _inventoryProvider = provider;
  }

  static void unbindInventoryProvider(InventoryProvider provider) {
    if (identical(_inventoryProvider, provider)) {
      _inventoryProvider = null;
    }
  }

  static void bindWorkflowProvider(WorkflowProvider provider) {
    _workflowProvider = provider;
  }

  static void unbindWorkflowProvider(WorkflowProvider provider) {
    if (identical(_workflowProvider, provider)) {
      _workflowProvider = null;
    }
  }

  /// Purges all user-scoped caches and subscriptions after logout or remote
  /// sign-out so the next login cannot read the previous user's data.
  static Future<void> purgeOnSessionEnd() async {
    if (kDebugMode) {
      debugPrint('SessionPurgeService: purging user-scoped session data');
    }

    try {
      await resolveOfflineQueueService().clearQueue();
    } catch (e) {
      debugPrint('SessionPurgeService: offline queue clear failed: $e');
    }

    if (_coordinator != null) {
      await _coordinator!.purgeUserSession();
    } else {
      sl<UnifiedDataService>().purgeUserSession();
      _inventoryProvider?.clearCache();
      _workflowProvider?.clearCache();
    }

    try {
      await sl<HybridDamService>().clearAllCaches();
    } catch (e) {
      debugPrint('SessionPurgeService: HybridDam cache clear failed: $e');
    }

    try {
      sl<RealtimeSupabaseService>().dispose();
    } catch (e) {
      debugPrint('SessionPurgeService: realtime dispose failed: $e');
    }
  }
}
