import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/asset.dart';
import '../services/unified_data_service.dart';
import '../utils/performance_optimizer.dart';
import '../utils/stream_subscription_cancel.dart';
import 'domain/cmms_domain_provider.dart';
import '../config/locator.dart';

class AssetProvider with ChangeNotifier implements CmmsDomainProvider {
  AssetProvider({UnifiedDataService? dataService})
      : _dataService = dataService ?? sl<UnifiedDataService>();

  final UnifiedDataService _dataService;
  bool _isDisposed = false;
  StreamSubscription<List<Asset>>? _assetsSubscription;
  List<Asset> _realtimeAssets = [];

  List<Asset> get assets =>
      _realtimeAssets.isNotEmpty ? _realtimeAssets : _dataService.assets;

  bool get isAssetsLoading => _dataService.isAssetsLoading;

  Stream<List<Asset>> get assetsStream => _dataService.assetsStream;

  @override
  void clearCache() {
    _realtimeAssets = [];
  }

  @override
  Future<void> cancelRealtimeListeners() async {
    await cancelStreamSubscriptions([_assetsSubscription]);
    _assetsSubscription = null;
  }

  @override
  Future<void> startRealtimeListeners() async {
    if (_isDisposed) return;
    await cancelRealtimeListeners();
    if (_isDisposed) return;

    _assetsSubscription = _dataService.assetsStream.listen(
      (assets) {
        _realtimeAssets = assets;
        if (!_isDisposed) {
          ChangeNotifierBatcher.batchNotify(
            () => notifyListeners(),
            batchKey: this,
          );
        }
      },
      onError: (error) {
        debugPrint('❌ Assets stream error: $error');
      },
    );
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
