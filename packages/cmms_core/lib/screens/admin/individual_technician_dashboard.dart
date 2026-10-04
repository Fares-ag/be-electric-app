import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pm_task.dart';
import '../../models/user.dart';
import '../../models/work_order.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../pm_tasks/pm_task_detail_screen.dart';
import '../work_orders/work_order_detail_screen.dart';

class IndividualTechnicianDashboard extends StatefulWidget {
  const IndividualTechnicianDashboard({
    required this.technician,
    super.key,
  });
  final User technician;

  @override
  State<IndividualTechnicianDashboard> createState() =>
      _IndividualTechnicianDashboardState();
}

class _IndividualTechnicianDashboardState
    extends State<IndividualTechnicianDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTechnicianData();
  }

  Future<void> _loadTechnicianData() async {
    try {
      // Load technician-specific data using unified provider
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);

      // Get technician-specific data from unified provider
      unifiedProvider.getWorkOrdersByTechnician(widget.technician.id);
      unifiedProvider.getPMTasksByTechnician(widget.technician.id);

      print(
        'ðŸ“Š Individual Technician Dashboard: Loaded data for ${widget.technician.name}',
      );
    } catch (e, st) {
      print('Error loading technician data: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          // Get technician-specific data
          unifiedProvider.getWorkOrdersByTechnician(widget.technician.id);
          unifiedProvider.getPMTasksByTechnician(widget.technician.id);

          return Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              title: Text('${widget.technician.name} - Dashboard'),
              backgroundColor: AppTheme.surfaceColor,
              foregroundColor: AppTheme.darkTextColor,
              elevation: AppTheme.elevationS,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboardTab(),
                _buildWorkOrdersTab(),
                _buildPMTasksTab(),
                _buildAnalyticsTab(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              backgroundColor: AppTheme.surfaceColor,
              selectedItemColor: AppTheme.accentBlue,
              unselectedItemColor: AppTheme.secondaryTextColor,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.work),
                  label: 'Work Orders',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'PM Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
              ],
            ),
          );
        },
      );

  Widget _buildDashboardTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final workOrders =
              unifiedProvider.getWorkOrdersByTechnician(widget.technician.id);
          final pmTasks =
              unifiedProvider.getPMTasksByTechnician(widget.technician.id);

          // Mobile responsive check
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          final padding = isMobile ? AppTheme.spacingM : AppTheme.spacingL;
          final avatarSize = isMobile ? 32.0 : 40.0;

          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Technician Info Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(
                    isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: avatarSize,
                        backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                        child: Icon(
                          Icons.build,
                          color: AppTheme.accentBlue,
                          size: avatarSize,
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.technician.name,
                              style: (isMobile
                                      ? AppTheme.heading2
                                      : AppTheme.heading1)
                                  .copyWith(
                                color: AppTheme.darkTextColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingXS),
                            Text(
                              widget.technician.email,
                              style: (isMobile
                                      ? AppTheme.smallText
                                      : AppTheme.bodyText)
                                  .copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.technician.department != null) ...[
                              const SizedBox(height: AppTheme.spacingS),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: AppTheme.spacingXS,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusS),
                                ),
                                child: Text(
                                  widget.technician.department!,
                                  style: AppTheme.smallText.copyWith(
                                    color: AppTheme.accentBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                ),

                // Performance Stats
                Text(
                  'Performance Overview',
                  style: (isMobile ? AppTheme.bodyText : AppTheme.heading2)
                      .copyWith(
                    color: AppTheme.darkTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Stats Grid - Responsive (2 columns on mobile, 2 columns on desktop)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Work Orders',
                        workOrders.length.toString(),
                        Icons.work,
                        AppTheme.accentBlue,
                        isMobile: isMobile,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? AppTheme.spacingS : AppTheme.spacingM,
                    ),
                    Expanded(
                      child: _buildStatCard(
                        'Completed',
                        workOrders
                            .where(
                              (wo) => wo.status == WorkOrderStatus.completed,
                            )
                            .length
                            .toString(),
                        Icons.check_circle,
                        AppTheme.accentGreen,
                        isMobile: isMobile,
                      ),
                    ),
                  ],
                ),

                SizedBox(
                  height: isMobile ? AppTheme.spacingS : AppTheme.spacingL,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'PM Tasks',
                        pmTasks.length.toString(),
                        Icons.schedule,
                        AppTheme.accentOrange,
                        isMobile: isMobile,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? AppTheme.spacingS : AppTheme.spacingM,
                    ),
                    Expanded(
                      child: _buildStatCard(
                        'In Progress',
                        workOrders
                            .where(
                              (wo) => wo.status == WorkOrderStatus.inProgress,
                            )
                            .length
                            .toString(),
                        Icons.hourglass_empty,
                        AppTheme.accentRed,
                        isMobile: isMobile,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingL),

                // Recent Activity
                Text(
                  'Recent Activity',
                  style: AppTheme.heading2.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Recent work orders and PM tasks for ${widget.technician.name}',
                          style: AppTheme.bodyText.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedIndex = 1; // Switch to work orders tab
                            });
                          },
                          icon: const Icon(Icons.work),
                          label: const Text('View All Work Orders'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _buildWorkOrdersTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final workOrders =
              unifiedProvider.getWorkOrdersByTechnician(widget.technician.id);

          return Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Work Orders - ${widget.technician.name}',
                  style: AppTheme.heading1.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Expanded(
                  child: workOrders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.work_outline,
                                size: 80,
                                color: AppTheme.secondaryTextColor,
                              ),
                              const SizedBox(height: AppTheme.spacingL),
                              Text(
                                'No Work Orders Assigned',
                                style: AppTheme.heading2.copyWith(
                                  color: AppTheme.darkTextColor,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Text(
                                'This technician has no assigned work orders.',
                                style: AppTheme.bodyText.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: workOrders.length,
                          itemBuilder: (context, index) {
                            final workOrder = workOrders[index];
                            return _buildWorkOrderCard(workOrder);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );

  Widget _buildPMTasksTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final pmTasks =
              unifiedProvider.getPMTasksByTechnician(widget.technician.id);

          return Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PM Tasks - ${widget.technician.name}',
                  style: AppTheme.heading1.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Expanded(
                  child: pmTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                size: 80,
                                color: AppTheme.secondaryTextColor,
                              ),
                              const SizedBox(height: AppTheme.spacingL),
                              Text(
                                'No PM Tasks Assigned',
                                style: AppTheme.heading2.copyWith(
                                  color: AppTheme.darkTextColor,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Text(
                                'This technician has no assigned PM tasks.',
                                style: AppTheme.bodyText.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: pmTasks.length,
                          itemBuilder: (context, index) {
                            final pmTask = pmTasks[index];
                            return _buildPMTaskCard(pmTask);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );

  Widget _buildAnalyticsTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          // Get technician-specific data from unified provider
          final workOrders =
              unifiedProvider.getWorkOrdersByTechnician(widget.technician.id);
          final pmTasks =
              unifiedProvider.getPMTasksByTechnician(widget.technician.id);

          // Calculate technician-specific analytics
          final analytics = _calculateTechnicianAnalytics(workOrders, pmTasks);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics - ${widget.technician.name}',
                  style: AppTheme.heading1.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Performance Overview Cards
                _buildPerformanceOverview(analytics),
                const SizedBox(height: AppTheme.spacingL),

                // Key Metrics Grid
                _buildKeyMetricsGrid(analytics),
                const SizedBox(height: AppTheme.spacingL),

                // Work Order Analytics
                _buildWorkOrderAnalytics(analytics),
                const SizedBox(height: AppTheme.spacingL),

                // PM Task Analytics
                _buildPMTaskAnalytics(analytics),
                const SizedBox(height: AppTheme.spacingL),

                // Performance Trends
                _buildPerformanceTrends(analytics),
                const SizedBox(height: AppTheme.spacingL),

                // Quality Metrics
                _buildQualityMetrics(analytics),
              ],
            ),
          );
        },
      );

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isMobile = false,
  }) =>
      Container(
        padding:
            EdgeInsets.all(isMobile ? AppTheme.spacingS : AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: isMobile ? 4 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isMobile ? 24 : 32),
            SizedBox(height: isMobile ? AppTheme.spacingXS : AppTheme.spacingS),
            Text(
              value,
              style:
                  (isMobile ? AppTheme.heading2 : AppTheme.heading1).copyWith(
                color: AppTheme.darkTextColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              title,
              style: (isMobile
                      ? const TextStyle(fontSize: 10)
                      : AppTheme.smallText)
                  .copyWith(
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  Widget _buildWorkOrderCard(WorkOrder workOrder) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: _getPriorityColor(workOrder.priority).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    WorkOrderDetailScreen(workOrder: workOrder),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with ticket number and status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getPriorityColor(workOrder.priority).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    // Ticket number with icon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(workOrder.priority),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.confirmation_number,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            workOrder.ticketNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.workOrderStatusColor(workOrder.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getWorkOrderStatusIcon(workOrder.status),
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(workOrder.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Problem description
                    Text(
                      workOrder.problemDescription,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkTextColor,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Asset info
                    if (workOrder.asset != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.precision_manufacturing,
                              size: 16,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workOrder.asset!.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkTextColor,
                                  ),
                                ),
                                Text(
                                  workOrder.asset!.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Info row with priority and date
                    Row(
                      children: [
                        // Priority indicator
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(workOrder.priority)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getPriorityIcon(workOrder.priority),
                                  size: 14,
                                  color: _getPriorityColor(workOrder.priority),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  workOrder.priority.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _getPriorityColor(workOrder.priority),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Date
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(workOrder.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildPMTaskCard(PMTask pmTask) {
    final frequencyColor = _getFrequencyColor(pmTask.frequency);
    final statusColor = _getPMTaskStatusColor(pmTask.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pmTask.isOverdue
              ? Colors.red.shade300
              : frequencyColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PMTaskDetailScreen(pmTask: pmTask),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with colored background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pmTask.isOverdue
                    ? Colors.red.shade50
                    : frequencyColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  // Frequency icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: frequencyColor.withOpacity(0.3)),
                    ),
                    child: Icon(
                      _getFrequencyIcon(pmTask.frequency),
                      color: frequencyColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Task name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pmTask.taskName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: frequencyColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    size: 12,
                                    color: frequencyColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    pmTask.frequencyDisplayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: frequencyColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPMTaskStatusIcon(pmTask.status),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pmTask.statusDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asset information
                  if (pmTask.assetName != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.precision_manufacturing,
                            size: 18,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pmTask.assetName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkTextColor,
                                ),
                              ),
                              if (pmTask.assetLocation != null &&
                                  pmTask.assetLocation!.isNotEmpty)
                                Text(
                                  pmTask.assetLocation!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Description
                  if (pmTask.description.isNotEmpty) ...[
                    Text(
                      pmTask.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Footer with due date
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pmTask.isOverdue
                          ? Colors.red.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Due date
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                pmTask.isOverdue
                                    ? Icons.warning_rounded
                                    : pmTask.isDueToday
                                        ? Icons.today
                                        : Icons.event,
                                size: 18,
                                color: pmTask.isOverdue
                                    ? Colors.red
                                    : pmTask.isDueToday
                                        ? Colors.orange
                                        : AppTheme.accentBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pmTask.isOverdue
                                          ? 'Overdue'
                                          : pmTask.isDueToday
                                              ? 'Due Today'
                                              : 'Next Due',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(
                                        pmTask.nextDue ?? DateTime.now(),
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: pmTask.isOverdue
                                            ? Colors.red
                                            : AppTheme.darkTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPMTaskStatusColor(status) {
    switch (status.toString()) {
      case 'PMTaskStatus.completed':
        return AppTheme.accentGreen;
      case 'PMTaskStatus.inProgress':
        return AppTheme.accentOrange;
      case 'PMTaskStatus.pending':
        return AppTheme.accentBlue;
      case 'PMTaskStatus.overdue':
        return Colors.red;
      case 'PMTaskStatus.cancelled':
        return Colors.grey;
      default:
        return AppTheme.secondaryTextColor;
    }
  }

  String _getStatusText(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return 'Open';
      case WorkOrderStatus.assigned:
        return 'Assigned';
      case WorkOrderStatus.inProgress:
        return 'In Progress';
      case WorkOrderStatus.completed:
        return 'Completed';
      case WorkOrderStatus.cancelled:
        return 'Cancelled';
      case WorkOrderStatus.closed:
        return 'Closed';
      case WorkOrderStatus.reopened:
        return 'Reopened';
    }
  }

  // Enhanced Analytics Methods
  Map<String, dynamic> _calculateTechnicianAnalytics(
    List workOrders,
    List pmTasks,
  ) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Filter technician's work orders and PM tasks
    final technicianWorkOrders = workOrders
        .where((wo) => wo.hasTechnician(widget.technician.id))
        .toList();
    final technicianPMTasks = pmTasks
        .where((task) => task.hasTechnician(widget.technician.id))
        .toList();

    // Calculate completion rates
    final completedWorkOrders = technicianWorkOrders
        .where((wo) => wo.status.toString().contains('completed'))
        .length;
    final completedPMTasks = technicianPMTasks
        .where((task) => task.status.toString().contains('completed'))
        .length;

    final workOrderCompletionRate = technicianWorkOrders.isEmpty
        ? 0.0
        : (completedWorkOrders / technicianWorkOrders.length) * 100;
    final pmTaskCompletionRate = technicianPMTasks.isEmpty
        ? 0.0
        : (completedPMTasks / technicianPMTasks.length) * 100;

    // Calculate average completion times
    final completedWOWithTimes = technicianWorkOrders
        .where(
          (wo) =>
              wo.status.toString().contains('completed') &&
              wo.completedAt != null,
        )
        .toList();
    final avgCompletionTime = completedWOWithTimes.isEmpty
        ? 0.0
        : completedWOWithTimes
                .map(
                  (wo) => wo.completedAt!
                      .difference(wo.createdAt)
                      .inHours
                      .toDouble(),
                )
                .reduce((a, b) => a + b) /
            completedWOWithTimes.length;

    // Calculate efficiency score
    final totalTasks = technicianWorkOrders.length + technicianPMTasks.length;
    final completedTasks = completedWorkOrders + completedPMTasks;
    final efficiencyScore =
        totalTasks == 0 ? 0.0 : (completedTasks / totalTasks) * 100;

    // Calculate recent performance (last 30 days)
    final recentWorkOrders = technicianWorkOrders
        .where((wo) => wo.createdAt.isAfter(thirtyDaysAgo))
        .length;
    final recentPMTasks = technicianPMTasks
        .where((task) => task.createdAt.isAfter(thirtyDaysAgo))
        .length;

    // Calculate quality metrics
    final onTimeCompletions = completedWOWithTimes
        .where((wo) => wo.completedAt!.difference(wo.createdAt).inHours <= 24)
        .length;
    final qualityScore = completedWOWithTimes.isEmpty
        ? 0.0
        : (onTimeCompletions / completedWOWithTimes.length) * 100;

    return {
      'totalWorkOrders': technicianWorkOrders.length,
      'totalPMTasks': technicianPMTasks.length,
      'completedWorkOrders': completedWorkOrders,
      'completedPMTasks': completedPMTasks,
      'workOrderCompletionRate': workOrderCompletionRate,
      'pmTaskCompletionRate': pmTaskCompletionRate,
      'avgCompletionTime': avgCompletionTime,
      'efficiencyScore': efficiencyScore,
      'recentWorkOrders': recentWorkOrders,
      'recentPMTasks': recentPMTasks,
      'qualityScore': qualityScore,
      'onTimeCompletions': onTimeCompletions,
      'totalCompletedTasks': completedTasks,
      'totalTasks': totalTasks,
    };
  }

  Widget _buildPerformanceOverview(Map<String, dynamic> analytics) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Overview',
            style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Efficiency Score',
                  '${analytics['efficiencyScore'].toStringAsFixed(1)}%',
                  Icons.speed,
                  _getEfficiencyColor(analytics['efficiencyScore']),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildAnalyticsCard(
                  'Quality Score',
                  '${analytics['qualityScore'].toStringAsFixed(1)}%',
                  Icons.star,
                  _getQualityColor(analytics['qualityScore']),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _buildKeyMetricsGrid(Map<String, dynamic> analytics) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Metrics',
            style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
          ),
          const SizedBox(height: AppTheme.spacingM),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: AppTheme.spacingM,
            mainAxisSpacing: AppTheme.spacingM,
            children: [
              _buildAnalyticsCard(
                'Work Orders',
                '${analytics['totalWorkOrders']}',
                Icons.work,
                AppTheme.accentBlue,
              ),
              _buildAnalyticsCard(
                'PM Tasks',
                '${analytics['totalPMTasks']}',
                Icons.schedule,
                AppTheme.accentGreen,
              ),
              _buildAnalyticsCard(
                'Completed',
                '${analytics['totalCompletedTasks']}',
                Icons.check_circle,
                AppTheme.accentGreen,
              ),
              _buildAnalyticsCard(
                'Avg Time',
                '${analytics['avgCompletionTime'].toStringAsFixed(1)}h',
                Icons.timer,
                AppTheme.accentOrange,
              ),
            ],
          ),
        ],
      );

  Widget _buildWorkOrderAnalytics(Map<String, dynamic> analytics) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Order Analytics',
              style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Completion Rate',
                    '${analytics['workOrderCompletionRate'].toStringAsFixed(1)}%',
                    Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'On-Time Rate',
                    '${analytics['qualityScore'].toStringAsFixed(1)}%',
                    Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Recent (30d)',
                    '${analytics['recentWorkOrders']}',
                    Icons.trending_up,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Avg Completion',
                    '${analytics['avgCompletionTime'].toStringAsFixed(1)}h',
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildPMTaskAnalytics(Map<String, dynamic> analytics) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PM Task Analytics',
              style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Completion Rate',
                    '${analytics['pmTaskCompletionRate'].toStringAsFixed(1)}%',
                    Icons.analytics,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Recent (30d)',
                    '${analytics['recentPMTasks']}',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildPerformanceTrends(Map<String, dynamic> analytics) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Trends',
              style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildTrendItem(
              'Task Completion',
              analytics['efficiencyScore'] > 80
                  ? 'Excellent'
                  : analytics['efficiencyScore'] > 60
                      ? 'Good'
                      : 'Needs Improvement',
              analytics['efficiencyScore'] > 80
                  ? Colors.green
                  : analytics['efficiencyScore'] > 60
                      ? Colors.orange
                      : Colors.red,
            ),
            const SizedBox(height: AppTheme.spacingS),
            _buildTrendItem(
              'Quality Performance',
              analytics['qualityScore'] > 90
                  ? 'Outstanding'
                  : analytics['qualityScore'] > 70
                      ? 'Good'
                      : 'Needs Focus',
              analytics['qualityScore'] > 90
                  ? Colors.green
                  : analytics['qualityScore'] > 70
                      ? Colors.orange
                      : Colors.red,
            ),
            const SizedBox(height: AppTheme.spacingS),
            _buildTrendItem(
              'Workload',
              analytics['totalTasks'] > 20
                  ? 'High'
                  : analytics['totalTasks'] > 10
                      ? 'Moderate'
                      : 'Light',
              analytics['totalTasks'] > 20
                  ? Colors.blue
                  : analytics['totalTasks'] > 10
                      ? Colors.orange
                      : Colors.green,
            ),
          ],
        ),
      );

  Widget _buildQualityMetrics(Map<String, dynamic> analytics) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality Metrics',
              style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildQualityItem(
                    'On-Time Completions',
                    '${analytics['onTimeCompletions']}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildQualityItem(
                    'Total Completed',
                    '${analytics['totalCompletedTasks']}',
                    Icons.done_all,
                    AppTheme.accentBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) =>
      Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              value,
              style: AppTheme.heading1.copyWith(color: AppTheme.darkTextColor),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              title,
              style: AppTheme.bodyText
                  .copyWith(color: AppTheme.secondaryTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildMetricItem(String title, String value, IconData icon) => Column(
        children: [
          Icon(icon, color: AppTheme.accentBlue, size: 20),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            value,
            style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
          ),
          Text(
            title,
            style:
                AppTheme.bodyText.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildTrendItem(String title, String status, Color color) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              title,
              style: AppTheme.bodyText.copyWith(color: AppTheme.darkTextColor),
            ),
          ),
          Text(
            status,
            style: AppTheme.bodyText.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );

  Widget _buildQualityItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) =>
      Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            value,
            style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
          ),
          Text(
            title,
            style:
                AppTheme.bodyText.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Color _getEfficiencyColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getQualityColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  // Helper methods for work order cards
  Color _getPriorityColor(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low:
        return AppTheme.accentGreen;
      case WorkOrderPriority.medium:
        return AppTheme.accentOrange;
      case WorkOrderPriority.high:
        return AppTheme.accentOrange;
      case WorkOrderPriority.urgent:
        return AppTheme.accentRed;
      case WorkOrderPriority.critical:
        return const Color(0xFF7B1FA2); // Purple
    }
  }

  IconData _getPriorityIcon(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low:
        return Icons.arrow_downward;
      case WorkOrderPriority.medium:
        return Icons.remove;
      case WorkOrderPriority.high:
        return Icons.arrow_upward;
      case WorkOrderPriority.urgent:
        return Icons.error_outline;
      case WorkOrderPriority.critical:
        return Icons.priority_high;
    }
  }

  IconData _getWorkOrderStatusIcon(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return Icons.inbox;
      case WorkOrderStatus.assigned:
        return Icons.person_add;
      case WorkOrderStatus.inProgress:
        return Icons.sync;
      case WorkOrderStatus.completed:
        return Icons.check_circle;
      case WorkOrderStatus.cancelled:
        return Icons.cancel;
      case WorkOrderStatus.closed:
        return Icons.done_all;
      case WorkOrderStatus.reopened:
        return Icons.restore; // Icon for reopened status
    }
  }

  // Helper methods for PM task cards
  Color _getFrequencyColor(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return Colors.purple;
      case PMTaskFrequency.weekly:
        return Colors.blue;
      case PMTaskFrequency.monthly:
        return Colors.teal;
      case PMTaskFrequency.quarterly:
        return Colors.indigo;
      case PMTaskFrequency.semiAnnually:
        return Colors.deepPurple;
      case PMTaskFrequency.annually:
        return Colors.deepOrange;
      case PMTaskFrequency.asNeeded:
        return Colors.grey;
    }
  }

  IconData _getFrequencyIcon(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return Icons.today;
      case PMTaskFrequency.weekly:
        return Icons.view_week;
      case PMTaskFrequency.monthly:
        return Icons.calendar_month;
      case PMTaskFrequency.quarterly:
        return Icons.calendar_view_month;
      case PMTaskFrequency.semiAnnually:
        return Icons.calendar_today;
      case PMTaskFrequency.annually:
        return Icons.event_repeat;
      case PMTaskFrequency.asNeeded:
        return Icons.schedule;
    }
  }

  IconData _getPMTaskStatusIcon(PMTaskStatus status) {
    switch (status) {
      case PMTaskStatus.pending:
        return Icons.pending;
      case PMTaskStatus.inProgress:
        return Icons.sync;
      case PMTaskStatus.completed:
        return Icons.check_circle;
      case PMTaskStatus.overdue:
        return Icons.warning;
      case PMTaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime date) => '${date.month}/${date.day}/${date.year}';
}
