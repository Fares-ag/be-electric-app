// Simplified Reporting Service - Basic reporting without external dependencies

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/asset.dart';
import '../models/inventory_item.dart';
import '../models/pm_task.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../models/work_order.dart';
import 'unified_data_service.dart';
import '../config/locator.dart';

enum ReportType {
  workOrderSummary,
  pmTaskSummary,
  technicianPerformance,
  assetMaintenance,
  costAnalysis,
  inventoryReport,
  escalationReport,
  systemHealth,
  custom,
}

enum ReportFormat {
  txt,
  csv,
  json,
}

enum ReportPeriod {
  today,
  yesterday,
  last7Days,
  last30Days,
  last90Days,
  lastYear,
  custom,
}

class ReportConfig {
  ReportConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.format,
    required this.period,
    this.startDate,
    this.endDate,
    this.filters = const {},
    this.groupBy,
    this.sortBy,
    this.includeCharts = false,
    this.includeDetails = true,
    this.includeSummary = true,
  });

  final String id;
  final String name;
  final ReportType type;
  final ReportFormat format;
  final ReportPeriod period;
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, dynamic> filters;
  final String? groupBy;
  final String? sortBy;
  final bool includeCharts;
  final bool includeDetails;
  final bool includeSummary;
}

class ReportData {
  ReportData({
    required this.config,
    required this.generatedAt,
    required this.data,
    this.filePath,
    this.fileSize,
    this.summary = const {},
  });

  final ReportConfig config;
  final DateTime generatedAt;
  final Map<String, dynamic> data;
  final String? filePath;
  final int? fileSize;
  final Map<String, dynamic> summary;
}

class SimplifiedReportingService {

  UnifiedDataService get _dataService => sl<UnifiedDataService>();
  final List<ReportData> _generatedReports = [];

  List<ReportData> get generatedReports => List.unmodifiable(_generatedReports);

  /// Generate report
  Future<ReportData> generateReport(ReportConfig config) async {
    try {
      debugPrint(
        '📊 SimplifiedReportingService: Generating report: ${config.name}',
      );

      final data = await _collectReportData(config);
      final reportData = ReportData(
        config: config,
        generatedAt: DateTime.now(),
        data: data,
      );

      // Generate file based on format
      String? filePath;
      int? fileSize;

      switch (config.format) {
        case ReportFormat.txt:
          filePath = await _generateText(reportData);
          break;
        case ReportFormat.csv:
          filePath = await _generateCSV(reportData);
          break;
        case ReportFormat.json:
          filePath = await _generateJSON(reportData);
          break;
      }

      final file = File(filePath);
      fileSize = await file.length();

      final finalReportData = ReportData(
        config: config,
        generatedAt: reportData.generatedAt,
        data: data,
        filePath: filePath,
        fileSize: fileSize,
        summary: reportData.summary,
      );

      _generatedReports.add(finalReportData);
      return finalReportData;
    } catch (e, st) {
      debugPrint('❌ SimplifiedReportingService: Error generating report: $e');
      rethrow;
    }
  }

  /// Collect report data
  Future<Map<String, dynamic>> _collectReportData(ReportConfig config) async {
    final dateRange = _getDateRange(config);
    final workOrders = _filterWorkOrders(dateRange, config.filters);
    final pmTasks = _filterPMTasks(dateRange, config.filters);
    final users = _dataService.users;
    final assets = _dataService.assets;
    final inventoryItems = _dataService.inventoryItems;

    switch (config.type) {
      case ReportType.workOrderSummary:
        return _generateWorkOrderSummary(workOrders, users, assets);
      case ReportType.pmTaskSummary:
        return _generatePMTaskSummary(pmTasks, users, assets);
      case ReportType.technicianPerformance:
        return _generateTechnicianPerformance(workOrders, pmTasks, users);
      case ReportType.assetMaintenance:
        return _generateAssetMaintenance(workOrders, pmTasks, assets);
      case ReportType.costAnalysis:
        return _generateCostAnalysis(workOrders, pmTasks);
      case ReportType.inventoryReport:
        return _generateInventoryReport(inventoryItems);
      case ReportType.escalationReport:
        return _generateEscalationReport();
      case ReportType.systemHealth:
        return _generateSystemHealthReport();
      case ReportType.custom:
        return _generateCustomReport(config);
      default:
        return {};
    }
  }

