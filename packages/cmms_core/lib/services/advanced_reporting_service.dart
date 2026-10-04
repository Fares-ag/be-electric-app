// Advanced Reporting Service - Comprehensive reporting and analytics

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'dart:ui' as ui;
import 'package:universal_html/html.dart' as html;

import '../models/asset.dart';
import '../models/inventory_item.dart';
import '../models/pm_task.dart';
import '../models/user.dart';
import '../models/work_order.dart';
import '../utils/work_order_duration.dart';
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
  pdf,
  excel,
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
    this.includeCharts = true,
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
    this.charts = const [],
    this.summary = const {},
  });

  final ReportConfig config;
  final DateTime generatedAt;
  final Map<String, dynamic> data;
  final String? filePath;
  final int? fileSize;
  final List<Map<String, dynamic>> charts;
  final Map<String, dynamic> summary;
}

class AdvancedReportingService {

  UnifiedDataService get _dataService => sl<UnifiedDataService>();
  final List<ReportData> _generatedReports = [];

  List<ReportData> get generatedReports => List.unmodifiable(_generatedReports);

  /// Generate report
  Future<ReportData> generateReport(ReportConfig config) async {
    try {
      debugPrint(
        '📊 AdvancedReportingService: Generating report: ${config.name}',
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
        case ReportFormat.pdf:
          filePath = await _generatePDF(reportData);
          break;
        case ReportFormat.excel:
          filePath = await _generateExcel(reportData);
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
        charts: reportData.charts,
        summary: reportData.summary,
      );

      _generatedReports.add(finalReportData);
      return finalReportData;
    } catch (e, st) {
      debugPrint('❌ AdvancedReportingService: Error generating report: $e');
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

    final technicianPerformance =
        _calculateTechnicianPerformanceMap(workOrders, users);

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
      'technicianPerformance': technicianPerformance,
      'workOrders': workOrders.map(_workOrderToMap).toList(),
    };
  }

