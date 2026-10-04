// Consolidated Analytics Service
//
// Main analytics service that consolidates functionality from:
// - analytics_service.dart
// - unified_analytics_service.dart
// - enhanced_analytics_service.dart
//
// This is the single source of truth for all analytics operations.

import 'dart:async';

import 'package:cmms_core/models/analytics_models.dart';
import 'package:cmms_core/models/asset.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/services/enhanced_notification_service.dart' as enh;
import 'package:cmms_core/services/logger_service.dart';
import 'package:cmms_core/services/unified_data_service.dart';

import 'analytics_calculator.dart';
import '../../config/locator.dart';

/// Main analytics service providing comprehensive analytics capabilities
class AnalyticsService {
  /// Create an analytics service instance
  ///
  /// Note: Use GetIt service locator to obtain instances:
  /// ```dart
  /// final analytics = getIt<AnalyticsService>();
  /// ```
  AnalyticsService();

  // Calculator instance (will be injected)
  final _calculator = AnalyticsCalculator();

  // Cache for performance
  final Map<String, dynamic> _cache = {};
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Stream controllers for real-time updates
  final StreamController<KPIMetrics> _kpiController =
      StreamController<KPIMetrics>.broadcast();
  final StreamController<Map<String, dynamic>> _metricsController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of real-time KPI updates
  Stream<KPIMetrics> get kpiStream => _kpiController.stream;

  /// Stream of metrics updates
  Stream<Map<String, dynamic>> get metricsStream => _metricsController.stream;

  /// Initialize the analytics service
  Future<void> initialize() async {
    LoggerService.info('Initializing analytics service', tag: 'Analytics');
    // Future initialization logic here
  }

  /// Get comprehensive dashboard data
  Future<Map<String, dynamic>> getDashboardData({
    Duration period = const Duration(days: 30),
  }) async {
    try {
      LoggerService.debug(
        'Generating dashboard data for ${period.inDays} days',
        tag: 'Analytics',
      );

      // Check cache first
      final cacheKey = 'dashboard_${period.inDays}';
      if (_isCacheValid(cacheKey)) {
        return _cache[cacheKey] as Map<String, dynamic>;
      }

      // Load system data
      final data = await _loadSystemData();

      // Calculate metrics
      final kpis = await _calculator.calculateKPIs(
        workOrders: data['workOrders'] as List<WorkOrder>,
        assets: data['assets'] as List<Asset>,
        pmTasks: data['pmTasks'] as List<PMTask>,
        period: period,
      );

      final dashboard = {
        'kpis': kpis.toJson(),
        'workOrders':
            _getWorkOrderMetrics(data['workOrders'] as List<WorkOrder>),
        'assets': _getAssetMetrics(data['assets'] as List<Asset>),
        'pmTasks': _getPMTaskMetrics(data['pmTasks'] as List<PMTask>),
        'users': _getUserMetrics(data['users'] as List<User>),
        'period': period.inDays,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      // Cache results
      _cache[cacheKey] = dashboard;
      _lastCacheUpdate = DateTime.now();

      LoggerService.info(
        'Dashboard data generated successfully',
        tag: 'Analytics',
      );
      return dashboard;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error generating dashboard data',
        error: e,
        stackTrace: stackTrace,
        tag: 'Analytics',
      );
      return _getDefaultDashboard();
    }
  }

  /// Generate comprehensive analytics report
  Future<AnalyticsReport> generateReport({
    Duration period = const Duration(days: 30),
  }) async {
    try {
      LoggerService.debug('Generating analytics report', tag: 'Analytics');

      // TODO: Implement full report generation with proper model construction
      // For now, this is a placeholder to allow compilation
      throw UnimplementedError(
        'Full analytics report generation will be implemented in Phase 2.2',
      );

      // Commented out to avoid unused variable warning:
      // final data = await _loadSystemData();
      // final workOrders = data['workOrders'] as List<WorkOrder>;
      // final assets = data['assets'] as List<Asset>;
      // final pmTasks = data['pmTasks'] as List<PMTask>;
      //
      // final kpis = await _calculator.calculateKPIs(
      //   workOrders: workOrders,
      //   assets: assets,
      //   pmTasks: pmTasks,
      //   period: period,
      // );

      // Future implementation:
      // return AnalyticsReport(
      //   kpiMetrics: kpis,
      //   technicianPerformance: _calculateTechnicianPerformance(),
      //   assetPerformance: _calculateAssetPerformance(),
      //   maintenanceTrends: _calculateMaintenanceTrends(),
      //   costAnalysis: _calculateCostAnalysis(),
      //   generatedAt: DateTime.now(),
      //   reportPeriod: '${period.inDays} days',
      //   trends: _calculateTrends(),
      // );
    } catch (e, stackTrace) {
      LoggerService.error(
        'Error generating report',
        error: e,
        stackTrace: stackTrace,
        tag: 'Analytics',
      );
      rethrow;
    }
  }

