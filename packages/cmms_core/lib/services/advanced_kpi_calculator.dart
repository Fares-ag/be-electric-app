// Advanced KPI calculation service for accurate analytics

import 'dart:math';

import '../models/analytics_models.dart';
import '../models/asset.dart';
import '../models/pm_task.dart';
import '../models/user.dart';
import '../models/work_order.dart';
import 'data_quality_service.dart';

class AdvancedKPICalculator {
  /// Calculate accurate MTTR (Mean Time To Repair) with data validation
  static double calculateAccurateMTTR(List<WorkOrder> workOrders) {
    try {
      // Filter valid work orders with complete time data
      final validWorkOrders = workOrders
          .where(
            (wo) =>
                wo.startedAt != null &&
                wo.completedAt != null &&
                wo.status == WorkOrderStatus.completed &&
                wo.completedAt!.isAfter(wo.startedAt!),
          )
          .toList();

      if (validWorkOrders.isEmpty) {
        print('📊 Advanced KPI: No valid work orders for MTTR calculation');
        return 0;
      }

      // Calculate repair times
      final repairTimes = validWorkOrders
          .map((wo) => wo.completedAt!.difference(wo.startedAt!).inMinutes)
          .toList();

      // Remove outliers using IQR method
      final filteredTimes = _removeOutliers(repairTimes);

      if (filteredTimes.isEmpty) {
        print('📊 Advanced KPI: All repair times were outliers');
        return 0;
      }

      // Calculate mean
      final totalMinutes =
          filteredTimes.fold<int>(0, (sum, time) => sum + time);
      final meanMinutes = totalMinutes / filteredTimes.length;

      print(
        '📊 Advanced KPI: MTTR calculated from ${filteredTimes.length} valid work orders',
      );
      return meanMinutes / 60.0; // Convert to hours
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating MTTR: $e');
      return 0;
    }
  }