  Map<String, dynamic> _calculateTechnicianPerformanceMap(
    List<WorkOrder> workOrders,
    List<User> users,
  ) {
    final performance = <String, Map<String, dynamic>>{};
    final technicians = users.where((u) => u.role == 'technician');
    for (final tech in technicians) {
      final userWorkOrders =
          workOrders.where((wo) => wo.hasTechnician(tech.id)).toList();
      final completed = userWorkOrders
          .where((wo) => wo.status == WorkOrderStatus.completed)
          .length;
      final avgCompletion =
          _calculateTechnicianAverageCompletionTime(userWorkOrders)
              .inHours
              .toDouble();
      final totalCost = _calculateTechnicianTotalCost(userWorkOrders);
      performance[tech.id] = {
        'technicianName': tech.name,
        'totalWorkOrders': userWorkOrders.length,
        'completedWorkOrders': completed,
        'completionRate': userWorkOrders.isNotEmpty
            ? (completed / userWorkOrders.length) * 100
            : 0.0,
        'averageCompletionTimeHours': avgCompletion,
        'totalCost': totalCost,
      };
    }
    return performance;
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
    final technicians = users.where((u) => u.role == 'technician').toList();
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

    final totalValue = inventoryItems.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * (item.cost ?? 0)),
    );

    return {
      'summary': {
        'totalItems': totalItems,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
        'totalValue': totalValue,
      },
      'categoryBreakdown': categoryBreakdown,
      'lowStockItems': inventoryItems
          .where((item) => item.quantity <= 10)
          .map(_inventoryItemToMap)
          .toList(),
      'inventoryItems': inventoryItems.map(_inventoryItemToMap).toList(),
    };
  }

  /// Generate PDF report
  Future<String> _generatePDF(ReportData reportData) async {
    try {
      // Syncfusion-based generation (robust on web and mobile)
      final sDoc = sf.PdfDocument();
      final sPage = sDoc.pages.add();

      final sTitle = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        20,
        style: sf.PdfFontStyle.bold,
      );
      final sHeader = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        14,
        style: sf.PdfFontStyle.bold,
      );
      final sBody = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10);

      double y0 = 20;
      sPage.graphics.drawString(
        'Q-AUTO CMMS',
        sTitle,
        brush: sf.PdfSolidBrush(sf.PdfColor(33, 150, 243)),
        bounds: ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 28),
      );
      y0 += 26;
      sPage.graphics.drawString(
        reportData.config.name,
        sHeader,
        bounds: ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 22),
      );
      y0 += 14;
      sPage.graphics.drawLine(
        sf.PdfPen(sf.PdfColor(33, 150, 243), width: 2),
        ui.Offset(20, y0),
        ui.Offset(sPage.getClientSize().width - 20, y0),
      );
      y0 += 16;

      final genStr = reportData.generatedAt
          .toIso8601String()
          .replaceFirst('T', ' ')
          .split('.')[0];
      sPage.graphics.drawString(
        'Generated: $genStr',
        sBody,
        bounds: ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 16),
      );
      y0 += 22;

      if (reportData.summary.isNotEmpty) {
        sPage.graphics.drawString(
          'Executive Summary',
          sHeader,
          bounds:
              ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 18),
        );
        y0 += 18;
        final sGrid = sf.PdfGrid();
        sGrid.columns.add(count: 2);
        sGrid.headers.add(1);
        sGrid.headers[0].cells[0].value = 'Metric';
        sGrid.headers[0].cells[1].value = 'Value';
        for (final e in reportData.summary.entries) {
          final r = sGrid.rows.add();
          r.cells[0].value = _formatKey(e.key);
          r.cells[1].value = _valueToString(e.value);
        }
        final drawn = sGrid.draw(
          page: sPage,
          bounds: ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 0),
        )!;
        y0 = drawn.bounds.bottom + 16;
      }

      sPage.graphics.drawString(
        'Details',
        sHeader,
        bounds: ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 18),
      );
      y0 += 18;
      final dGrid = sf.PdfGrid();
      dGrid.columns.add(count: 2);
      dGrid.headers.add(1);
      dGrid.headers[0].cells[0].value = 'Field';
      dGrid.headers[0].cells[1].value = 'Value';
      for (final e in reportData.data.entries) {
        final r = dGrid.rows.add();
        r.cells[0].value = _formatKey(e.key);
        r.cells[1].value = _valueToString(e.value);
      }
      dGrid.draw(
        page: sPage,
        bounds: ui.Rect.fromLTWH(20, y0, sPage.getClientSize().width - 40, 0),
      );

      final outBytes = await sDoc.save();
      sDoc.dispose();

      if (kIsWeb) {
        final blob = html.Blob([outBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        debugPrint('✅ PDF generated for web download');
        return 'web_download_complete';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(path);
        await file.writeAsBytes(outBytes, flush: true);
        debugPrint('✅ PDF generated: $path');
        return path;
      }
      // Create PDF document with professional design
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(50),
          build: (pw.Context context) => [
            // Professional Header with colored background
            _buildHeader(reportData),
            pw.SizedBox(height: 20),

            // Generated date with icon
            _buildReportInfo(reportData),
            pw.SizedBox(height: 30),

            // Executive Summary Section
            if (reportData.summary.isNotEmpty) ...[
              _buildSummarySection(reportData),
              pw.SizedBox(height: 20),
            ],

            // Detailed Data Section
            _buildDetailsSection(reportData),
            pw.SizedBox(height: 20),

            // Footer
            _buildFooter(context, reportData),
          ],
        ),
      );

      // Save to file (platform-aware)
      final pdfBytes = await pdf.save();
      String filePath;

      if (kIsWeb) {
        // Web: Trigger browser download
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          )
          ..click();
        html.Url.revokeObjectUrl(url);

        debugPrint('✅ PDF generated for web download');
        return 'web_download_complete';
      } else {
        // Mobile/Desktop: Save to file system
        final directory = await getApplicationDocumentsDirectory();
        filePath =
            '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

        debugPrint('✅ PDF generated: $filePath');
        return filePath;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      // Fallback to text download (web) or text file (mobile/desktop)
      final content = StringBuffer()
        ..writeln('Report: ${reportData.config.name}')
        ..writeln('Generated: ${reportData.generatedAt.toIso8601String()}')
        ..writeln()
        ..writeln('Summary:')
        ..writeln(jsonEncode(_makeEncodable(reportData.summary)))
        ..writeln()
        ..writeln('Data:')
        ..writeln(jsonEncode(_makeEncodable(reportData.data)));

      if (kIsWeb) {
        final blob = html.Blob([content.toString()], 'text/plain');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.txt',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'web_download_complete';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.txt';
        final file = File(filePath);
        await file.writeAsString(content.toString());
        return filePath;
      }
    }
  }

  /// Build professional header with company branding
  pw.Widget _buildHeader(ReportData reportData) => pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Q-AUTO CMMS',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),),
                      pw.SizedBox(height: 5),
                      pw.Text('Maintenance Management System',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                            fontStyle: pw.FontStyle.italic,
                          ),),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(color: PdfColors.blue, thickness: 2),
            pw.SizedBox(height: 10),
            pw.Text(
              reportData.config.name,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ],
        ),
      );

  /// Build report information section
  pw.Widget _buildReportInfo(ReportData reportData) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              'Generated: ${reportData.generatedAt.toIso8601String().split('T')[0]}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            pw.Text(
              reportData.generatedAt
                  .toIso8601String()
                  .split('T')[1]
                  .split('.')[0],
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      );

  /// Build executive summary section with key metrics
  pw.Widget _buildSummarySection(ReportData reportData) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Executive Summary',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),),
          pw.SizedBox(height: 15),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header row
                pw.TableRow(children: [
                  _buildTableCell('Metric', isHeader: true),
                  _buildTableCell('Value', isHeader: true),
                ],),
                // Data rows
                ...reportData.summary.entries.map((entry) => pw.TableRow(
                    children: [
                      _buildTableCell(_formatKey(entry.key)),
                      _buildTableCell(_formatValue(entry.value),
                          alignRight: true),
                    ],
                  )),
              ],
            ),
          ),
        ],
      );

  /// Build details section with professional table
  pw.Widget _buildDetailsSection(ReportData reportData) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Detailed Information',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),),
          pw.SizedBox(height: 15),
          if (_canBuildDataTable(reportData.data))
            _buildDataTable(reportData.data)
          else
            _buildDataList(reportData.data),
        ],
      );

  /// Build professional data table
  pw.Widget _buildDataTable(Map<String, dynamic> data) {
    final entries = data.entries.toList();
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(3),
        },
        children: [
          // Header
          pw.TableRow(
            decoration: const pw.BoxDecoration(),
            children: [
              _buildTableCell('Field', isHeader: true),
              _buildTableCell('Value', isHeader: true),
            ],
          ),
          // Data rows with alternating colors
          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return pw.TableRow(
              decoration: index % 2 == 0 ? null : const pw.BoxDecoration(),
              children: [
                _buildTableCell(_formatKey(row.key)),
                _buildTableCell(_formatValue(row.value)),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Build simple data list for non-table data
  pw.Widget _buildDataList(Map<String, dynamic> data) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        padding: const pw.EdgeInsets.all(15),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: data.entries.map((entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 120,
                    child: pw.Text(
                      _formatKey(entry.key),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      _formatValue(entry.value),
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )).toList(),
        ),
      );

  /// Build professional footer
  pw.Widget _buildFooter(pw.Context context, ReportData reportData) =>
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 20),
        padding: const pw.EdgeInsets.all(15),
        decoration: const pw.BoxDecoration(),
        child: pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              height: 2,
              color: PdfColors.grey,
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Q-AUTO CMMS Report',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
                pw.Text(
                  'Generated: ${DateTime.now().year}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// Build a table cell
  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool alignRight = false,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 12 : 11,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? PdfColors.blue.shade(0.8) : PdfColors.black,
          ),
          textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );

  /// Check if data can be built as a table
  bool _canBuildDataTable(Map<String, dynamic> data) {
    return data.length < 20; // Only use tables for reasonable data sizes
  }

  /// Format key for display
  String _formatKey(String key) => key
      .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m.group(1)}')
      .trim()
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  /// Format value for display
  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is List) {
      if (value.isEmpty) return 'None';
      return value.take(3).join(', ') + (value.length > 3 ? '...' : '');
    }
    if (value is Map) {
      return '${value.length} items';
    }
    return value.toString();
  }

  /// Safely load image for PDF
  /// Returns null if image cannot be loaded (prevents PDF generation errors)
  Future<pw.ImageProvider?> _loadImageSafely(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) {
      debugPrint('⚠️ No image path provided');
      return null;
    }

    try {
      // Handle both file paths and network URLs
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        debugPrint('⚠️ Network images not supported in PDF reports');
        return null;
      }

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('⚠️ Image file not found: $imagePath');
        return null;
      }

      final imageBytes = await file.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      debugPrint('✅ Successfully loaded image: $imagePath');
      return image;
    } catch (e, st) {
      debugPrint('❌ Error loading image: $imagePath - $e');
      return null; // Return null instead of throwing to prevent PDF failure
    }
  }

  /// Build image widget with error handling
  Future<pw.Widget> _buildImageWidget(
    String? imagePath, {
    String? label,
  }) async {
    final image = await _loadImageSafely(imagePath);

    if (image == null) {
      // Return a placeholder box with error message
      return pw.Container(
        height: 150,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey,
          border: pw.Border.all(color: PdfColors.grey),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Icon(const pw.IconData(0x1F5BC),
                  size: 30, color: PdfColors.grey,),
              pw.SizedBox(height: 5),
              pw.Text(
                label ?? 'Image not available',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Return the actual image
    return pw.Container(
      height: 150,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey.shade(0.3)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 5,
        verticalRadius: 5,
        child: pw.Image(image, fit: pw.BoxFit.cover),
      ),
    );
  }

  /// Generate Excel report (CSV format - opens in Excel)
  Future<String> _generateExcel(ReportData reportData) async {
    try {
      final csvContent = StringBuffer();

      // Header
      csvContent.writeln('Report: ${reportData.config.name}');
      csvContent
          .writeln('Generated: ${reportData.generatedAt.toIso8601String()}');
      csvContent.writeln();

      // Summary section
      if (reportData.summary.isNotEmpty) {
        csvContent.writeln('Summary');
        for (final entry in reportData.summary.entries) {
          csvContent.writeln('"${entry.key}","${entry.value}"');
        }
        csvContent.writeln();
      }

      // Data section
      csvContent.writeln('Details');
      for (final entry in reportData.data.entries) {
        // Handle lists and maps in the value
        final value = entry.value;
        final stringValue = value is List
            ? value.map((e) => e.toString()).join('; ')
            : value is Map
                ? value.entries.map((e) => '${e.key}: ${e.value}').join('; ')
                : value.toString();
        csvContent.writeln('"${entry.key}","$stringValue"');
      }

      // Save as CSV file (Excel-compatible)
      if (kIsWeb) {
        final blob = html.Blob([csvContent.toString()], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.csv',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        debugPrint('✅ CSV/Excel report generated for web download');
        return 'web_download_complete';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(filePath);
        await file.writeAsString(csvContent.toString());
        debugPrint('✅ CSV/Excel report generated: $filePath');
        return filePath;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error generating Excel/CSV report: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate CSV report
  Future<String> _generateCSV(ReportData reportData) async {
    final csvContent = StringBuffer();
    csvContent.writeln('Report,${reportData.config.name}');
    csvContent.writeln('Generated,${reportData.generatedAt.toIso8601String()}');
    csvContent.writeln();

    for (final entry in reportData.data.entries) {
      final v = _valueToString(entry.value);
      csvContent.writeln('${entry.key},$v');
    }

    if (kIsWeb) {
      final blob = html.Blob([csvContent.toString()], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.csv',
        )
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'web_download_complete';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath =
          '${directory.path}/report_${reportData.config.id}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());
      return filePath;
    }
  }

  // ============================================================================
  // ENCODING HELPERS
  // ============================================================================

  dynamic _makeEncodable(dynamic value) {
    if (value == null) return null;
    if (value is num || value is String || value is bool) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is Duration) return value.inSeconds; // store seconds
    if (value is Enum) return value.name;
    if (value is Map) {
      return {
        for (final e in value.entries)
          e.key.toString(): _makeEncodable(e.value),
      };
    }
    if (value is Iterable) {
      return value.map(_makeEncodable).toList();
    }
    // Fallback to string
    return value.toString();
  }

  String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return value.toIso8601String();
    if (value is Duration) return formatWorkDuration(value);
    if (value is Enum) return value.name;
    if (value is List) return value.map(_valueToString).join('; ');
    if (value is Map) {
      return value
          .entries
          .map((e) => '${e.key}: ${_valueToString(e.value)}')
          .join('; ');
    }
    return value.toString();
  }

  /// Generate JSON report
  Future<String> _generateJSON(ReportData reportData) async {
    final jsonContent = jsonEncode(
      _makeEncodable({
        'config': {
          'id': reportData.config.id,
          'name': reportData.config.name,
          'type': reportData.config.type.toString(),
          'format': reportData.config.format.toString(),
          'period': reportData.config.period.toString(),
        },
        'generatedAt': reportData.generatedAt.toIso8601String(),
        'data': reportData.data,
      }),
    );

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
        'cost': item.cost,
        'totalValue': item.quantity * (item.cost ?? 0),
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
