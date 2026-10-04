import 'dart:convert';

import 'package:cmms_core/models/purchase_order.dart';
import 'package:cmms_core/services/supabase_database_service.dart';
import 'package:cmms_core/services/parts_request_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/locator.dart';

class PurchaseOrderService {

  late SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Create a new purchase order
  Future<PurchaseOrder> createPurchaseOrder({
    required String title,
    required String description,
    required List<PurchaseOrderItem> items,
    required String createdBy,
    PurchaseOrderPriority priority = PurchaseOrderPriority.medium,
    String? vendor,
    String? vendorContact,
    String? vendorEmail,
    String? vendorPhone,
    String? notes,
  }) async {
    final now = DateTime.now();
    final poNumber = 'PO-${now.millisecondsSinceEpoch}';
    final totalAmount =
        items.fold<double>(0, (sum, item) => sum + item.totalPrice);

    final purchaseOrder = PurchaseOrder(
      id: now.millisecondsSinceEpoch.toString(),
      poNumber: poNumber,
      title: title,
      description: description,
      items: items,
      totalAmount: totalAmount,
      status: PurchaseOrderStatus.draft,
      priority: priority,
      vendor: vendor,
      vendorContact: vendorContact,
      vendorEmail: vendorEmail,
      vendorPhone: vendorPhone,
      createdAt: now,
      createdBy: createdBy,
      notes: notes,
      isOffline: true,
      updatedAt: now,
    );

    await _savePurchaseOrder(purchaseOrder);
    return purchaseOrder;
  }

  // Create purchase order from parts requests
  Future<PurchaseOrder> createPurchaseOrderFromPartsRequests({
    required List<String> partsRequestIds,
    required String createdBy,
    String? vendor,
    String? vendorContact,
    String? vendorEmail,
    String? vendorPhone,
    String? notes,
  }) async {
    final partsRequestService = sl<PartsRequestService>();
    final items = <PurchaseOrderItem>[];

    for (final requestId in partsRequestIds) {
      final request = await partsRequestService.getPartsRequestById(requestId);
      if (request != null && request.inventoryItem != null) {
        final inventoryItem = request.inventoryItem!;
        final item = PurchaseOrderItem(
          inventoryItemId: inventoryItem.id,
          quantity: request.quantity,
          unitPrice: inventoryItem.cost ?? 0.0,
          totalPrice: (inventoryItem.cost ?? 0.0) * request.quantity,
          notes: request.reason,
        );
        items.add(item);
      }
    }

    if (items.isEmpty) {
      throw Exception('No valid parts requests found');
    }

    return createPurchaseOrder(
      title: 'Purchase Order from Parts Requests',
      description: 'Generated from ${partsRequestIds.length} parts requests',
      items: items,
      createdBy: createdBy,
      vendor: vendor,
      vendorContact: vendorContact,
      vendorEmail: vendorEmail,
      vendorPhone: vendorPhone,
      notes: notes,
    );
  }

  // Get all purchase orders
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    final ordersJson = _prefs.getStringList('purchase_orders') ?? [];
    final orders = ordersJson
        .map((json) => PurchaseOrder.fromMap(jsonDecode(json)))
        .toList();

    // Load related objects
    final enrichedOrders = <PurchaseOrder>[];
    for (final order in orders) {
      final enrichedOrder = await _enrichPurchaseOrder(order);
      enrichedOrders.add(enrichedOrder);
    }