  /// Get date range for report
  Map<String, DateTime> _getDateRange(ReportConfig config) {
    final now = DateTime.now();
    DateTime startDate;
    var endDate = now;

    switch (config.period) {
      case ReportPeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(now.year, now.month, now.day);
        break;
      case ReportPeriod.last7Days:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case ReportPeriod.last30Days:
        startDate = now.subtract(const Duration(days: 30));
        break;
      case ReportPeriod.last90Days:
        startDate = now.subtract(const Duration(days: 90));
        break;
      case ReportPeriod.lastYear:
        startDate = now.subtract(const Duration(days: 365));
        break;
      case ReportPeriod.custom:
        startDate = config.startDate ?? now.subtract(const Duration(days: 30));
        endDate = config.endDate ?? now;
        break;
    }

    return {'start': startDate, 'end': endDate};
  }

  /// Filter work orders
  List<WorkOrder> _filterWorkOrders(
    Map<String, DateTime> dateRange,
    Map<String, dynamic> filters,
  ) =>
      _dataService.workOrders.where((wo) {
        // Date filter
        if (wo.createdAt.isBefore(dateRange['start']!) ||
            wo.createdAt.isAfter(dateRange['end']!)) {
          return false;
        }

        // Status filter
        if (filters.containsKey('status')) {
          final status = filters['status'] as WorkOrderStatus?;
          if (status != null && wo.status != status) return false;
        }

        // Priority filter
        if (filters.containsKey('priority')) {
          final priority = filters['priority'] as WorkOrderPriority?;
          if (priority != null && wo.priority != priority) return false;
        }

        // Technician filter
        if (filters.containsKey('technicianId')) {
          final technicianId = filters['technicianId'] as String?;
          if (technicianId != null && !wo.hasTechnician(technicianId)) {
            return false;
          }
        }

        return true;
      }).toList();

  /// Filter PM tasks
  List<PMTask> _filterPMTasks(
    Map<String, DateTime> dateRange,
    Map<String, dynamic> filters,
  ) =>
      _dataService.pmTasks.where((pt) {
        // Date filter
        if (pt.createdAt.isBefore(dateRange['start']!) ||
            pt.createdAt.isAfter(dateRange['end']!)) {
          return false;
        }

        // Status filter
        if (filters.containsKey('status')) {
          final status = filters['status'] as PMTaskStatus?;
          if (status != null && pt.status != status) return false;
        }

        // Technician filter
        if (filters.containsKey('technicianId')) {
          final technicianId = filters['technicianId'] as String?;
          if (technicianId != null && !pt.hasTechnician(technicianId)) {
            return false;
          }
        }

        return true;
      }).toList();

  /// Generate work order summary
  Map<String, dynamic> _generateWorkOrderSummary(
    List<WorkOrder> workOrders,
    List<User> users,
    List<Asset> assets,
  ) {
    final totalWorkOrders = workOrders.length;
    final completedWorkOrders =
        workOrders.where((wo) => wo.status == WorkOrderStatus.completed).length;
    final inProgressWorkOrders = workOrders
        .where((wo) => wo.status == WorkOrderStatus.inProgress)
        .length;
    final pendingWorkOrders =
        workOrders.where((wo) => wo.status == WorkOrderStatus.open).length;
    final overdueWorkOrders = workOrders.where(_isOverdue).length;

    final completionRate =
        totalWorkOrders > 0 ? (completedWorkOrders / totalWorkOrders) * 100 : 0;
    final averageCompletionTime = _calculateAverageCompletionTime(workOrders);

    final statusBreakdown = <String, int>{};
    for (final status in WorkOrderStatus.values) {
      statusBreakdown[status.toString().split('.').last] =
          workOrders.where((wo) => wo.status == status).length;
    }

    final priorityBreakdown = <String, int>{};
    for (final priority in WorkOrderPriority.values) {
      priorityBreakdown[priority.toString().split('.').last] =
          workOrders.where((wo) => wo.priority == priority).length;
    }

    return {
      'summary': {
        'totalWorkOrders': totalWorkOrders,
        'completedWorkOrders': completedWorkOrders,
        'inProgressWorkOrders': inProgressWorkOrders,
        'pendingWorkOrders': pendingWorkOrders,
        'overdueWorkOrders': overdueWorkOrders,
        'completionRate': completionRate,
        'averageCompletionTime': averageCompletionTime,
      },
      'statusBreakdown': statusBreakdown,
      'priorityBreakdown': priorityBreakdown,
      'workOrders': workOrders.map(_workOrderToMap).toList(),
    };
  }

