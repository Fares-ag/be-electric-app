// Enhanced Inventory Service - Advanced inventory operations

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/inventory_item.dart';
import '../models/user_role.dart';
import 'enhanced_notification_service.dart';
import 'supabase_database_service.dart';
import 'unified_data_service.dart';
import '../config/locator.dart';

enum InventoryRequestStatus {
  pending,
  approved,
  rejected,
  ordered,
  received,
  cancelled,
}

enum InventoryRequestPriority {
  low,
  medium,
  high,
  critical,
}

class InventoryRequest {
  InventoryRequest({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.requestedBy,
    required this.createdAt,
    this.status = InventoryRequestStatus.pending,
    this.priority = InventoryRequestPriority.medium,
    this.justification,
    this.approvedBy,
    this.approvedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.orderedAt,
    this.receivedAt,
    this.workOrderId,
    this.pmTaskId,
    this.notes,
    this.unitCost,
    this.totalCost,
    this.vendor,
    this.purchaseOrderNumber,
  });

  final String id;
  final String itemId;
  final int quantity;
  final String requestedBy;
  final DateTime createdAt;
  final InventoryRequestStatus status;
  final InventoryRequestPriority priority;
  final String? justification;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? orderedAt;
  final DateTime? receivedAt;
  final String? workOrderId;
  final String? pmTaskId;
  final String? notes;
  final double? unitCost;
  final double? totalCost;
  final String? vendor;
  final String? purchaseOrderNumber;
}

class Vendor {
  Vendor({
    required this.id,
    required this.name,
    required this.contactEmail,
    required this.contactPhone,
    this.address,
    this.website,
    this.rating,
    this.isActive = true,
    this.notes,
  });

  final String id;
  final String name;
  final String contactEmail;
  final String contactPhone;
  final String? address;
  final String? website;
  final double? rating;
  final bool isActive;
  final String? notes;
}

class EnhancedInventoryService {

  UnifiedDataService get _dataService => sl<UnifiedDataService>();
  final EnhancedNotificationService _notificationService =
      sl<EnhancedNotificationService>();
  final SupabaseDatabaseService _firestoreService =
      sl<SupabaseDatabaseService>();

  final List<InventoryRequest> _requests = [];
  final List<Vendor> _vendors = [];
  final List<Map<String, dynamic>> _transactions = [];

  List<InventoryRequest> get requests => List.unmodifiable(_requests);
  List<Vendor> get vendors => List.unmodifiable(_vendors);
  List<Map<String, dynamic>> get transactions =>
      List.unmodifiable(_transactions);

  /// Initialize inventory service
  Future<void> initialize() async {
    await _loadInventoryData();
    _startLowStockMonitoring();
    debugPrint('EnhancedInventoryService: Initialized');
  }

  /// Load inventory data
  Future<void> _loadInventoryData() async {
    try {
      // Try Supabase first, fallback to default vendors
      try {
        final firestoreVendors = await _firestoreService.getVendors();
        _vendors.clear();
        _vendors.addAll(firestoreVendors);
        print(
          'EnhancedInventoryService: Loaded ${_vendors.length} vendors from Supabase',
        );
      } catch (e, st) {
        print(
          'EnhancedInventoryService: Supabase unavailable, loading default vendors: $e',
        );
        await _loadDefaultVendors();
      }
    } catch (e, st) {
      debugPrint(
        'EnhancedInventoryService: Error loading inventory data: $e',
      );
      await _loadDefaultVendors();
    }
  }

  /// Load default vendors
  Future<void> _loadDefaultVendors() async {
    _vendors.addAll([
      Vendor(
        id: 'vendor_001',
        name: 'Industrial Supply Co.',
        contactEmail: 'orders@industrialsupply.com',
        contactPhone: '+1-555-0123',
        address: '123 Industrial Blvd, Manufacturing City, MC 12345',
        website: 'https://industrialsupply.com',
        rating: 4.5,
      ),
      Vendor(
        id: 'vendor_002',
        name: 'Maintenance Parts Direct',
        contactEmail: 'sales@maintenanceparts.com',
        contactPhone: '+1-555-0456',
        address: '456 Parts Avenue, Supply Town, ST 67890',
        website: 'https://maintenanceparts.com',
        rating: 4.2,
      ),
      Vendor(
        id: 'vendor_003',
        name: 'Equipment Solutions Ltd',
        contactEmail: 'info@equipmentsolutions.com',
        contactPhone: '+1-555-0789',
        address: '789 Equipment Street, Solutions City, SC 13579',
        website: 'https://equipmentsolutions.com',
        rating: 4.8,
      ),
    ]);
  }

