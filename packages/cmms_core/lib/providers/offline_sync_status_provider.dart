import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_service_access.dart';
import '../utils/offline_sync_utils.dart' as sync_utils;

/// Reactive offline / pending-sync state for technician UI indicators.
class OfflineSyncStatusProvider extends ChangeNotifier {
  OfflineSyncStatusProvider() {
    unawaited(_initialize());
  }

  bool _isOffline = false;
  bool _isRefreshing = false;
  sync_utils.OfflineSyncSnapshot _snapshot =
      sync_utils.OfflineSyncSnapshot.empty();
  bool _initialized = false;

  ConnectivityService? _connectivity;
  VoidCallback? _connectivityListener;

  bool get isOffline => _isOffline;
  bool get isRefreshing => _isRefreshing;
  sync_utils.OfflineSyncSnapshot get snapshot => _snapshot;
  int get pendingOperationCount => _snapshot.totalPendingOperations;

  bool get showGlobalBanner =>
      AppConfig.isOfflineModeEnabled &&
      _initialized &&
      (_isOffline || _snapshot.hasPendingOperations);

  String get globalBannerMessage {
    final pending = _snapshot.totalPendingOperations;
    if (_isOffline && pending > 0) {
      return 'Offline — $pending change${pending == 1 ? '' : 's'} pending sync';
    }
    if (_isOffline) {
      return 'Offline — showing cached work orders and PM tasks';
    }
    if (pending > 0) {
      return '$pending change${pending == 1 ? '' : 's'} pending sync to server';
    }
    return '';
  }

  bool isWorkOrderPendingSync(WorkOrder workOrder) =>
      sync_utils.isWorkOrderPendingSync(workOrder, _snapshot);

  bool isPMTaskPendingSync(PMTask pmTask) =>
      sync_utils.isPMTaskPendingSync(pmTask, _snapshot);

  Future<void> _initialize() async {
    if (kIsWeb || !AppConfig.isOfflineModeEnabled) {
      _initialized = true;
      return;
    }

    try {
      _connectivity = resolveConnectivityService();
      await _connectivity!.initialize();
      _isOffline = !_connectivity!.isOnline;
      _connectivityListener = () {
        final nextOffline = !_connectivity!.isOnline;
        if (nextOffline == _isOffline) return;
        _isOffline = nextOffline;
        notifyListeners();
        if (!_isOffline) {
          unawaited(refresh());
        }
      };
      _connectivity!.addListener(_connectivityListener!);
    } catch (e) {
      debugPrint('OfflineSyncStatusProvider: connectivity init failed: $e');
    }

    resolveOfflineQueueService()
        .queueRevision
        .addListener(_onQueueRevisionChanged);
    await refresh();
    _initialized = true;
    notifyListeners();
  }

  void _onQueueRevisionChanged() {
    unawaited(refresh());
  }

  /// Reload pending queue snapshot (call after manual sync if needed).
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      _snapshot = await resolveOfflineQueueService().getSyncSnapshot();
      notifyListeners();
    } catch (e) {
      debugPrint('OfflineSyncStatusProvider: refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void dispose() {
    if (_connectivityListener != null && _connectivity != null) {
      _connectivity!.removeListener(_connectivityListener!);
    }
    resolveOfflineQueueService()
        .queueRevision
        .removeListener(_onQueueRevisionChanged);
    super.dispose();
  }
}
