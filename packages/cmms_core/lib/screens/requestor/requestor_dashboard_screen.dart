// Requestor Dashboard - Status tracking and request management

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pm_task.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/enhanced_notification_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';
import '../pm_tasks/pm_task_detail_screen.dart';
import '../work_orders/work_order_detail_screen.dart';
import 'requestor_main_screen.dart';
import '../../config/locator.dart';

class RequestorDashboardScreen extends StatefulWidget {
  const RequestorDashboardScreen({super.key});

  @override
  State<RequestorDashboardScreen> createState() =>
      _RequestorDashboardScreenState();
}

class _RequestorDashboardScreenState extends State<RequestorDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final EnhancedNotificationService _notificationService =
      sl<EnhancedNotificationService>();

  final ScrollController _requestsScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRequestorData();
    _requestsScrollController.addListener(_onRequestsScroll);
    _historyScrollController.addListener(_onHistoryScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _requestsScrollController
      ..removeListener(_onRequestsScroll)
      ..dispose();
    _historyScrollController
      ..removeListener(_onHistoryScroll)
      ..dispose();
    super.dispose();
  }

  void _onRequestsScroll() {
    if (!_requestsScrollController.hasClients) return;
    final pos = _requestsScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      Provider.of<UnifiedDataProvider>(context, listen: false)
          .loadMoreWorkOrders();
    }
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    final pos = _historyScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      Provider.of<UnifiedDataProvider>(context, listen: false)
          .loadMoreWorkOrders();
    }
  }

  Future<void> _loadRequestorData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    await unifiedProvider.loadRequestorWorkOrders(userId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('My Requests'),
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            StreamBuilder<List<EnhancedNotification>>(
              stream: _notificationService.notificationStream,
              builder: (context, snapshot) {
                final unreadCount = _notificationService.unreadCount;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: _showNotifications,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              tooltip: 'Menu',
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accentBlue,
            labelColor: AppTheme.darkTextColor,
            unselectedLabelColor: AppTheme.secondaryTextColor,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'My Requests'),
              Tab(text: 'History'),
              Tab(text: 'Notifications'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildDashboardTab(),
            _buildMyRequestsTab(),
            _buildHistoryTab(),
            _buildNotificationsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createNewRequest,
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Request'),
        ),
      );

  Widget _buildDashboardTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final currentUser =
              Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Not logged in'));
          }

          final myWorkOrders = unifiedProvider.workOrders
              .where((wo) => wo.requestorId == currentUser.id)
              .toList();
          final myPMTasks = unifiedProvider.pmTasks
              .where((pt) => pt.hasTechnician(currentUser.id))
              .toList();

          return RefreshIndicator(
            onRefresh: _loadRequestorData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats
                  _buildQuickStats(myWorkOrders, myPMTasks),
                  const SizedBox(height: AppTheme.spacingL),

                  // Recent Activity
                  _buildRecentActivity(myWorkOrders, myPMTasks),
                  const SizedBox(height: AppTheme.spacingL),

                  // Status Overview
                  _buildStatusOverview(myWorkOrders),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildMyRequestsTab() => Consumer<UnifiedDataProvider>(
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
            onRefresh: _loadRequestorData,
            child: ListView.builder(
              controller: _requestsScrollController,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: myWorkOrders.length + 1,
              itemBuilder: (context, index) {
                if (index == myWorkOrders.length) {
                  return _buildLoadMoreFooter(unifiedProvider);
                }
                return _buildWorkOrderCard(myWorkOrders[index]);
              },
            ),
          );
        },
      );

  Widget _buildHistoryTab() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final currentUser =
              Provider.of<AuthProvider>(context, listen: false).currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Not logged in'));
          }

          final myWorkOrders = unifiedProvider.workOrders
              .where((wo) => wo.requestorId == currentUser.id)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return RefreshIndicator(
            onRefresh: _loadRequestorData,
            child: ListView.builder(
              controller: _historyScrollController,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: myWorkOrders.length + 1,
              itemBuilder: (context, index) {
                if (index == myWorkOrders.length) {
                  return _buildLoadMoreFooter(unifiedProvider);
                }
                return _buildWorkOrderCard(myWorkOrders[index]);
              },
            ),
          );
        },
      );

  Widget _buildNotificationsTab() => StreamBuilder<List<EnhancedNotification>>(
        stream: _notificationService.notificationStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          final myNotifications = notifications
              .where(
                (n) =>
                    n.userId == null ||
                    n.userId ==
                        Provider.of<AuthProvider>(context, listen: false)
                            .currentUser
                            ?.id,
              )
              .toList();

          if (myNotifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppTheme.lightGrey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.lightGrey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            itemCount: myNotifications.length,
            itemBuilder: (context, index) {
              final notification = myNotifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      );

  Widget _buildQuickStats(List<WorkOrder> workOrders, List<PMTask> pmTasks) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Stats',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Requests',
                      workOrders.length.toString(),
                      Icons.assignment,
                      AppTheme.accentBlue,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Completed',
                      workOrders
                          .where((wo) => wo.status == WorkOrderStatus.completed)
                          .length
                          .toString(),
                      Icons.check_circle,
                      AppTheme.accentGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'In Progress',
                      workOrders
                          .where(
                            (wo) => wo.status == WorkOrderStatus.inProgress,
                          )
                          .length
                          .toString(),
                      Icons.work,
                      AppTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: _buildStatCard(
                      'Pending',
                      workOrders
                          .where((wo) => wo.status == WorkOrderStatus.open)
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

  Widget _buildStatCard(
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

  Widget _buildRecentActivity(
    List<WorkOrder> workOrders,
    List<PMTask> pmTasks,
  ) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Activity',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              if (workOrders.isEmpty)
                const Text(
                  'No recent activity',
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                )
              else
                ...workOrders.take(5).map(_buildActivityItem),
            ],
          ),
        ),
      );

  Widget _buildActivityItem(WorkOrder workOrder) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppTheme.workOrderStatusColor(workOrder.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Text(
                '${workOrder.assetName ?? (workOrder.assetId == null ? 'General Maintenance' : 'Unknown Asset')} - ${_getStatusText(workOrder.status)}',
                style: AppTheme.bodyText,
              ),
            ),
            Text(
              _formatDate(workOrder.updatedAt),
              style: AppTheme.smallText
                  .copyWith(color: AppTheme.secondaryTextColor),
            ),
          ],
        ),
      );

  Widget _buildStatusOverview(List<WorkOrder> workOrders) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status Overview',
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              ...WorkOrderStatus.values.map((status) {
                final count =
                    workOrders.where((wo) => wo.status == status).length;
                if (count == 0) return const SizedBox.shrink();
                return _buildStatusItem(status, count);
              }),
            ],
          ),
        ),
      );

  Widget _buildStatusItem(WorkOrderStatus status, int count) => Padding(
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

  Widget _buildWorkOrderCard(WorkOrder workOrder) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        child: InkWell(
          onTap: () => _viewWorkOrderDetails(workOrder),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        workOrder.assetName ??
                            (workOrder.assetId == null
                                ? 'General Maintenance'
                                : 'Unknown Asset'),
                        style: AppTheme.heading2.copyWith(
                          color: AppTheme.darkTextColor,
                        ),
                      ),
                    ),
                    _buildStatusChip(workOrder.status),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  workOrder.problemDescription,
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: AppTheme.secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Created ${_formatDate(workOrder.createdAt)}',
                      style: AppTheme.smallText.copyWith(
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    const Spacer(),
                    if (workOrder.assignedTechnicianName != null) ...[
                      const Icon(
                        Icons.person,
                        size: 16,
                        color: AppTheme.secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workOrder.assignedTechnicianName!,
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildStatusChip(WorkOrderStatus status) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.workOrderStatusColor(status),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getStatusText(status),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _buildNotificationCard(EnhancedNotification notification) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: notification.isRead
                        ? AppTheme.disabledColor
                        : _getPriorityColor(notification.priority),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: AppTheme.bodyText.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(notification.createdAt),
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _buildLoadMoreFooter(UnifiedDataProvider provider) {
    if (provider.isLoadingMoreWorkOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!provider.hasMoreWorkOrders) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'All requests loaded',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return AppTheme.lightGrey;
      case NotificationPriority.medium:
        return AppTheme.accentBlue;
      case NotificationPriority.high:
        return AppTheme.accentOrange;
      case NotificationPriority.critical:
        return AppTheme.accentRed;
    }
  }

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

  Future<void> _viewWorkOrderDetails(WorkOrder workOrder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkOrderDetailScreen(workOrder: workOrder),
      ),
    );
  }

  Future<void> _handleNotificationTap(EnhancedNotification notification) async {
    if (!mounted) return;
    await _notificationService.markAsRead(notification.id);

    if (notification.relatedId != null && notification.relatedType != null) {
      if (!mounted) return;
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      
      // Navigate to related item
      switch (notification.relatedType) {
        case 'work_order':
          final workOrder = unifiedProvider.workOrders
                  .firstWhere((wo) => wo.id == notification.relatedId);
          if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkOrderDetailScreen(workOrder: workOrder),
            ),
          );
          }
          break;
        case 'pm_task':
          final pmTask = unifiedProvider.pmTasks
                  .firstWhere((pt) => pt.id == notification.relatedId);
          if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PMTaskDetailScreen(pmTask: pmTask),
            ),
          );
          }
          break;
      }
    }
  }

  Future<void> _showNotifications() async {
    // Show notifications dialog or navigate to notifications tab
    _tabController.animateTo(3);
  }

  Future<void> _createNewRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RequestorMainScreen(),
      ),
    );
    // Refresh data after returning
    if (mounted) {
      await _loadRequestorData();
    }
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  }
}