  /// Start low stock monitoring
  void _startLowStockMonitoring() {
    Timer.periodic(const Duration(hours: 1), (timer) {
      _checkLowStockItems();
    });
  }

  /// Check for low stock items
  Future<void> _checkLowStockItems() async {
    final inventoryItems = _dataService.inventoryItems;
    final managers = _dataService.users
        .where((u) => u.role == UserRole.manager || u.role == UserRole.admin)
        .toList();

    for (final item in inventoryItems) {
      if (item.quantity <= 10) {
        // Low stock threshold
        for (final manager in managers) {
          await _notificationService.notifyLowStock(
            itemId: item.id,
            itemName: item.name,
            currentStock: item.quantity.toInt(),
            minStock: 10,
            managerId: manager.id,
          );
        }
      }
    }
  }

  /// Create inventory request
  Future<String> createInventoryRequest({
    required String itemId,
    required int quantity,
    required String requestedBy,
    InventoryRequestPriority priority = InventoryRequestPriority.medium,
    String? justification,
    String? workOrderId,
    String? pmTaskId,
    String? notes,
  }) async {
    final request = InventoryRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      itemId: itemId,
      quantity: quantity,
      requestedBy: requestedBy,
      createdAt: DateTime.now(),
      priority: priority,
      justification: justification,
      workOrderId: workOrderId,
      pmTaskId: pmTaskId,
      notes: notes,
    );

    _requests.add(request);
    await _notifyManagers(request);

