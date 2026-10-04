import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/locator.dart';
import '../config/service_locator.dart';
import 'offline_queue_service.dart';

/// Tracks device connectivity for offline-mode gating.
///
/// When [AppConfig.isOfflineModeEnabled] is false, [isOnline] is always treated
/// as true for mutation decisions (fail-fast online-only).
///
/// Prefer GetIt (`sl<ConnectivityService>()`). [instance] is the same object
/// when registered via `ConnectivityService.instance` in the locator.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  static ConnectivityService? _instance;
  static ConnectivityService get instance =>
      _instance ??= ConnectivityService();

  final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOnline = true;
  bool _initialized = false;

  bool get isOnline {
    if (!AppConfig.isOfflineModeEnabled) return true;
    return _isOnline;
  }

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('ConnectivityService: initial check failed: $e');
      _isOnline = true;
    }

    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
    _initialized = true;
    notifyListeners();
    debugPrint('ConnectivityService: initialized (online=$_isOnline)');
  }

  Future<void> _onChanged(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    if (wasOnline == _isOnline) return;
    notifyListeners();
    debugPrint('ConnectivityService: online=$_isOnline');

    if (!wasOnline && _isOnline && AppConfig.isOfflineModeEnabled) {
      try {
        await _resolveOfflineQueue().processQueue();
      } catch (e) {
        debugPrint('ConnectivityService: flush on reconnect failed: $e');
      }
    }
  }

  /// Force a re-check (e.g. after app resume).
  Future<bool> refresh() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final next = result != ConnectivityResult.none;
      if (next != _isOnline) {
        final wasOnline = _isOnline;
        _isOnline = next;
        notifyListeners();
        if (!wasOnline && _isOnline && AppConfig.isOfflineModeEnabled) {
          unawaited(_resolveOfflineQueue().processQueue());
        }
      }
    } catch (e) {
      debugPrint('ConnectivityService: refresh failed: $e');
    }
    return isOnline;
  }

  OfflineQueueService _resolveOfflineQueue() {
    if (getIt.isRegistered<OfflineQueueService>()) {
      return sl<OfflineQueueService>();
    }
    return OfflineQueueService.instance;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