    return enrichedOrders;
  }

  // Get purchase orders by status
  Future<List<PurchaseOrder>> getPurchaseOrdersByStatus(
    PurchaseOrderStatus status,
  ) async {
    final allOrders = await getAllPurchaseOrders();
    return allOrders.where((order) => order.status == status).toList();
  }

  // Get purchase orders by creator
  Future<List<PurchaseOrder>> getPurchaseOrdersByCreator(
    String createdBy,
  ) async {
    final allOrders = await getAllPurchaseOrders();
    return allOrders.where((order) => order.createdBy == createdBy).toList();
  }

  // Get purchase order by ID
  Future<PurchaseOrder?> getPurchaseOrderById(String id) async {
    final allOrders = await getAllPurchaseOrders();
    try {
      return allOrders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }

  // Submit purchase order for approval
  Future<PurchaseOrder> submitPurchaseOrder(String id) async {
    final order = await getPurchaseOrderById(id);
    if (order == null) {
      throw Exception('Purchase order not found');
    }

    final updatedOrder = order.copyWith(
      status: PurchaseOrderStatus.pending,
      updatedAt: DateTime.now(),
    );

    await _savePurchaseOrder(updatedOrder);
    return updatedOrder;
  }

  // Approve purchase order
  Future<PurchaseOrder> approvePurchaseOrder({
    required String id,
    required String approvedBy,
    String? notes,
  }) async {
    final order = await getPurchaseOrderById(id);
    if (order == null) {
      throw Exception('Purchase order not found');
    }

    final updatedOrder = order.copyWith(
      status: PurchaseOrderStatus.approved,
      approvedAt: DateTime.now(),
      approvedBy: approvedBy,
      notes: notes,
      updatedAt: DateTime.now(),
    );

    await _savePurchaseOrder(updatedOrder);
    return updatedOrder;
  }

  // Reject purchase order
  Future<PurchaseOrder> rejectPurchaseOrder({
    required String id,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    final order = await getPurchaseOrderById(id);
    if (order == null) {
      throw Exception('Purchase order not found');
    }

    final updatedOrder = order.copyWith(
      status: PurchaseOrderStatus.cancelled,
      approvedBy: rejectedBy,
      rejectionReason: rejectionReason,
      updatedAt: DateTime.now(),
    );

    await _savePurchaseOrder(updatedOrder);
    return updatedOrder;
  }

  // Mark purchase order as ordered
  Future<PurchaseOrder> markAsOrdered(String id) async {
    final order = await getPurchaseOrderById(id);
    if (order == null) {
      throw Exception('Purchase order not found');
    }

    final updatedOrder = order.copyWith(
      status: PurchaseOrderStatus.ordered,
      orderedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _savePurchaseOrder(updatedOrder);
    return updatedOrder;
  }

  // Mark purchase order as received
  Future<PurchaseOrder> markAsReceived(String id) async {
    final order = await getPurchaseOrderById(id);
    if (order == null) {
      throw Exception('Purchase order not found');
    }

    final updatedOrder = order.copyWith(
      status: PurchaseOrderStatus.received,
      receivedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _savePurchaseOrder(updatedOrder);
    return updatedOrder;
  }

  // Update purchase order
  Future<PurchaseOrder> updatePurchaseOrder(PurchaseOrder order) async {
    final updatedOrder = order.copyWith(updatedAt: DateTime.now());
    await _savePurchaseOrder(updatedOrder);
    return updatedOrder;
  }

  // Delete purchase order
  Future<void> deletePurchaseOrder(String id) async {
    final allOrders = await getAllPurchaseOrders();
    final filteredOrders = allOrders.where((order) => order.id != id).toList();
    await _savePurchaseOrders(filteredOrders);
  }

  // Get purchase order statistics
  Future<Map<String, dynamic>> getPurchaseOrderStats() async {
    final allOrders = await getAllPurchaseOrders();

    final totalOrders = allOrders.length;
    final totalValue =
        allOrders.fold<double>(0, (sum, order) => sum + order.totalAmount);

    final ordersByStatus = <PurchaseOrderStatus, int>{};
    for (final status in PurchaseOrderStatus.values) {
      ordersByStatus[status] =
          allOrders.where((o) => o.status == status).length;
    }

    final ordersByPriority = <PurchaseOrderPriority, int>{};
    for (final priority in PurchaseOrderPriority.values) {
      ordersByPriority[priority] =
          allOrders.where((o) => o.priority == priority).length;
    }

    final averageOrderValue = totalOrders > 0 ? totalValue / totalOrders : 0.0;

    return {
      'totalOrders': totalOrders,
      'totalValue': totalValue,
      'averageOrderValue': averageOrderValue,
      'ordersByStatus': ordersByStatus,
      'ordersByPriority': ordersByPriority,
    };
  }

  // Private methods
  Future<void> _savePurchaseOrder(PurchaseOrder order) async {
    final allOrders = await getAllPurchaseOrders();
    final index = allOrders.indexWhere((o) => o.id == order.id);

    if (index != -1) {
      allOrders[index] = order;
    } else {
      allOrders.add(order);
    }

    await _savePurchaseOrders(allOrders);
  }

  Future<void> _savePurchaseOrders(List<PurchaseOrder> orders) async {
    final ordersJson = orders.map((o) => jsonEncode(o.toMap())).toList();
    await _prefs.setStringList('purchase_orders', ordersJson);
  }

  Future<PurchaseOrder> _enrichPurchaseOrder(PurchaseOrder order) async {
    // Use Firestore to fetch related objects
    final creator = order.createdBy != null
        ? await sl<SupabaseDatabaseService>().getUserById(order.createdBy!)
        : null;
    final approver = order.approvedBy != null
        ? await sl<SupabaseDatabaseService>().getUserById(order.approvedBy!)
        : null;

    // Enrich items with inventory item details
    final enrichedItems = <PurchaseOrderItem>[];
    for (final item in order.items) {
      final inventoryItem = await sl<SupabaseDatabaseService>()
          .getInventoryItem(item.inventoryItemId);
      enrichedItems.add(
        PurchaseOrderItem(
          inventoryItemId: item.inventoryItemId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          notes: item.notes,
          inventoryItem: inventoryItem,
        ),
      );
    }

    return order.copyWith(
      creator: creator,
      approver: approver,
      items: enrichedItems,
    );
  }
}
