// Requestor Status Screen - Track maintenance request status and history

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/requestor_home_navigation.dart';
import '../../utils/requestor_status_loading.dart';
import '../../utils/work_order_cancellation_notes.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/reopen_work_order_dialog.dart';
import '../../widgets/requestor_more_menu.dart';
import '../work_orders/work_order_detail_screen.dart';
import 'edit_request_screen.dart';
import '../../utils/user_facing_errors.dart';

class RequestorStatusScreen extends StatefulWidget {
  const RequestorStatusScreen({super.key});

  @override
  State<RequestorStatusScreen> createState() => _RequestorStatusScreenState();
}

class _RequestorStatusScreenState extends State<RequestorStatusScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  WorkOrderStatus? _statusFilter;
  WorkOrderPriority? _priorityFilter;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequestorWorkOrders();
    });
  }

  Future<void> _loadRequestorWorkOrders() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || !mounted) return;

    try {
      await Provider.of<UnifiedDataProvider>(context, listen: false)
          .loadRequestorWorkOrders(user.id);
    } catch (e, st) {
      if (!mounted) return;
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not load your requests. Pull down to retry.',
        stackTrace: st,
        contextLabel: 'RequestorStatus: load',
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await _loadRequestorWorkOrders();
  }

  Widget _buildRefreshableBody({required Widget child}) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF002911),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    return Selector<
        UnifiedDataProvider,
        ({List<WorkOrder> workOrders, bool isWorkOrdersLoading})>(
      selector: (_, provider) => (
        workOrders: provider.workOrders,
        isWorkOrdersLoading: provider.isWorkOrdersLoading,
      ),
      builder: (context, data, child) {
        final allWorkOrders = data.workOrders;
        final showInitialLoading = shouldShowRequestorStatusInitialLoading(
          isWorkOrdersLoading: data.isWorkOrdersLoading,
          requestCount: allWorkOrders.length,
        );

        // Get user's work orders in real-time!
        final myRequests = user != null
            ? (allWorkOrders.where((wo) => wo.requestorId == user.id).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            : <WorkOrder>[];

        return Scaffold(
          backgroundColor: const Color(0xFFE5E7EB),
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(128),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomAppBar(
                  usePageTitle: true,
                  title: 'My Requests (${myRequests.length})',
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
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _showFilterDialog,
                      tooltip: 'Filter & search',
                    ),
                  ],
                ),
                Material(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF002911),
                    unselectedLabelColor: AppTheme.secondaryTextColor,
                    indicatorColor: const Color(0xFF002911),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: const [
                      Tab(
                        child: _TabIconLabel(
                          icon: Icons.pending_actions,
                          text: 'Active',
                        ),
                      ),
                      Tab(
                        child: _TabIconLabel(
                          icon: Icons.history,
                          text: 'History',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Search bar
              if (_searchQuery.isNotEmpty ||
                  _statusFilter != null ||
                  _priorityFilter != null)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveLayout.getResponsivePadding(
                      context,
                    ).left,
                    vertical: AppTheme.spacingS,
                  ),
                  color: AppTheme.accentBlue.withValues(alpha: 0.1),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        Chip(
                          label: Text(
                            'Search: $_searchQuery',
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                      if (_statusFilter != null)
                        Chip(
                          label: Text('Status: ${_statusFilter!.name}'),
                          onDeleted: () {
                            setState(() {
                              _statusFilter = null;
                            });
                          },
                        ),
                      if (_priorityFilter != null)
                        Chip(
                          label: Text('Priority: ${_priorityFilter!.name}'),
                          onDeleted: () {
                            setState(() {
                              _priorityFilter = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveRequestsTab(
                      myRequests,
                      showInitialLoading: showInitialLoading,
                    ),
                    _buildHistoryTab(
                      myRequests,
                      showInitialLoading: showInitialLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(
              bottom: 4 + MediaQuery.viewPaddingOf(context).bottom * 0.5,
            ),
            child: FloatingActionButton.extended(
              onPressed: () => navigateToRequestorMain(context),
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
              backgroundColor: const Color(0xFF002911),
              foregroundColor: Colors.white,
            ),
          ),
        );
      },
    );
  }

  List<WorkOrder> _filterRequests(List<WorkOrder> requests) {
    // Optimized: combine all filters in single where clause
    final query = _searchQuery.toLowerCase();
    final hasSearchQuery = _searchQuery.isNotEmpty;

    return requests.where((r) {
      // Status filter
      if (_statusFilter != null && r.status != _statusFilter) {
        return false;
      }
      // Priority filter
      if (_priorityFilter != null && r.priority != _priorityFilter) {
        return false;
      }
      // Search query
      if (hasSearchQuery) {
        final matchesSearch = r.ticketNumber.toLowerCase().contains(query) ||
            r.problemDescription.toLowerCase().contains(query) ||
            (r.assetId?.toLowerCase().contains(query) ?? false) ||
            (r.assetName?.toLowerCase().contains(query) ?? false);
        if (!matchesSearch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildActiveRequestsTab(
    List<WorkOrder> myRequests, {
    required bool showInitialLoading,
  }) {
    if (showInitialLoading) {
      return _buildRefreshableBody(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    var activeRequests = myRequests
        .where(
          (request) =>
              request.status ==
                  WorkOrderStatus
                      .reopened || // Reopened should appear in Active tab
              (request.status != WorkOrderStatus.completed &&
                  request.status != WorkOrderStatus.closed &&
                  request.status != WorkOrderStatus.cancelled),
        )
        .toList();

    activeRequests = _filterRequests(activeRequests);

    if (activeRequests.isEmpty) {
      return _buildRefreshableBody(
        child: _buildEmptyState(
          icon: Icons.check_circle_outline,
          title: 'No Active Requests',
          message: 'You have no pending maintenance requests.',
          actionText: 'Create New Request',
          onAction: () => navigateToRequestorMain(context),
          includeScrollView: false,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF002911),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listOuterPadding(context),
        itemCount: activeRequests.length,
        itemBuilder: (context, index) {
          final request = activeRequests[index];
          return _buildRequestCard(context, request);
        },
      ),
    );
  }

  Widget _buildHistoryTab(
    List<WorkOrder> myRequests, {
    required bool showInitialLoading,
  }) {
    if (showInitialLoading) {
      return _buildRefreshableBody(
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show all past requests: completed, closed, and cancelled (but not reopened - those go to Active)
    var pastRequests = myRequests
        .where(
          (request) =>
              (request.status == WorkOrderStatus.completed ||
                  request.status == WorkOrderStatus.closed ||
                  request.status == WorkOrderStatus.cancelled) &&
              request.status !=
                  WorkOrderStatus
                      .reopened, // Reopened should not appear in History
        )
        .toList();

    pastRequests = _filterRequests(pastRequests);

    if (pastRequests.isEmpty) {
      return _buildRefreshableBody(
        child: _buildEmptyState(
          icon: Icons.history,
          title: 'No Request History',
          message: 'You have no past maintenance requests.',
          actionText: 'Create New Request',
          onAction: () => navigateToRequestorMain(context),
          includeScrollView: false,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF002911),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listOuterPadding(context),
        itemCount: pastRequests.length,
        itemBuilder: (context, index) {
          final request = pastRequests[index];
          return _buildRequestCard(context, request);
        },
      ),
    );
  }

  EdgeInsets _listOuterPadding(BuildContext context) {
    final p = ResponsiveLayout.getResponsivePadding(context);
    final bottom = 88 + MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(p.left, p.top, p.right, bottom);
  }

  /// Edit / Cancel: full-width stacked on narrow cards or small screens; [Wrap] on wider to avoid overflow.
  Widget _buildRequestorEditCancelBar(BuildContext context, WorkOrder request) {
    final screenW = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenW;
        final useStack = screenW < 420 || available < 400;

        void onEdit() => _editRequest(request);
        void onCancel() => _cancelRequest(request);

        if (useStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentBlue,
                  minimumSize: const Size(double.infinity, 44),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentRed,
                  minimumSize: const Size(double.infinity, 44),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ],
          );
        }

        return Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentBlue,
                  minimumSize: const Size(0, 44),
                ),
              ),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentRed,
                  minimumSize: const Size(0, 44),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, WorkOrder request) {
    final pad = MediaQuery.sizeOf(context).width < 360
        ? 10.0
        : AppTheme.spacingM;

    return Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        elevation: 2,
        child: InkWell(
          onTap: () => _viewFullWorkOrder(request),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        request.ticketNumber,
                        style: AppTheme.heading2.copyWith(
                          color: AppTheme.darkTextColor,
                          fontSize: MediaQuery.sizeOf(context).width < 360
                              ? 16
                              : 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingS,
                              vertical: AppTheme.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.workOrderStatusColor(request.status)
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusS),
                              border: Border.all(
                                color: AppTheme.workOrderStatusColor(request.status)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              _getStatusText(request.status),
                              style: AppTheme.smallText.copyWith(
                                color: AppTheme.workOrderStatusColor(request.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingS),

                // Problem description
                Text(
                  request.problemDescription,
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Show additional notes/details if available
                if (request.notes != null && request.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    request.notes!,
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Show customer contact info if available
                if (request.customerName != null ||
                    request.customerPhone != null ||
                    request.customerEmail != null) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Wrap(
                    spacing: AppTheme.spacingS,
                    children: [
                      if (request.customerName != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person,
                              size: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              request.customerName!,
                              style: AppTheme.smallText.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      if (request.customerPhone != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone,
                              size: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              request.customerPhone!,
                              style: AppTheme.smallText.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: AppTheme.spacingS),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.build,
                          size: 16,
                          color: AppTheme.secondaryTextColor,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Expanded(
                          child: Text(
                            'Asset: ${request.assetName ?? request.assetId ?? 'N/A'}',
                            style: AppTheme.smallText.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _getPriorityIcon(request.priority),
                          size: 16,
                          color: _getPriorityColor(request.priority),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getPriorityText(request.priority),
                          style: AppTheme.smallText.copyWith(
                            color: _getPriorityColor(request.priority),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingS),

                // Dates and assigned technician
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: AppTheme.secondaryTextColor,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Flexible(
                      child: Text(
                        'Created: ${_formatDate(request.createdAt)}',
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                if (request.assignedTechnicianIds.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 16,
                        color: AppTheme.secondaryTextColor,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Flexible(
                        child: Text(
                          'Assigned to: ${request.assignedTechnicians?.map((t) => t.name).join(', ') ?? request.assignedTechnicianIds.join(', ')}',
                          style: AppTheme.smallText.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                if (request.status == WorkOrderStatus.open ||
                    request.status == WorkOrderStatus.assigned) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  _buildRequestorEditCancelBar(context, request),
                ],

                if (request.completedAt != null) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppTheme.accentGreen,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        'Completed: ${_formatDate(request.completedAt!)}',
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],

                // Reopen button for completed/closed requests
                // Note: If the work order was already reopened (status = open),
                // it won't appear in this filtered list anyway, so this button is safe to show
                if ((request.status == WorkOrderStatus.completed ||
                    request.status == WorkOrderStatus.closed)) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _reopenRequest(request),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Reopen Work Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],

                // Requestors do not see total / labor / parts / actual costs (operational & financials).
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionText,
    required VoidCallback onAction,
    bool includeScrollView = true,
  }) {
    final hPad = ResponsiveLayout.getResponsivePadding(context).left;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 64,
          color: AppTheme.secondaryTextColor,
        ),
        const SizedBox(height: AppTheme.spacingL),
        Text(
          title,
          style: AppTheme.heading2.copyWith(
            color: AppTheme.secondaryTextColor,
            fontSize: 20,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingM),
        Text(
          message,
          style: AppTheme.bodyText.copyWith(
            color: AppTheme.secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacingL),
        ElevatedButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add),
          label: Text(actionText),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );

    if (!includeScrollView) {
      return Center(child: content);
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          hPad,
          AppTheme.spacingL,
          hPad,
          AppTheme.spacingXL,
        ),
        child: content,
      ),
    );
  }

  void _viewFullWorkOrder(WorkOrder request) {
    // Navigate to full work order detail screen so requestors can see
    // all completion details including photos, corrective actions, etc.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkOrderDetailScreen(workOrder: request),
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
        return Colors.green;
      case WorkOrderPriority.medium:
        return Colors.orange;
      case WorkOrderPriority.high:
        return Colors.red;
      case WorkOrderPriority.urgent:
        return Colors.deepOrange;
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

  String _getPriorityText(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low:
        return 'Low';
      case WorkOrderPriority.medium:
        return 'Medium';
      case WorkOrderPriority.high:
        return 'High';
      case WorkOrderPriority.urgent:
        return 'Urgent';
      case WorkOrderPriority.critical:
        return 'Critical';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Requests'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search field
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search',
                    hintText: 'Search by ticket, description, or asset...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _searchDebounceTimer?.cancel();
                    _searchDebounceTimer =
                        Timer(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        _searchQuery = value;
                        setDialogState(() {});
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Status filter
                DropdownButtonFormField<WorkOrderStatus?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<WorkOrderStatus?>(
                      value: null,
                      child: Text('All Statuses'),
                    ),
                    ...WorkOrderStatus.values.map(
                      (status) => DropdownMenuItem<WorkOrderStatus?>(
                        value: status,
                        child: Text(status.name.toUpperCase()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _statusFilter = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Priority filter
                DropdownButtonFormField<WorkOrderPriority?>(
                  initialValue: _priorityFilter,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<WorkOrderPriority?>(
                      value: null,
                      child: Text('All Priorities'),
                    ),
                    ...WorkOrderPriority.values.map(
                      (priority) => DropdownMenuItem<WorkOrderPriority?>(
                        value: priority,
                        child: Text(priority.name.toUpperCase()),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      _priorityFilter = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _searchQuery = '';
                  _statusFilter = null;
                  _priorityFilter = null;
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                _searchDebounceTimer?.cancel();
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    setState(() {}); // Refresh the UI after dialog closes
  }

  Future<void> _editRequest(WorkOrder request) async {
    if (!mounted) return;
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRequestScreen(workOrder: request),
      ),
    );

    if (result == true && mounted) {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        await unifiedProvider.loadRequestorWorkOrders(userId);
      }
    }
  }

  Future<void> _cancelRequest(WorkOrder request) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this request? This action cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'Please provide a reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    try {
      if (confirmed == true && reasonController.text.trim().isNotEmpty) {
        if (!mounted) return;
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);

        try {
          final updatedWorkOrder = request.copyWith(
            status: WorkOrderStatus.cancelled,
            notes: appendWorkOrderCancellationNote(
              existingNotes: request.notes,
              cancellationReason: reasonController.text,
            ),
            updatedAt: DateTime.now(),
          );

          await unifiedProvider.updateWorkOrder(updatedWorkOrder);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Request cancelled successfully'),
                backgroundColor: AppTheme.accentGreen,
              ),
            );
          }
        } catch (e, st) {
          if (mounted) {
            showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not cancel request. Please try again.',
          stackTrace: st,
          contextLabel: 'RequestorStatus: cancel',
          backgroundColor: AppTheme.accentRed,
        );
          }
        }
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _reopenRequest(WorkOrder request) async {
    // Show confirmation dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReopenWorkOrderDialog(
        workOrder: request,
      ),
    );

    if (result == null || result['reopen'] != true || !mounted) {
      return;
    }

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final reason = result['reason'] as String;
      final editedDescription = result['editedDescription'] as String?;

      // Call reopen method - this will update the work order status to "open"
      final reopenedWorkOrder = await unifiedProvider.reopenWorkOrder(
        workOrderId: request.id,
        currentUserId: authProvider.currentUser!.id,
        reason: reason,
        editedDescription: editedDescription,
      );

      if (!mounted) return;

      // Wait a moment for the UI to update via Selector
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Work order ${reopenedWorkOrder.ticketNumber} reopened successfully. It will now appear in the Active tab.'),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      // The Selector should automatically update the UI since we called notifyListeners()
      // The reopened work order (status = open) will automatically disappear from History tab
      // and appear in Active tab due to the filtering logic
    } on Exception catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reopening work order: ${e.toString()}'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

}

/// Compact tab label for narrow phones (avoids TabBar overflow).
class _TabIconLabel extends StatelessWidget {
  const _TabIconLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }
}
