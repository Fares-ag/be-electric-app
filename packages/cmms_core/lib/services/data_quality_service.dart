// Data quality validation and monitoring service for CMMS analytics

import '../models/asset.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';

class DataQualityService {
  /// Validate work order data quality
  static Future<bool> validateWorkOrderData(WorkOrder workOrder) async {
    try {
      // Validate timestamps
      if (workOrder.startedAt != null && workOrder.completedAt != null) {
        if (workOrder.completedAt!.isBefore(workOrder.startedAt!)) {
          print(
            'âŒ Data Quality: Invalid time sequence for work order ${workOrder.id}',
          );
          return false; // Invalid time sequence
        }
      }

      // Validate required fields
      if (workOrder.problemDescription.isEmpty) {
        print(
          'âŒ Data Quality: Missing problem description for work order ${workOrder.id}',
        );
        return false;
      }

      if (workOrder.assignedTechnicianIds.isEmpty &&
          workOrder.status != WorkOrderStatus.open) {
        print(
          'âŒ Data Quality: Missing assigned technician for work order ${workOrder.id}',
        );
        return false;
      }

      // Validate asset reference
      if (workOrder.assetId == null || workOrder.assetId!.isEmpty) {
        print(
          'âŒ Data Quality: Missing asset ID for work order ${workOrder.id}',
        );
        return false;
      }

      return true;
    } catch (e, st) {
      print(
          'âŒ Data Quality: Error validating work order ${workOrder.id}: $e',);
      return false;
    }
  }

  /// Filter valid work orders for analytics
  static Future<List<WorkOrder>> filterValidWorkOrders(
    List<WorkOrder> orders,
  ) async {
    final validOrders = <WorkOrder>[];

    for (final order in orders) {
      if (await validateWorkOrderData(order)) {
        validOrders.add(order);
      }
    }

    print(
      'ðŸ“Š Data Quality: ${validOrders.length}/${orders.length} work orders are valid for analytics',
    );
    return validOrders;
  }

  /// Validate asset data quality
  static Future<bool> validateAssetData(Asset asset) async {
    try {
      // Validate required fields
      if (asset.id.isEmpty || asset.name.isEmpty || asset.location.isEmpty) {
        print(
            'âŒ Data Quality: Missing required fields for asset ${asset.id}',);
        return false;
      }

      // Validate dates
      if (asset.installationDate != null && asset.purchaseDate != null) {
        if (asset.installationDate!.isBefore(asset.purchaseDate!)) {
          print(
            'âŒ Data Quality: Installation date before purchase date for asset ${asset.id}',
          );
          return false;
        }
      }

      // Validate maintenance dates
      if (asset.lastMaintenanceDate != null &&
          asset.nextMaintenanceDate != null) {
        if (asset.nextMaintenanceDate!.isBefore(asset.lastMaintenanceDate!)) {
          print(
            'âŒ Data Quality: Next maintenance before last maintenance for asset ${asset.id}',
          );
          return false;
        }
      }

      return true;
    } catch (e, st) {
      print('âŒ Data Quality: Error validating asset ${asset.id}: $e');
      return false;
    }
  }

  /// Filter valid assets for analytics
  static Future<List<Asset>> filterValidAssets(List<Asset> assets) async {
    final validAssets = <Asset>[];

    for (final asset in assets) {
      if (await validateAssetData(asset)) {
        validAssets.add(asset);
      }
    }

    print(
      'ðŸ“Š Data Quality: ${validAssets.length}/${assets.length} assets are valid for analytics',
    );
    return validAssets;
  }

  /// Validate PM task data quality
  static Future<bool> validatePMTaskData(PMTask task) async {
    try {
      // Validate required fields
      if (task.id.isEmpty || task.taskName.isEmpty || task.assetId.isEmpty) {
        print(
            'âŒ Data Quality: Missing required fields for PM task ${task.id}',);
        return false;
      }

      // Validate dates
      if (task.lastCompletedAt != null && task.nextDueDate != null) {
        if (task.nextDueDate!.isBefore(task.lastCompletedAt!)) {
          print(
            'âŒ Data Quality: Next due date before last completed for PM task ${task.id}',
          );
          return false;
        }
      }

      return true;
    } catch (e, st) {
      print('âŒ Data Quality: Error validating PM task ${task.id}: $e');
      return false;
    }
  }

  /// Filter valid PM tasks for analytics
  static Future<List<PMTask>> filterValidPMTasks(List<PMTask> tasks) async {
    final validTasks = <PMTask>[];

    for (final task in tasks) {
      if (await validatePMTaskData(task)) {
        validTasks.add(task);
      }
    }

    print(
      'ðŸ“Š Data Quality: ${validTasks.length}/${tasks.length} PM tasks are valid for analytics',
    );
    return validTasks;
  }