    debugPrint(
      'EnhancedInventoryService: Created inventory request for ${request.quantity} units of item $itemId',
    );
    return request.id;
  }

  /// Notify managers of new request
  Future<void> _notifyManagers(InventoryRequest request) async {
    final managers = _dataService.users
        .where((u) => u.role == UserRole.manager || u.role == UserRole.admin)
        .toList();
    final item =
        _dataService.inventoryItems.firstWhere((i) => i.id == request.itemId);

    for (final manager in managers) {
      await _notificationService.createNotification(
        title: 'New Inventory Request',
        message:
            'Request for ${request.quantity} units of ${item.name} (Priority: ${request.priority.name})',
        type: NotificationType.inventoryRequest,
        priority: request.priority == InventoryRequestPriority.critical
            ? NotificationPriority.critical
            : NotificationPriority.high,
        userId: manager.id,
        relatedId: request.id,
        relatedType: 'inventory_request',
        data: {
          'itemName': item.name,
          'quantity': request.quantity,
          'priority': request.priority.name,
          'requestedBy': request.requestedBy,
        },
      );
    }
  }

  /// Approve inventory request
  Future<void> approveRequest(
    String requestId,
    String approvedBy, {
    String? notes,
  }) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = InventoryRequest(
        id: _requests[index].id,
        itemId: _requests[index].itemId,
        quantity: _requests[index].quantity,
        requestedBy: _requests[index].requestedBy,
        createdAt: _requests[index].createdAt,
        status: InventoryRequestStatus.approved,
        priority: _requests[index].priority,
        justification: _requests[index].justification,
        approvedBy: approvedBy,
        approvedAt: DateTime.now(),
        rejectedBy: _requests[index].rejectedBy,
        rejectedAt: _requests[index].rejectedAt,
        rejectionReason: _requests[index].rejectionReason,
        orderedAt: _requests[index].orderedAt,
        receivedAt: _requests[index].receivedAt,
        workOrderId: _requests[index].workOrderId,
        pmTaskId: _requests[index].pmTaskId,
        notes: notes ?? _requests[index].notes,
        unitCost: _requests[index].unitCost,
        totalCost: _requests[index].totalCost,
        vendor: _requests[index].vendor,
        purchaseOrderNumber: _requests[index].purchaseOrderNumber,
      );

      await _notifyRequestor(requestId, 'approved');
      debugPrint('EnhancedInventoryService: Approved request $requestId');
    }
  }

  /// Reject inventory request
  Future<void> rejectRequest(
    String requestId,
    String rejectedBy,
    String reason,
  ) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = InventoryRequest(
        id: _requests[index].id,
        itemId: _requests[index].itemId,
        quantity: _requests[index].quantity,
        requestedBy: _requests[index].requestedBy,
        createdAt: _requests[index].createdAt,
        status: InventoryRequestStatus.rejected,
        priority: _requests[index].priority,
        justification: _requests[index].justification,
        approvedBy: _requests[index].approvedBy,
        approvedAt: _requests[index].approvedAt,
        rejectedBy: rejectedBy,
        rejectedAt: DateTime.now(),
        rejectionReason: reason,
        orderedAt: _requests[index].orderedAt,
        receivedAt: _requests[index].receivedAt,
        workOrderId: _requests[index].workOrderId,
        pmTaskId: _requests[index].pmTaskId,
        notes: _requests[index].notes,
        unitCost: _requests[index].unitCost,
        totalCost: _requests[index].totalCost,
        vendor: _requests[index].vendor,
        purchaseOrderNumber: _requests[index].purchaseOrderNumber,
      );

      await _notifyRequestor(requestId, 'rejected', reason: reason);
      debugPrint('EnhancedInventoryService: Rejected request $requestId');
    }
  }

  /// Mark request as ordered
  Future<void> markAsOrdered(
    String requestId,
    String vendor,
    String purchaseOrderNumber,
    double unitCost,
  ) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      final totalCost = _requests[index].quantity * unitCost;

      _requests[index] = InventoryRequest(
        id: _requests[index].id,
        itemId: _requests[index].itemId,
        quantity: _requests[index].quantity,
        requestedBy: _requests[index].requestedBy,
        createdAt: _requests[index].createdAt,
        status: InventoryRequestStatus.ordered,
        priority: _requests[index].priority,
        justification: _requests[index].justification,
        approvedBy: _requests[index].approvedBy,
        approvedAt: _requests[index].approvedAt,
        rejectedBy: _requests[index].rejectedBy,
        rejectedAt: _requests[index].rejectedAt,
        rejectionReason: _requests[index].rejectionReason,
        orderedAt: DateTime.now(),
        receivedAt: _requests[index].receivedAt,
        workOrderId: _requests[index].workOrderId,
        pmTaskId: _requests[index].pmTaskId,
        notes: _requests[index].notes,
        unitCost: unitCost,
        totalCost: totalCost,
        vendor: vendor,
        purchaseOrderNumber: purchaseOrderNumber,
      );

      await _notifyRequestor(requestId, 'ordered');
      debugPrint(
        'EnhancedInventoryService: Marked request $requestId as ordered',
      );
    }
  }

  /// Mark request as received
  Future<void> markAsReceived(String requestId) async {
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _requests[index] = InventoryRequest(
        id: _requests[index].id,
        itemId: _requests[index].itemId,
        quantity: _requests[index].quantity,
        requestedBy: _requests[index].requestedBy,
        createdAt: _requests[index].createdAt,
        status: InventoryRequestStatus.received,
        priority: _requests[index].priority,
        justification: _requests[index].justification,
        approvedBy: _requests[index].approvedBy,
        approvedAt: _requests[index].approvedAt,
        rejectedBy: _requests[index].rejectedBy,
        rejectedAt: _requests[index].rejectedAt,
        rejectionReason: _requests[index].rejectionReason,
        orderedAt: _requests[index].orderedAt,
        receivedAt: DateTime.now(),
        workOrderId: _requests[index].workOrderId,
        pmTaskId: _requests[index].pmTaskId,
        notes: _requests[index].notes,
        unitCost: _requests[index].unitCost,
        totalCost: _requests[index].totalCost,
        vendor: _requests[index].vendor,
        purchaseOrderNumber: _requests[index].purchaseOrderNumber,
      );

      // Update inventory
      await _updateInventoryStock(_requests[index]);
      await _notifyRequestor(requestId, 'received');
      debugPrint(
        'EnhancedInventoryService: Marked request $requestId as received',
      );
    }
  }

  /// Update inventory stock
  Future<void> _updateInventoryStock(InventoryRequest request) async {
    final itemIndex =
        _dataService.inventoryItems.indexWhere((i) => i.id == request.itemId);
    if (itemIndex != -1) {
      final currentItem = _dataService.inventoryItems[itemIndex];
      // Prepare updated item (kept for future updateInventoryItem integration)
      final updatedItem = InventoryItem(
        id: currentItem.id,
        name: currentItem.name,
        category: currentItem.category,
        quantity: currentItem.quantity + request.quantity,
        unit: currentItem.unit,
        createdAt: currentItem.createdAt,
        updatedAt: DateTime.now(),
        description: currentItem.description,
        supplier: currentItem.supplier,
        location: currentItem.location,
      );

      // Update in data service (would need to implement updateInventoryItem method)
      // await _dataService.updateInventoryItem(updatedItem);
      debugPrint(
          'EnhancedInventoryService: Updated inventory item prepared: ${updatedItem.id}',);

      // Record transaction
      _transactions.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'stock_in',
        'itemId': request.itemId,
        'quantity': request.quantity,
        'unitCost': request.unitCost,
        'totalCost': request.totalCost,
        'vendor': request.vendor,
        'purchaseOrderNumber': request.purchaseOrderNumber,
        'timestamp': DateTime.now().toIso8601String(),
        'requestId': request.id,
      });
    }
  }

  /// Notify requestor of status change
  Future<void> _notifyRequestor(
    String requestId,
    String status, {
    String? reason,
  }) async {
    final request = _requests.firstWhere((r) => r.id == requestId);
    final item =
        _dataService.inventoryItems.firstWhere((i) => i.id == request.itemId);

    String message;
    switch (status) {
      case 'approved':
        message =
            'Your request for ${request.quantity} units of ${item.name} has been approved';
        break;
      case 'rejected':
        message =
            'Your request for ${request.quantity} units of ${item.name} has been rejected: $reason';
        break;
      case 'ordered':
        message =
            'Your request for ${request.quantity} units of ${item.name} has been ordered';
        break;
      case 'received':
        message =
            'Your request for ${request.quantity} units of ${item.name} has been received';
        break;
      default:
        message = 'Your inventory request status has been updated';
    }

    await _notificationService.createNotification(
      title: 'Inventory Request Update',
      message: message,
      type: NotificationType.inventoryRequest,
      userId: request.requestedBy,
      relatedId: requestId,
      relatedType: 'inventory_request',
      data: {
        'itemName': item.name,
        'quantity': request.quantity,
        'status': status,
        'reason': reason,
      },
    );
  }

  /// Get requests by status
  List<InventoryRequest> getRequestsByStatus(InventoryRequestStatus status) =>
      _requests.where((r) => r.status == status).toList();

  /// Get requests by user
  List<InventoryRequest> getRequestsByUser(String userId) =>
      _requests.where((r) => r.requestedBy == userId).toList();

  /// Get requests by work order
  List<InventoryRequest> getRequestsByWorkOrder(String workOrderId) =>
      _requests.where((r) => r.workOrderId == workOrderId).toList();

  /// Get requests by PM task
  List<InventoryRequest> getRequestsByPMTask(String pmTaskId) =>
      _requests.where((r) => r.pmTaskId == pmTaskId).toList();

  /// Get inventory statistics
  Map<String, dynamic> getInventoryStats() {
    final totalItems = _dataService.inventoryItems.length;
    final lowStockItems =
        _dataService.inventoryItems.where((item) => item.quantity <= 10).length;
    final outOfStockItems =
        _dataService.inventoryItems.where((item) => item.quantity == 0).length;
    final totalValue = _dataService.inventoryItems
        .fold<double>(0, (sum, item) => sum + item.quantity);

    final pendingRequests = _requests
        .where((r) => r.status == InventoryRequestStatus.pending)
        .length;
    final approvedRequests = _requests
        .where((r) => r.status == InventoryRequestStatus.approved)
        .length;
    final orderedRequests = _requests
        .where((r) => r.status == InventoryRequestStatus.ordered)
        .length;

    return {
      'totalItems': totalItems,
      'lowStockItems': lowStockItems,
      'outOfStockItems': outOfStockItems,
      'totalValue': totalValue,
      'pendingRequests': pendingRequests,
      'approvedRequests': approvedRequests,
      'orderedRequests': orderedRequests,
      'totalRequests': _requests.length,
    };
  }

  /// Get vendor by ID
  Vendor? getVendorById(String vendorId) {
    try {
      return _vendors.firstWhere((v) => v.id == vendorId);
    } catch (e, st) {
      return null;
    }
  }

  /// Add vendor
  Future<void> addVendor(Vendor vendor) async {
    _vendors.add(vendor);

    // Save to Supabase
    try {
      await _firestoreService.saveVendor(vendor);
      debugPrint('EnhancedInventoryService: Vendor saved to Supabase');
    } catch (e, st) {
      debugPrint(
        'EnhancedInventoryService: Failed to save vendor to Supabase: $e',
      );
    }

    debugPrint('EnhancedInventoryService: Added vendor ${vendor.name}');
  }

  /// Update vendor
  Future<void> updateVendor(Vendor vendor) async {
    final index = _vendors.indexWhere((v) => v.id == vendor.id);
    if (index != -1) {
      _vendors[index] = vendor;

      // Save to Supabase
      try {
        await _firestoreService.saveVendor(vendor);
        debugPrint('EnhancedInventoryService: Vendor updated in Supabase');
      } catch (e, st) {
        debugPrint(
          'EnhancedInventoryService: Failed to update vendor in Supabase: $e',
        );
      }

      debugPrint('EnhancedInventoryService: Updated vendor ${vendor.name}');
    }
  }

  /// Get transaction history
  List<Map<String, dynamic>> getTransactionHistory({
    String? itemId,
    int? limit,
  }) {
    var transactions = _transactions;

    if (itemId != null) {
      transactions = transactions.where((t) => t['itemId'] == itemId).toList();
    }

    transactions.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    if (limit != null) {
      transactions = transactions.take(limit).toList();
    }

    return transactions;
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
