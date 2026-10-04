// Data quality monitoring service for continuous data validation

import 'dart:async';
import 'dart:math';

import '../models/asset.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../services/unified_data_service.dart';
import 'data_quality_service.dart';
import '../config/locator.dart';

class DataQualityMonitor {

  Timer? _monitoringTimer;
  final StreamController<DataQualityReport> _qualityController =
      StreamController<DataQualityReport>.broadcast();
  final StreamController<Map<String, dynamic>> _alertController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Quality thresholds
  static const double _minQualityScore = 80;
  static const double _minDataFreshness = 70;
  static const int _maxDuplicatePercentage = 5;
  static const int _maxOutlierPercentage = 10;

  // Cache for performance
  DataQualityReport? _lastReport;
  DateTime? _lastCheck;

  /// Stream of data quality updates
  Stream<DataQualityReport> get qualityStream => _qualityController.stream;

  /// Stream of quality alerts
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;

  /// Start continuous data quality monitoring
  void startMonitoring({Duration checkInterval = const Duration(hours: 1)}) {
    print(
      'ðŸ” Data Quality Monitor: Starting continuous monitoring with ${checkInterval.inHours}h intervals',
    );

    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(checkInterval, (_) {
      _performQualityCheck();
    });

    // Initial check
    _performQualityCheck();
  }

