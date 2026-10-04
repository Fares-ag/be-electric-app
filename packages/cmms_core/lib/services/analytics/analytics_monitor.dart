// Analytics Monitor
//
// Handles real-time analytics monitoring and updates:
// - Stream-based real-time KPI updates
// - Automatic refresh
// - Background monitoring
//
// Consolidated from realtime_analytics_service.dart and enhanced_analytics_integration.dart

import 'dart:async';
import 'package:cmms_core/models/analytics_models.dart';
import 'package:cmms_core/services/logger_service.dart';
import 'package:cmms_core/services/unified_data_service.dart';
import 'analytics_calculator.dart';
import '../../config/locator.dart';

/// Real-time analytics monitoring service
class AnalyticsMonitor {
  /// Create an analytics monitor instance
  ///
  /// Note: Use GetIt service locator to obtain instances:
  /// ```dart
  /// final monitor = getIt<AnalyticsMonitor>();
  /// ```
  AnalyticsMonitor();

  // Calculator instance (will be injected)
  final _calculator = AnalyticsCalculator();

  // Stream controllers
  final StreamController<KPIMetrics> _kpiController =
      StreamController<KPIMetrics>.broadcast();
  final StreamController<Map<String, dynamic>> _metricsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Monitoring state
  Timer? _updateTimer;
  bool _isMonitoring = false;
  Duration _updateInterval = const Duration(minutes: 5);

  /// Stream of real-time KPI updates
  Stream<KPIMetrics> get kpiStream => _kpiController.stream;

  /// Stream of metrics updates
  Stream<Map<String, dynamic>> get metricsStream => _metricsController.stream;

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Get current update interval
  Duration get updateInterval => _updateInterval;

  /// Start real-time analytics monitoring
  void startMonitoring({
    Duration updateInterval = const Duration(minutes: 5),
  }) {
    if (_isMonitoring) {
      LoggerService.debug(
        'Analytics monitoring already running',
        tag: 'AnalyticsMonitor',
      );
      return;
    }

    LoggerService.info(
      'Starting analytics monitoring (interval: ${updateInterval.inMinutes}min)',
      tag: 'AnalyticsMonitor',
    );

    _updateInterval = updateInterval;
    _isMonitoring = true;

    // Initial update
    _updateAnalytics();

    // Schedule periodic updates
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_updateInterval, (_) {
      _updateAnalytics();
    });
  }

  /// Stop real-time analytics monitoring
  void stopMonitoring() {
    if (!_isMonitoring) {
      return;
    }

    LoggerService.info(
      'Stopping analytics monitoring',
      tag: 'AnalyticsMonitor',
    );

    _updateTimer?.cancel();
    _updateTimer = null;
    _isMonitoring = false;
  }

  /// Force an immediate analytics update
  Future<void> forceUpdate() async {
    LoggerService.debug('Forcing analytics update', tag: 'AnalyticsMonitor');
    await _updateAnalytics();
  }

  /// Update analytics data and broadcast to streams
  Future<void> _updateAnalytics() async {
    try {
      final dataService = sl<UnifiedDataService>();

      // Calculate latest KPIs
      final kpis = await _calculator.calculateKPIs(
        workOrders: dataService.workOrders,
        assets: dataService.assets,
        pmTasks: dataService.pmTasks,
      );

      // Broadcast KPI update
      _kpiController.add(kpis);

      // Calculate additional metrics
      final metrics = {
        'workOrders':
            _calculator.calculateWorkOrderMetrics(dataService.workOrders),
        'assets': _calculator.calculateAssetMetrics(
          dataService.assets,
          dataService.workOrders,
        ),
        'pmTasks': _calculator.calculatePMTaskMetrics(dataService.pmTasks),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Broadcast metrics update
      _metricsController.add(metrics);

      LoggerService.debug(
        'Analytics update completed',
        tag: 'AnalyticsMonitor',
      );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error updating analytics',
        error: e,
        stackTrace: stackTrace,
        tag: 'AnalyticsMonitor',
      );
    }
  }

  /// Change the update interval (requires restart of monitoring)
  void setUpdateInterval(Duration newInterval) {
    LoggerService.info(
      'Updating monitoring interval to ${newInterval.inMinutes}min',
      tag: 'AnalyticsMonitor',
    );

    final wasMonitoring = _isMonitoring;
    if (wasMonitoring) {
      stopMonitoring();
    }

    _updateInterval = newInterval;

    if (wasMonitoring) {
      startMonitoring(updateInterval: _updateInterval);
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _kpiController.close();
    _metricsController.close();
  }
}
