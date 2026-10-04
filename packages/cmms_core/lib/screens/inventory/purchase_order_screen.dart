import 'package:flutter/material.dart';
import 'package:cmms_core/models/parts_request.dart';
import 'package:cmms_core/models/purchase_order.dart';
import 'package:cmms_core/services/parts_request_service.dart';
import 'package:cmms_core/services/purchase_order_service.dart';
import 'package:cmms_core/utils/app_theme.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  final PurchaseOrderService _purchaseOrderService = sl<PurchaseOrderService>();
  final PartsRequestService _partsRequestService = sl<PartsRequestService>();

  List<PurchaseOrder> _purchaseOrders = [];
  List<PartsRequest> _pendingPartsRequests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final orders = await _purchaseOrderService.getAllPurchaseOrders();
      final requests = await _partsRequestService.getPendingPartsRequests();

      setState(() {
        _purchaseOrders = orders;
        _pendingPartsRequests = requests;
      });
    } catch (e, st) {
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not load data. Please try again.',
        stackTrace: st,
        contextLabel: 'PurchaseOrderScreen: load data',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPurchaseOrderFromPartsRequests() async {
    if (_pendingPartsRequests.isEmpty) {
      _showErrorSnackBar('No pending parts requests available');
      return;
    }

    final selectedRequests = await _showPartsRequestSelectionDialog();
    if (selectedRequests.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _purchaseOrderService.createPurchaseOrderFromPartsRequests(
        partsRequestIds: selectedRequests.map((r) => r.id).toList(),
        createdBy: 'current_user_id', // TODO: Get from auth provider
      );

      await _loadData();
      _showSuccessSnackBar('Purchase order created successfully');
    } catch (e, st) {
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not create purchase order. Please try again.',
        stackTrace: st,
        contextLabel: 'PurchaseOrderScreen: create order',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<PartsRequest>> _showPartsRequestSelectionDialog() async =>
      await showDialog<List<PartsRequest>>(
        context: context,
        builder: (context) => PartsRequestSelectionDialog(
          partsRequests: _pendingPartsRequests,
        ),
      ) ??
      [];

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Purchase Orders'),
          backgroundColor: AppTheme.primaryWhite,
          foregroundColor: AppTheme.primaryBlack,
          elevation: AppTheme.elevationS,
          actions: [
            if (_pendingPartsRequests.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _createPurchaseOrderFromPartsRequests,
                tooltip: 'Create from Parts Requests',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: AppTheme.spacingXL),
                    _buildPurchaseOrdersList(),
                  ],
                ),
              ),
      );

  Widget _buildStatsCards() {
    final stats = _calculateStats();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Orders',
            '${stats['totalOrders']}',
            Icons.receipt,
            AppTheme.accentBlue,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: _buildStatCard(
            'Pending Requests',
            '${_pendingPartsRequests.length}',
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: _buildStatCard(
            'Total Value',
            'QAR ${stats['totalValue'].toStringAsFixed(0)}',
            Icons.attach_money,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) =>
      Card(
        elevation: AppTheme.elevationS,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                value,
                style: AppTheme.heading2.copyWith(color: color),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                title,
                style: AppTheme.smallText,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildPurchaseOrdersList() {
    if (_purchaseOrders.isEmpty) {
      return Card(
        elevation: AppTheme.elevationS,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: AppTheme.secondaryTextGrey,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'No purchase orders found',
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.secondaryTextGrey,
                  ),
                ),
                if (_pendingPartsRequests.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  ElevatedButton(
                    onPressed: _createPurchaseOrderFromPartsRequests,
                    child: const Text('Create from Parts Requests'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: AppTheme.elevationS,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Purchase Orders (${_purchaseOrders.length})',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ..._purchaseOrders.map(_buildPurchaseOrderCard),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderCard(PurchaseOrder order) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.poNumber,
                    style: AppTheme.bodyText.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      _getStatusText(order.status),
                      style: AppTheme.smallText.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                order.title,
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Items: ${order.items.length}',
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Total: QAR ${order.totalAmount.toStringAsFixed(2)}',
                style: AppTheme.bodyText.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentBlue,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Created: ${_formatDateTime(order.createdAt)}',
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextGrey,
                ),
              ),
              if (order.vendor != null) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Vendor: ${order.vendor}',
                  style: AppTheme.smallText.copyWith(
                    color: AppTheme.secondaryTextGrey,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Map<String, dynamic> _calculateStats() {
    final totalOrders = _purchaseOrders.length;
    final totalValue = _purchaseOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );

    return {
      'totalOrders': totalOrders,
      'totalValue': totalValue,
    };
  }

  String _getStatusText(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return 'Draft';
      case PurchaseOrderStatus.pending:
        return 'Pending';
      case PurchaseOrderStatus.approved:
        return 'Approved';
      case PurchaseOrderStatus.ordered:
        return 'Ordered';
      case PurchaseOrderStatus.received:
        return 'Received';
      case PurchaseOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Colors.grey;
      case PurchaseOrderStatus.pending:
        return Colors.orange;
      case PurchaseOrderStatus.approved:
        return Colors.blue;
      case PurchaseOrderStatus.ordered:
        return Colors.purple;
      case PurchaseOrderStatus.received:
        return Colors.green;
      case PurchaseOrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}

class PartsRequestSelectionDialog extends StatefulWidget {
  const PartsRequestSelectionDialog({
    required this.partsRequests,
    super.key,
  });
  final List<PartsRequest> partsRequests;

  @override
  State<PartsRequestSelectionDialog> createState() =>
      _PartsRequestSelectionDialogState();
}

class _PartsRequestSelectionDialogState
    extends State<PartsRequestSelectionDialog> {
  final Set<String> _selectedRequestIds = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Select Parts Requests'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: widget.partsRequests.length,
            itemBuilder: (context, index) {
              final request = widget.partsRequests[index];
              final isSelected = _selectedRequestIds.contains(request.id);

              return CheckboxListTile(
                title: Text(request.inventoryItem?.name ?? 'Unknown Item'),
                subtitle: Text('Qty: ${request.quantity} - ${request.reason}'),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      _selectedRequestIds.add(request.id);
                    } else {
                      _selectedRequestIds.remove(request.id);
                    }
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop([]),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _selectedRequestIds.isEmpty
                ? null
                : () {
                    final selectedRequests = widget.partsRequests
                        .where((r) => _selectedRequestIds.contains(r.id))
                        .toList();
                    Navigator.of(context).pop(selectedRequests);
                  },
            child: const Text('Create Purchase Order'),
          ),
        ],
      );
}