  /// Generate PM task summary
  Map<String, dynamic> _generatePMTaskSummary(
    List<PMTask> pmTasks,
    List<User> users,
    List<Asset> assets,
  ) {
    final totalPMTasks = pmTasks.length;
    final completedPMTasks =
        pmTasks.where((pt) => pt.status == PMTaskStatus.completed).length;
    final pendingPMTasks =
        pmTasks.where((pt) => pt.status == PMTaskStatus.pending).length;
    final overduePMTasks = pmTasks.where(_isPMTaskOverdue).length;

    final completionRate =
        totalPMTasks > 0 ? (completedPMTasks / totalPMTasks) * 100 : 0;

    final statusBreakdown = <String, int>{};
    for (final status in PMTaskStatus.values) {
      statusBreakdown[status.toString().split('.').last] =
          pmTasks.where((pt) => pt.status == status).length;
    }

    final frequencyBreakdown = <String, int>{};
    for (final frequency in PMTaskFrequency.values) {
      frequencyBreakdown[frequency.toString().split('.').last] =
          pmTasks.where((pt) => pt.frequency == frequency).length;
    }

    return {
      'summary': {
        'totalPMTasks': totalPMTasks,
        'completedPMTasks': completedPMTasks,
        'pendingPMTasks': pendingPMTasks,
        'overduePMTasks': overduePMTasks,
        'completionRate': completionRate,
      },
      'statusBreakdown': statusBreakdown,
      'frequencyBreakdown': frequencyBreakdown,
      'pmTasks': pmTasks.map(_pmTaskToMap).toList(),
    };
  }

  /// Generate technician performance report
  Map<String, dynamic> _generateTechnicianPerformance(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
    List<User> users,
  ) {
    final technicians =
        users.where((u) => u.role == UserRole.technician).toList();
    final performance = <String, Map<String, dynamic>>{};

    for (final technician in technicians) {
      final technicianWorkOrders = workOrders
          .where((wo) => wo.hasTechnician(technician.id))
          .toList();
      final technicianPMTasks = pmTasks
          .where((pt) => pt.hasTechnician(technician.id))
          .toList();

      final completedWorkOrders = technicianWorkOrders
          .where((wo) => wo.status == WorkOrderStatus.completed)
          .length;
      final completedPMTasks = technicianPMTasks
          .where((pt) => pt.status == PMTaskStatus.completed)
          .length;

      final averageCompletionTime =
          _calculateTechnicianAverageCompletionTime(technicianWorkOrders);
      final totalCost = _calculateTechnicianTotalCost(technicianWorkOrders);

      performance[technician.id] = {
        'technicianName': technician.name,
        'totalWorkOrders': technicianWorkOrders.length,
        'completedWorkOrders': completedWorkOrders,
        'totalPMTasks': technicianPMTasks.length,
        'completedPMTasks': completedPMTasks,
        'completionRate': technicianWorkOrders.isNotEmpty
            ? (completedWorkOrders / technicianWorkOrders.length) * 100
            : 0,
        'averageCompletionTime': averageCompletionTime,
        'totalCost': totalCost,
        'efficiency': _calculateTechnicianEfficiency(
          technicianWorkOrders,
          technicianPMTasks,
        ),
      };
    }

    return {
      'technicians': performance,
      'summary': _calculatePerformanceSummary(performance),
    };
  }

