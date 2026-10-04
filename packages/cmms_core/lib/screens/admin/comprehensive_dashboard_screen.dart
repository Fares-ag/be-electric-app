// Comprehensive Dashboard - Showcase all enhanced CMMS features

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/unified_data_provider.dart';
import '../../services/advanced_reporting_service.dart';
import '../../services/audit_logging_service.dart';
import '../../services/comprehensive_cmms_service.dart';
import '../../services/enhanced_inventory_service.dart';
import '../../services/enhanced_notification_service.dart';
import '../../services/escalation_service.dart';
import '../../services/workflow_automation_service.dart';
import '../../utils/app_theme.dart';
import '../../config/locator.dart';
// Removed unused model imports

class ComprehensiveDashboardScreen extends StatefulWidget {
  const ComprehensiveDashboardScreen({super.key});

  @override
  State<ComprehensiveDashboardScreen> createState() =>
      _ComprehensiveDashboardScreenState();
}

class _ComprehensiveDashboardScreenState
    extends State<ComprehensiveDashboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final ComprehensiveCMMSService _cmmsService = sl<ComprehensiveCMMSService>();
  final EnhancedNotificationService _notificationService =
      sl<EnhancedNotificationService>();
  final EscalationService _escalationService = sl<EscalationService>();
  final AdvancedReportingService _reportingService = sl<AdvancedReportingService>();
  final EnhancedInventoryService _inventoryService = sl<EnhancedInventoryService>();
  final WorkflowAutomationService _automationService =
      sl<WorkflowAutomationService>();
  final AuditLoggingService _auditService = sl<AuditLoggingService>();

  Map<String, dynamic>? _systemStats;
  Map<String, dynamic>? _serviceHealth;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      _systemStats = _cmmsService.getSystemStatistics();
      _serviceHealth = _cmmsService.getServiceHealth();
    } catch (e, st) {
      debugPrint('Error loading dashboard data: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Comprehensive CMMS Dashboard'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.darkTextColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDashboardData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppTheme.accentBlue,
            labelColor: AppTheme.darkTextColor,
            unselectedLabelColor: AppTheme.secondaryTextColor,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Notifications'),
              Tab(text: 'Escalations'),
              Tab(text: 'Reports'),
              Tab(text: 'Inventory'),
              Tab(text: 'Automation'),
              Tab(text: 'Audit'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildNotificationsTab(),
                  _buildEscalationsTab(),
                  _buildReportsTab(),
                  _buildInventoryTab(),
                  _buildAutomationTab(),
                  _buildAuditTab(),
                ],
              ),
      );

  Widget _buildOverviewTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) => RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // System Health Status
                _buildSystemHealthCard(),
                const SizedBox(height: AppTheme.spacingL),

                // Key Metrics
                _buildKeyMetricsCard(),
                const SizedBox(height: AppTheme.spacingL),

                // Service Status
                _buildServiceStatusCard(),
                const SizedBox(height: AppTheme.spacingL),

                // Recent Activity
                _buildRecentActivityCard(),
              ],
            ),
          ),
        ),
      );

  Widget _buildNotificationsTab() => StreamBuilder<List<EnhancedNotification>>(
        stream: _notificationService.notificationStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          final unreadCount = _notificationService.unreadCount;

          return Column(
            children: [
              // Notification Stats
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                margin: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Notifications',
                        notifications.length.toString(),
                        Icons.notifications,
                        AppTheme.accentBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Unread',
                        unreadCount.toString(),
                        Icons.notifications_active,
                        AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),

              // Notifications List
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(notification);
                  },
                ),
              ),
            ],
          );
        },
      );

  Widget _buildEscalationsTab() => Column(
        children: [
          // Escalation Stats
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Active Escalations',
                    _escalationService.activeEvents.length.toString(),
                    Icons.warning,
                    AppTheme.accentRed,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Total Events',
                    _escalationService.events.length.toString(),
                    Icons.timeline,
                    AppTheme.accentBlue,
                  ),
                ),
              ],
            ),
          ),

          // Escalations List
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              itemCount: _escalationService.activeEvents.length,
              itemBuilder: (context, index) {
                final event = _escalationService.activeEvents[index];
                return _buildEscalationCard(event);
              },
            ),
          ),
        ],
      );

  Widget _buildReportsTab() => Column(
        children: [
          // Report Actions
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Advanced Reporting',
                  style:
                      AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generateWorkOrderReport,
                        icon: const Icon(Icons.assignment),
                        label: const Text('Work Orders'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generatePMTaskReport,
                        icon: const Icon(Icons.task),
                        label: const Text('PM Tasks'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generateInventoryReport,
                        icon: const Icon(Icons.inventory),
                        label: const Text('Inventory'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generateAuditReport,
                        icon: const Icon(Icons.security),
                        label: const Text('Audit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Generated Reports
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              itemCount: _reportingService.generatedReports.length,
              itemBuilder: (context, index) {
                final report = _reportingService.generatedReports[index];
                return _buildReportCard(report);
              },
            ),
          ),
        ],
      );

  Widget _buildInventoryTab() => Column(
        children: [
          // Inventory Stats
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Enhanced Inventory Management',
                  style:
                      AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Items',
                        _inventoryService
                            .getInventoryStats()['totalItems']
                            .toString(),
                        Icons.inventory,
                        AppTheme.accentBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Low Stock',
                        _inventoryService
                            .getInventoryStats()['lowStockItems']
                            .toString(),
                        Icons.warning,
                        AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Pending Requests',
                        _inventoryService
                            .getInventoryStats()['pendingRequests']
                            .toString(),
                        Icons.pending,
                        AppTheme.accentBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Vendors',
                        _inventoryService.vendors.length.toString(),
                        Icons.business,
                        AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Inventory Actions
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createInventoryRequest,
                    icon: const Icon(Icons.add),
                    label: const Text('New Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen, // Be Electric brand green
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewInventoryRequests,
                    icon: const Icon(Icons.list),
                    label: const Text('View Requests'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen, // Be Electric brand green
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inventory Requests
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              itemCount: _inventoryService.requests.length,
              itemBuilder: (context, index) {
                final request = _inventoryService.requests[index];
                return _buildInventoryRequestCard(request);
              },
            ),
          ),
        ],
      );

  Widget _buildAutomationTab() => Column(
        children: [
          // Automation Stats
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Workflow Automation',
                  style:
                      AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Active Rules',
                        _automationService
                            .getAutomationStats()['activeRules']
                            .toString(),
                        Icons.rule,
                        AppTheme.accentGreen,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Executions',
                        _automationService
                            .getAutomationStats()['totalExecutions']
                            .toString(),
                        Icons.play_arrow,
                        AppTheme.accentBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Success Rate',
                        '${_automationService.getAutomationStats()['successRate'].toStringAsFixed(1)}%',
                        Icons.check_circle,
                        AppTheme.accentGreen,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Failed',
                        _automationService
                            .getAutomationStats()['failedExecutions']
                            .toString(),
                        Icons.error,
                        AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Automation Rules
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              itemCount: _automationService.rules.length,
              itemBuilder: (context, index) {
                final rule = _automationService.rules[index];
                return _buildAutomationRuleCard(rule);
              },
            ),
          ),
        ],
      );

  Widget _buildAuditTab() => Column(
        children: [
          // Audit Stats
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Audit Logging',
                  style:
                      AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Total Events',
                        _auditService.getAuditStats()['totalEvents'].toString(),
                        Icons.history,
                        AppTheme.accentBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Last 24h',
                        _auditService
                            .getAuditStats()['eventsLast24Hours']
                            .toString(),
                        Icons.schedule,
                        AppTheme.accentOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Last 7 Days',
                        _auditService
                            .getAuditStats()['eventsLast7Days']
                            .toString(),
                        Icons.calendar_today,
                        AppTheme.accentGreen,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Most Active',
                        _auditService.getAuditStats()['mostActiveUser'] ??
                            'N/A',
                        Icons.person,
                        AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Audit Events
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
              itemCount: _auditService.events.length,
              itemBuilder: (context, index) {
                final event = _auditService.events[index];
                return _buildAuditEventCard(event);
              },
            ),
          ),
        ],
      );

  // Helper widgets
  Widget _buildSystemHealthCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Health',
                style:
                    AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (_serviceHealth != null) ...[
                _buildHealthItem(
                  'Comprehensive Service',
                  _serviceHealth!['comprehensiveService'],
                ),
                _buildHealthItem(
                  'Data Service',
                  _serviceHealth!['dataService'],
                ),
                _buildHealthItem(
                  'Notification Service',
                  _serviceHealth!['notificationService'],
                ),
                _buildHealthItem(
                  'Escalation Service',
                  _serviceHealth!['escalationService'],
                ),
                _buildHealthItem(
                  'Reporting Service',
                  _serviceHealth!['reportingService'],
                ),
                _buildHealthItem(
                  'Inventory Service',
                  _serviceHealth!['inventoryService'],
                ),
                _buildHealthItem(
                  'Automation Service',
                  _serviceHealth!['automationService'],
                ),
                _buildHealthItem(
                  'Audit Service',
                  _serviceHealth!['auditService'],
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildHealthItem(String name, bool isHealthy) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.error,
              color: isHealthy ? AppTheme.accentGreen : AppTheme.accentRed,
              size: 16,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              name,
              style: AppTheme.bodyText,
            ),
          ],
        ),
      );

  Widget _buildKeyMetricsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Key Metrics',
                style:
                    AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (_systemStats != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Work Orders',
                        _systemStats!['dataService']['workOrders'].toString(),
                        Icons.assignment,
                        AppTheme.accentBlue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'PM Tasks',
                        _systemStats!['dataService']['pmTasks'].toString(),
                        Icons.task,
                        AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Users',
                        _systemStats!['dataService']['users'].toString(),
                        Icons.people,
                        AppTheme.accentOrange,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Assets',
                        _systemStats!['dataService']['assets'].toString(),
                        Icons.build,
                        AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildServiceStatusCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service Status',
                style:
                    AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (_systemStats != null) ...[
                _buildServiceItem(
                  'Notifications',
                  _systemStats!['notifications']['total'],
                ),
                _buildServiceItem(
                  'Escalations',
                  _systemStats!['escalations']['active'],
                ),
                _buildServiceItem(
                  'Inventory Requests',
                  _systemStats!['inventory']['requests'],
                ),
                _buildServiceItem(
                  'Automation Rules',
                  _systemStats!['automation']['rules'],
                ),
                _buildServiceItem(
                  'Audit Events',
                  _systemStats!['audit']['events'],
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildServiceItem(String name, int count) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
          children: [
            const Icon(
              Icons.circle,
              color: AppTheme.accentBlue,
              size: 8,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              name,
              style: AppTheme.bodyText,
            ),
            const Spacer(),
            Text(
              count.toString(),
              style: AppTheme.bodyText.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
      );

  Widget _buildRecentActivityCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style:
                    AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              const Text(
                'Recent system activity will be displayed here',
                style: TextStyle(color: AppTheme.lightGrey),
              ),
            ],
          ),
        ),
      );

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) =>
      Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              value,
              style: AppTheme.heading2.copyWith(color: color),
            ),
            Text(
              title,
              style: AppTheme.smallText
                  .copyWith(color: AppTheme.secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildNotificationCard(EnhancedNotification notification) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: notification.isRead
                ? AppTheme.disabledColor
                : AppTheme.accentBlue,
            child: Icon(
              Icons.notifications,
              color: notification.isRead
                  ? AppTheme.secondaryTextColor
                  : Colors.white,
            ),
          ),
          title: Text(
            notification.title,
            style: AppTheme.bodyText.copyWith(
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(
            notification.message,
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
          trailing: Text(
            _formatDate(notification.createdAt),
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      );

  Widget _buildEscalationCard(EscalationEvent event) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppTheme.accentRed,
            child: Icon(Icons.warning, color: Colors.white),
          ),
          title: Text(
            'Escalation: ${event.type.toString().split('.').last}',
            style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Item: ${event.itemId}',
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
          trailing: Text(
            _formatDate(event.createdAt),
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      );

  Widget _buildReportCard(ReportData report) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: AppTheme.accentBlue,
            child: Icon(Icons.description, color: Colors.white),
          ),
          title: Text(
            report.config.name,
            style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Format: ${report.config.format.toString().split('.').last}',
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
          trailing: Text(
            _formatDate(report.generatedAt),
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      );

  Widget _buildInventoryRequestCard(InventoryRequest request) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getRequestStatusColor(request.status),
            child: Icon(
              _getRequestStatusIcon(request.status),
              color: Colors.white,
            ),
          ),
          title: Text(
            'Request: ${request.id}',
            style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Quantity: ${request.quantity}',
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
          trailing: Text(
            _formatDate(request.createdAt),
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      );

  Widget _buildAutomationRuleCard(AutomationRule rule) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                rule.isActive ? AppTheme.accentGreen : AppTheme.lightGrey,
            child: Icon(
              Icons.rule,
              color: rule.isActive ? Colors.white : AppTheme.secondaryTextColor,
            ),
          ),
          title: Text(
            rule.name,
            style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            rule.description,
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
          trailing: Text(
            'Priority: ${rule.priority}',
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      );

  Widget _buildAuditEventCard(AuditEvent event) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _getAuditSeverityColor(event.severity),
            child: Icon(
              _getAuditEventIcon(event.type),
              color: Colors.white,
            ),
          ),
          title: Text(
            event.description,
            style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'User: ${event.userName ?? event.userId}',
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
          trailing: Text(
            _formatDate(event.timestamp),
            style:
                AppTheme.smallText.copyWith(color: AppTheme.secondaryTextColor),
          ),
        ),
      );

  // Helper methods
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getRequestStatusColor(InventoryRequestStatus status) {
    switch (status) {
      case InventoryRequestStatus.pending:
        return AppTheme.accentOrange;
      case InventoryRequestStatus.approved:
        return AppTheme.accentGreen;
      case InventoryRequestStatus.rejected:
        return AppTheme.accentRed;
      case InventoryRequestStatus.ordered:
        return AppTheme.accentBlue;
      case InventoryRequestStatus.received:
        return AppTheme.accentGreen;
      case InventoryRequestStatus.cancelled:
        return AppTheme.lightGrey;
    }
  }

  IconData _getRequestStatusIcon(InventoryRequestStatus status) {
    switch (status) {
      case InventoryRequestStatus.pending:
        return Icons.pending;
      case InventoryRequestStatus.approved:
        return Icons.check;
      case InventoryRequestStatus.rejected:
        return Icons.close;
      case InventoryRequestStatus.ordered:
        return Icons.shopping_cart;
      case InventoryRequestStatus.received:
        return Icons.check_circle;
      case InventoryRequestStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getAuditSeverityColor(AuditEventSeverity severity) {
    switch (severity) {
      case AuditEventSeverity.low:
        return AppTheme.accentGreen;
      case AuditEventSeverity.medium:
        return AppTheme.accentBlue;
      case AuditEventSeverity.high:
        return AppTheme.accentOrange;
      case AuditEventSeverity.critical:
        return AppTheme.accentRed;
    }
  }

  IconData _getAuditEventIcon(AuditEventType type) {
    switch (type) {
      case AuditEventType.userLogin:
        return Icons.login;
      case AuditEventType.userLogout:
        return Icons.logout;
      case AuditEventType.workOrderCreated:
        return Icons.assignment;
      case AuditEventType.workOrderCompleted:
        return Icons.check_circle;
      case AuditEventType.securityEvent:
        return Icons.security;
      case AuditEventType.errorOccurred:
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  // Action methods
  Future<void> _generateWorkOrderReport() async {
    // TODO: Implement work order report generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating work order report...')),
    );
  }

  Future<void> _generatePMTaskReport() async {
    // TODO: Implement PM task report generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PM task report...')),
    );
  }

  Future<void> _generateInventoryReport() async {
    // TODO: Implement inventory report generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating inventory report...')),
    );
  }

  Future<void> _generateAuditReport() async {
    // TODO: Implement audit report generation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating audit report...')),
    );
  }

  Future<void> _createInventoryRequest() async {
    // TODO: Navigate to inventory request creation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating inventory request...')),
    );
  }

  Future<void> _viewInventoryRequests() async {
    // TODO: Navigate to inventory requests list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Viewing inventory requests...')),
    );
  }
}