  /// Get KPIs for a specific period
  Future<KPIMetrics> getKPIs({
    Duration period = const Duration(days: 30),
  }) async {
    final data = await _loadSystemData();
    return _calculator.calculateKPIs(
      workOrders: data['workOrders'] as List<WorkOrder>,
      assets: data['assets'] as List<Asset>,
      pmTasks: data['pmTasks'] as List<PMTask>,
      period: period,
    );
  }

  /// Get work order analytics
  Map<String, dynamic> getWorkOrderAnalytics(List<WorkOrder> workOrders) =>
      _calculator.calculateWorkOrderMetrics(workOrders);

  /// Get asset analytics
  Map<String, dynamic> getAssetAnalytics(
    List<Asset> assets,
    List<WorkOrder> workOrders,
  ) =>
      _calculator.calculateAssetMetrics(assets, workOrders);

  /// Get PM task analytics
  Map<String, dynamic> getPMTaskAnalytics(List<PMTask> pmTasks) =>
      _calculator.calculatePMTaskMetrics(pmTasks);

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _lastCacheUpdate = null;
    LoggerService.debug('Analytics cache cleared', tag: 'Analytics');
  }

  /// Dispose resources
  void dispose() {
    _kpiController.close();
    _metricsController.close();
    clearCache();
  }

  // ============================================================================
  // NOTIFICATIONS BRIDGE (for UI compatibility)
  // ============================================================================

  /// Get current notification settings (stubbed per type; enabled by default)
  Future<Map<NotificationType, bool>> getNotificationSettings() async {
    // In a future phase, persist per-user settings. For now, default enabled.
    final settings = <NotificationType, bool>{
      for (final t in NotificationType.values) t: true,
    };
    return settings;
  }

  /// Update a single notification type setting (no-op placeholder)
  Future<void> updateNotificationSetting(
    NotificationType type,
    bool enabled,
  ) async {
    // Placeholder: persist to SharedPreferences/Firestore in future phase
    LoggerService.debug(
      'Notification setting updated: ${type.name} -> $enabled',
      tag: 'Analytics',
    );
  }

  /// Fetch notifications mapped to NotificationData for UI
  Future<List<NotificationData>> getNotifications() async {
    final service = sl<enh.EnhancedNotificationService>();
    final list = service.notifications;
    return list
        .map(
          (n) => NotificationData(
            id: n.id,
            title: n.title,
            body: n.message,
            type: _mapEnhTypeToModelType(n.type),
            priority: _mapEnhPriorityToModelPriority(n.priority),
            createdAt: n.createdAt,
            readAt: n.readAt,
            isRead: n.isRead,
            data: n.data ?? <String, dynamic>{},
            technicianId: n.userId, // best-effort mapping
            pmTaskId: n.relatedType == 'pm_task' ? n.relatedId : null,
            assetId: n.relatedType == 'asset' ? n.relatedId : null,
          ),
        )
        .toList();
  }

  /// Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final service = sl<enh.EnhancedNotificationService>();
    await service.markAsRead(notificationId);
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    final service = sl<enh.EnhancedNotificationService>();
    await service.clearAllNotifications();
  }

  // Mapping helpers between enhanced service enums and UI model enums
  NotificationType _mapEnhTypeToModelType(enh.NotificationType t) {
    switch (t) {
      case enh.NotificationType.workOrderAssigned:
        return NotificationType.workOrderAssigned;
      case enh.NotificationType.workOrderCompleted:
        return NotificationType.workOrderCompleted;
      case enh.NotificationType.workOrderOverdue:
        return NotificationType.workOrderOverdue;
      case enh.NotificationType.pmTaskDue:
        return NotificationType.pmTaskDue;
      case enh.NotificationType.pmTaskOverdue:
        return NotificationType.pmTaskOverdue;
      case enh.NotificationType.systemAlert:
        return NotificationType.systemUpdate;
      default:
        // Map other enhanced types to closest equivalents
        return NotificationType.systemUpdate;
    }
  }

  NotificationPriority _mapEnhPriorityToModelPriority(
    enh.NotificationPriority p,
  ) {
    switch (p) {
      case enh.NotificationPriority.low:
        return NotificationPriority.low;
      case enh.NotificationPriority.medium:
        return NotificationPriority.medium;
      case enh.NotificationPriority.high:
        return NotificationPriority.high;
      case enh.NotificationPriority.critical:
        return NotificationPriority.critical;
    }
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Load all system data
  Future<Map<String, dynamic>> _loadSystemData() async {
    final dataService = sl<UnifiedDataService>();
    return {
      'workOrders': dataService.workOrders,
      'assets': dataService.assets,
      'pmTasks': dataService.pmTasks,
      'users': dataService.users,
      'inventory': dataService.inventoryItems,
    };
  }

  /// Check if cache is valid
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;
    if (_lastCacheUpdate == null) return false;

    final age = DateTime.now().difference(_lastCacheUpdate!);
    return age < _cacheExpiry;
  }

  /// Get work order metrics
  Map<String, dynamic> _getWorkOrderMetrics(List<WorkOrder> workOrders) {
    final total = workOrders.length;
    final open =
        workOrders.where((wo) => wo.status == WorkOrderStatus.open).length;
    final inProgress = workOrders
        .where((wo) => wo.status == WorkOrderStatus.inProgress)
        .length;
    final completed =
        workOrders.where((wo) => wo.status == WorkOrderStatus.completed).length;

    return {
      'total': total,
      'open': open,
      'inProgress': inProgress,
      'completed': completed,
      'completionRate': total > 0 ? (completed / total * 100) : 0.0,
    };
  }

  /// Get asset metrics
  Map<String, dynamic> _getAssetMetrics(List<Asset> assets) {
    final total = assets.length;
    final operational = assets.where((a) => a.status == 'active').length;
    final maintenance = assets.where((a) => a.status == 'maintenance').length;
    final outOfService = assets.where((a) => a.status == 'inactive').length;

    return {
      'total': total,
      'operational': operational,
      'maintenance': maintenance,
      'outOfService': outOfService,
      'operationalRate': total > 0 ? (operational / total * 100) : 0.0,
    };
  }

  /// Get PM task metrics
  Map<String, dynamic> _getPMTaskMetrics(List<PMTask> pmTasks) {
    final total = pmTasks.length;
    final pending =
        pmTasks.where((pm) => pm.status == PMTaskStatus.pending).length;
    final inProgress =
        pmTasks.where((pm) => pm.status == PMTaskStatus.inProgress).length;
    final completed =
        pmTasks.where((pm) => pm.status == PMTaskStatus.completed).length;

    return {
      'total': total,
      'pending': pending,
      'inProgress': inProgress,
      'completed': completed,
      'completionRate': total > 0 ? (completed / total * 100) : 0.0,
    };
  }

  /// Get user metrics
  Map<String, dynamic> _getUserMetrics(List<User> users) {
    final total = users.length;
    final active = users.where((u) => u.isActive).length;
    final admins = users.where((u) => u.role == 'admin').length;
    final managers = users.where((u) => u.role == 'manager').length;
    final technicians = users.where((u) => u.role == 'technician').length;

    return {
      'total': total,
      'active': active,
      'admins': admins,
      'managers': managers,
      'technicians': technicians,
    };
  }

  /// Get default dashboard data
  Map<String, dynamic> _getDefaultDashboard() => {
        'kpis': KPIMetrics.empty().toJson(),
        'workOrders': {
          'total': 0,
          'open': 0,
          'inProgress': 0,
          'completed': 0,
          'completionRate': 0.0,
        },
        'assets': {
          'total': 0,
          'operational': 0,
          'maintenance': 0,
          'outOfService': 0,
          'operationalRate': 0.0,
        },
        'pmTasks': {
          'total': 0,
          'pending': 0,
          'inProgress': 0,
          'completed': 0,
          'completionRate': 0.0,
        },
        'users': {
          'total': 0,
          'active': 0,
          'admins': 0,
          'managers': 0,
          'technicians': 0,
        },
        'period': 30,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
}
