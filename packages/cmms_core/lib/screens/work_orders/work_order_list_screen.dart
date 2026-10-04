import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/locator.dart';
import '../../models/user.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/supabase_database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/offline_sync_indicators.dart';
import '../../widgets/technician_assignment_dialog.dart';
import 'create_work_request_screen.dart';
import 'work_order_detail_screen.dart';

class WorkOrderListScreen extends StatefulWidget {
  const WorkOrderListScreen({
    super.key,
    this.isTechnicianView = false,
    this.showAppBar = true,
    this.onAppBarContent,
    this.assetId,
    this.initialStatusFilter,
    this.initialPriorityFilter,
    this.startDate,
    this.endDate,
  });
  final bool isTechnicianView;
  /// When false, no AppBar is shown (e.g. when embedded in technician main).
  final bool showAppBar;
  /// When set (e.g. when embedded), the parent can show filter/sort + title in one row. Called with a Row(filters left, title center).
  final void Function(Widget)? onAppBarContent;
  final String? assetId;
  final WorkOrderStatus? initialStatusFilter;
  final WorkOrderPriority? initialPriorityFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends State<WorkOrderListScreen> {
  // Filter state
  WorkOrderStatus? _selectedStatusFilter;
  WorkOrderPriority? _selectedPriorityFilter;
  bool _showOverdueOnly = false;

  // Sort state
  String _sortBy =
      'createdAt'; // 'createdAt', 'priority', 'status', 'assignedTechnician', 'assetId'
  bool _sortAscending = false; // false = newest first, true = oldest first

  // Company name cache
  final Map<String, String> _companyNameCache = {};

  // Infinite scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter;
    _selectedPriorityFilter = widget.initialPriorityFilter;
    debugPrint('📋 Work Order List: Data loaded from unified provider');

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Trigger load when within 300 px of the bottom.
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final provider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      provider.loadMoreWorkOrders();
    }
  }

  @override
  Widget build(BuildContext context) =>
      Consumer2<AuthProvider, UnifiedDataProvider>(
        builder: (context, authProvider, unifiedProvider, child) {
          // Safety check for current user
          if (authProvider.currentUser == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Get work orders based on user role and view mode
          List<WorkOrder> workOrders;

          if (widget.isTechnicianView) {
            // Technician view: show work orders assigned to them OR created by them
            final currentUserId = authProvider.currentUser!.id;
            workOrders = unifiedProvider.workOrders
                .where(
                  (wo) =>
                      wo.hasTechnician(currentUserId),
                )
                .toList();
          } else if (authProvider.currentUser!.role == 'requestor') {
            // Requestor view: show only their own work orders
            workOrders = unifiedProvider.workOrders
                .where((wo) => wo.requestorId == authProvider.currentUser!.id)
                .toList();
          } else if (authProvider.currentUser!.role == 'technician') {
            // Technician's main view: show work orders created by them or assigned to them
            final currentUserId = authProvider.currentUser!.id;
            workOrders = unifiedProvider.workOrders
                .where(
                  (wo) =>
                      wo.hasTechnician(currentUserId),
                )
                .toList();
          } else {
            // Manager/Admin view: show all work orders
            workOrders = unifiedProvider.workOrders;
          }

          // Apply optional deep-link filters
          if (widget.assetId != null) {
            workOrders =
                workOrders.where((w) => w.assetId == widget.assetId).toList();
          }
          if (widget.startDate != null || widget.endDate != null) {
            final start =
                widget.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final end = widget.endDate ?? DateTime.now();
            workOrders = workOrders.where((w) {
              final created = w.createdAt;
              return (created.isAfter(start) ||
                      created.isAtSameMomentAs(start)) &&
                  (created.isBefore(end) || created.isAtSameMomentAs(end));
            }).toList();
          }

          // Apply UI filters - optimized: combine all filters in single where clause
          workOrders = workOrders.where((w) {
            // Status filter
            if (_selectedStatusFilter != null &&
                w.status != _selectedStatusFilter) {
              return false;
            }
            // Priority filter
            if (_selectedPriorityFilter != null &&
                w.priority != _selectedPriorityFilter) {
              return false;
            }
            // Overdue filter
            if (_showOverdueOnly) {
              final now = DateTime.now();
              final overdueThreshold = now.subtract(const Duration(days: 7));
              // Consider work orders overdue if they're open/assigned/inProgress
              // and created more than 7 days ago
              if (w.status == WorkOrderStatus.completed ||
                  w.status == WorkOrderStatus.cancelled ||
                  w.status == WorkOrderStatus.closed ||
                  !w.createdAt.isBefore(overdueThreshold)) {
                return false;
              }
            }
            return true;
          }).toList();

          // Apply sorting
          workOrders = _sortWorkOrders(workOrders);

          return Scaffold(
            appBar: widget.showAppBar
                ? AppBar(
                    title: const Text('Work Orders'),
                    actions: _buildAppBarActions(context),
                  )
                : null,
            body: widget.showAppBar
                ? _buildBody(
                    context,
                    workOrders,
                    authProvider,
                    unifiedProvider,
                  )
                : (widget.onAppBarContent != null
                    ? _NotifyParentAppBar(
                        appBarRow: Row(
                          children: [
                            ..._buildAppBarActions(context),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Work Orders',
                                  style: AppTheme.heading2.copyWith(
                                    color: AppTheme.darkTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        onAppBarContent: widget.onAppBarContent!,
                        child: _buildBody(
                          context,
                          workOrders,
                          authProvider,
                          unifiedProvider,
                        ),
                      )
                    : _buildBody(
                        context,
                        workOrders,
                        authProvider,
                        unifiedProvider,
                      )),
            floatingActionButton: !widget.isTechnicianView &&
                    (authProvider.isManager ||
                        (authProvider.currentUser?.isAdmin ?? false))
                ? FloatingActionButton(
                    heroTag: 'work_order_list_fab',
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateWorkRequestScreen(),
                        ),
                      );
                      if (result == true) {
                        await unifiedProvider.refreshAll();
                      }
                    },
                    backgroundColor: AppTheme.primaryColor,
                    tooltip: 'Create Work Order',
                    child: const Icon(Icons.add, color: Colors.white),
                  )
                : null,
          );
        },
      );

  Widget _buildFilterSortBar(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        color: AppTheme.surfaceColor,
        child: Row(
          children: _buildAppBarActions(context),
        ),
      );

  Widget _buildBody(
    BuildContext context,
    List<WorkOrder> workOrders,
    AuthProvider authProvider,
    UnifiedDataProvider unifiedProvider,
  ) =>
      RefreshIndicator(
        onRefresh: () async {
          await unifiedProvider.refreshAll();
        },
        child: unifiedProvider.isWorkOrdersLoading
            ? const Center(child: CircularProgressIndicator())
            : workOrders.isEmpty
                ? Center(
                    child: Padding(
                      padding:
                          ResponsiveLayout.getResponsivePadding(context),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 64,
                            color: AppTheme.secondaryTextColor,
                          ),
                          const SizedBox(height: AppTheme.spacingM),
                          Text(
                            'No work orders found',
                            style: AppTheme.bodyText.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildWorkOrderList(workOrders, unifiedProvider),
      );

  List<Widget> _buildAppBarActions(BuildContext context) => [
        PopupMenuButton<Object?>(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
          onSelected: (value) {
            setState(() {
              if (value == 'all') {
                _selectedStatusFilter = null;
                _selectedPriorityFilter = null;
                _showOverdueOnly = false;
              } else if (value == 'overdue') {
                _showOverdueOnly = true;
                _selectedStatusFilter = null;
                _selectedPriorityFilter = null;
              } else if (value is WorkOrderStatus) {
                _selectedStatusFilter = value;
                _showOverdueOnly = false;
                _selectedPriorityFilter = null;
              } else if (value is WorkOrderPriority) {
                _selectedPriorityFilter = value;
                _showOverdueOnly = false;
                _selectedStatusFilter = null;
              }
            });
            debugPrint('📋 Work Order List: Filter by $value');
          },
          itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(
                            _selectedStatusFilter == null &&
                                    _selectedPriorityFilter == null &&
                                    !_showOverdueOnly
                                ? Icons.check
                                : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('All'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'overdue',
                      child: Text('Overdue'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: WorkOrderStatus.open,
                      child: Text('Open'),
                    ),
                    const PopupMenuItem(
                      value: WorkOrderStatus.assigned,
                      child: Text('Assigned'),
                    ),
                    const PopupMenuItem(
                      value: WorkOrderStatus.inProgress,
                      child: Text('In Progress'),
                    ),
                    const PopupMenuItem(
                      value: WorkOrderStatus.completed,
                      child: Text('Completed'),
                    ),
                    const PopupMenuItem(
                      value: WorkOrderStatus.cancelled,
                      child: Text('Cancelled'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: WorkOrderPriority.high,
                      child: Text('High Priority'),
                    ),
                    const PopupMenuItem(
                      value: WorkOrderPriority.urgent,
                      child: Text('Urgent'),
                    ),
            const PopupMenuItem(
              value: WorkOrderPriority.critical,
              child: Text('Critical'),
            ),
          ],
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: (value) {
            setState(() {
              if (_sortBy == value) {
                _sortAscending = !_sortAscending;
              } else {
                _sortBy = value;
                _sortAscending = false;
              }
            });
            debugPrint(
                '📋 Work Order List: Sort by $value (${_sortAscending ? "asc" : "desc"})');
          },
          itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'createdAt',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'createdAt' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Date'),
                          if (_sortBy == 'createdAt')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'priority',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'priority' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Priority'),
                          if (_sortBy == 'priority')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'status' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Status'),
                          if (_sortBy == 'status')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'assignedTechnician',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'assignedTechnician'
                                ? Icons.check
                                : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Technician'),
                          if (_sortBy == 'assignedTechnician')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'assetId',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'assetId' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Asset'),
                          if (_sortBy == 'assetId')
                            Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
          ],
        ),
      ];

  Widget _buildWorkOrderCard(
    WorkOrder workOrder,
    BuildContext context,
    UnifiedDataProvider unifiedProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _getPriorityColor(workOrder.priority).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkOrderDetailScreen(workOrder: workOrder),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and ticket number
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPriorityColor(workOrder.priority)
                    .withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: status (left) and ticket number (right, orange fills to edge)
                  Row(
                    children: [
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(workOrder),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(workOrder),
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getStatusText(workOrder),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      WorkOrderPendingSyncBadge(workOrder: workOrder),
                      const SizedBox(width: 8),
                      // Ticket number – orange background extends to right edge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(workOrder.priority),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.confirmation_number,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  workOrder.ticketNumber,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Requestor badge under status (when from requestor)
                  if (_isFromRequestor(workOrder, unifiedProvider)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Requestor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            color: AppTheme.accentBlue.withValues(alpha: 0.1),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                workOrder.asset!.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Info row with technician and date
                  Row(
                    children: [
                      // Technicians (show all assigned)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    (workOrder.assignedTechnicians != null &&
                                            workOrder.assignedTechnicians!
                                                .isNotEmpty)
                                        ? AppTheme.accentGreen
                                        : Colors.grey[400],
                                child: Icon(
                                  (workOrder.assignedTechnicians != null &&
                                          workOrder
                                              .assignedTechnicians!.isNotEmpty)
                                      ? Icons.person
                                      : Icons.person_outline,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatTechniciansList(
                                      workOrder.assignedTechnicians),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: (workOrder.assignedTechnicians !=
                                                null &&
                                            workOrder.assignedTechnicians!
                                                .isNotEmpty)
                                        ? AppTheme.darkTextColor
                                        : Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Priority indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(workOrder.priority)
                              .withValues(alpha: 0.15),
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
                                color: _getPriorityColor(workOrder.priority),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Requestor info (if from requestor)
                  if (_isFromRequestor(workOrder, unifiedProvider)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accentBlue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 14,
                            color: AppTheme.accentBlue,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Requestor: ${_getRequestorName(workOrder, unifiedProvider)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.accentBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Company name (if available)
                  if (workOrder.companyId != null &&
                      workOrder.companyId!.isNotEmpty) ...[
                    FutureBuilder<String?>(
                      future: _getCompanyName(workOrder.companyId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        final companyName = snapshot.data;
                        if (companyName == null || companyName.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.business,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Company: $companyName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Date and category
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
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
                      if (workOrder.category != null) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.category,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              workOrder.categoryDisplayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(WorkOrder workOrder) {
    if (workOrder.isPaused) {
      return AppTheme.workOrderStatusPaused;
    }
    return AppTheme.workOrderStatusColor(workOrder.status);
  }

  String _getStatusText(WorkOrder workOrder) {
    // Check if paused first - paused work orders should show as paused
    if (workOrder.isPaused) {
      return 'Paused';
    }

    switch (workOrder.status) {
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

  bool _isFromRequestor(WorkOrder workOrder, UnifiedDataProvider provider) {
    if (workOrder.requestorId.isEmpty) return false;

    // Check if the requestor user exists and has requestor role
    try {
      final requestor = provider.users.firstWhere(
        (u) => u.id == workOrder.requestorId,
        orElse: () => throw Exception('User not found'),
      );
      return requestor.role == 'requestor';
    } catch (e) {
      // If user not found, check if requestorName exists (indicates it's from a requestor)
      return workOrder.requestorName != null &&
          workOrder.requestorName!.isNotEmpty;
    }
  }

  String _getRequestorName(WorkOrder workOrder, UnifiedDataProvider provider) {
    // First try to get from requestorName field
    if (workOrder.requestorName != null &&
        workOrder.requestorName!.isNotEmpty) {
      return workOrder.requestorName!;
    }

    // Then try to get from requestor object
    if (workOrder.requestor != null) {
      return workOrder.requestor!.name;
    }

    // Finally try to get from users list
    if (workOrder.requestorId.isNotEmpty) {
      try {
        final requestor = provider.users.firstWhere(
          (u) => u.id == workOrder.requestorId,
        );
        return requestor.name;
      } catch (e) {
        return 'Unknown Requestor';
      }
    }

    return 'Unknown Requestor';
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

  String _formatTechniciansList(List<User>? technicians) {
    if (technicians == null || technicians.isEmpty) {
      return 'Unassigned';
    }
    if (technicians.length == 1) {
      return technicians.first.name;
    }
    if (technicians.length == 2) {
      // Show both names for 2 technicians
      return '${technicians[0].name}, ${technicians[1].name}';
    }
    // For 3+ technicians, show first two and count of others
    return '${technicians[0].name}, ${technicians[1].name} +${technicians.length - 2}';
  }

  Future<String?> _getCompanyName(String companyId) async {
    // Check cache first
    if (_companyNameCache.containsKey(companyId)) {
      return _companyNameCache[companyId];
    }

    try {
      final company =
          await sl<SupabaseDatabaseService>().getCompanyById(companyId);
      final companyName = company?.name;

      // Cache the result
      if (companyName != null) {
        _companyNameCache[companyId] = companyName;
      }

      return companyName;
    } catch (e) {
      return null;
    }
  }

  Color _getPriorityColor(WorkOrderPriority priority) {
    switch (priority) {
      case WorkOrderPriority.low:
        return AppTheme.accentGreen;
      case WorkOrderPriority.medium:
        return AppTheme.accentOrange;
      case WorkOrderPriority.high:
        return const Color(0xFFFF6B6B);
      case WorkOrderPriority.urgent:
        return const Color(0xFFFF7043);
      case WorkOrderPriority.critical:
        return AppTheme.accentRed;
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

  IconData _getStatusIcon(WorkOrder workOrder) {
    // Check if paused first - paused work orders should show pause icon
    if (workOrder.isPaused) {
      return Icons.pause_circle;
    }

    switch (workOrder.status) {
      case WorkOrderStatus.open:
        return Icons.inbox;
      case WorkOrderStatus.assigned:
        return Icons.person_add;
      case WorkOrderStatus.inProgress:
        return Icons.build_circle;
      case WorkOrderStatus.completed:
        return Icons.check_circle;
      case WorkOrderStatus.cancelled:
        return Icons.cancel;
      case WorkOrderStatus.closed:
        return Icons.lock;
      case WorkOrderStatus.reopened:
        return Icons.restore; // Icon for reopened status
    }
  }

  Future<void> _showAssignmentDialog(
    WorkOrder workOrder,
    BuildContext context,
    UnifiedDataProvider unifiedProvider,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TechnicianAssignmentDialog(
        workOrderId: workOrder.id,
        currentTechnicianId: workOrder.assignedTechnicianId,
        currentTechnicianIds: workOrder.assignedTechnicianIds,
      ),
    );

    if (result ?? false) {
      // Refresh the work orders list
      await unifiedProvider.refreshAll();
    }
  }

  Future<void> _unassignTechnician(
    WorkOrder workOrder,
    BuildContext context,
    UnifiedDataProvider unifiedProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign Technician'),
        content: Text(
          'Are you sure you want to unassign ${workOrder.assignedTechnician?.name ?? 'the technician'} from this work order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        await unifiedProvider.unassignTechnicianFromWorkOrder(workOrder.id);
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Technician unassigned successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        await unifiedProvider.refreshAll();
        if (!mounted) return;
      } on Exception catch (e) {
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error unassigning technician: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

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
            'All work orders loaded',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildWorkOrderList(
      List<WorkOrder> workOrders, UnifiedDataProvider unifiedProvider) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    const kBottomNavHeight = 56.0;
    final listBottom = padding.bottom + kBottomNavHeight + bottomSafe;

    if (isDesktop || isTablet) {
      // Use CustomScrollView so we can append the footer slivers.
      final columns = isDesktop ? 2 : 1;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  left: padding.left,
                  right: padding.right,
                  top: padding.top,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: padding.horizontal / 2,
                    mainAxisSpacing: padding.vertical / 2,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildWorkOrderCard(
                      workOrders[index],
                      context,
                      unifiedProvider,
                    ),
                    childCount: workOrders.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: listBottom),
                  child: _buildLoadMoreFooter(unifiedProvider),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile: list view with infinite-scroll footer
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: padding.top,
        bottom: listBottom,
      ),
      // +1 for the footer item
      itemCount: workOrders.length + 1,
      itemBuilder: (context, index) {
        if (index == workOrders.length) {
          return _buildLoadMoreFooter(unifiedProvider);
        }
        final workOrder = workOrders[index];
        return _buildWorkOrderCard(
          workOrder,
          context,
          unifiedProvider,
        );
      },
    );
  }

  List<WorkOrder> _sortWorkOrders(List<WorkOrder> workOrders) {
    final sorted = List<WorkOrder>.from(workOrders);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'priority':
          // Priority order: critical > urgent > high > medium > low
          final priorityOrder = {
            WorkOrderPriority.critical: 5,
            WorkOrderPriority.urgent: 4,
            WorkOrderPriority.high: 3,
            WorkOrderPriority.medium: 2,
            WorkOrderPriority.low: 1,
          };
          comparison = (priorityOrder[a.priority] ?? 0)
              .compareTo(priorityOrder[b.priority] ?? 0);
          break;
        case 'status':
          // Status order: open > assigned > inProgress > completed > cancelled > closed
          final statusOrder = {
            WorkOrderStatus.reopened: 1,
            WorkOrderStatus.open: 2,
            WorkOrderStatus.assigned: 3,
            WorkOrderStatus.inProgress: 4,
            WorkOrderStatus.completed: 5,
            WorkOrderStatus.cancelled: 6,
            WorkOrderStatus.closed: 7,
          };
          comparison = (statusOrder[a.status] ?? 0)
              .compareTo(statusOrder[b.status] ?? 0);
          break;
        case 'assignedTechnician':
          final aName = a.assignedTechnician?.name ??
              (a.assignedTechnicians?.isNotEmpty == true
                  ? a.assignedTechnicians!.first.name
                  : 'Unassigned');
          final bName = b.assignedTechnician?.name ??
              (b.assignedTechnicians?.isNotEmpty == true
                  ? b.assignedTechnicians!.first.name
                  : 'Unassigned');
          comparison = aName.compareTo(bName);
          break;
        case 'assetId':
          final aAsset = a.assetName ?? a.asset?.name ?? 'No Asset';
          final bAsset = b.assetName ?? b.asset?.name ?? 'No Asset';
          comparison = aAsset.compareTo(bAsset);
          break;
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }
}

/// Notifies parent of app bar row (filters left + title center) when embedded.
class _NotifyParentAppBar extends StatefulWidget {
  const _NotifyParentAppBar({
    required this.appBarRow,
    required this.onAppBarContent,
    required this.child,
  });
  final Widget appBarRow;
  final void Function(Widget) onAppBarContent;
  final Widget child;

  @override
  State<_NotifyParentAppBar> createState() => _NotifyParentAppBarState();
}

class _NotifyParentAppBarState extends State<_NotifyParentAppBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onAppBarContent(widget.appBarRow);
    });
  }

  @override
  void didUpdateWidget(_NotifyParentAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appBarRow != widget.appBarRow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAppBarContent(widget.appBarRow);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