  /// Generate asset maintenance report
  Map<String, dynamic> _generateAssetMaintenance(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
    List<Asset> assets,
  ) {
    final assetMaintenance = <String, Map<String, dynamic>>{};

    for (final asset in assets) {
      final assetWorkOrders =
          workOrders.where((wo) => wo.assetId == asset.id).toList();
      final assetPMTasks =
          pmTasks.where((pt) => pt.assetId == asset.id).toList();

      final totalMaintenanceEvents =
          assetWorkOrders.length + assetPMTasks.length;
      final criticalWorkOrders = assetWorkOrders
          .where((wo) => wo.priority == WorkOrderPriority.critical)
          .length;
      final lastMaintenance =
          _getLastMaintenanceDate(assetWorkOrders, assetPMTasks);

      assetMaintenance[asset.id] = {
        'assetName': asset.name,
        'assetLocation': asset.location,
        'totalWorkOrders': assetWorkOrders.length,
        'totalPMTasks': assetPMTasks.length,
        'totalMaintenanceEvents': totalMaintenanceEvents,
        'criticalWorkOrders': criticalWorkOrders,
        'lastMaintenance': lastMaintenance?.toIso8601String(),
        'maintenanceFrequency':
            _calculateMaintenanceFrequency(assetWorkOrders, assetPMTasks),
        'reliability':
            _calculateAssetReliability(assetWorkOrders, assetPMTasks),
      };
    }

    return {
      'assets': assetMaintenance,
      'summary': _calculateAssetMaintenanceSummary(assetMaintenance),
    };
  }

  /// Generate cost analysis report
  Map<String, dynamic> _generateCostAnalysis(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
  ) {
    final totalLaborCost =
        workOrders.fold<double>(0, (sum, wo) => sum + (wo.laborCost ?? 0));
    final totalPartsCost =
        workOrders.fold<double>(0, (sum, wo) => sum + (wo.partsCost ?? 0));
    final totalCost = totalLaborCost + totalPartsCost;

    final costByPriority = <String, double>{};
    for (final priority in WorkOrderPriority.values) {
      final priorityWorkOrders =
          workOrders.where((wo) => wo.priority == priority);
      costByPriority[priority.toString().split('.').last] = priorityWorkOrders
          .fold<double>(0, (sum, wo) => sum + (wo.totalCost ?? 0));
    }

    final costByStatus = <String, double>{};
    for (final status in WorkOrderStatus.values) {
      final statusWorkOrders = workOrders.where((wo) => wo.status == status);
      costByStatus[status.toString().split('.').last] = statusWorkOrders
          .fold<double>(0, (sum, wo) => sum + (wo.totalCost ?? 0));
    }

    return {
      'summary': {
        'totalLaborCost': totalLaborCost,
        'totalPartsCost': totalPartsCost,
        'totalCost': totalCost,
        'averageCostPerWorkOrder':
            workOrders.isNotEmpty ? totalCost / workOrders.length : 0,
      },
      'costByPriority': costByPriority,
      'costByStatus': costByStatus,
      'monthlyCosts': _calculateMonthlyCosts(workOrders),
    };
  }

  /// Generate inventory report
  Map<String, dynamic> _generateInventoryReport(
    List<InventoryItem> inventoryItems,
  ) {
    final totalItems = inventoryItems.length;
    final lowStockItems =
        inventoryItems.where((item) => item.quantity <= 10).length;
    final outOfStockItems =
        inventoryItems.where((item) => item.quantity == 0).length;

    final categoryBreakdown = <String, int>{};
    for (final item in inventoryItems) {
      final category = item.category;
      categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
    }

    return {
      'summary': {
        'totalItems': totalItems,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
      },
      'categoryBreakdown': categoryBreakdown,
      'lowStockItems': inventoryItems
          .where((item) => item.quantity <= 10)
          .map(_inventoryItemToMap)
          .toList(),
      'inventoryItems': inventoryItems.map(_inventoryItemToMap).toList(),
    };
  }

  /// Generate text report
  Future<String> _generateText(ReportData reportData) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final file = File(filePath);

    final content = '''
Report: ${reportData.config.name}
Generated: ${reportData.generatedAt.toIso8601String()}

Report Data:
${jsonEncode(reportData.data)}
''';

