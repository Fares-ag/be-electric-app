// Admin Reporting Screen - Generate all types of reports

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/advanced_reporting_service.dart' as advanced;
import '../../utils/app_theme.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  final advanced.AdvancedReportingService _advancedReporting =
      sl<advanced.AdvancedReportingService>();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Reports'),
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Generate Reports',
                style: AppTheme.heading1.copyWith(
                  color: AppTheme.darkTextColor,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a report type to generate comprehensive analytics',
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),

              // Work Order Reports Section
              _buildReportSection(
                'Work Order Reports',
                Icons.work,
                Colors.blue,
                [
                  _ReportCard(
                    title: 'Work Order Summary',
                    description: 'Comprehensive overview of all work orders',
                    icon: Icons.summarize,
                    color: Colors.blue,
                    formats: ['PDF', 'Excel', 'CSV'],
                    onGenerate: _generateWorkOrderSummary,
                  ),
                  _ReportCard(
                    title: 'Overdue Work Orders',
                    description: 'List of work orders past their due date',
                    icon: Icons.warning_amber,
                    color: Colors.orange,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateOverdueReport,
                  ),
                  _ReportCard(
                    title: 'Completion Rate Analysis',
                    description: 'Work order completion statistics and trends',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateCompletionRateReport,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Asset Reports Section
              _buildReportSection(
                'Asset Reports',
                Icons.inventory_2,
                Colors.purple,
                [
                  _ReportCard(
                    title: 'Asset Performance',
                    description: 'Downtime, uptime, and reliability metrics',
                    icon: Icons.trending_up,
                    color: Colors.purple,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateAssetPerformanceReport,
                  ),
                  _ReportCard(
                    title: 'Asset Maintenance History',
                    description: 'Complete maintenance records per asset',
                    icon: Icons.history,
                    color: Colors.indigo,
                    formats: ['PDF', 'CSV'],
                    onGenerate: _generateAssetHistoryReport,
                  ),
                  _ReportCard(
                    title: 'Asset Lifecycle Report',
                    description:
                        'Asset age, depreciation, and lifecycle status',
                    icon: Icons.timeline,
                    color: Colors.deepPurple,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateAssetLifecycleReport,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Maintenance Reports Section
              _buildReportSection(
                'Maintenance Reports',
                Icons.build,
                Colors.teal,
                [
                  _ReportCard(
                    title: 'PM Compliance Report',
                    description: 'Preventive maintenance completion rates',
                    icon: Icons.fact_check,
                    color: Colors.teal,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generatePMComplianceReport,
                  ),
                  _ReportCard(
                    title: 'Maintenance Cost Analysis',
                    description: 'Labor, parts, and total cost breakdown',
                    icon: Icons.attach_money,
                    color: Colors.green,
                    formats: ['PDF', 'Excel', 'CSV'],
                    onGenerate: _generateCostAnalysisReport,
                  ),
                  _ReportCard(
                    title: 'MTTR & MTBF Analysis',
                    description: 'Mean time to repair and between failures',
                    icon: Icons.speed,
                    color: Colors.cyan,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateMTTRMTBFReport,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Technician Reports Section
              _buildReportSection(
                'Technician Reports',
                Icons.engineering,
                Colors.orange,
                [
                  _ReportCard(
                    title: 'Technician Performance',
                    description: 'Individual technician productivity metrics',
                    icon: Icons.person_outline,
                    color: Colors.orange,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateTechnicianPerformanceReport,
                  ),
                  _ReportCard(
                    title: 'Workload Distribution',
                    description: 'Work order allocation across technicians',
                    icon: Icons.pie_chart,
                    color: Colors.deepOrange,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateWorkloadReport,
                  ),
                  _ReportCard(
                    title: 'Technician Utilization',
                    description: 'Time tracking and utilization rates',
                    icon: Icons.access_time,
                    color: Colors.amber,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateUtilizationReport,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Inventory Reports Section
              _buildReportSection(
                'Inventory Reports',
                Icons.warehouse,
                Colors.brown,
                [
                  _ReportCard(
                    title: 'Inventory Levels',
                    description: 'Current stock levels and reorder points',
                    icon: Icons.inventory,
                    color: Colors.brown,
                    formats: ['PDF', 'Excel', 'CSV'],
                    onGenerate: _generateInventoryLevelsReport,
                  ),
                  _ReportCard(
                    title: 'Parts Usage Report',
                    description: 'Most used parts and consumption trends',
                    icon: Icons.settings,
                    color: Colors.blueGrey,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generatePartsUsageReport,
                  ),
                  _ReportCard(
                    title: 'Inventory Valuation',
                    description: 'Total inventory value and cost analysis',
                    icon: Icons.calculate,
                    color: Colors.green,
                    formats: ['PDF', 'Excel'],
                    onGenerate: _generateInventoryValuationReport,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Comprehensive Reports Section
              _buildReportSection(
                'Comprehensive Reports',
                Icons.assessment,
                Colors.red,
                [
                  _ReportCard(
                    title: 'Executive Summary',
                    description: 'High-level overview for management',
                    icon: Icons.business_center,
                    color: Colors.red,
                    formats: ['PDF'],
                    onGenerate: _generateExecutiveSummary,
                  ),
                  _ReportCard(
                    title: 'Annual Report',
                    description: 'Yearly performance and analytics',
                    icon: Icons.calendar_today,
                    color: Colors.deepPurple,
                    formats: ['PDF'],
                    onGenerate: _generateAnnualReport,
                  ),
                  _ReportCard(
                    title: 'Custom Report',
                    description: 'Build your own custom report',
                    icon: Icons.tune,
                    color: Colors.pink,
                    formats: ['PDF', 'Excel', 'CSV'],
                    onGenerate: _generateCustomReport,
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      );

  Widget _buildReportSection(
    String title,
    IconData icon,
    Color color,
    List<_ReportCard> reports,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reports.map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildReportCard(report),
            ),
          ),
        ],
      );

  Widget _buildReportCard(_ReportCard report) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showFormatDialog(report),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: report.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    report.icon,
                    color: report.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );

  void _showFormatDialog(_ReportCard report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.description),
            const SizedBox(height: 20),
            const Text(
              'Select format:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...report.formats.map(
              (format) => ListTile(
                leading: Icon(_getFormatIcon(format)),
                title: Text(format),
                onTap: () {
                  Navigator.pop(context);
                  report.onGenerate(format.toLowerCase());
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  IconData _getFormatIcon(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'excel':
        return Icons.table_chart;
      case 'csv':
        return Icons.grid_on;
      case 'json':
        return Icons.code;
      default:
        return Icons.file_present;
    }
  }

  // Report Generation Methods
  Future<void> _generateWorkOrderSummary(String format) async {
    await _generateReport(
      'Work Order Summary',
      advanced.ReportType.workOrderSummary,
      _getReportFormat(format),
    );
  }

  Future<void> _generateOverdueReport(String format) async {
    await _generateReport(
      'Overdue Work Orders',
      advanced.ReportType.workOrderSummary,
      _getReportFormat(format),
    );
  }

  Future<void> _generateCompletionRateReport(String format) async {
    await _generateReport(
      'Completion Rate Analysis',
      advanced.ReportType.workOrderSummary,
      _getReportFormat(format),
    );
  }

  Future<void> _generateAssetPerformanceReport(String format) async {
    await _generateReport(
      'Asset Performance',
      advanced.ReportType.assetMaintenance,
      _getReportFormat(format),
    );
  }

  Future<void> _generateAssetHistoryReport(String format) async {
    await _generateReport(
      'Asset Maintenance History',
      advanced.ReportType.assetMaintenance,
      _getReportFormat(format),
    );
  }

  Future<void> _generateAssetLifecycleReport(String format) async {
    await _generateReport(
      'Asset Lifecycle',
      advanced.ReportType.assetMaintenance,
      _getReportFormat(format),
    );
  }

  Future<void> _generatePMComplianceReport(String format) async {
    await _generateReport(
      'PM Compliance',
      advanced.ReportType.pmTaskSummary,
      _getReportFormat(format),
    );
  }

  Future<void> _generateCostAnalysisReport(String format) async {
    await _generateReport(
      'Maintenance Cost Analysis',
      advanced.ReportType.costAnalysis,
      _getReportFormat(format),
    );
  }

  Future<void> _generateMTTRMTBFReport(String format) async {
    await _generateReport(
      'MTTR & MTBF Analysis',
      advanced.ReportType.workOrderSummary,
      _getReportFormat(format),
    );
  }

  Future<void> _generateTechnicianPerformanceReport(String format) async {
    await _generateReport(
      'Technician Performance',
      advanced.ReportType.technicianPerformance,
      _getReportFormat(format),
    );
  }

  Future<void> _generateWorkloadReport(String format) async {
    await _generateReport(
      'Workload Distribution',
      advanced.ReportType.technicianPerformance,
      _getReportFormat(format),
    );
  }

  Future<void> _generateUtilizationReport(String format) async {
    await _generateReport(
      'Technician Utilization',
      advanced.ReportType.technicianPerformance,
      _getReportFormat(format),
    );
  }

  Future<void> _generateInventoryLevelsReport(String format) async {
    await _generateReport(
      'Inventory Levels',
      advanced.ReportType.inventoryReport,
      _getReportFormat(format),
    );
  }

  Future<void> _generatePartsUsageReport(String format) async {
    await _generateReport(
      'Parts Usage',
      advanced.ReportType.inventoryReport,
      _getReportFormat(format),
    );
  }

  Future<void> _generateInventoryValuationReport(String format) async {
    await _generateReport(
      'Inventory Valuation',
      advanced.ReportType.inventoryReport,
      _getReportFormat(format),
    );
  }

  Future<void> _generateExecutiveSummary(String format) async {
    await _generateReport(
      'Executive Summary',
      advanced.ReportType.custom,
      _getReportFormat(format),
    );
  }

  Future<void> _generateAnnualReport(String format) async {
    await _generateReport(
      'Annual Report',
      advanced.ReportType.custom,
      _getReportFormat(format),
    );
  }

  Future<void> _generateCustomReport(String format) async {
    await _generateReport(
      'Custom Report',
      advanced.ReportType.custom,
      _getReportFormat(format),
    );
  }

  advanced.ReportFormat _getReportFormat(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return advanced.ReportFormat.pdf;
      case 'excel':
        return advanced.ReportFormat.excel;
      case 'csv':
        return advanced.ReportFormat.csv;
      case 'json':
        return advanced.ReportFormat.json;
      default:
        return advanced.ReportFormat.pdf;
    }
  }

  Future<void> _generateReport(
    String reportName,
    advanced.ReportType type,
    advanced.ReportFormat format,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generating $reportName...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final config = advanced.ReportConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: reportName,
        type: type,
        format: format,
        period: advanced.ReportPeriod.last30Days,
        filters: {},
      );

      final report = await _advancedReporting.generateReport(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reportName generated successfully!'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                if (report.filePath != null) {
                  if (kIsWeb) {
                    // On web, try to open the file URL
                    final uri = Uri.tryParse(report.filePath!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      // Show message that file download is not available on web
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('File opening not available on web. Please download the file manually.'),
                          ),
                        );
                      }
                    }
                  } else {
                    // On mobile, show message that open_file is disabled
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File opening feature is temporarily disabled.'),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not generate report. Please try again.',
          stackTrace: st,
          contextLabel: 'Reporting: generate report',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }
}

class _ReportCard {
  _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.formats,
    required this.onGenerate,
  });
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> formats;
  final Function(String) onGenerate;
}
