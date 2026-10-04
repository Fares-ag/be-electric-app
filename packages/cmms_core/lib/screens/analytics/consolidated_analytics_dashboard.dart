// Consolidated Analytics Dashboard - composes Firestore + local KPIs
// Best practices:
// - Stateless/Stateful split for data lifecycles
// - Period selector triggers reloads
// - Uses streams for realtime and Future for local KPIs
// - debugPrint logging, typed catches, mounted checks
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/analytics_models.dart';
import '../../models/pm_task.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/analytics/analytics_calculator.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/realtime_analytics_service.dart';
import '../../services/unified_data_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/chart_theme.dart';
import '../../utils/responsive_layout.dart';
import '../pm_tasks/pm_task_list_screen.dart';
import '../work_orders/work_order_list_screen.dart';
import '../../config/locator.dart';

class ConsolidatedAnalyticsDashboard extends StatefulWidget {
  const ConsolidatedAnalyticsDashboard({
    super.key,
    this.isTechnicianView = false,
    this.technicianId,
    this.advancedMode = false,
  });

  final bool isTechnicianView;
  final String? technicianId;
  final bool advancedMode;

  @override
  State<ConsolidatedAnalyticsDashboard> createState() =>
      _ConsolidatedAnalyticsDashboardState();
}

class _ConsolidatedAnalyticsDashboardState
    extends State<ConsolidatedAnalyticsDashboard> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final RealtimeAnalyticsService _realtime = sl<RealtimeAnalyticsService>();
  final AnalyticsCalculator _calculator = AnalyticsCalculator();

  String _periodKey = '30d';
  KPIMetrics? _localKpis;
  bool _loading = true;
  DateTime? _lastUpdated;
  List<WorkOrder> _periodWorkOrders = const [];
  List<PMTask> _periodPmTasks = const [];
  String? _filterTechnicianId;
  String? _filterAssetId;
  String? _filterLocation;
  String? _filterCategory;
  Map<String, String> _userNameCache = <String, String>{};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _realtime.initialize();
    await _loadKPIs();
  }

  Future<void> _loadKPIs() async {
    setState(() => _loading = true);
    try {
      // Pull current synced data from provider (reflects Firestore)
      final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
      final allWorkOrders = unified.workOrders;
      final allAssets = unified.assets;
      final allPmTasks = unified.pmTasks;
      final userMap = <String, String>{};
      for (final user in unified.users) {
        if (user.id.isNotEmpty) {
          userMap[user.id] = user.name.isNotEmpty ? user.name : user.email;
        }
      }

      // Optional technician scoping
      final scopedWorkOrders = widget.isTechnicianView
          ? allWorkOrders
              .where((wo) =>
                  wo.hasTechnician(
                      widget.technicianId ??
                          Provider.of<AuthProvider>(context, listen: false)
                              .currentUser
                              ?.id ??
                          '',),)
              .toList()
          : allWorkOrders;
      final scopedPmTasks = widget.isTechnicianView
          ? allPmTasks
              .where((pm) =>
                  pm.hasTechnician(
                      widget.technicianId ??
                          Provider.of<AuthProvider>(context, listen: false)
                              .currentUser
                              ?.id ??
                          '',),)
              .toList()
          : allPmTasks;

      // Filter by selected period for accuracy
      final cutoff = DateTime.now().subtract(_durationFromKey(_periodKey));
      var periodWorkOrders =
          scopedWorkOrders.where((wo) => wo.updatedAt.isAfter(cutoff)).toList();
      var periodPmTasks = scopedPmTasks
          .where((pm) => (pm.updatedAt ?? pm.createdAt).isAfter(cutoff))
          .toList();

      // In technician view, only show this technician's data (ignore filter by other technicians)
      if (widget.isTechnicianView) {
        _filterTechnicianId = null;
      }
      // Apply global filters (admin only; technician filter is hidden in technician view)
      if (_filterTechnicianId != null && _filterTechnicianId!.isNotEmpty) {
        periodWorkOrders = periodWorkOrders
            .where((wo) => wo.hasTechnician(_filterTechnicianId!))
            .toList();
        periodPmTasks = periodPmTasks
            .where((pm) => pm.hasTechnician(_filterTechnicianId!))
            .toList();
      }
      if (_filterAssetId != null && _filterAssetId!.isNotEmpty) {
        periodWorkOrders = periodWorkOrders
            .where((wo) => wo.assetId == _filterAssetId)
            .toList();
        periodPmTasks =
            periodPmTasks.where((pm) => pm.assetId == _filterAssetId).toList();
      }
      if (_filterLocation != null && _filterLocation!.isNotEmpty) {
        periodWorkOrders = periodWorkOrders
            .where((wo) => allAssets.any(
                (a) => a.id == wo.assetId && a.location == _filterLocation,),)
            .toList();
      }
      if (_filterCategory != null && _filterCategory!.isNotEmpty) {
        periodWorkOrders = periodWorkOrders
            .where((wo) => allAssets.any((a) =>
                a.id == wo.assetId && (a.category ?? '') == _filterCategory,),)
            .toList();
        periodPmTasks = periodPmTasks
            .where((pm) => allAssets.any((a) =>
                a.id == pm.assetId && (a.category ?? '') == _filterCategory,),)
            .toList();
      }

      // In technician view, scope assets to those in the technician's work orders/PM tasks
      // so Asset Uptime and MTBF reflect only assets they work on.
      final scopedAssets = widget.isTechnicianView
          ? allAssets
              .where((a) =>
                  periodWorkOrders.any((wo) => wo.assetId == a.id) ||
                  periodPmTasks.any((pm) => pm.assetId == a.id),)
              .toList()
          : allAssets;

      final kpis = await _calculator.calculateKPIs(
        workOrders: periodWorkOrders,
        assets: scopedAssets,
        pmTasks: periodPmTasks,
        period: _durationFromKey(_periodKey),
      );
      if (!mounted) return;
      setState(() {
        _localKpis = kpis;
        _loading = false;
        _lastUpdated = DateTime.now();
        _periodWorkOrders = periodWorkOrders;
        _periodPmTasks = periodPmTasks;
        _userNameCache = userMap;
      });
    } on Exception catch (e, st) {
      debugPrint('Dashboard: load KPIs error $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _realtime.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.darkTextColor,
          title: Text(
            'Analytics',
            style: AppTheme.heading2.copyWith(fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          actions: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildPeriodChipWidgets(),
                ),
              ),
            ),
            if (!widget.isTechnicianView)
              IconButton(
                tooltip: 'Filters',
                onPressed: _showFiltersSheet,
                icon: const Icon(Icons.filter_list),
              ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () async {
                _analyticsService.clearCache();
                await _loadKPIs();
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        backgroundColor: AppTheme.backgroundColor,
        body: _loading
            ? _buildSkeleton()
            : RefreshIndicator(
                onRefresh: () async {
                  _analyticsService.clearCache();
                  await _loadKPIs();
                },
                child: Builder(
                  builder: (context) {
                    final padding = ResponsiveLayout.getResponsivePadding(context);
                    final bottomSafe = MediaQuery.of(context).padding.bottom;
                    const kBottomNavHeight = 56.0;
                    final scrollBottom = widget.isTechnicianView
                        ? padding.bottom + kBottomNavHeight + bottomSafe
                        : padding.bottom;
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: padding.left,
                        right: padding.right,
                        top: padding.top,
                        bottom: scrollBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.isTechnicianView
                            ? _buildTechnicianBasicsContent()
                            : _buildFullDashboardContent(),
                      ),
                    );
                  },
                ),
              ),
      );

  List<Widget> _buildTechnicianBasicsContent() => [
        _buildHeaderMeta(),
        const SizedBox(height: 12),
        _buildKpiGrid(),
        const SizedBox(height: 20),
        _buildTechnicianScopedSummaryCards(),
        const SizedBox(height: 20),
        _buildRecentWorkOrders(),
      ];

  List<Widget> _buildFullDashboardContent() => [
        _buildHeaderMeta(),
        const SizedBox(height: 8),
        _buildFilterBar(),
        const SizedBox(height: 12),
        _buildKpiGrid(),
        const SizedBox(height: 20),
        _buildRealtimeCardsRow(),
        const SizedBox(height: 20),
        _buildBreakdowns(),
        const SizedBox(height: 20),
        _buildPMComplianceLocal(),
        const SizedBox(height: 20),
        _buildChartsRow(),
        const SizedBox(height: 20),
        _buildPriorityDistribution(),
        const SizedBox(height: 20),
        _buildResponseTimeHistogram(),
        const SizedBox(height: 20),
        _buildRecentWorkOrders(),
        const SizedBox(height: 20),
        _buildAssetPerformanceTable(),
        const SizedBox(height: 8),
        _buildCsvCopyButton(_buildAssetPerfCsvRows(),
            filename: 'assets_performance.csv',),
        const SizedBox(height: 20),
        _buildCostBreakdown(),
        const SizedBox(height: 8),
        _buildCostByCategoryChart(),
        const SizedBox(height: 8),
        _buildCsvCopyButton(_buildCostCsvRows(),
            filename: 'cost_breakdown.csv',),
        const SizedBox(height: 20),
        _buildTechnicianPerformance(),
        const SizedBox(height: 8),
        _buildCsvCopyButton(_buildTechPerfCsvRows(),
            filename: 'technicians.csv',),
        const SizedBox(height: 20),
        _buildPMOperations(),
        const SizedBox(height: 8),
        _buildCsvCopyButton(_buildPMOpsCsvRows(),
            filename: 'pm_operations.csv',),
        const SizedBox(height: 20),
        _buildReliabilityAndQuality(),
        const SizedBox(height: 8),
        _buildCsvCopyButton(_buildReliabilityCsvRows(),
            filename: 'reliability_quality.csv',),
        const SizedBox(height: 24),
        _buildFinancialKPIs(),
        const SizedBox(height: 8),
        _buildCsvCopyButton(_buildFinancialCsvRows(),
            filename: 'financial_assets.csv',),
      ];

  List<Widget> _buildPeriodChipWidgets() {
    const options = <String, String>{
      '7d': '7D',
      '30d': '30D',
      '90d': '90D',
      '365d': '12M',
    };
    return options.entries.map((e) {
      final selected = _periodKey == e.key;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Text(
            e.value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.darkTextColor,
            ),
          ),
          selected: selected,
          selectedColor: AppTheme.primaryColor,
          backgroundColor: AppTheme.surfaceColor,
          onSelected: (_) {
            setState(() => _periodKey = e.key);
            _loadKPIs();
          },
        ),
      );
    }).toList();
  }

  Widget _buildSkeleton() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters skeleton row
            Row(
              children: [
                Container(
                    width: 80,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),),),
                const SizedBox(width: 8),
                Container(
                    width: 120,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),),),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // KPI skeleton grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              itemCount: 4,
              itemBuilder: (context, index) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 120,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Section skeletons
            ...List.generate(
              2,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildHeaderMeta() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // Live dot
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Live',
              style: AppTheme.smallText.copyWith(
                color: AppTheme.secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            if (_lastUpdated != null)
              Expanded(
                child: Text(
                  'Updated ${_lastUpdated!.toLocal().toIso8601String().substring(0, 19)}',
                  style: AppTheme.smallText.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      );

  Widget _buildKpiGrid() {
    final k = _localKpis ?? KPIMetrics.empty();
    final items = <_KpiInfo>[
      _KpiInfo('MTTR', k.mttr.toStringAsFixed(1), 'h', Icons.build_circle),
      _KpiInfo('MTBF', k.mtbf.toStringAsFixed(1), 'h', Icons.timelapse),
      _KpiInfo('Asset Uptime', k.assetUptime.toStringAsFixed(1), '%',
          Icons.memory,),
      _KpiInfo(
        'Completion Rate',
        k.completionRate.toStringAsFixed(1),
        '%',
        Icons.task_alt,
      ),
      _KpiInfo(
        'Average Response Time',
        k.averageResponseTime.toStringAsFixed(1),
        'h',
        Icons.bolt,
      ),
      _KpiInfo('TAT', k.averageTAT.toStringAsFixed(1), 'd', Icons.schedule),
      _KpiInfo(
        'PM Compliance Rate',
        k.complianceRate.toStringAsFixed(1),
        '%',
        Icons.rule_folder,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final crossAxisCount = isWide ? 4 : 2;
        // Use a smaller aspect ratio so cells are taller and fit title + value (avoids bottom overflow).
        final aspectRatio = isWide ? 2.2 : 1.5;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final it = items[index];
            return _KpiCard(
              title: it.title,
              value: it.value,
              unit: it.unit,
              icon: it.icon,
              onTap: () => _onKpiTap(it.title),
            );
          },
        );
      },
    );
  }

  Duration _durationFromKey(String key) {
    switch (key) {
      case '7d':
        return const Duration(days: 7);
      case '30d':
        return const Duration(days: 30);
      case '90d':
        return const Duration(days: 90);
      case '365d':
        return const Duration(days: 365);
      default:
        return const Duration(days: 30);
    }
  }

  Widget _buildRealtimeCardsRow() => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: _SectionCard(
                  title: 'Work Orders',
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: _realtime.workOrdersSummaryStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorCard(
                          message: 'Failed to load work orders',
                          details: snapshot.error.toString(),
                          onRetry: () => setState(() {}),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const _PlaceholderBody(subtitle: 'No data');
                      }
                      final data = snapshot.data!;
                      return _SummaryTable(
                        rows: [
                          _SummaryRow('Total', '${data['total'] ?? '-'}'),
                          _SummaryRow('Open', '${data['open'] ?? '-'}'),
                          _SummaryRow(
                              'In Progress', '${data['inProgress'] ?? '-'}',),
                          _SummaryRow(
                              'Completed', '${data['completed'] ?? '-'}',),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                width: isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: _SectionCard(
                  title: 'Maintenance Costs',
                  child: StreamBuilder<CostAnalysis>(
                    stream: _realtime.maintenanceCostsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorCard(
                          message: 'Failed to load costs',
                          details: snapshot.error.toString(),
                          onRetry: () => setState(() {}),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const _PlaceholderBody(subtitle: 'No data');
                      }
                      final c = snapshot.data!;
                      return _SummaryTable(
                        rows: [
                          _SummaryRow(
                              'Total', _fmtCurrency(c.totalMaintenanceCost),),
                          _SummaryRow('Labor', _fmtCurrency(c.laborCost)),
                          _SummaryRow('Parts', _fmtCurrency(c.partsCost)),
                          _SummaryRow('Downtime', _fmtCurrency(c.downtimeCost)),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: _SectionCard(
                  title: 'PM Compliance (Server)',
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: _realtime.pmComplianceStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorCard(
                          message: 'Failed to load PM compliance',
                          details: snapshot.error.toString(),
                          onRetry: () => setState(() {}),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const _PlaceholderBody(subtitle: 'No data');
                      }
                      final data = snapshot.data!;
                      final rate =
                          (data['compliancePercent'] as num?)?.toDouble() ??
                              0.0;
                      return _SummaryTable(
                        rows: [
                          _SummaryRow(
                              'Compliance', '${rate.toStringAsFixed(1)} %',),
                          _SummaryRow(
                              'Completed', '${data['completed'] ?? '-'}',),
                          _SummaryRow('Total', '${data['total'] ?? '-'}'),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );

  String _fmtCurrency(num? v) {
    if (v == null) return '-';
    return 'QAR ${v.toStringAsFixed(0)}';
  }

  /// Technician view: summary cards from scoped period data (not global streams).
  Widget _buildTechnicianScopedSummaryCards() => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final open = _periodWorkOrders
              .where((wo) =>
                  wo.status == WorkOrderStatus.open ||
                  wo.status == WorkOrderStatus.assigned ||
                  wo.status == WorkOrderStatus.reopened,)
              .length;
          final inProgress = _periodWorkOrders
              .where((wo) => wo.status == WorkOrderStatus.inProgress,)
              .length;
          final completed = _periodWorkOrders
              .where((wo) =>
                  wo.status == WorkOrderStatus.completed ||
                  wo.status == WorkOrderStatus.closed,)
              .length;
          final pmTotal = _periodPmTasks.length;
          final pmCompleted = _periodPmTasks
              .where((t) => t.status == PMTaskStatus.completed,)
              .length;
          final pmOverdue =
              _periodPmTasks.where((t) => t.isOverdue,).length;
          final pmDueSoon = _periodPmTasks
              .where((t) =>
                  t.nextDueDate != null &&
                  t.nextDueDate!
                      .isAfter(DateTime.now()) &&
                  t.nextDueDate!
                      .isBefore(DateTime.now().add(const Duration(days: 7))),)
              .length;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: _SectionCard(
                  title: 'Your Work Orders',
                  child: _SummaryTable(
                    rows: [
                      _SummaryRow('Total', '${_periodWorkOrders.length}'),
                      _SummaryRow('Open / Assigned', '$open'),
                      _SummaryRow('In Progress', '$inProgress'),
                      _SummaryRow('Completed', '$completed'),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth,
                child: _SectionCard(
                  title: 'Your PM Tasks',
                  child: _SummaryTable(
                    rows: [
                      _SummaryRow('Total', '$pmTotal'),
                      _SummaryRow('Completed', '$pmCompleted'),
                      _SummaryRow('Overdue', '$pmOverdue'),
                      _SummaryRow('Due in 7 days', '$pmDueSoon'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget _buildBreakdowns() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final cutoff = DateTime.now().subtract(_durationFromKey(_periodKey));

    // Technician scoping
    final techScopeId = widget.technicianId ??
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ??
        '';
    var workOrders = widget.isTechnicianView
        ? unified.workOrders.where((wo) => wo.hasTechnician(techScopeId)).toList()
        : unified.workOrders;

    // Period filter
    workOrders =
        workOrders.where((wo) => wo.updatedAt.isAfter(cutoff)).toList();

    // Status breakdown
    final byStatus = <String, int>{};
    for (final wo in workOrders) {
      final key = wo.status.name;
      byStatus[key] = (byStatus[key] ?? 0) + 1;
    }

    // Priority breakdown
    final byPriority = <String, int>{};
    for (final wo in workOrders) {
      final key = wo.priority.name;
      byPriority[key] = (byPriority[key] ?? 0) + 1;
    }

    final statusRows = byStatus.entries.map((e) {
      WorkOrderStatus? st;
      try {
        st = WorkOrderStatus.values.firstWhere((s) => s.name == e.key);
      } catch (_) {
        st = null;
      }
      return _SummaryRow(e.key, e.value.toString(), status: st);
    }).toList();
    final priorityRows = byPriority.entries.map((e) {
      WorkOrderPriority? pr;
      try {
        pr = WorkOrderPriority.values.firstWhere((p) => p.name == e.key);
      } catch (_) {
        pr = null;
      }
      return _SummaryRow(e.key, e.value.toString(), priority: pr);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              child: _SectionCard(
                title: 'Status Breakdown',
                child: _SummaryTable(
                  rows: statusRows,
                  onRowTap: (row) {
                    if (row.status != null) {
                      final (start, end) = _currentPeriodRange();
                      _openWorkOrdersFiltered(
                        status: row.status,
                        start: start,
                        end: end,
                      );
                    }
                  },
                ),
              ),
            ),
            SizedBox(
              width: isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              child: _SectionCard(
                title: 'Priority Breakdown',
                child: _SummaryTable(
                  rows: priorityRows,
                  onRowTap: (row) {
                    if (row.priority != null) {
                      final (start, end) = _currentPeriodRange();
                      _openWorkOrdersFiltered(
                        priority: row.priority,
                        start: start,
                        end: end,
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPMComplianceLocal() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final cutoff = DateTime.now().subtract(_durationFromKey(_periodKey));

    final techScopeId = widget.technicianId ??
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ??
        '';
    var pmTasks = widget.isTechnicianView
        ? unified.pmTasks.where((pm) => pm.hasTechnician(techScopeId)).toList()
        : unified.pmTasks;

    pmTasks = pmTasks
        .where((pm) => (pm.updatedAt ?? pm.createdAt).isAfter(cutoff))
        .toList();

    final total = pmTasks.length;
    final completed = pmTasks.where((p) => p.status.name == 'completed').length;
    final rate = total > 0 ? (completed / total * 100) : 0.0;

    return _SectionCard(
      title: 'PM Compliance (Local)',
      child: GestureDetector(
        onTap: () {
          final (start, end) = _currentPeriodRange();
          _openPmTasksFiltered(
            status: PMTaskStatus.completed,
            start: start,
            end: end,
          );
        },
        child: _SummaryTable(
          rows: [
            _SummaryRow('Compliance', '${rate.toStringAsFixed(1)} %'),
            _SummaryRow('Completed', '$completed'),
            _SummaryRow('Total', '$total'),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsRow() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final cutoff = DateTime.now().subtract(_durationFromKey(_periodKey));

    final techScopeId = widget.technicianId ??
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ??
        '';
    var workOrders = widget.isTechnicianView
        ? unified.workOrders.where((wo) => wo.hasTechnician(techScopeId)).toList()
        : unified.workOrders;

    workOrders =
        workOrders.where((wo) => wo.updatedAt.isAfter(cutoff)).toList();

    final byStatus = <String, int>{};
    for (final wo in workOrders) {
      byStatus[wo.status.name] = (byStatus[wo.status.name] ?? 0) + 1;
    }
    final totalStatus = byStatus.values.fold<int>(0, (a, b) => a + b);

    final byDayOpened = <DateTime, int>{};
    final byDayCompleted = <DateTime, int>{};
    for (final wo in workOrders) {
      final openDay = DateTime(
        wo.updatedAt.year,
        wo.updatedAt.month,
        wo.updatedAt.day,
      );
      byDayOpened[openDay] = (byDayOpened[openDay] ?? 0) + 1;
      if (wo.status == WorkOrderStatus.completed) {
        final compDay = DateTime(
          (wo.completedAt ?? wo.updatedAt).year,
          (wo.completedAt ?? wo.updatedAt).month,
          (wo.completedAt ?? wo.updatedAt).day,
        );
        byDayCompleted[compDay] = (byDayCompleted[compDay] ?? 0) + 1;
      }
    }
    final allDays = <DateTime>{...byDayOpened.keys, ...byDayCompleted.keys}
        .toList()
      ..sort();
    final trendData = allDays
        .map((d) => _TrendPoint(
              date: d,
              opened: (byDayOpened[d] ?? 0).toDouble(),
              completed: (byDayCompleted[d] ?? 0).toDouble(),
            ),)
        .toList();

    final statusCard = _SectionCard(
      title: 'Status Distribution',
      child: (byStatus.isEmpty || totalStatus == 0)
          ? const _PlaceholderBody(subtitle: 'No data')
          : SizedBox(
              height: 200,
              child: SfCircularChart(
                legend: ChartThemeUtil.legendRight(),
                tooltipBehavior: ChartThemeUtil.tooltip('point.x: point.y'),
                series: <CircularSeries<_StatusCount, String>>[
                  PieSeries<_StatusCount, String>(
                    dataSource: byStatus.entries
                        .map((e) => _StatusCount(
                            status: e.key, count: e.value.toDouble(),),)
                        .toList(),
                    xValueMapper: (_StatusCount d, _) => d.status,
                    yValueMapper: (_StatusCount d, _) => d.count,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    explode: true,
                    explodeIndex: 0,
                  ),
                ],
              ),
            ),
    );

    final trendCard = _SectionCard(
      title: 'WO Volume Trend',
      child: trendData.isEmpty
          ? const _PlaceholderBody(subtitle: 'No data')
          : SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: ChartThemeUtil.dateTimeXAxis(),
                primaryYAxis: ChartThemeUtil.yAxisZero(),
                legend: ChartThemeUtil.legendBottom(),
                tooltipBehavior: ChartThemeUtil.tooltip('point.x: point.y'),
                series: <CartesianSeries<_TrendPoint, DateTime>>[
                  SplineSeries<_TrendPoint, DateTime>(
                    name: 'Opened',
                    dataSource: trendData,
                    xValueMapper: (_TrendPoint p, _) => p.date,
                    yValueMapper: (_TrendPoint p, _) => p.opened,
                    color: AppTheme.accentBlue,
                    width: 3,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                  SplineSeries<_TrendPoint, DateTime>(
                    name: 'Completed',
                    dataSource: trendData,
                    xValueMapper: (_TrendPoint p, _) => p.date,
                    yValueMapper: (_TrendPoint p, _) => p.completed,
                    color: AppTheme.primaryColor,
                    width: 3,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final first = SizedBox(
            width:
                isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
            height: 260,
            child: statusCard,);
        final second = SizedBox(
            width:
                isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
            height: 260,
            child: trendCard,);
        final legend = SizedBox(
          width: constraints.maxWidth,
          child: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendDot(color: AppTheme.accentBlue, label: 'Opened'),
                _LegendDot(
                    color: AppTheme.primaryColor, label: 'Completed',),
              ],
            ),
          ),
        );
        return Wrap(
            spacing: 12, runSpacing: 12, children: [first, second, legend],);
      },
    );
  }

  (DateTime, DateTime) _currentPeriodRange() {
    final end = DateTime.now();
    final start = end.subtract(_durationFromKey(_periodKey));
    return (start, end);
  }

  void _openWorkOrdersFiltered({
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    DateTime? start,
    DateTime? end,
  }) {
    // Hybrid: server-filtered preview + option to open full list
    _showServerFilteredWorkOrders(
        status: status, priority: priority, start: start, end: end,);
  }

  void _openPmTasksFiltered({
    PMTaskStatus? status,
    DateTime? start,
    DateTime? end,
  }) {
    _showServerFilteredPMTasks(status: status, start: start, end: end);
  }

  // =========================== Filters ===========================
  Widget _buildFilterBar() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final technicians = unified.users
        .where((u) => u.isTechnician || u.isManager || u.isAdmin)
        .toList();
    final assets = unified.assets;
    final locations = unified.assets
        .map((a) => a.location)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final categories = unified.assets
        .map((a) => a.category ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters',
              style: AppTheme.smallText.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondaryTextColor,),),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (!widget.isTechnicianView)
                SizedBox(
                  width: 240,
                  child: _buildDropdown<String>(
                    label: 'Technician',
                    value: _filterTechnicianId,
                    items: [
                      const DropdownMenuItem(child: Text('Any')),
                      ...technicians
                          .map((t) =>
                              DropdownMenuItem(value: t.id, child: Text(t.name)),)
                          ,
                    ],
                    onChanged: (v) {
                      setState(() => _filterTechnicianId = v);
                      _loadKPIs();
                    },
                  ),
                ),
              SizedBox(
                width: 240,
                child: _buildDropdown<String>(
                  label: 'Asset',
                  value: _filterAssetId,
                  items: [
                    const DropdownMenuItem(child: Text('Any')),
                    ...assets
                        .map((a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),)
                        ,
                  ],
                  onChanged: (v) {
                    setState(() => _filterAssetId = v);
                    _loadKPIs();
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildDropdown<String>(
                  label: 'Location',
                  value: _filterLocation,
                  items: [
                    const DropdownMenuItem(child: Text('Any')),
                    ...locations
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        ,
                  ],
                  onChanged: (v) {
                    setState(() => _filterLocation = v);
                    _loadKPIs();
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: _buildDropdown<String>(
                  label: 'Category',
                  value: _filterCategory,
                  items: [
                    const DropdownMenuItem(child: Text('Any')),
                    ...categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        ,
                  ],
                  onChanged: (v) {
                    setState(() => _filterCategory = v);
                    _loadKPIs();
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterTechnicianId = null;
                    _filterAssetId = null;
                    _filterLocation = null;
                    _filterCategory = null;
                  });
                  _loadKPIs();
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFiltersSheet() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final technicians = unified.users
        .where((u) => u.isTechnician || u.isManager || u.isAdmin)
        .toList();
    final assets = unified.assets;
    final locations = unified.assets
        .map((a) => a.location)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final categories = unified.assets
        .map((a) => a.category ?? '')
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters', style: AppTheme.heading2),
            const SizedBox(height: 12),
            if (!widget.isTechnicianView)
              _buildDropdown<String>(
                label: 'Technician',
                value: _filterTechnicianId,
                items: [
                  const DropdownMenuItem(child: Text('Any')),
                  ...technicians
                      .map((t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.name)),)
                      ,
                ],
                onChanged: (v) => setState(() => _filterTechnicianId = v),
              ),
            if (!widget.isTechnicianView) const SizedBox(height: 8),
            _buildDropdown<String>(
              label: 'Asset',
              value: _filterAssetId,
              items: [
                const DropdownMenuItem(child: Text('Any')),
                ...assets
                    .map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name)),)
                    ,
              ],
              onChanged: (v) => setState(() => _filterAssetId = v),
            ),
            const SizedBox(height: 8),
            _buildDropdown<String>(
              label: 'Location',
              value: _filterLocation,
              items: [
                const DropdownMenuItem(child: Text('Any')),
                ...locations
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    ,
              ],
              onChanged: (v) => setState(() => _filterLocation = v),
            ),
            const SizedBox(height: 8),
            _buildDropdown<String>(
              label: 'Category',
              value: _filterCategory,
              items: [
                const DropdownMenuItem(child: Text('Any')),
                ...categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    ,
              ],
              onChanged: (v) => setState(() => _filterCategory = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(
                      () {
                        _filterTechnicianId = null;
                        _filterAssetId = null;
                        _filterLocation = null;
                        _filterCategory = null;
                      },
                    );
                  },
                  child: const Text('Clear'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _loadKPIs();
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T?>> items,
    required void Function(T? v) onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.smallText
                .copyWith(color: AppTheme.secondaryTextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          DropdownButton<T?>(
            isExpanded: true,
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ],
      );

  // =========================== CSV export ===========================
  Widget _buildCsvCopyButton(List<List<String>> rows,
      {required String filename,}) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () async {
              final csv = _toCsv(rows);
              await Clipboard.setData(ClipboardData(text: csv));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy CSV'),
          ),
          TextButton.icon(
            onPressed: () async {
              final csv = _toCsv(rows);
              _downloadCsv(filename, csv);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download CSV'),
          ),
        ],
      ),
    );
  }

  String _toCsv(List<List<String>> rows) => rows
      .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
      .join('\n');

  List<List<String>> _buildTechPerfCsvRows() {
    if (_periodWorkOrders.isEmpty) return const [];
    final agg = <String, _TechAgg>{};
    for (final wo in _periodWorkOrders) {
      final techIds =
          wo.assignedTechnicianIds.isEmpty ? <String>['unassigned'] : wo.assignedTechnicianIds;
      for (final techId in techIds) {
        final rec = agg.putIfAbsent(techId, _TechAgg.new);
        if (wo.status == WorkOrderStatus.completed) {
          rec.completed += 1;
          final tatHrs = _hoursBetween(wo.startedAt, wo.completedAt);
          if (tatHrs != null) {
            rec.tatSum += tatHrs;
            rec.tatCount += 1;
          }
        }
      }
    }
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final rows = <List<String>>[
      ['Technician', 'Completed', 'Avg TAT (h)'],
      ...agg.entries.map((e) => [
            _techNameById(unified, e.key),
            e.value.completed.toString(),
            _fmtHours(e.value.avgTat),
          ],),
    ];
    return rows;
  }

  void _downloadCsv(String filename, String data) {
    try {
      final bytes = utf8.encode(data);
      final content = base64Encode(bytes);
      html.AnchorElement(href: 'data:text/csv;base64,$content')
        ..setAttribute('download', filename)
        ..click();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Download not supported on this platform'),),
        );
      }
    }
  }

  List<List<String>> _buildFinancialCsvRows() {
    if (_periodWorkOrders.isEmpty) return const [];
    final costByAsset = <String, double>{};
    for (final wo in _periodWorkOrders) {
      final assetId = wo.assetId ?? 'unassigned';
      final c = wo.totalCost ?? ((wo.laborCost ?? 0) + (wo.partsCost ?? 0));
      costByAsset.update(assetId, (v) => v + c, ifAbsent: () => c);
    }
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final rows = <List<String>>[
      ['Asset', 'Total Cost'],
      ...costByAsset.entries
          .map((e) => [_assetNameById(unified, e.key), _fmtCurrency(e.value)]),
    ];
    return rows;
  }

  List<List<String>> _buildAssetPerfCsvRows() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final cutoff = DateTime.now().subtract(_durationFromKey(_periodKey));
    final assets = unified.assets;
    final workOrders =
        unified.workOrders.where((wo) => wo.updatedAt.isAfter(cutoff)).toList();
    final rows = <List<String>>[
      ['Asset', 'Uptime (%)', 'MTBF (h)', 'MTTR (h)', 'Cost'],
      ...assets.take(20).map((asset) {
        final assetWOs =
            workOrders.where((wo) => wo.assetId == asset.id).toList();
        final completed =
            assetWOs.where((wo) => wo.status.name == 'completed').toList();
        double mttrH = 0;
        if (completed.isNotEmpty) {
          final totalH = completed.fold<double>(0, (sum, wo) {
            final start = wo.createdAt;
            final end = wo.completedAt ?? wo.updatedAt;
            return sum + end.difference(start).inMinutes / 60.0;
          });
          mttrH = totalH / completed.length;
        }
        final periodHours =
            DateTime.now().difference(cutoff).inHours.toDouble();
        final mtbfH =
            completed.isNotEmpty ? periodHours / completed.length : 0.0;
        final uptime = (asset.status == 'active') ? 100.0 : 0.0;
        const cost = 0.0;
        return [
          asset.name,
          uptime.toStringAsFixed(1),
          mtbfH.toStringAsFixed(1),
          mttrH.toStringAsFixed(1),
          _fmtCurrency(cost),
        ];
      }),
    ];
    return rows;
  }

  List<List<String>> _buildPMOpsCsvRows() {
    final total = _periodPmTasks.length;
    final completed =
        _periodPmTasks.where((t) => t.status == PMTaskStatus.completed).length;
    final overdue = _periodPmTasks.where((t) => t.isOverdue).length;
    final backlog = total - completed;
    final next7 = _periodPmTasks
        .where((t) =>
            t.nextDueDate != null &&
            t.nextDueDate!
                .isBefore(DateTime.now().add(const Duration(days: 7))),)
        .length;
    return [
      ['Metric', 'Value'],
      ['Total', '$total'],
      ['Completed', '$completed'],
      ['Backlog', '$backlog'],
      ['Overdue', '$overdue'],
      ['Due in 7 days', '$next7'],
    ];
  }

  List<List<String>> _buildReliabilityCsvRows() {
    double downtimeHrs = 0;
    double firstResponseHrs = 0;
    var responseCount = 0;
    var rework = 0;
    var completed = 0;
    var techSigned = 0;
    var withNotes = 0;

    for (final wo in _periodWorkOrders) {
      if (wo.status == WorkOrderStatus.completed) {
        completed += 1;
        final hrs = _hoursBetween(wo.startedAt, wo.completedAt);
        if (hrs != null) downtimeHrs += hrs;
        final rhrs = _hoursBetween(wo.createdAt, wo.firstResponseTime);
        if (rhrs != null) {
          firstResponseHrs += rhrs;
          responseCount += 1;
        }
        if (wo.isRepeatFailure ?? false) rework += 1;
        if ((wo.technicianSignature ?? '').isNotEmpty) techSigned += 1;
        if ((wo.notes ?? '').isNotEmpty ||
            (wo.correctiveActions ?? '').isNotEmpty) {
          withNotes += 1;
        }
      }
    }

    final reworkRate = completed == 0 ? 0.0 : (rework / completed) * 100.0;
    final signatureCoverage =
        completed == 0 ? 0.0 : (techSigned / completed) * 100.0;
    final notesCoverage =
        completed == 0 ? 0.0 : (withNotes / completed) * 100.0;
    final avgResponse =
        responseCount == 0 ? 0.0 : firstResponseHrs / responseCount;

    return [
      ['Metric', 'Value'],
      ['Downtime (hrs)', _fmtNumber(downtimeHrs)],
      ['Avg response (hrs)', _fmtNumber(avgResponse)],
      ['Rework rate (%)', _fmtNumber(reworkRate)],
      ['Tech signature coverage (%)', _fmtNumber(signatureCoverage)],
      ['Completion notes coverage (%)', _fmtNumber(notesCoverage)],
    ];
  }

  List<List<String>> _buildCostCsvRows() {
    double labor = 0, parts = 0, total = 0;
    for (final wo in _periodWorkOrders) {
      labor += wo.laborCost ?? 0;
      parts += wo.partsCost ?? 0;
      total += wo.totalCost ?? ((wo.laborCost ?? 0) + (wo.partsCost ?? 0));
    }
    return [
      ['Type', 'Amount'],
      ['Labor', _fmtCurrency(labor)],
      ['Parts', _fmtCurrency(parts)],
      ['Total', _fmtCurrency(total)],
    ];
  }

  // =========================== New comprehensive sections ===========================
  Widget _buildCostBreakdown() {
    double labor = 0, parts = 0, total = 0;
    for (final wo in _periodWorkOrders) {
      labor += wo.laborCost ?? 0;
      parts += wo.partsCost ?? 0;
      total += wo.totalCost ?? ((wo.laborCost ?? 0) + (wo.partsCost ?? 0));
    }
    if (labor == 0 && parts == 0 && total == 0) {
      return const _SectionCard(
          title: 'Cost Breakdown',
          child: _PlaceholderBody(subtitle: 'No cost data'),);
    }

    final rows = <_SummaryRow>[
      _SummaryRow('Labor', _fmtCurrency(labor)),
      _SummaryRow('Parts', _fmtCurrency(parts)),
      _SummaryRow('Total', _fmtCurrency(total)),
    ];

    return _SectionCard(
      title: 'Cost Breakdown',
      child: Column(
        children: [
          _SummaryTable(rows: rows),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              primaryXAxis: ChartThemeUtil.categoryXAxis(),
              primaryYAxis: ChartThemeUtil.yAxisZero(),
              tooltipBehavior: ChartThemeUtil.tooltip('point.x: QAR point.y'),
              series: <CartesianSeries<_BarPoint, String>>[
                ColumnSeries<_BarPoint, String>(
                  dataSource: <_BarPoint>[
                    _BarPoint(label: 'Labor', value: labor),
                    _BarPoint(label: 'Parts', value: parts),
                    _BarPoint(label: 'Total', value: total),
                  ],
                  xValueMapper: (_BarPoint p, _) => p.label,
                  yValueMapper: (_BarPoint p, _) => p.value,
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                  borderRadius: BorderRadius.circular(6),
                  color: AppTheme.accentBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicianPerformance() {
    if (_periodWorkOrders.isEmpty) {
      return const _SectionCard(
          title: 'Technician Performance',
          child: _PlaceholderBody(subtitle: 'No data'),);
    }
    final agg = <String, _TechAgg>{};
    for (final wo in _periodWorkOrders) {
      final techIds =
          wo.assignedTechnicianIds.isEmpty ? <String>['unassigned'] : wo.assignedTechnicianIds;
      for (final techId in techIds) {
        final rec = agg.putIfAbsent(techId, _TechAgg.new);
        if (wo.status == WorkOrderStatus.completed) {
          rec.completed += 1;
          final tatHrs = _hoursBetween(wo.startedAt, wo.completedAt);
          if (tatHrs != null) {
            rec.tatSum += tatHrs;
            rec.tatCount += 1;
          }
        }
      }
    }
    final entries = agg.entries.toList()
      ..sort((a, b) => b.value.completed.compareTo(a.value.completed));
    final top = entries.take(5).toList();

    final rows = top
        .map((e) => _SummaryRow(
              _technicianLabel(e.key),
              'Done: ${e.value.completed}  • Avg TAT: ${_fmtHours(e.value.avgTat)}h',
            ),)
        .toList();

    return _SectionCard(
      title: widget.isTechnicianView
          ? 'Your Performance'
          : 'Technician Performance (Top 5)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryTable(rows: rows),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: SfCartesianChart(
              primaryXAxis: ChartThemeUtil.categoryXAxis(),
              primaryYAxis: ChartThemeUtil.yAxisZero(),
              tooltipBehavior: ChartThemeUtil.tooltip('point.x: point.y'),
              series: <CartesianSeries<_BarPoint, String>>[
                ColumnSeries<_BarPoint, String>(
                  dataSource: [
                    for (var i = 0; i < top.length; i++)
                      _BarPoint(
                        label: _technicianLabel(top[i].key),
                        value: top[i].value.completed.toDouble(),
                      ),
                  ],
                  xValueMapper: (_BarPoint p, _) => p.label,
                  yValueMapper: (_BarPoint p, _) => p.value,
                  color: AppTheme.accentBlue,
                  borderRadius: BorderRadius.circular(6),
                  dataLabelSettings: const DataLabelSettings(isVisible: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _technicianLabel(String? id) {
    if (id == null || id.isEmpty) return 'Unknown';
    if (id == 'unassigned') return 'Unassigned';
    final name = _userNameCache[id];
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    if (id.length > 8) {
      return '${id.substring(0, 6)}…';
    }
    return id;
  }

  Widget _buildPMOperations() {
    final total = _periodPmTasks.length;
    final completed =
        _periodPmTasks.where((t) => t.status == PMTaskStatus.completed).length;
    final overdue = _periodPmTasks.where((t) => t.isOverdue).length;
    final backlog = total - completed;
    final next7 = _periodPmTasks
        .where((t) =>
            t.nextDueDate != null &&
            t.nextDueDate!
                .isBefore(DateTime.now().add(const Duration(days: 7))),)
        .length;

    final rows = <_SummaryRow>[
      _SummaryRow('Total', '$total'),
      _SummaryRow('Completed', '$completed'),
      _SummaryRow('Backlog', '$backlog'),
      _SummaryRow('Overdue', '$overdue'),
      _SummaryRow('Due in 7 days', '$next7'),
    ];

    return _SectionCard(
        title: 'PM Operations', child: _SummaryTable(rows: rows),);
  }

  Widget _buildReliabilityAndQuality() {
    double downtimeHrs = 0;
    double firstResponseHrs = 0;
    var responseCount = 0;
    var rework = 0;
    var completed = 0;
    var techSigned = 0;
    var withNotes = 0;

    for (final wo in _periodWorkOrders) {
      if (wo.status == WorkOrderStatus.completed) {
        completed += 1;
        final hrs = _hoursBetween(wo.startedAt, wo.completedAt);
        if (hrs != null) downtimeHrs += hrs;
        final rhrs = _hoursBetween(wo.createdAt, wo.firstResponseTime);
        if (rhrs != null) {
          firstResponseHrs += rhrs;
          responseCount += 1;
        }
        if (wo.isRepeatFailure ?? false) rework += 1;
        if ((wo.technicianSignature ?? '').isNotEmpty) techSigned += 1;
        if ((wo.notes ?? '').isNotEmpty ||
            (wo.correctiveActions ?? '').isNotEmpty) {
          withNotes += 1;
        }
      }
    }

    final reworkRate = completed == 0 ? 0.0 : (rework / completed) * 100.0;
    final signatureCoverage =
        completed == 0 ? 0.0 : (techSigned / completed) * 100.0;
    final notesCoverage =
        completed == 0 ? 0.0 : (withNotes / completed) * 100.0;
    final avgResponse =
        responseCount == 0 ? 0.0 : firstResponseHrs / responseCount;

    final rows = <_SummaryRow>[
      _SummaryRow('Downtime (hrs)', _fmtNumber(downtimeHrs)),
      _SummaryRow('Avg response (hrs)', _fmtNumber(avgResponse)),
      _SummaryRow('Rework rate (%)', _fmtNumber(reworkRate)),
      _SummaryRow('Tech signature coverage (%)', _fmtNumber(signatureCoverage)),
      _SummaryRow('Completion notes coverage (%)', _fmtNumber(notesCoverage)),
    ];

    return _SectionCard(
        title: 'Reliability & Quality', child: _SummaryTable(rows: rows),);
  }

  Widget _buildFinancialKPIs() {
    if (_periodWorkOrders.isEmpty) {
      return const _SectionCard(
          title: 'Financial KPIs',
          child: _PlaceholderBody(subtitle: 'No data'),);
    }
    final costByAsset = <String, double>{};
    for (final wo in _periodWorkOrders) {
      final assetId = wo.assetId ?? 'unassigned';
      final c = wo.totalCost ?? ((wo.laborCost ?? 0) + (wo.partsCost ?? 0));
      costByAsset.update(assetId, (v) => v + c, ifAbsent: () => c);
    }
    final top = costByAsset.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final rows = top
        .take(5)
        .map((e) =>
            _SummaryRow(_assetNameById(unified, e.key), _fmtCurrency(e.value)),)
        .toList();

    return _SectionCard(
        title: 'Financial KPIs (Top Assets by Cost)',
        child: _SummaryTable(rows: rows),);
  }

  Widget _buildCostByCategoryChart() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final byCategory = <String, double>{};
    for (final wo in _periodWorkOrders) {
      final asset = unified.assets.where((a) => a.id == wo.assetId).toList();
      if (asset.isEmpty) continue;
      final cat = asset.first.category ?? 'Uncategorized';
      final c = wo.totalCost ?? ((wo.laborCost ?? 0) + (wo.partsCost ?? 0));
      byCategory.update(cat, (v) => v + c, ifAbsent: () => c);
    }
    if (byCategory.isEmpty) {
      return const _SectionCard(
          title: 'Cost by Category',
          child: _PlaceholderBody(subtitle: 'No data'),);
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final data =
        entries.map((e) => _PieCost(cat: e.key, value: e.value)).toList();

    return _SectionCard(
      title: 'Cost by Category',
      child: SizedBox(
        height: 240,
        child: Row(
          children: [
            Expanded(
              child: SfCircularChart(
                legend: ChartThemeUtil.legendRight(),
                tooltipBehavior: ChartThemeUtil.tooltip('point.x: QAR point.y'),
                series: <CircularSeries<_PieCost, String>>[
                  DoughnutSeries<_PieCost, String>(
                    dataSource: data,
                    xValueMapper: (_PieCost d, _) => d.cat,
                    yValueMapper: (_PieCost d, _) => d.value,
                    dataLabelMapper: (_PieCost d, _) => d.cat,
                    dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelIntersectAction: LabelIntersectAction.hide,),
                    explode: true,
                    explodeIndex: 0,
                    innerRadius: '55%',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryTable(
                rows: entries
                    .take(8)
                    .map((e) => _SummaryRow(e.key, _fmtCurrency(e.value)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Priority distribution chart
  Widget _buildPriorityDistribution() {
    final counts = <String, int>{};
    for (final wo in _periodWorkOrders) {
      counts[wo.priority.name] = (counts[wo.priority.name] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return const _SectionCard(
          title: 'Priority Distribution',
          child: _PlaceholderBody(subtitle: 'No data'),);
    }
    final data = counts.entries
        .map((e) => _BarPoint(label: e.key, value: e.value.toDouble()))
        .toList();
    return _SectionCard(
      title: 'Priority Distribution',
      child: SizedBox(
        height: 220,
        child: SfCartesianChart(
          primaryXAxis: ChartThemeUtil.categoryXAxis(),
          primaryYAxis: ChartThemeUtil.yAxisZero(),
          tooltipBehavior: ChartThemeUtil.tooltip('point.x: point.y'),
          series: <CartesianSeries<_BarPoint, String>>[
            ColumnSeries<_BarPoint, String>(
              dataSource: data,
              xValueMapper: (_BarPoint p, _) => p.label,
              yValueMapper: (_BarPoint p, _) => p.value,
              color: AppTheme.accentBlue,
              borderRadius: BorderRadius.circular(6),
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  // Response time histogram (hours from createdAt to firstResponseTime)
  Widget _buildResponseTimeHistogram() {
    final buckets = <String, int>{
      '0-1h': 0,
      '1-4h': 0,
      '4-12h': 0,
      '12-24h': 0,
      '24h+': 0,
    };
    for (final wo in _periodWorkOrders) {
      final hrs = _hoursBetween(wo.createdAt, wo.firstResponseTime);
      if (hrs == null) continue;
      if (hrs <= 1) {
        buckets['0-1h'] = buckets['0-1h']! + 1;
      } else if (hrs <= 4) {
        buckets['1-4h'] = buckets['1-4h']! + 1;
      } else if (hrs <= 12) {
        buckets['4-12h'] = buckets['4-12h']! + 1;
      } else if (hrs <= 24) {
        buckets['12-24h'] = buckets['12-24h']! + 1;
      } else {
        buckets['24h+'] = buckets['24h+']! + 1;
      }
    }
    final total = buckets.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const _SectionCard(
          title: 'Response Time Histogram',
          child: _PlaceholderBody(subtitle: 'No data'),);
    }
    final data = buckets.entries
        .map((e) => _BarPoint(label: e.key, value: e.value.toDouble()))
        .toList();
    return _SectionCard(
      title: 'Response Time Histogram',
      child: SizedBox(
        height: 220,
        child: SfCartesianChart(
          primaryXAxis: ChartThemeUtil.categoryXAxis(),
          primaryYAxis: ChartThemeUtil.yAxisZero(),
          tooltipBehavior: ChartThemeUtil.tooltip('point.x: point.y'),
          series: <CartesianSeries<_BarPoint, String>>[
            ColumnSeries<_BarPoint, String>(
              dataSource: data,
              xValueMapper: (_BarPoint p, _) => p.label,
              yValueMapper: (_BarPoint p, _) => p.value,
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(6),
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  // =========================== helpers ===========================
  double? _hoursBetween(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    return end.difference(start).inMinutes / 60.0;
  }

  String _fmtNumber(num v) => v.toStringAsFixed(1);
  String _fmtHours(num v) => v.toStringAsFixed(1);

  String _techNameById(UnifiedDataProvider unified, String id) {
    if (id == 'unassigned') return 'Unassigned';
    try {
      return unified.users.firstWhere((u) => u.id == id).name;
    } catch (_) {
      return id;
    }
  }

  String _assetNameById(UnifiedDataProvider unified, String id) {
    if (id == 'unassigned') return 'Unassigned';
    try {
      return unified.assets.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return id;
    }
  }

  // Chart models moved to top-level (see bottom of file)

  // =========================== Server-filtered previews ===========================
  Future<void> _showServerFilteredWorkOrders({
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    DateTime? start,
    DateTime? end,
  }) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<List<WorkOrder>>(
        future: sl<UnifiedDataService>().queryWorkOrders(
          status: status,
          priority: priority,
          assignedTechnicianId: _filterTechnicianId,
          assetId: _filterAssetId,
          startDate: start,
          endDate: end,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          var items = snapshot.data!;
          // Apply location and category filters client-side (asset properties)
          if (_filterLocation != null && _filterLocation!.isNotEmpty) {
            final unified =
                Provider.of<UnifiedDataProvider>(context, listen: false);
            items = items
                .where((wo) => unified.assets.any(
                    (a) => a.id == wo.assetId && a.location == _filterLocation,),)
                .toList();
          }
          if (_filterCategory != null && _filterCategory!.isNotEmpty) {
            final unified =
                Provider.of<UnifiedDataProvider>(context, listen: false);
            items = items
                .where((wo) => unified.assets.any((a) =>
                    a.id == wo.assetId &&
                    (a.category ?? '') == _filterCategory,),)
                .toList();
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Server Results (${items.length})',
                        style: AppTheme.heading2,),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (context) => WorkOrderListScreen(
                              isTechnicianView: widget.isTechnicianView,
                              initialStatusFilter: status,
                              initialPriorityFilter: priority,
                              startDate: start,
                              endDate: end,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open full list'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const _PlaceholderBody(subtitle: 'No results')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length.clamp(0, 25),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final wo = items[idx];
                        return ListTile(
                          dense: true,
                          title: Text(wo.ticketNumber),
                          subtitle: Text(
                              '${wo.statusDisplayName} • ${wo.priorityDisplayName}',),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showServerFilteredPMTasks({
    PMTaskStatus? status,
    DateTime? start,
    DateTime? end,
  }) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<List<PMTask>>(
        future: sl<UnifiedDataService>().queryPMTasks(
          status: status,
          assignedTechnicianId: _filterTechnicianId,
          startDate: start,
          endDate: end,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          var items = snapshot.data!;
          // Apply location and category filters client-side (asset properties)
          if (_filterLocation != null && _filterLocation!.isNotEmpty) {
            final unified =
                Provider.of<UnifiedDataProvider>(context, listen: false);
            items = items
                .where((wo) => unified.assets.any(
                    (a) => a.id == wo.assetId && a.location == _filterLocation,),)
                .toList();
          }
          if (_filterCategory != null && _filterCategory!.isNotEmpty) {
            final unified =
                Provider.of<UnifiedDataProvider>(context, listen: false);
            items = items
                .where((wo) => unified.assets.any((a) =>
                    a.id == wo.assetId &&
                    (a.category ?? '') == _filterCategory,),)
                .toList();
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Server Results (${items.length})',
                        style: AppTheme.heading2,),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (context) => PMTaskListScreen(
                              isTechnicianView: widget.isTechnicianView,
                              initialStatusFilter: status,
                              startDate: start,
                              endDate: end,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open full list'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const _PlaceholderBody(subtitle: 'No results')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length.clamp(0, 25),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final t = items[idx];
                        return ListTile(
                          dense: true,
                          title: Text(t.taskName),
                          subtitle: Text(t.status.name),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _onKpiTap(String title) {
    final (start, end) = _currentPeriodRange();
    switch (title) {
      case 'MTTR':
      case 'TAT':
      case 'Completion Rate':
        _openWorkOrdersFiltered(
          status: WorkOrderStatus.completed,
          start: start,
          end: end,
        );
        break;
      case 'Average Response Time':
        _openWorkOrdersFiltered(
          status: WorkOrderStatus.open,
          start: start,
          end: end,
        );
        break;
      case 'Asset Uptime':
        _openWorkOrdersFiltered(start: start, end: end);
        break;
      default:
        _openWorkOrdersFiltered(start: start, end: end);
    }
  }

  Widget _buildAssetPerformanceTable() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    final cutoff = DateTime.now().subtract(_durationFromKey(_periodKey));

    // Very lightweight estimates based on available fields
    final assets = unified.assets;
    final workOrders =
        unified.workOrders.where((wo) => wo.updatedAt.isAfter(cutoff)).toList();

    final rows = assets.take(20).map((asset) {
      final assetWOs =
          workOrders.where((wo) => wo.assetId == asset.id).toList();
      final completed =
          assetWOs.where((wo) => wo.status.name == 'completed').toList();

      // Simple MTTR: avg (completedAt - createdAt) in hours
      double mttrH = 0;
      if (completed.isNotEmpty) {
        final totalH = completed.fold<double>(0, (sum, wo) {
          final start = wo.createdAt;
          final end = wo.completedAt ?? wo.updatedAt;
          return sum + end.difference(start).inMinutes / 60.0;
        });
        mttrH = totalH / completed.length;
      }

      // Simple MTBF proxy: periodHours / failures
      final periodHours = DateTime.now().difference(cutoff).inHours.toDouble();
      final mtbfH = completed.isNotEmpty ? periodHours / completed.length : 0.0;

      // Uptime: proxy based on asset.status
      final uptime = (asset.status == 'active') ? 100.0 : 0.0;

      // Cost placeholder: 0 (hook up when cost per WO/parts is available locally)
      const cost = 0.0;

      return _AssetPerfRow(
        assetName: asset.name,
        uptimePct: uptime,
        mtbfH: mtbfH,
        mttrH: mttrH,
        cost: cost,
      );
    }).toList();

    return _SectionCard(
      title: 'Asset Performance (period)',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Asset')),
            DataColumn(label: Text('Uptime (%)')),
            DataColumn(label: Text('MTBF (h)')),
            DataColumn(label: Text('MTTR (h)')),
            DataColumn(label: Text('Cost')),
          ],
          rows: rows
              .map(
                (r) => DataRow(
                  cells: [
                    DataCell(Text(r.assetName)),
                    DataCell(Text(r.uptimePct.toStringAsFixed(1))),
                    DataCell(Text(r.mtbfH.toStringAsFixed(1))),
                    DataCell(Text(r.mttrH.toStringAsFixed(1))),
                    DataCell(Text(_fmtCurrency(r.cost))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRecentWorkOrders() {
    final unified = Provider.of<UnifiedDataProvider>(context, listen: false);
    var items = unified.workOrders;
    if (widget.isTechnicianView) {
      final techId = widget.technicianId ??
          Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
      if (techId != null && techId.isNotEmpty) {
        items = items.where((wo) => wo.hasTechnician(techId)).toList();
      }
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final recent = items.take(5).toList();

    return _SectionCard(
      title: 'Recent Work Orders',
      child: recent.isEmpty
          ? const _PlaceholderBody(subtitle: 'No recent activity')
          : _SummaryTable(
              rows: recent
                  .map(
                    (wo) => _SummaryRow(
                      wo.ticketNumber,
                      wo.status.name,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.onTap,
  });
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 400;
    final padding = isNarrow ? 10.0 : 12.0;
    final spacing = isNarrow ? 4.0 : 6.0;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.accentBlue, size: 20),
                SizedBox(width: padding),
                Expanded(
                  child: Text(
                    title,
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: isNarrow ? 12 : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: AppTheme.heading1.copyWith(
                      color: AppTheme.darkTextColor,
                      fontWeight: FontWeight.w700,
                      fontSize: isNarrow ? 20 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width < 400 ? 10.0 : 14.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTheme.heading2.copyWith(
              color: AppTheme.darkTextColor,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: padding * 0.5),
          child,
        ],
      ),
    );
  }
}

class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) => Text(
        subtitle,
        style: AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
      );
}

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({
    required this.message,
    required this.details,
    required this.onRetry,
  });
  final String message;
  final String details;
  final VoidCallback onRetry;

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.message,
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.darkTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  _expanded ? 'Hide details' : 'Show details',
                  style: AppTheme.smallText.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                widget.details,
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ),
          ],
        ],
      );
}

class _AssetPerfRow {
  _AssetPerfRow({
    required this.assetName,
    required this.uptimePct,
    required this.mtbfH,
    required this.mttrH,
    required this.cost,
  });
  final String assetName;
  final double uptimePct;
  final double mtbfH;
  final double mttrH;
  final double cost;
}

class _TechAgg {
  int completed = 0;
  double tatSum = 0;
  int tatCount = 0;
  double get avgTat => tatCount == 0 ? 0.0 : tatSum / tatCount;
}

class _SummaryRow {
  _SummaryRow(this.label, this.value, {this.status, this.priority});
  final String label;
  final String value;
  final WorkOrderStatus? status;
  final WorkOrderPriority? priority;
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.rows, this.onRowTap});
  final List<_SummaryRow> rows;
  final void Function(_SummaryRow row)? onRowTap;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 400;
    final rowPadding = isNarrow ? 4.0 : 6.0;
    final gap = isNarrow ? 6.0 : 8.0;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rows
              .map((r) => InkWell(
                    onTap: onRowTap != null ? () => onRowTap!(r) : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: rowPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              r.label,
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.secondaryTextColor,
                                fontSize: isNarrow ? 13 : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            flex: 1,
                            child: Text(
                              r.value,
                              style: AppTheme.bodyText.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.darkTextColor,
                                fontSize: isNarrow ? 13 : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),)
              .toList(),
        ),
      ),
    );
  }
}

class _KpiInfo {
  _KpiInfo(this.title, this.value, this.unit, this.icon);
  final String title;
  final String value;
  final String unit;
  final IconData icon;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.smallText.copyWith(
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}

// Chart DTOs
class _StatusCount {
  _StatusCount({required this.status, required this.count});
  final String status;
  final double count;
}

class _TrendPoint {
  _TrendPoint(
      {required this.date, required this.opened, required this.completed,});
  final DateTime date;
  final double opened;
  final double completed;
}

// ignore: camel_case_types
class _PieCost {
  _PieCost({required this.cat, required this.value});
  final String cat;
  final double value;
}

class _BarPoint {
  _BarPoint({required this.label, required this.value});
  final String label;
  final double value;
}
