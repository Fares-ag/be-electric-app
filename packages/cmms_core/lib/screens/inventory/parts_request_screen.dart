import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cmms_core/models/inventory_item.dart';
import 'package:cmms_core/models/parts_request.dart';
import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/providers/unified_data_provider.dart';
import 'package:cmms_core/services/parts_request_service.dart';
import 'package:cmms_core/utils/app_theme.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';
import '../../widgets/offline_sync_banner.dart';

class PartsRequestScreen extends StatefulWidget {
  const PartsRequestScreen({
    required this.workOrder,
    super.key,
  });
  final WorkOrder workOrder;

  @override
  State<PartsRequestScreen> createState() => _PartsRequestScreenState();
}

class _PartsRequestScreenState extends State<PartsRequestScreen> {
  final PartsRequestService _partsRequestService = sl<PartsRequestService>();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<InventoryItem> _inventoryItems = [];
  List<PartsRequest> _partsRequests = [];
  InventoryItem? _selectedItem;
  PartsRequestPriority _selectedPriority = PartsRequestPriority.medium;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get inventory from UnifiedDataProvider (real-time!)
      final items = Provider.of<UnifiedDataProvider>(context, listen: false)
          .inventoryItems;

      final requests = await _partsRequestService
          .getPartsRequestsByWorkOrder(widget.workOrder.id);

      setState(() {
        _inventoryItems = items;
        _partsRequests = requests;
      });

      if (_partsRequestService.lastListFromCache && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _partsRequestService.lastListError ??
                  'Showing cached parts requests. Cloud refresh failed.',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not load data. Please try again.',
        stackTrace: st,
        contextLabel: 'PartsRequestScreen: load data',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPartsRequest() async {
    if (_selectedItem == null) {
      _showErrorSnackBar('Please select an inventory item');
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showErrorSnackBar('Please enter a valid quantity');
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter a reason for the request');
      return;
    }

    final currentUserId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    if (currentUserId.isEmpty) {
      _showErrorSnackBar('Please sign in again to create a parts request');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _partsRequestService.createPartsRequest(
        workOrderId: widget.workOrder.id,
        technicianId: currentUserId,
        inventoryItemId: _selectedItem!.id,
        quantity: quantity,
        reason: _reasonController.text.trim(),
        priority: _selectedPriority,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        inventoryItem: _selectedItem,
      );

      _clearForm();
      await _loadData();
      _showSuccessSnackBar('Parts request created successfully');
    } catch (e, st) {
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not create parts request. Please try again.',
        stackTrace: st,
        contextLabel: 'PartsRequestScreen: create request',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _selectedItem = null;
    _quantityController.clear();
    _reasonController.clear();
    _notesController.clear();
    _selectedPriority = PartsRequestPriority.medium;
  }

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
          title: const Text('Parts Request'),
          backgroundColor: AppTheme.primaryWhite,
          foregroundColor: AppTheme.primaryBlack,
          elevation: AppTheme.elevationS,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWorkOrderInfo(),
                    const SizedBox(height: AppTheme.spacingXL),
                    _buildPartsRequestForm(),
                    const SizedBox(height: AppTheme.spacingXL),
                    _buildPartsRequestsList(),
                  ],
                ),
              ),
      );

  Widget _buildWorkOrderInfo() => Card(
        elevation: AppTheme.elevationS,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Work Order: ${widget.workOrder.ticketNumber}',
                style: AppTheme.heading2,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Asset: ${widget.workOrder.asset?.name ?? 'Unknown'}',
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Problem: ${widget.workOrder.problemDescription}',
                style: AppTheme.bodyText,
              ),
            ],
          ),
        ),
      );

  Widget _buildPartsRequestForm() => Card(
        elevation: AppTheme.elevationS,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request Parts',
                style: AppTheme.heading2,
              ),
              const SizedBox(height: AppTheme.spacingM),

              // Inventory Item Selection
              DropdownButtonFormField<InventoryItem>(
                initialValue: _selectedItem,
                decoration: const InputDecoration(
                  labelText: 'Select Inventory Item',
                  border: OutlineInputBorder(),
                ),
                items: _inventoryItems
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text('${item.name} (Stock: ${item.quantity})'),
                      ),
                    )
                    .toList(),
                onChanged: (item) {
                  setState(() => _selectedItem = item);
                },
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Priority
              DropdownButtonFormField<PartsRequestPriority>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: PartsRequestPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(_getPriorityText(priority)),
                      ),
                    )
                    .toList(),
                onChanged: (priority) {
                  setState(() => _selectedPriority = priority!);
                },
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Request',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: AppTheme.spacingM),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createPartsRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Parts Request'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildPartsRequestsList() {
    if (_partsRequests.isEmpty) {
      return Card(
        elevation: AppTheme.elevationS,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Center(
            child: Text(
              'No parts requests for this work order',
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.secondaryTextGrey,
              ),
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
              'Parts Requests (${_partsRequests.length})',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ..._partsRequests.map(_buildPartsRequestCard),
          ],
        ),
      ),
    );
  }

  Widget _buildPartsRequestCard(PartsRequest request) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      request.inventoryItem?.name ?? 'Unknown Item',
                      style: AppTheme.bodyText.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (request.isOffline) ...[
                    const PendingSyncChip(),
                    const SizedBox(width: AppTheme.spacingS),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      _getStatusText(request.status),
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
                'Quantity: ${request.quantity}',
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Priority: ${_getPriorityText(request.priority)}',
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Reason: ${request.reason}',
                style: AppTheme.bodyText,
              ),
              if (request.notes != null) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Notes: ${request.notes}',
                  style: AppTheme.bodyText,
                ),
              ],
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Requested: ${_formatDateTime(request.requestedAt)}',
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextGrey,
                ),
              ),
            ],
          ),
        ),
      );

  String _getPriorityText(PartsRequestPriority priority) {
    switch (priority) {
      case PartsRequestPriority.low:
        return 'Low';
      case PartsRequestPriority.medium:
        return 'Medium';
      case PartsRequestPriority.high:
        return 'High';
      case PartsRequestPriority.urgent:
        return 'Urgent';
    }
  }

  String _getStatusText(PartsRequestStatus status) {
    switch (status) {
      case PartsRequestStatus.pending:
        return 'Pending';
      case PartsRequestStatus.approved:
        return 'Approved';
      case PartsRequestStatus.rejected:
        return 'Rejected';
      case PartsRequestStatus.fulfilled:
        return 'Fulfilled';
      case PartsRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(PartsRequestStatus status) {
    switch (status) {
      case PartsRequestStatus.pending:
        return Colors.orange;
      case PartsRequestStatus.approved:
        return Colors.blue;
      case PartsRequestStatus.rejected:
        return Colors.red;
      case PartsRequestStatus.fulfilled:
        return Colors.green;
      case PartsRequestStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}