    await file.writeAsString(content);
    return filePath;
  }

  /// Generate CSV report
  Future<String> _generateCSV(ReportData reportData) async {
    final csvContent = StringBuffer();
    csvContent.writeln('Report,${reportData.config.name}');
    csvContent.writeln('Generated,${reportData.generatedAt.toIso8601String()}');
    csvContent.writeln();

    for (final entry in reportData.data.entries) {
      csvContent.writeln('${entry.key},${entry.value}');
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(filePath);
    await file.writeAsString(csvContent.toString());

    return filePath;
  }

  /// Generate JSON report
  Future<String> _generateJSON(ReportData reportData) async {
    final jsonContent = jsonEncode({
      'config': {
        'id': reportData.config.id,
        'name': reportData.config.name,
        'type': reportData.config.type.toString(),
        'format': reportData.config.format.toString(),
        'period': reportData.config.period.toString(),
      },
      'generatedAt': reportData.generatedAt.toIso8601String(),
      'data': reportData.data,
    });

    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(filePath);
    await file.writeAsString(jsonContent);

    return filePath;
  }

  // Helper methods
  bool _isOverdue(WorkOrder workOrder) {
    if (workOrder.status == WorkOrderStatus.closed ||
        workOrder.status == WorkOrderStatus.cancelled) {
      return false;
    }

    final now = DateTime.now();
    final daysSinceCreated = now.difference(workOrder.createdAt).inDays;
    return daysSinceCreated > 7;
  }

  bool _isPMTaskOverdue(PMTask pmTask) {
    if (pmTask.status == PMTaskStatus.completed ||
        pmTask.status == PMTaskStatus.cancelled) {
      return false;
    }

    if (pmTask.nextDueDate == null) return false;
    return DateTime.now().isAfter(pmTask.nextDueDate!);
  }

  Duration _calculateAverageCompletionTime(List<WorkOrder> workOrders) {
    final completedWorkOrders = workOrders
        .where((wo) => wo.status == WorkOrderStatus.completed)
        .toList();
    if (completedWorkOrders.isEmpty) return Duration.zero;

    final totalDuration =
        completedWorkOrders.fold<Duration>(Duration.zero, (sum, wo) {
      if (wo.startedAt != null && wo.completedAt != null) {
        return sum + wo.completedAt!.difference(wo.startedAt!);
      }
      return sum;
    });

    return Duration(
      milliseconds: totalDuration.inMilliseconds ~/ completedWorkOrders.length,
    );
  }

  Duration _calculateTechnicianAverageCompletionTime(
    List<WorkOrder> workOrders,
  ) =>
      _calculateAverageCompletionTime(workOrders);

  double _calculateTechnicianTotalCost(List<WorkOrder> workOrders) =>
      workOrders.fold<double>(0, (sum, wo) => sum + (wo.totalCost ?? 0));

  double _calculateTechnicianEfficiency(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
  ) {
    final totalTasks = workOrders.length + pmTasks.length;
    if (totalTasks == 0) return 0;

    final completedTasks = workOrders
            .where((wo) => wo.status == WorkOrderStatus.completed)
            .length +
        pmTasks.where((pt) => pt.status == PMTaskStatus.completed).length;

    return (completedTasks / totalTasks) * 100;
  }

  Map<String, dynamic> _calculatePerformanceSummary(
    Map<String, Map<String, dynamic>> performance,
  ) {
    if (performance.isEmpty) return {};

    final totalWorkOrders = performance.values
        .fold<int>(0, (sum, p) => sum + (p['totalWorkOrders'] as int));
    final totalCompleted = performance.values
        .fold<int>(0, (sum, p) => sum + (p['completedWorkOrders'] as int));
    final averageEfficiency = performance.values
            .fold<double>(0, (sum, p) => sum + (p['efficiency'] as double)) /
        performance.length;

    return {
      'totalWorkOrders': totalWorkOrders,
      'totalCompleted': totalCompleted,
      'overallCompletionRate':
          totalWorkOrders > 0 ? (totalCompleted / totalWorkOrders) * 100 : 0,
      'averageEfficiency': averageEfficiency,
    };
  }

  DateTime? _getLastMaintenanceDate(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
  ) {
    DateTime? lastDate;

    for (final wo in workOrders) {
      if (wo.completedAt != null &&
          (lastDate == null || wo.completedAt!.isAfter(lastDate))) {
        lastDate = wo.completedAt;
      }
    }

    for (final pt in pmTasks) {
      if (pt.completedAt != null &&
          (lastDate == null || pt.completedAt!.isAfter(lastDate))) {
        lastDate = pt.completedAt;
      }
    }

    return lastDate;
  }

  double _calculateMaintenanceFrequency(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
  ) {
    final totalEvents = workOrders.length + pmTasks.length;
    if (totalEvents == 0) return 0;

    final now = DateTime.now();
    final daysSinceFirst = workOrders.isNotEmpty
        ? now.difference(workOrders.first.createdAt).inDays
        : 365;

    return totalEvents / (daysSinceFirst / 30); // Events per month
  }

  double _calculateAssetReliability(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
  ) {
    final totalEvents = workOrders.length + pmTasks.length;
    if (totalEvents == 0) return 100;

    final criticalEvents = workOrders
        .where((wo) => wo.priority == WorkOrderPriority.critical)
        .length;
    return ((totalEvents - criticalEvents) / totalEvents) * 100;
  }

  Map<String, dynamic> _calculateAssetMaintenanceSummary(
    Map<String, Map<String, dynamic>> assetMaintenance,
  ) {
    if (assetMaintenance.isEmpty) return {};

    final totalAssets = assetMaintenance.length;
    final totalEvents = assetMaintenance.values.fold<int>(
      0,
      (sum, asset) => sum + (asset['totalMaintenanceEvents'] as int),
    );
    final criticalAssets = assetMaintenance.values
        .where((asset) => (asset['criticalWorkOrders'] as int) > 0)
        .length;

    return {
      'totalAssets': totalAssets,
      'totalMaintenanceEvents': totalEvents,
      'criticalAssets': criticalAssets,
      'averageEventsPerAsset': totalAssets > 0 ? totalEvents / totalAssets : 0,
    };
  }

  List<Map<String, dynamic>> _calculateMonthlyCosts(
    List<WorkOrder> workOrders,
  ) {
    final monthlyCosts = <String, double>{};

    for (final wo in workOrders) {
      if (wo.totalCost != null && wo.totalCost! > 0) {
        final monthKey =
            '${wo.createdAt.year}-${wo.createdAt.month.toString().padLeft(2, '0')}';
        monthlyCosts[monthKey] = (monthlyCosts[monthKey] ?? 0) + wo.totalCost!;
      }
    }

    return monthlyCosts.entries
        .map((e) => {'month': e.key, 'cost': e.value})
        .toList();
  }

  Map<String, dynamic> _workOrderToMap(WorkOrder wo) => {
        'id': wo.id,
        'ticketNumber': wo.ticketNumber,
        'assetName': wo.assetName,
        'status': wo.status.toString(),
        'priority': wo.priority.toString(),
        'createdAt': wo.createdAt.toIso8601String(),
        'completedAt': wo.completedAt?.toIso8601String(),
        'totalCost': wo.totalCost,
      };

  Map<String, dynamic> _pmTaskToMap(PMTask pt) => {
        'id': pt.id,
        'taskName': pt.taskName,
        'status': pt.status.toString(),
        'frequency': pt.frequency.toString(),
        'createdAt': pt.createdAt.toIso8601String(),
        'completedAt': pt.completedAt?.toIso8601String(),
      };

  Map<String, dynamic> _inventoryItemToMap(InventoryItem item) => {
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'quantity': item.quantity,
      };

  Map<String, dynamic> _generateEscalationReport() {
    // TODO: Implement escalation report
    return {};
  }

  Map<String, dynamic> _generateSystemHealthReport() {
    // TODO: Implement system health report
    return {};
  }

  Map<String, dynamic> _generateCustomReport(ReportConfig config) {
    // TODO: Implement custom report based on config
    return {};
  }
}
