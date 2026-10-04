/// Lifecycle hooks shared by domain data providers.
abstract class CmmsDomainProvider {
  void clearCache();
  Future<void> startRealtimeListeners();
  Future<void> cancelRealtimeListeners();
}
