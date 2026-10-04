import '../config/service_locator.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import 'offline_network.dart';

ConnectivityService resolveConnectivityService() {
  if (getIt.isRegistered<ConnectivityService>()) {
    return getIt<ConnectivityService>();
  }
  return ConnectivityService.instance;
}

OfflineQueueService resolveOfflineQueueService() {
  if (getIt.isRegistered<OfflineQueueService>()) {
    return getIt<OfflineQueueService>();
  }
  return OfflineQueueService.instance;
}

@Deprecated('Use resolveOfflineQueueService')
OfflineQueueService resolveSyncQueueService() => resolveOfflineQueueService();

bool shouldEnqueueOfflineMutation({
  required bool offlineModeEnabled,
  required bool isOnline,
  Object? caughtError,
}) {
  if (!offlineModeEnabled) return false;
  if (!isOnline) return true;
  return caughtError != null && isLikelyNetworkError(caughtError);
}