  /// Check for duplicate work orders
  static List<WorkOrder> findDuplicateWorkOrders(List<WorkOrder> orders) {
    final duplicates = <WorkOrder>[];
    final seen = <String>{};

    for (final order in orders) {
      final key =
          '${order.assetId}_${order.problemDescription}_${order.createdAt.millisecondsSinceEpoch ~/ 86400000}';
      if (seen.contains(key)) {
        duplicates.add(order);
      } else {
        seen.add(key);
      }
    }

    if (duplicates.isNotEmpty) {
      print(
        'âš ï¸ Data Quality: Found ${duplicates.length} duplicate work orders',
      );
    }

    return duplicates;
  }

  /// Check for outlier work orders (unusually long durations)
  static List<WorkOrder> findOutlierWorkOrders(List<WorkOrder> orders) {
    final outliers = <WorkOrder>[];

    // Calculate average completion time
    final completedOrders = orders
        .where(
          (wo) =>
              wo.startedAt != null &&
              wo.completedAt != null &&
              wo.status == WorkOrderStatus.completed,
        )
        .toList();

    if (completedOrders.length < 3) return outliers;

    final durations = completedOrders
        .map((wo) => wo.completedAt!.difference(wo.startedAt!).inHours)
        .toList();

    durations.sort();
    // Calculate median for outlier detection
    durations[durations.length ~/ 2];
    final q1 = durations[durations.length ~/ 4];
    final q3 = durations[(durations.length * 3) ~/ 4];
    final iqr = q3 - q1;
    final upperBound = q3 + (1.5 * iqr);

    for (final order in completedOrders) {
      final duration = order.completedAt!.difference(order.startedAt!).inHours;
      if (duration > upperBound) {
        outliers.add(order);
      }
    }

    if (outliers.isNotEmpty) {
      print(
        'âš ï¸ Data Quality: Found ${outliers.length} outlier work orders (unusually long duration)',
      );
    }

    return outliers;
  }

  /// Calculate data freshness score
  static double calculateDataFreshness(List<WorkOrder> orders) {
    if (orders.isEmpty) return 0;

    final now = DateTime.now();
    final recentOrders =
        orders.where((wo) => now.difference(wo.updatedAt).inDays <= 7).length;

    return (recentOrders / orders.length) * 100;
  }

  /// Calculate overall data quality score
  static Future<double> calculateDataQualityScore(
    List<WorkOrder> workOrders,
    List<Asset> assets,
    List<PMTask> pmTasks,
  ) async {
    try {
      final validWorkOrders = await filterValidWorkOrders(workOrders);
      final validAssets = await filterValidAssets(assets);
      final validPMTasks = await filterValidPMTasks(pmTasks);

      final duplicates = findDuplicateWorkOrders(workOrders);
      final outliers = findOutlierWorkOrders(workOrders);
      final freshness = calculateDataFreshness(workOrders);

      // Calculate weighted score
      final workOrderScore = workOrders.isNotEmpty
          ? (validWorkOrders.length / workOrders.length) * 100
          : 100;
      final assetScore =
          assets.isNotEmpty ? (validAssets.length / assets.length) * 100 : 100;
      final pmTaskScore = pmTasks.isNotEmpty
          ? (validPMTasks.length / pmTasks.length) * 100
          : 100;

      final duplicatePenalty = (duplicates.length / workOrders.length) * 10;
      final outlierPenalty = (outliers.length / workOrders.length) * 5;
      final freshnessBonus = freshness * 0.1;

      final totalScore = (workOrderScore + assetScore + pmTaskScore) / 3 -
          duplicatePenalty -
          outlierPenalty +
          freshnessBonus;

      return totalScore.clamp(0.0, 100.0);
    } catch (e, st) {
      print('âŒ Data Quality: Error calculating quality score: $e');
      return 0.0;
    }
  }
}

/// Data quality report model
class DataQualityReport {
  DataQualityReport({
    required this.totalRecords,
    required this.incompleteRecords,
    required this.duplicateRecords,
    required this.outlierRecords,
    required this.dataFreshness,
    required this.accuracyScore,
    required this.generatedAt,
  });

  factory DataQualityReport.fromMap(Map<String, dynamic> map) =>
      DataQualityReport(
        totalRecords: map['totalRecords'] ?? 0,
        incompleteRecords: map['incompleteRecords'] ?? 0,
        duplicateRecords: map['duplicateRecords'] ?? 0,
        outlierRecords: map['outlierRecords'] ?? 0,
        dataFreshness: (map['dataFreshness'] ?? 0.0).toDouble(),
        accuracyScore: (map['accuracyScore'] ?? 0.0).toDouble(),
        generatedAt: DateTime.parse(
          map['generatedAt'] ?? DateTime.now().toIso8601String(),
        ),
      );

  final int totalRecords;
  final int incompleteRecords;
  final int duplicateRecords;
  final int outlierRecords;
  final double dataFreshness;
  final double accuracyScore;
  final DateTime generatedAt;

  Map<String, dynamic> toMap() => {
        'totalRecords': totalRecords,
        'incompleteRecords': incompleteRecords,
        'duplicateRecords': duplicateRecords,
        'outlierRecords': outlierRecords,
        'dataFreshness': dataFreshness,
        'accuracyScore': accuracyScore,
        'generatedAt': generatedAt.toIso8601String(),
      };
}
