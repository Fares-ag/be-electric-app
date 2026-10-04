import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../models/pm_task.dart';
import '../../models/work_order.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../pm_tasks/pm_task_detail_screen.dart';
import '../work_orders/create_work_request_screen.dart';
import '../work_orders/work_order_detail_screen.dart';
import '../../utils/user_facing_errors.dart';

class AssetDetailScreen extends StatefulWidget {
  const AssetDetailScreen({
    required this.asset,
    super.key,
  });
  final Asset asset;

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<WorkOrder> _workOrders = [];
  List<PMTask> _pmTasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAssetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);

      // Load work orders for this asset
      final allWorkOrders = unifiedProvider.workOrders;
      _workOrders =
          allWorkOrders.where((wo) => wo.assetId == widget.asset.id).toList();

      // Load PM tasks for this asset
      final allPMTasks = unifiedProvider.pmTasks;
      _pmTasks =
          allPMTasks.where((task) => task.assetId == widget.asset.id).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e, st) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load asset data. Please try again.',
          stackTrace: st,
          contextLabel: 'AssetDetail: load data',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _createWorkOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateWorkRequestScreen(),
      ),
    );

    if (result == true && mounted) {
      // Refresh the data
      _loadAssetData();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.asset.name),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.info), text: 'Details'),
              Tab(icon: Icon(Icons.work), text: 'Work Orders'),
              Tab(icon: Icon(Icons.schedule), text: 'PM Tasks'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAssetData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailsTab(),
                  _buildWorkOrdersTab(),
                  _buildPMTasksTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createWorkOrder,
          icon: const Icon(Icons.add),
          label: const Text('Create Work Order'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );

  Widget _buildDetailsTab() => SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asset Image and Header Card
            Card(
              elevation: AppTheme.elevationM,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              child: Column(
                children: [
                  // Asset Image
                  if (widget.asset.imageUrl != null &&
                      widget.asset.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusL),
                      ),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: Image.network(
                          widget.asset.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppTheme.radiusL),
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppTheme.radiusL),
                              ),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2,
                                    size: 64,
                                    color: AppTheme.accentBlue,
                                  ),
                                  SizedBox(height: AppTheme.spacingS),
                                  Text(
                                    'Asset Image',
                                    style: TextStyle(
                                      color: AppTheme.accentBlue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Asset Header Info
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.asset.name,
                                    style: AppTheme.heading1.copyWith(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTheme.spacingS,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _getStatusColor(widget.asset.status)
                                              .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
                                      border: Border.all(
                                        color:
                                            _getStatusColor(widget.asset.status)
                                                .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      widget.asset.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(
                                          widget.asset.status,
                                        ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code),
                              onPressed: _showQRCodeDialog,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppTheme.accentBlue.withOpacity(0.1),
                                foregroundColor: AppTheme.accentBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        _buildInfoRow('Asset ID', widget.asset.id),
                        _buildInfoRow('Location', widget.asset.location),
                        if (widget.asset.description != null &&
                            widget.asset.description!.isNotEmpty)
                          _buildInfoRow(
                            'Description',
                            widget.asset.description!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Technical Details Card
            Card(
              elevation: AppTheme.elevationS,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.build, color: AppTheme.accentBlue),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Technical Details',
                          style: AppTheme.heading2.copyWith(
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    if (widget.asset.category != null)
                      _buildInfoRow('Category', widget.asset.category!),
                    if (widget.asset.department != null)
                      _buildInfoRow('Department', widget.asset.department!),
                    if (widget.asset.assignedStaff != null)
                      _buildInfoRow(
                        'Assigned Staff',
                        widget.asset.assignedStaff!,
                      ),
                    if (widget.asset.condition != null)
                      _buildInfoRow('Condition', widget.asset.condition!),
                    if (widget.asset.manufacturer != null)
                      _buildInfoRow('Manufacturer', widget.asset.manufacturer!),
                    if (widget.asset.model != null)
                      _buildInfoRow('Model', widget.asset.model!),
                    if (widget.asset.modelDesc != null)
                      _buildInfoRow(
                        'Model Description',
                        widget.asset.modelDesc!,
                      ),
                    if (widget.asset.serialNumber != null)
                      _buildInfoRow(
                        'Serial Number',
                        widget.asset.serialNumber!,
                      ),
                    if (widget.asset.installationDate != null)
                      _buildInfoRow(
                        'Installation Date',
                        _formatDate(widget.asset.installationDate!),
                      ),
                    if (widget.asset.purchaseDate != null)
                      _buildInfoRow(
                        'Purchase Date',
                        _formatDate(widget.asset.purchaseDate!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Vehicle Information Card (if applicable)
            if (widget.asset.licPlate != null ||
                widget.asset.vehicleIdNo != null ||
                widget.asset.mileage != null)
              Card(
                elevation: AppTheme.elevationS,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            color: AppTheme.accentBlue,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Vehicle Information',
                            style: AppTheme.heading2.copyWith(
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      if (widget.asset.licPlate != null)
                        _buildInfoRow('License Plate', widget.asset.licPlate!),
                      if (widget.asset.vehicleIdNo != null)
                        _buildInfoRow('Vehicle ID', widget.asset.vehicleIdNo!),
                      if (widget.asset.mileage != null)
                        _buildInfoRow('Mileage', '${widget.asset.mileage} km'),
                      if (widget.asset.vehicleModel != null)
                        _buildInfoRow(
                          'Vehicle Model',
                          widget.asset.vehicleModel!,
                        ),
                      if (widget.asset.modelYear != null)
                        _buildInfoRow(
                          'Model Year',
                          widget.asset.modelYear!.toString(),
                        ),
                    ],
                  ),
                ),
              ),
            if (widget.asset.licPlate != null ||
                widget.asset.vehicleIdNo != null ||
                widget.asset.mileage != null)
              const SizedBox(height: AppTheme.spacingM),

            // Maintenance Information Card
            Card(
              elevation: AppTheme.elevationS,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.build_circle,
                          color: AppTheme.accentBlue,
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Maintenance Information',
                          style: AppTheme.heading2.copyWith(
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    if (widget.asset.lastMaintenanceDate != null)
                      _buildInfoRow(
                        'Last Maintenance',
                        _formatDate(widget.asset.lastMaintenanceDate!),
                      ),
                    if (widget.asset.nextMaintenanceDate != null)
                      _buildInfoRow(
                        'Next Maintenance',
                        _formatDate(widget.asset.nextMaintenanceDate!),
                      ),
                    if (widget.asset.maintenanceSchedule != null)
                      _buildInfoRow(
                        'Schedule',
                        widget.asset.maintenanceSchedule!,
                      ),
                    _buildInfoRow('Total Work Orders', '${_workOrders.length}'),
                    _buildInfoRow(
                      'Active PM Tasks',
                      '${_pmTasks.where((task) => task.status == 'pending').length}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Financial Information Card
            if (widget.asset.purchasePrice != null ||
                widget.asset.currentValue != null ||
                widget.asset.vendor != null)
              Card(
                elevation: AppTheme.elevationS,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            color: AppTheme.accentBlue,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Financial Information',
                            style: AppTheme.heading2.copyWith(
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      if (widget.asset.purchasePrice != null)
                        _buildInfoRow(
                          'Purchase Price',
                          'QAR ${widget.asset.purchasePrice!.toStringAsFixed(2)}',
                        ),
                      if (widget.asset.currentValue != null)
                        _buildInfoRow(
                          'Current Value',
                          'QAR ${widget.asset.currentValue!.toStringAsFixed(2)}',
                        ),
                      if (widget.asset.vendor != null)
                        _buildInfoRow('Vendor', widget.asset.vendor!),
                      if (widget.asset.warranty != null)
                        _buildInfoRow(
                          'Warranty',
                          widget.asset.warranty!,
                        ),
                    ],
                  ),
                ),
              ),
            if (widget.asset.purchasePrice != null ||
                widget.asset.currentValue != null ||
                widget.asset.vendor != null)
              const SizedBox(height: AppTheme.spacingM),

            // Quick Actions Card
            Card(
              elevation: AppTheme.elevationS,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on, color: AppTheme.accentBlue),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Quick Actions',
                          style: AppTheme.heading2.copyWith(
                            color: AppTheme.accentBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _createWorkOrder,
                            icon: const Icon(Icons.add),
                            label: const Text('New Work Order'),
                            style: AppTheme.elevatedButtonStyle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _tabController.animateTo(1);
                            },
                            icon: const Icon(Icons.work),
                            label: const Text('View Work Orders'),
                            style: AppTheme.outlinedButtonStyle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _tabController.animateTo(2);
                            },
                            icon: const Icon(Icons.schedule),
                            label: const Text('View PM Tasks'),
                            style: AppTheme.outlinedButtonStyle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showQRCodeDialog,
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Show QR Code'),
                            style: AppTheme.outlinedButtonStyle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildWorkOrdersTab() {
    if (_workOrders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No work orders found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create a work order to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: _workOrders.length,
      itemBuilder: (context, index) {
        final workOrder = _workOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  AppTheme.getPriorityColor(workOrder.priority.name)
                      .withOpacity(0.1),
              child: Icon(
                Icons.work,
                color: AppTheme.getPriorityColor(workOrder.priority.name),
              ),
            ),
            title: Text(
              workOrder.ticketNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workOrder.problemDescription),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: AppTheme.getStatusContainerDecoration(
                        AppTheme.getStatusColor(workOrder.status.name),
                      ),
                      child: Text(
                        workOrder.status.name.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.getStatusColor(workOrder.status.name),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: AppTheme.getStatusContainerDecoration(
                        AppTheme.getPriorityColor(workOrder.priority.name),
                      ),
                      child: Text(
                        workOrder.priority.name.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.getPriorityColor(
                            workOrder.priority.name,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to work order detail screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkOrderDetailScreen(workOrder: workOrder),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPMTasksTab() {
    if (_pmTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No PM tasks found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'PM tasks will appear here when scheduled',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: _pmTasks.length,
      itemBuilder: (context, index) {
        final pmTask = _pmTasks[index];
        final isOverdue = pmTask.nextDue != null &&
            pmTask.nextDue!.isBefore(DateTime.now()) &&
            pmTask.status == 'pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOverdue
                  ? AppTheme.errorColor.withOpacity(0.1)
                  : AppTheme.successColor.withOpacity(0.1),
              child: Icon(
                Icons.schedule,
                color: isOverdue ? AppTheme.errorColor : AppTheme.successColor,
              ),
            ),
            title: Text(
              pmTask.taskName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pmTask.description.isNotEmpty) Text(pmTask.description),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: AppTheme.getStatusContainerDecoration(
                        AppTheme.getStatusColor(pmTask.status.name),
                      ),
                      child: Text(
                        pmTask.status.name.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.getStatusColor(pmTask.status.name),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Due: ${_formatDate(pmTask.nextDue ?? DateTime.now())}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isOverdue ? AppTheme.errorColor : Colors.grey,
                        fontWeight:
                            isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to PM task detail screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PMTaskDetailScreen(pmTask: pmTask),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.successColor;
      case 'inactive':
        return AppTheme.warningColor;
      case 'written_off':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _showQRCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
        ),
        title: const Row(
          children: [
            Icon(Icons.qr_code, color: AppTheme.accentBlue),
            SizedBox(width: AppTheme.spacingS),
            Text('Asset QR Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.05),
                border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code,
                    size: 80,
                    color: AppTheme.accentBlue,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                        color: AppTheme.accentBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      widget.asset.qrCode ?? widget.asset.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'QR Code: ${widget.asset.qrCode ?? widget.asset.id}',
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.outlinedButtonStyle,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