  /// Calculate asset-specific MTBF (Mean Time Between Failures)
  static Map<String, double> calculateAssetMTBF(
    List<WorkOrder> workOrders,
    List<Asset> assets,
  ) {
    final assetMTBF = <String, double>{};

    try {
      for (final asset in assets) {
        // Get completed work orders for this asset, sorted by creation date
        final assetWorkOrders = workOrders
            .where(
              (wo) =>
                  wo.assetId == asset.id &&
                  wo.status == WorkOrderStatus.completed,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (assetWorkOrders.length < 2) {
          assetMTBF[asset.id] = 0.0;
          continue;
        }

        // Calculate intervals between failures
        final intervals = <Duration>[];
        for (var i = 1; i < assetWorkOrders.length; i++) {
          final interval = assetWorkOrders[i]
              .createdAt
              .difference(assetWorkOrders[i - 1].createdAt);
          intervals.add(interval);
        }

        if (intervals.isEmpty) {
          assetMTBF[asset.id] = 0.0;
          continue;
        }

        // Calculate mean interval
        final totalHours =
            intervals.fold<int>(0, (sum, interval) => sum + interval.inHours);
        final meanHours = totalHours / intervals.length;

        assetMTBF[asset.id] = meanHours;
      }

      print('📊 Advanced KPI: Calculated MTBF for ${assetMTBF.length} assets');
      return assetMTBF;
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating asset MTBF: $e');
      return {};
    }
  }

  /// Calculate overall MTBF
  static double calculateOverallMTBF(
    List<WorkOrder> workOrders,
    List<Asset> assets,
  ) {
    final assetMTBF = calculateAssetMTBF(workOrders, assets);
    final validMTBFs = assetMTBF.values.where((mtbf) => mtbf > 0).toList();

    if (validMTBFs.isEmpty) return 0;

    return validMTBFs.reduce((a, b) => a + b) / validMTBFs.length;
  }

  /// Calculate accurate asset uptime percentage
  static double calculateAssetUptime(
    String assetId,
    List<WorkOrder> workOrders,
  ) {
    try {
      final assetWorkOrders = workOrders
          .where(
            (wo) =>
                wo.assetId == assetId && wo.status == WorkOrderStatus.completed,
          )
          .toList();

      if (assetWorkOrders.isEmpty) return 100; // No failures = 100% uptime

      // Calculate total downtime
      final totalDowntime =
          assetWorkOrders.fold<Duration>(Duration.zero, (sum, wo) {
        if (wo.startedAt != null && wo.completedAt != null) {
          return sum + wo.completedAt!.difference(wo.startedAt!);
        }
        return sum;
      });

      // Assume 30 days period for calculation
      const totalTime = Duration(days: 30);
      final uptime = totalTime - totalDowntime;

      return (uptime.inMinutes / totalTime.inMinutes * 100).clamp(0.0, 100.0);
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating asset uptime for $assetId: $e');
      return 0;
    }
  }

  /// Calculate technician efficiency with multiple factors
  static double calculateTechnicianEfficiency(
    String technicianId,
    List<WorkOrder> workOrders,
  ) {
    try {
      final technicianWorkOrders =
          workOrders.where((wo) => wo.hasTechnician(technicianId)).toList();

      if (technicianWorkOrders.isEmpty) return 0;

      // Calculate completion rate
      final completedOrders = technicianWorkOrders
          .where((wo) => wo.status == WorkOrderStatus.completed)
          .length;
      final completionRate = completedOrders / technicianWorkOrders.length;

      // Calculate average response time
      final responseTimes = technicianWorkOrders
          .where((wo) => wo.assignedAt != null && wo.startedAt != null)
          .map((wo) => wo.startedAt!.difference(wo.assignedAt!).inHours)
          .toList();

      final avgResponseTime = responseTimes.isNotEmpty
          ? responseTimes.reduce((a, b) => a + b) / responseTimes.length
          : 0.0;

      // Calculate quality score (based on repeat failures)
      final repeatFailures = technicianWorkOrders
          .where((wo) => wo.isRepeatFailure ?? false)
          .length;
      final qualityScore = 1.0 - (repeatFailures / technicianWorkOrders.length);

      // Weighted efficiency calculation
      final efficiency = (completionRate * 0.4) +
          ((24 - avgResponseTime.clamp(0, 24)) / 24 * 0.3) +
          (qualityScore * 0.3);

      return (efficiency * 100).clamp(0.0, 100.0);
    } catch (e, st) {
      print(
        '❌ Advanced KPI: Error calculating technician efficiency for $technicianId: $e',
      );
      return 0;
    }
  }

  /// Calculate average response time with data validation
  static double calculateAverageResponseTime(List<WorkOrder> workOrders) {
    try {
      final validWorkOrders = workOrders
          .where((wo) => wo.assignedAt != null && wo.startedAt != null)
          .toList();

      if (validWorkOrders.isEmpty) return 0;

      final responseTimes = validWorkOrders
          .map((wo) => wo.startedAt!.difference(wo.assignedAt!).inHours)
          .toList();

      // Remove outliers
      final filteredTimes = _removeOutliers(responseTimes);

      if (filteredTimes.isEmpty) return 0;

      final totalHours =
          filteredTimes.fold<double>(0, (sum, time) => sum + time);
      return totalHours / filteredTimes.length;
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating average response time: $e');
      return 0;
    }
  }

  /// Calculate cost efficiency metrics
  static Map<String, double> calculateCostEfficiency(
    List<WorkOrder> workOrders,
  ) {
    try {
      final completedWorkOrders = workOrders
          .where(
            (wo) =>
                wo.status == WorkOrderStatus.completed && wo.totalCost != null,
          )
          .toList();

      if (completedWorkOrders.isEmpty) {
        return {
          'averageCost': 0.0,
          'costVariance': 0.0,
          'costTrend': 0.0,
        };
      }

      final costs = completedWorkOrders.map((wo) => wo.totalCost!).toList();
      final averageCost = costs.reduce((a, b) => a + b) / costs.length;

      // Calculate variance
      final variance = costs.fold<double>(
            0,
            (sum, cost) => sum + pow(cost - averageCost, 2),
          ) /
          costs.length;
      final costVariance = sqrt(variance);

      // Calculate trend (simplified)
      final sortedOrders = completedWorkOrders
        ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
      final recentCosts =
          sortedOrders.take(10).map((wo) => wo.totalCost!).toList();
      final olderCosts = sortedOrders
          .skip(max(0, sortedOrders.length - 20))
          .take(10)
          .map((wo) => wo.totalCost!)
          .toList();

      final recentAvg = recentCosts.isNotEmpty
          ? recentCosts.reduce((a, b) => a + b) / recentCosts.length
          : 0.0;
      final olderAvg = olderCosts.isNotEmpty
          ? olderCosts.reduce((a, b) => a + b) / olderCosts.length
          : 0.0;

      final costTrend =
          olderAvg > 0 ? ((recentAvg - olderAvg) / olderAvg) * 100 : 0.0;

      return {
        'averageCost': averageCost,
        'costVariance': costVariance,
        'costTrend': costTrend,
      };
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating cost efficiency: $e');
      return {
        'averageCost': 0.0,
        'costVariance': 0.0,
        'costTrend': 0.0,
      };
    }
  }

  /// Calculate predictive failure indicators
  static Map<String, dynamic> calculatePredictiveIndicators(
    List<WorkOrder> workOrders,
    List<Asset> assets,
  ) {
    try {
      final assetFailures = <String, List<WorkOrder>>{};

      // Group work orders by asset
      for (final workOrder in workOrders) {
        if (workOrder.status == WorkOrderStatus.completed &&
            workOrder.assetId != null) {
          assetFailures
              .putIfAbsent(workOrder.assetId!, () => [])
              .add(workOrder);
        }
      }

      final highRiskAssets = <String>[];
      final failurePatterns = <String, String>{};

      for (final entry in assetFailures.entries) {
        final assetId = entry.key;
        final failures = entry.value;

        if (failures.length >= 3) {
          // Check for increasing frequency
          failures.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          final intervals = <Duration>[];

          for (var i = 1; i < failures.length; i++) {
            intervals.add(
              failures[i].createdAt.difference(failures[i - 1].createdAt),
            );
          }

          if (intervals.length >= 2) {
            final recentInterval = intervals.last;
            final totalInterval = intervals.fold<Duration>(
              Duration.zero,
              (sum, interval) => sum + interval,
            );
            final avgInterval = Duration(
              milliseconds: totalInterval.inMilliseconds ~/ intervals.length,
            );

            if (recentInterval.inMilliseconds <
                avgInterval.inMilliseconds * 0.7) {
              highRiskAssets.add(assetId);
              failurePatterns[assetId] = 'Increasing frequency';
            }
          }

          // Check for repeat failures
          final repeatFailures =
              failures.where((wo) => wo.isRepeatFailure ?? false).length;
          if (repeatFailures >= 2) {
            highRiskAssets.add(assetId);
            failurePatterns[assetId] = 'Repeat failures';
          }
        }
      }

      return {
        'highRiskAssets': highRiskAssets,
        'failurePatterns': failurePatterns,
        'riskScore':
            (highRiskAssets.length / assets.length * 100).clamp(0.0, 100.0),
      };
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating predictive indicators: $e');
      return {
        'highRiskAssets': <String>[],
        'failurePatterns': <String, String>{},
        'riskScore': 0.0,
      };
    }
  }

  /// Calculate comprehensive KPI metrics with data quality validation
  static Future<KPIMetrics> calculateComprehensiveKPIs(
    List<WorkOrder> workOrders,
    List<Asset> assets,
    List<PMTask> pmTasks,
    List<User> users,
  ) async {
    try {
      // Validate data quality first
      final validWorkOrders =
          await DataQualityService.filterValidWorkOrders(workOrders);
      final validAssets = await DataQualityService.filterValidAssets(assets);
      final validPMTasks = await DataQualityService.filterValidPMTasks(pmTasks);

      print(
        '📊 Advanced KPI: Using ${validWorkOrders.length}/${workOrders.length} valid work orders',
      );
      print(
        '📊 Advanced KPI: Using ${validAssets.length}/${assets.length} valid assets',
      );
      print(
        '📊 Advanced KPI: Using ${validPMTasks.length}/${pmTasks.length} valid PM tasks',
      );

      // Calculate core metrics
      final mttr = calculateAccurateMTTR(validWorkOrders);
      final mtbf = calculateOverallMTBF(validWorkOrders, validAssets);
      final avgResponseTime = calculateAverageResponseTime(validWorkOrders);

      // Calculate completion rates
      final totalWorkOrders = validWorkOrders.length;
      final completedWorkOrders = validWorkOrders
          .where((wo) => wo.status == WorkOrderStatus.completed)
          .length;
      final overdueWorkOrders =
          validWorkOrders.where((wo) => wo.isOverdue).length;
      final completionRate = totalWorkOrders > 0
          ? (completedWorkOrders / totalWorkOrders) * 100
          : 0.0;

      // Calculate asset uptime
      final assetUptimes = validAssets
          .map((asset) => calculateAssetUptime(asset.id, validWorkOrders))
          .toList();
      final overallUptime = assetUptimes.isNotEmpty
          ? assetUptimes.reduce((a, b) => a + b) / assetUptimes.length
          : 100.0;

      // Calculate technician efficiency
      final technicianEfficiencies = users
          .where((user) => user.role == 'technician')
          .map(
            (user) => calculateTechnicianEfficiency(user.id, validWorkOrders),
          )
          .toList();
      final avgTechnicianEfficiency = technicianEfficiencies.isNotEmpty
          ? technicianEfficiencies.reduce((a, b) => a + b) /
              technicianEfficiencies.length
          : 0.0;

      // Calculate TAT and Compliance metrics
      final averageTAT = _calculateAverageTAT(validWorkOrders);
      final complianceRate = _calculateComplianceRate(validWorkOrders);

      return KPIMetrics(
        mttr: mttr,
        mtbf: mtbf,
        assetUptime: overallUptime,
        technicianEfficiency: avgTechnicianEfficiency,
        totalWorkOrders: totalWorkOrders,
        completedWorkOrders: completedWorkOrders,
        overdueWorkOrders: overdueWorkOrders,
        completionRate: completionRate,
        averageResponseTime: avgResponseTime,
        averageTAT: averageTAT,
        complianceRate: complianceRate,
      );
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating comprehensive KPIs: $e');
      return const KPIMetrics(
        mttr: 0,
        mtbf: 0,
        assetUptime: 0,
        technicianEfficiency: 0,
        totalWorkOrders: 0,
        completedWorkOrders: 0,
        overdueWorkOrders: 0,
        completionRate: 0,
        averageResponseTime: 0,
        averageTAT: 0,
        complianceRate: 0,
      );
    }
  }

  /// Calculate Average Turnaround Time (TAT) in days
  static double _calculateAverageTAT(List<WorkOrder> workOrders) {
    try {
      final completedWorkOrders = workOrders
          .where((wo) => wo.status == WorkOrderStatus.completed)
          .toList();

      if (completedWorkOrders.isEmpty) return 0;

      var totalTAT = 0.0;
      for (final workOrder in completedWorkOrders) {
        if (workOrder.completedAt != null) {
          final tatInDays = workOrder.completedAt!
              .difference(workOrder.createdAt)
              .inDays
              .toDouble();
          totalTAT += tatInDays;
        }
      }

      return totalTAT / completedWorkOrders.length;
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating average TAT: $e');
      return 0;
    }
  }

  /// Calculate Compliance Rate percentage
  static double _calculateComplianceRate(List<WorkOrder> workOrders) {
    try {
      final completedWorkOrders = workOrders
          .where((wo) => wo.status == WorkOrderStatus.completed)
          .toList();

      if (completedWorkOrders.isEmpty) return 0;

      var onTimeCount = 0;
      for (final workOrder in completedWorkOrders) {
        if (workOrder.completedAt != null) {
          // Calculate expected completion time based on priority
          final expectedDays = _getExpectedCompletionDays(workOrder.priority);
          final expectedCompletion =
              workOrder.createdAt.add(Duration(days: expectedDays));

          // Check if completed on or before expected completion date
          if (workOrder.completedAt!.isBefore(expectedCompletion) ||
              workOrder.completedAt!.isAtSameMomentAs(expectedCompletion)) {
            onTimeCount++;
          }
        }
      }

      return (onTimeCount / completedWorkOrders.length) * 100;
    } catch (e, st) {
      print('❌ Advanced KPI: Error calculating compliance rate: $e');
      return 0;
    }
  }

  /// Get expected completion days based on priority
  static int _getExpectedCompletionDays(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.critical:
        return 1; // 1 day for critical
      case WorkOrderPriority.high:
        return 3; // 3 days for high
      case WorkOrderPriority.urgent:
        return 2; // 2 days for urgent
      case WorkOrderPriority.medium:
        return 7; // 1 week for medium
      case WorkOrderPriority.low:
        return 14; // 2 weeks for low
    }
  }

  /// Remove outliers using IQR (Interquartile Range) method
  static List<int> _removeOutliers(List<int> values) {
    if (values.length < 4) return values;

    values.sort();
    final q1Index = values.length ~/ 4;
    final q3Index = (values.length * 3) ~/ 4;

    final q1 = values[q1Index];
    final q3 = values[q3Index];
    final iqr = q3 - q1;

    final lowerBound = q1 - (1.5 * iqr);
    final upperBound = q3 + (1.5 * iqr);

    return values
        .where((value) => value >= lowerBound && value <= upperBound)
        .toList();
  }

  /// Remove outliers for double values
  static List<double> _removeOutliersDouble(List<double> values) {
    if (values.length < 4) return values;

    values.sort();
    final q1Index = values.length ~/ 4;
    final q3Index = (values.length * 3) ~/ 4;

    final q1 = values[q1Index];
    final q3 = values[q3Index];
    final iqr = q3 - q1;

    final lowerBound = q1 - (1.5 * iqr);
    final upperBound = q3 + (1.5 * iqr);

    return values
        .where((value) => value >= lowerBound && value <= upperBound)
        .toList();
  }
}