  /// Stop data quality monitoring
  void stopMonitoring() {
    print('ðŸ” Data Quality Monitor: Stopping monitoring');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Perform comprehensive quality check
  Future<void> _performQualityCheck() async {
    try {
      print('ðŸ” Data Quality Monitor: Performing quality check...');

      // ðŸ”¥ Load real-time data from UnifiedDataService
      final dataService = sl<UnifiedDataService>();
      final workOrders = dataService.workOrders;
      final assets = dataService.assets;
      final pmTasks = dataService.pmTasks;

      // Generate quality report
      final report = await _generateQualityReport(workOrders, assets, pmTasks);

      // Check for quality issues
      await _checkQualityIssues(report, workOrders, assets, pmTasks);

      // Update cache
      _lastReport = report;
      _lastCheck = DateTime.now();

      // Emit update
      if (!_qualityController.isClosed) {
        _qualityController.add(report);
      }

      print(
        'ðŸ” Data Quality Monitor: Quality check completed - Score: ${report.accuracyScore.toStringAsFixed(1)}%',
      );
    } catch (e, st) {
      print('âŒ Data Quality Monitor: Error during quality check: $e');
    }
  }

  /// Generate comprehensive quality report
  Future<DataQualityReport> _generateQualityReport(
    List<WorkOrder> workOrders,
    List<Asset> assets,
    List<PMTask> pmTasks,
  ) async {
    try {
      // Validate data
      final validWorkOrders =
          await DataQualityService.filterValidWorkOrders(workOrders);
      final validAssets = await DataQualityService.filterValidAssets(assets);
      final validPMTasks = await DataQualityService.filterValidPMTasks(pmTasks);

      // Find issues
      final duplicates = DataQualityService.findDuplicateWorkOrders(workOrders);
      final outliers = DataQualityService.findOutlierWorkOrders(workOrders);
      final freshness = DataQualityService.calculateDataFreshness(workOrders);

      // Calculate accuracy score
      final accuracyScore = await DataQualityService.calculateDataQualityScore(
        workOrders,
        assets,
        pmTasks,
      );

      return DataQualityReport(
        totalRecords: workOrders.length + assets.length + pmTasks.length,
        incompleteRecords: (workOrders.length - validWorkOrders.length) +
            (assets.length - validAssets.length) +
            (pmTasks.length - validPMTasks.length),
        duplicateRecords: duplicates.length,
        outlierRecords: outliers.length,
        dataFreshness: freshness,
        accuracyScore: accuracyScore,
        generatedAt: DateTime.now(),
      );
    } catch (e, st) {
      print('âŒ Data Quality Monitor: Error generating quality report: $e');
      return DataQualityReport(
        totalRecords: 0,
        incompleteRecords: 0,
        duplicateRecords: 0,
        outlierRecords: 0,
        dataFreshness: 0,
        accuracyScore: 0,
        generatedAt: DateTime.now(),
      );
    }
  }

  /// Check for quality issues and generate alerts
  Future<void> _checkQualityIssues(
    DataQualityReport report,
    List<WorkOrder> workOrders,
    List<Asset> assets,
    List<PMTask> pmTasks,
  ) async {
    final alerts = <Map<String, dynamic>>[];

    // Check overall quality score
    if (report.accuracyScore < _minQualityScore) {
      alerts.add({
        'type': 'quality_score_low',
        'severity': 'high',
        'message':
            'Data quality score is below threshold (${report.accuracyScore.toStringAsFixed(1)}% < $_minQualityScore%)',
        'value': report.accuracyScore,
        'threshold': _minQualityScore,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check data freshness
    if (report.dataFreshness < _minDataFreshness) {
      alerts.add({
        'type': 'data_stale',
        'severity': 'medium',
        'message':
            'Data freshness is below threshold (${report.dataFreshness.toStringAsFixed(1)}% < $_minDataFreshness%)',
        'value': report.dataFreshness,
        'threshold': _minDataFreshness,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check duplicate percentage
    final duplicatePercentage = report.totalRecords > 0
        ? (report.duplicateRecords / report.totalRecords) * 100
        : 0.0;

    if (duplicatePercentage > _maxDuplicatePercentage) {
      alerts.add({
        'type': 'duplicates_high',
        'severity': 'medium',
        'message':
            'Duplicate records exceed threshold (${duplicatePercentage.toStringAsFixed(1)}% > $_maxDuplicatePercentage%)',
        'value': duplicatePercentage,
        'threshold': _maxDuplicatePercentage.toDouble(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check outlier percentage
    final outlierPercentage = report.totalRecords > 0
        ? (report.outlierRecords / report.totalRecords) * 100
        : 0.0;

    if (outlierPercentage > _maxOutlierPercentage) {
      alerts.add({
        'type': 'outliers_high',
        'severity': 'low',
        'message':
            'Outlier records exceed threshold (${outlierPercentage.toStringAsFixed(1)}% > $_maxOutlierPercentage%)',
        'value': outlierPercentage,
        'threshold': _maxOutlierPercentage.toDouble(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check for specific data issues
    await _checkSpecificDataIssues(workOrders, assets, pmTasks, alerts);

    // Emit alerts
    for (final alert in alerts) {
      if (!_alertController.isClosed) {
        _alertController.add(alert);
      }
    }

    if (alerts.isNotEmpty) {
      print(
        'âš ï¸ Data Quality Monitor: Generated ${alerts.length} quality alerts',
      );
    }
  }

  /// Check for specific data issues
  Future<void> _checkSpecificDataIssues(
    List<WorkOrder> workOrders,
    List<Asset> assets,
    List<PMTask> pmTasks,
    List<Map<String, dynamic>> alerts,
  ) async {
    // Check for work orders without assigned technicians
    final unassignedWorkOrders = workOrders
        .where(
          (wo) =>
              wo.assignedTechnicianIds.isEmpty &&
              wo.status != WorkOrderStatus.open,
        )
        .length;

    if (unassignedWorkOrders > 0) {
      alerts.add({
        'type': 'unassigned_work_orders',
        'severity': 'medium',
        'message':
            '$unassignedWorkOrders work orders are not assigned to technicians',
        'value': unassignedWorkOrders,
        'threshold': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check for work orders with missing timestamps
    final incompleteTimestamps = workOrders
        .where(
          (wo) =>
              wo.status == WorkOrderStatus.completed &&
              (wo.startedAt == null || wo.completedAt == null),
        )
        .length;

    if (incompleteTimestamps > 0) {
      alerts.add({
        'type': 'incomplete_timestamps',
        'severity': 'high',
        'message':
            '$incompleteTimestamps completed work orders have missing timestamps',
        'value': incompleteTimestamps,
        'threshold': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check for assets without maintenance history
    final assetsWithoutMaintenance = assets
        .where(
          (asset) => workOrders.where((wo) => wo.assetId == asset.id).isEmpty,
        )
        .length;

    if (assetsWithoutMaintenance > 0) {
      alerts.add({
        'type': 'assets_no_maintenance',
        'severity': 'low',
        'message':
            '$assetsWithoutMaintenance assets have no maintenance history',
        'value': assetsWithoutMaintenance,
        'threshold': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check for overdue PM tasks
    final overduePMTasks = pmTasks
        .where(
          (task) =>
              task.nextDueDate != null &&
              task.nextDueDate!.isBefore(DateTime.now()) &&
              task.status != 'completed',
        )
        .length;

    if (overduePMTasks > 0) {
      alerts.add({
        'type': 'overdue_pm_tasks',
        'severity': 'medium',
        'message': '$overduePMTasks PM tasks are overdue',
        'value': overduePMTasks,
        'threshold': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    // Check for work orders with missing cost data
    final missingCosts = workOrders
        .where(
          (wo) =>
              wo.status == WorkOrderStatus.completed && wo.totalCost == null,
        )
        .length;

    if (missingCosts > 0) {
      alerts.add({
        'type': 'missing_cost_data',
        'severity': 'medium',
        'message': '$missingCosts completed work orders are missing cost data',
        'value': missingCosts,
        'threshold': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get current quality report
  Future<DataQualityReport?> getCurrentQualityReport() async {
    if (_lastReport != null &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!).inHours < 2) {
      return _lastReport;
    }

    // Force a new check if cache is stale
    await _performQualityCheck();
    return _lastReport;
  }

  /// Get quality trends over time
  Future<List<Map<String, dynamic>>> getQualityTrends({
    Duration period = const Duration(days: 30),
  }) async {
    try {
      // This would typically query historical quality data
      // For now, return a simplified trend
      final trends = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (var i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        trends.add({
          'date': date.toIso8601String(),
          'qualityScore': 85.0 + (Random().nextDouble() * 10), // Simulated data
          'dataFreshness': 80.0 + (Random().nextDouble() * 15),
          'duplicatePercentage': Random().nextDouble() * 5,
          'outlierPercentage': Random().nextDouble() * 8,
        });
      }

      return trends.reversed.toList(); // Most recent first
    } catch (e, st) {
      print('âŒ Data Quality Monitor: Error getting quality trends: $e');
      return [];
    }
  }

  /// Get quality recommendations
  Future<List<Map<String, dynamic>>> getQualityRecommendations() async {
    try {
      final report = await getCurrentQualityReport();
      if (report == null) return [];

      final recommendations = <Map<String, dynamic>>[];

      // Quality score recommendations
      if (report.accuracyScore < 90) {
        recommendations.add({
          'type': 'improve_data_validation',
          'priority': 'high',
          'title': 'Improve Data Validation',
          'description':
              'Implement stricter data validation rules to improve data quality',
          'impact': 'High',
          'effort': 'Medium',
        });
      }

      // Duplicate recommendations
      if (report.duplicateRecords > 0) {
        recommendations.add({
          'type': 'implement_duplicate_detection',
          'priority': 'medium',
          'title': 'Implement Duplicate Detection',
          'description':
              'Add duplicate detection logic to prevent duplicate work orders',
          'impact': 'Medium',
          'effort': 'Low',
        });
      }

      // Freshness recommendations
      if (report.dataFreshness < 80) {
        recommendations.add({
          'type': 'improve_data_sync',
          'priority': 'high',
          'title': 'Improve Data Synchronization',
          'description':
              'Implement more frequent data synchronization to improve freshness',
          'impact': 'High',
          'effort': 'High',
        });
      }

      // Outlier recommendations
      if (report.outlierRecords > 0) {
        recommendations.add({
          'type': 'implement_outlier_detection',
          'priority': 'low',
          'title': 'Implement Outlier Detection',
          'description':
              'Add outlier detection to identify and review unusual data points',
          'impact': 'Low',
          'effort': 'Medium',
        });
      }

      return recommendations;
    } catch (e, st) {
      print(
        'âŒ Data Quality Monitor: Error getting quality recommendations: $e',
      );
      return [];
    }
  }

  /// Validate specific data record
  Future<Map<String, dynamic>> validateRecord(
    String type,
    Map<String, dynamic> data,
  ) async {
    try {
      final issues = <String>[];
      final warnings = <String>[];

      switch (type) {
        case 'work_order':
          final workOrder = WorkOrder.fromMap(data);
          final isValid =
              await DataQualityService.validateWorkOrderData(workOrder);

          if (!isValid) {
            issues.add('Work order data validation failed');
          }

          // Check for specific issues
          if (workOrder.problemDescription.isEmpty) {
            issues.add('Problem description is required');
          }

          if (workOrder.assignedTechnicianIds.isEmpty &&
              workOrder.status != WorkOrderStatus.open) {
            warnings.add('Work order should be assigned to a technician');
          }

          if (workOrder.startedAt != null && workOrder.completedAt != null) {
            if (workOrder.completedAt!.isBefore(workOrder.startedAt!)) {
              issues.add('Completion time cannot be before start time');
            }
          }

          break;

        case 'asset':
          final asset = Asset.fromMap(data);
          final isValid = await DataQualityService.validateAssetData(asset);

          if (!isValid) {
            issues.add('Asset data validation failed');
          }

          // Check for specific issues
          if (asset.name.isEmpty) {
            issues.add('Asset name is required');
          }

          if (asset.location.isEmpty) {
            issues.add('Asset location is required');
          }

          break;

        case 'pm_task':
          final pmTask = PMTask.fromMap(data);
          final isValid = await DataQualityService.validatePMTaskData(pmTask);

          if (!isValid) {
            issues.add('PM task data validation failed');
          }

          // Check for specific issues
          if (pmTask.taskName.isEmpty) {
            issues.add('Task name is required');
          }

          if (pmTask.frequency == null) {
            issues.add('Task frequency is required');
          }

          break;
      }

      return {
        'valid': issues.isEmpty,
        'issues': issues,
        'warnings': warnings,
        'validatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e, st) {
      print('âŒ Data Quality Monitor: Error validating record: $e');
      return {
        'valid': false,
        'issues': ['Validation error: $e'],
        'warnings': [],
        'validatedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _qualityController.close();
    _alertController.close();
  }
}
