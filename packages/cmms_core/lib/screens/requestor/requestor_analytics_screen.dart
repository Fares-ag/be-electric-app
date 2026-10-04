import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/requestor_home_navigation.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/work_order_duration.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/requestor_more_menu.dart';

class RequestorAnalyticsScreen extends StatelessWidget {
  const RequestorAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'My Analytics',
        usePageTitle: true,
        showMenu: false,
        showBackButton: true,
        onMoreTap: () {
          showRequestorMoreMenu(
            context,
            primaryLabel: 'Home',
            primaryIcon: Icons.home_outlined,
            onPrimaryNav: () => navigateToRequestorMain(context),
          );
        },
      ),
      body: Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final currentUser =
              Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Not logged in'));
          }

          final myWorkOrders = unifiedProvider.workOrders
              .where((wo) => wo.requestorId == currentUser.id)
              .toList();

          return RefreshIndicator(
            onRefresh: () =>
                unifiedProvider.loadRequestorWorkOrders(currentUser.id),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: padding,
                  child: isDesktop
                      ? _buildDesktopLayout(context, myWorkOrders, unifiedProvider)
                      : _buildMobileLayout(context, myWorkOrders, unifiedProvider),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<WorkOrder> myWorkOrders,
    UnifiedDataProvider unifiedProvider,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOverviewStats(context, myWorkOrders),
              const SizedBox(height: AppTheme.spacingL),
              _buildStatusBreakdown(context, myWorkOrders),
              const SizedBox(height: AppTheme.spacingL),
              _buildPriorityBreakdown(context, myWorkOrders),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacingL),
        // Right column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPerformanceMetrics(context, myWorkOrders),
              const SizedBox(height: AppTheme.spacingL),
              _buildRecentTrends(context, myWorkOrders),
              const SizedBox(height: AppTheme.spacingL),
              _buildTopAssets(context, myWorkOrders, unifiedProvider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    List<WorkOrder> myWorkOrders,
    UnifiedDataProvider unifiedProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOverviewStats(context, myWorkOrders),
        const SizedBox(height: AppTheme.spacingL),
        _buildStatusBreakdown(context, myWorkOrders),
        const SizedBox(height: AppTheme.spacingL),
        _buildPriorityBreakdown(context, myWorkOrders),
        const SizedBox(height: AppTheme.spacingL),
        _buildPerformanceMetrics(context, myWorkOrders),
        const SizedBox(height: AppTheme.spacingL),
        _buildRecentTrends(context, myWorkOrders),
        const SizedBox(height: AppTheme.spacingL),
        _buildTopAssets(context, myWorkOrders, unifiedProvider),
      ],
    );
  }

  Widget _buildOverviewStats(BuildContext context, List<WorkOrder> workOrders) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    
    return Card(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: AppTheme.heading1.copyWith(
                  color: AppTheme.darkTextColor,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(
                    context,
                    mobile: 20,
                    tablet: 22,
                    desktop: 24,
                  ),
                ),
              ),
              SizedBox(height: isDesktop ? AppTheme.spacingL : AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total Requests',
                      workOrders.length.toString(),
                      Icons.assignment,
                      const Color(0xFF002911), // Be Electric green
                    ),
                  ),
                  SizedBox(width: isDesktop ? AppTheme.spacingL : AppTheme.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Completed',
                      workOrders
                          .where((wo) => wo.status == WorkOrderStatus.completed)
                          .length
                          .toString(),
                      Icons.check_circle,
                      const Color(0xFF002911), // Be Electric green
                    ),
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? AppTheme.spacingL : AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'In Progress',
                      workOrders
                          .where((wo) => wo.status == WorkOrderStatus.inProgress)
                          .length
                          .toString(),
                      Icons.work,
                      AppTheme.accentOrange,
                    ),
                  ),
                  SizedBox(width: isDesktop ? AppTheme.spacingL : AppTheme.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Pending',
                      workOrders
                          .where((wo) => wo.status == WorkOrderStatus.open ||
                              wo.status == WorkOrderStatus.assigned)
                          .length
                          .toString(),
                      Icons.pending,
                      AppTheme.disabledColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Container(
      padding: EdgeInsets.all(isDesktop ? AppTheme.spacingL : AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: ResponsiveLayout.getResponsiveIconSize(
              context,
              mobile: 28,
              tablet: 32,
              desktop: 36,
            ),
          ),
          SizedBox(height: isDesktop ? AppTheme.spacingM : AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.heading1.copyWith(
              color: color,
              fontSize: ResponsiveLayout.getResponsiveFontSize(
                context,
                mobile: 24,
                tablet: 28,
                desktop: 32,
              ),
            ),
          ),
          Text(
            title,
            style: AppTheme.smallText.copyWith(
              color: AppTheme.secondaryTextColor,
              fontSize: ResponsiveLayout.getResponsiveFontSize(
                context,
                mobile: 12,
                tablet: 13,
                desktop: 14,
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(BuildContext context, List<WorkOrder> workOrders) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Card(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status Breakdown',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              ...WorkOrderStatus.values.map((status) {
                final count =
                    workOrders.where((wo) => wo.status == status).length;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppTheme.workOrderStatusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          _getStatusText(status),
                          style: AppTheme.bodyText,
                        ),
                      ),
                      Text(
                        count.toString(),
                        style: AppTheme.bodyText.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.workOrderStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
  }

  Widget _buildPriorityBreakdown(BuildContext context, List<WorkOrder> workOrders) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Card(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Priority Breakdown',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                  fontSize: ResponsiveLayout.getResponsiveFontSize(
                    context,
                    mobile: 18,
                    tablet: 20,
                    desktop: 22,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              ...WorkOrderPriority.values.map((priority) {
                final count =
                    workOrders.where((wo) => wo.priority == priority).length;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: Row(
                    children: [
                      Icon(
                        _getPriorityIcon(priority),
                        size: 16,
                        color: _getPriorityColor(priority),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          priority.name.toUpperCase(),
                          style: AppTheme.bodyText,
                        ),
                      ),
                      Text(
                        count.toString(),
                        style: AppTheme.bodyText.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(priority),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      );
  }

  Widget _buildPerformanceMetrics(BuildContext context, List<WorkOrder> workOrders) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final completedOrders = workOrders
        .where((wo) => wo.status == WorkOrderStatus.completed &&
            wo.completedAt != null &&
            wo.createdAt != null)
        .toList();

    if (completedOrders.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
          child: Column(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 48,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'No performance data available',
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Complete some requests to see metrics',
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate average resolution time
    final totalDays = completedOrders.fold<double>(
      0,
      (sum, wo) =>
          sum +
          elapsedDaysBetween(wo.createdAt, wo.completedAt!),
    );
    final avgDays = totalDays / completedOrders.length;

    // Find fastest and slowest
    final fastest = completedOrders.reduce((a, b) {
      final aSeconds = elapsedSecondsBetween(a.createdAt, a.completedAt!);
      final bSeconds = elapsedSecondsBetween(b.createdAt, b.completedAt!);
      return aSeconds <= bSeconds ? a : b;
    });
    final slowest = completedOrders.reduce((a, b) {
      final aSeconds = elapsedSecondsBetween(a.createdAt, a.completedAt!);
      final bSeconds = elapsedSecondsBetween(b.createdAt, b.completedAt!);
      return aSeconds >= bSeconds ? a : b;
    });

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: AppTheme.heading2.copyWith(
                color: AppTheme.darkTextColor,
                fontSize: ResponsiveLayout.getResponsiveFontSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildMetricRow(
              context,
              'Average Resolution Time',
              '${avgDays.toStringAsFixed(1)} days',
              Icons.timer,
            ),
            _buildMetricRow(
              context,
              'Fastest Resolution',
              formatWorkDurationSeconds(
                elapsedSecondsBetween(
                  fastest.createdAt,
                  fastest.completedAt!,
                ),
              ),
              Icons.flash_on,
              AppTheme.accentGreen,
            ),
            _buildMetricRow(
              context,
              'Slowest Resolution',
              formatWorkDurationSeconds(
                elapsedSecondsBetween(
                  slowest.createdAt,
                  slowest.completedAt!,
                ),
              ),
              Icons.hourglass_empty,
              AppTheme.accentOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? AppTheme.spacingL : AppTheme.spacingM),
      child: Row(
        children: [
          Icon(
            icon,
            size: ResponsiveLayout.getResponsiveIconSize(
              context,
              mobile: 18,
              tablet: 20,
              desktop: 22,
            ),
            color: color ?? const Color(0xFF002911), // Be Electric green
          ),
          SizedBox(width: isDesktop ? AppTheme.spacingM : AppTheme.spacingS),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyText.copyWith(
                fontSize: ResponsiveLayout.getResponsiveFontSize(
                  context,
                  mobile: 14,
                  tablet: 15,
                  desktop: 16,
                ),
              ),
            ),
          ),
          Text(
            value,
            style: AppTheme.bodyText.copyWith(
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.darkTextColor,
              fontSize: ResponsiveLayout.getResponsiveFontSize(
                context,
                mobile: 14,
                tablet: 15,
                desktop: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrends(BuildContext context, List<WorkOrder> workOrders) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    // Group by month
    final now = DateTime.now();
    final last6Months = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      last6Months[monthKey] = workOrders
          .where((wo) =>
              wo.createdAt.year == month.year &&
              wo.createdAt.month == month.month)
          .length;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Trends (Last 6 Months)',
              style: AppTheme.heading2.copyWith(
                color: AppTheme.darkTextColor,
                fontSize: ResponsiveLayout.getResponsiveFontSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            if (last6Months.values.every((v) => v == 0))
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Text(
                    'No requests in the last 6 months',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ),
              )
            else
              ...last6Months.entries.map((entry) {
                final maxValue = last6Months.values.reduce((a, b) => a > b ? a : b);
                final percentage = maxValue > 0 ? entry.value / maxValue : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatMonth(entry.key),
                            style: AppTheme.smallText,
                          ),
                          Text(
                            entry.value.toString(),
                            style: AppTheme.bodyText.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: AppTheme.lightGrey,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF002911), // Be Electric green
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAssets(
    BuildContext context,
    List<WorkOrder> workOrders,
    UnifiedDataProvider provider,
  ) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final assetCounts = <String, int>{};
    for (final wo in workOrders) {
      if (wo.assetId != null && wo.assetId!.isNotEmpty) {
        assetCounts[wo.assetId!] = (assetCounts[wo.assetId!] ?? 0) + 1;
      }
    }

    final sortedAssets = assetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topAssets = sortedAssets.take(5).toList();

    if (topAssets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? AppTheme.spacingXL : AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Requested Assets',
              style: AppTheme.heading2.copyWith(
                color: AppTheme.darkTextColor,
                fontSize: ResponsiveLayout.getResponsiveFontSize(
                  context,
                  mobile: 18,
                  tablet: 20,
                  desktop: 22,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...topAssets.map((entry) {
              final asset = provider.assets
                  .where((a) => a.id == entry.key)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      size: 20,
                      color: Color(0xFF002911), // Be Electric green
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        asset?.name ?? entry.key,
                        style: AppTheme.bodyText,
                      ),
                    ),
                    Text(
                      '${entry.value} request${entry.value == 1 ? '' : 's'}',
                      style: AppTheme.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF002911), // Be Electric green
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
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
      case WorkOrderStatus.closed:
        return 'Closed';
      case WorkOrderStatus.cancelled:
        return 'Cancelled';
      case WorkOrderStatus.reopened:
        return 'Reopened';
    }
  }

  Color _getPriorityColor(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low:
        return AppTheme.accentGreen;
      case WorkOrderPriority.medium:
        return AppTheme.accentOrange;
      case WorkOrderPriority.high:
        return AppTheme.accentRed;
      case WorkOrderPriority.urgent:
        return AppTheme.accentRed;
      case WorkOrderPriority.critical:
        return Colors.purple;
    }
  }

  IconData _getPriorityIcon(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low:
        return Icons.keyboard_arrow_down;
      case WorkOrderPriority.medium:
        return Icons.remove;
      case WorkOrderPriority.high:
        return Icons.keyboard_arrow_up;
      case WorkOrderPriority.urgent:
        return Icons.error_outline;
      case WorkOrderPriority.critical:
        return Icons.priority_high;
    }
  }

  String _formatMonth(String monthKey) {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${monthNames[month - 1]} $year';
  }
}


