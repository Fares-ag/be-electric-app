import 'dart:async';
import 'dart:convert';

import 'package:cmms_core/models/inventory_item.dart';
import 'package:cmms_core/models/parts_request.dart';
import 'package:cmms_core/services/realtime_supabase_service.dart';
import 'package:cmms_core/services/supabase_database_service.dart';
import 'package:cmms_core/services/enhanced_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/locator.dart';
import '../utils/offline_service_access.dart';
import '../utils/parts_list_fetch.dart';

class PartsRequestService {
  /// Public constructor for GetIt (`PartsRequestService.new`).
  PartsRequestService();

  late SharedPreferences _prefs;
  bool _realtimeListening = false;
  final StreamController<List<PartsRequest>> _requestsController =
      StreamController<List<PartsRequest>>.broadcast();

  /// Set when [getAllPartsRequests] served SharedPreferences after a cloud error.
  String? _lastListError;
  bool _lastListFromCache = false;

  /// Last cloud error message when the list was served from cache (null if fresh).
  String? get lastListError => _lastListError;

  /// True when the last [getAllPartsRequests] used prefs fallback.
  bool get lastListFromCache => _lastListFromCache;

  /// Emits whenever the parts-request cache is refreshed from realtime/API.
  Stream<List<PartsRequest>> get requestsChanged => _requestsController.stream;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Live INSERT/UPDATE on parts_requests (RLS scopes visible rows).
  void startRealtimeListener() {
    if (_realtimeListening) return;
    _realtimeListening = true;
    sl<RealtimeSupabaseService>().listenToPartsRequestChanges(
      onChanged: () {
        unawaited(_refreshFromRealtime());
      },
    );
  }

  void stopRealtimeListener() {
    if (!_realtimeListening) return;
    sl<RealtimeSupabaseService>().stopListeningToPartsRequestChanges();
    _realtimeListening = false;
  }

  Future<void> _refreshFromRealtime() async {
    try {
      final requests = await getAllPartsRequests();
      if (!_requestsController.isClosed) {
        _requestsController.add(requests);
      }
    } catch (e) {
      debugPrint('PartsRequestService: realtime refresh failed: $e');
    }
  }

  // Create a new parts request (online Supabase, or durable offline queue).
  Future<PartsRequest> createPartsRequest({
    required String workOrderId,
    required String technicianId,
    required String inventoryItemId,
    required int quantity,
    required String reason,
    PartsRequestPriority priority = PartsRequestPriority.medium,
    String? notes,
    InventoryItem? inventoryItem,
  }) async {
    final now = DateTime.now();
    final request = PartsRequest(
      id: now.millisecondsSinceEpoch.toString(),
      workOrderId: workOrderId,
      technicianId: technicianId,
      inventoryItemId: inventoryItemId,
      quantity: quantity,
      reason: reason,
      priority: priority,
      status: PartsRequestStatus.pending,
      requestedAt: now,
      notes: notes,
      isOffline: true,
      updatedAt: now,
      inventoryItem: inventoryItem,
    );

    Future<PartsRequest> queueOffline() async {
      await _savePartsRequest(request);
      await resolveSyncQueueService().enqueuePartsRequestCreate(
        request,
        requestedBy: technicianId,
      );
      debugPrint(
        'PartsRequestService: queued offline create ${request.id}',
      );
      return request;
    }

    if (!AppConfig.isOfflineModeEnabled) {
      final id =
          await sl<SupabaseDatabaseService>().createPartsRequest(request);
      final cloudRequest = request.copyWith(id: id, isOffline: false);
      await _savePartsRequest(cloudRequest);
      await _notifyManagersOfNewRequest(cloudRequest);
      return cloudRequest;
    }

    if (shouldEnqueueOfflineMutation(
      offlineModeEnabled: true,
      isOnline: resolveConnectivityService().isOnline,
    )) {
      return queueOffline();
    }

    try {
      final id =
          await sl<SupabaseDatabaseService>().createPartsRequest(request);
      final cloudRequest = request.copyWith(id: id, isOffline: false);
      await _savePartsRequest(cloudRequest);
      await _notifyManagersOfNewRequest(cloudRequest);
      return cloudRequest;
    } catch (e) {
      if (shouldEnqueueOfflineMutation(
        offlineModeEnabled: true,
        isOnline: true,
        caughtError: e,
      )) {
        return queueOffline();
      }
      rethrow;
    }
  }

  // Get all parts requests
  Future<List<PartsRequest>> getAllPartsRequests() async {
    List<PartsRequest> requests;
    try {
      requests = await sl<SupabaseDatabaseService>().getAllPartsRequests();
      final requestsJson = requests.map((r) => jsonEncode(r.toMap())).toList();
      await _prefs.setStringList('parts_requests', requestsJson);
      _lastListError = null;
      _lastListFromCache = false;
    } catch (e) {
      final requestsJson = _prefs.getStringList('parts_requests') ?? [];
      final fallback = resolvePartsListFallback(
        error: e,
        prefsJson: requestsJson,
      );
      _lastListError = fallback.errorMessage;
      _lastListFromCache = fallback.fromCache;
      requests = fallback.requests;
      debugPrint(
        'PartsRequestService: cloud list failed; serving cache '
        '(${requests.length} rows): $e',
      );
    }

    final enrichedRequests = <PartsRequest>[];
    for (final request in requests) {
      final enrichedRequest = await _enrichPartsRequest(request);
      enrichedRequests.add(enrichedRequest);
    }

    return enrichedRequests;
  }

  // Get parts requests by work order
  Future<List<PartsRequest>> getPartsRequestsByWorkOrder(
    String workOrderId,
  ) async {
    final allRequests = await getAllPartsRequests();
    return allRequests
        .where((request) => request.workOrderId == workOrderId)
        .toList();
  }

  // Get parts requests by technician
  Future<List<PartsRequest>> getPartsRequestsByTechnician(
    String technicianId,
  ) async {
    final allRequests = await getAllPartsRequests();
    return allRequests
        .where((request) => request.technicianId == technicianId)
        .toList();
  }

  // Get pending parts requests
  Future<List<PartsRequest>> getPendingPartsRequests() async {
    final allRequests = await getAllPartsRequests();
    return allRequests
        .where((request) => request.status == PartsRequestStatus.pending)
        .toList();
  }

  // Approve a parts request (cloud UPDATE must succeed; stock decrements on fulfill).
  Future<PartsRequest> approvePartsRequest({
    required String requestId,
    required String approvedBy,
    String? notes,
  }) async {
    if (approvedBy.trim().isEmpty || approvedBy == 'manager') {
      throw Exception('Authenticated approver id is required');
    }
    final request = await getPartsRequestById(requestId);
    if (request == null) {
      throw Exception('Parts request not found');
    }

    final isAvailable = await checkPartsAvailability(
      request.inventoryItemId,
      request.quantity,
    );
    if (!isAvailable) {
      throw Exception('Insufficient stock for the requested item');
    }

    final updatedRequest = request.copyWith(
      status: PartsRequestStatus.approved,
      approvedAt: DateTime.now(),
      approvedBy: approvedBy,
      notes: notes,
      updatedAt: DateTime.now(),
    );

    await sl<SupabaseDatabaseService>()
        .updatePartsRequest(updatedRequest.id, updatedRequest);

    await _savePartsRequest(updatedRequest);
    await _notifyRequester(
      userId: request.technicianId,
      title: 'Parts Request Approved',
      message:
          'Your parts request for item ${request.inventoryItemId} (qty ${request.quantity}) has been approved.',
      priority: NotificationPriority.high,
      workOrderId: request.workOrderId,
      inventoryItemId: request.inventoryItemId,
      quantity: request.quantity,
      status: 'approved',
    );
    return updatedRequest;
  }

  // Reject a parts request
  Future<PartsRequest> rejectPartsRequest({
    required String requestId,
    required String rejectedBy,
    required String rejectionReason,
  }) async {
    if (rejectedBy.trim().isEmpty || rejectedBy == 'manager') {
      throw Exception('Authenticated rejector id is required');
    }
    final request = await getPartsRequestById(requestId);
    if (request == null) {
      throw Exception('Parts request not found');
    }

    final updatedRequest = request.copyWith(
      status: PartsRequestStatus.rejected,
      approvedBy: rejectedBy,
      rejectionReason: rejectionReason,
      updatedAt: DateTime.now(),
    );

    await sl<SupabaseDatabaseService>()
        .updatePartsRequest(updatedRequest.id, updatedRequest);

    await _savePartsRequest(updatedRequest);
    await _notifyRequester(
      userId: request.technicianId,
      title: 'Parts Request Rejected',
      message:
          'Your parts request for item ${request.inventoryItemId} was rejected.',
      priority: NotificationPriority.medium,
      workOrderId: request.workOrderId,
      inventoryItemId: request.inventoryItemId,
      quantity: request.quantity,
      status: 'rejected',
    );
    return updatedRequest;
  }

  // Fulfill a parts request — sole path that decrements inventory.
  Future<PartsRequest> fulfillPartsRequest({
    required String requestId,
    required String fulfilledBy,
  }) async {
    if (fulfilledBy.trim().isEmpty || fulfilledBy == 'manager') {
      throw Exception('Authenticated fulfiller id is required');
    }
    final request = await getPartsRequestById(requestId);
    if (request == null) {
      throw Exception('Parts request not found');
    }
    if (request.status == PartsRequestStatus.fulfilled) {
      return request;
    }

    final updatedRequest = request.copyWith(
      status: PartsRequestStatus.fulfilled,
      fulfilledAt: DateTime.now(),
      approvedBy: fulfilledBy,
      updatedAt: DateTime.now(),
    );

    await sl<SupabaseDatabaseService>()
        .updatePartsRequest(updatedRequest.id, updatedRequest);

    await _decrementInventoryQuantity(
      request.inventoryItemId,
      request.quantity,
    );

    await _savePartsRequest(updatedRequest);
    return updatedRequest;
  }

  // Get parts request by ID
  Future<PartsRequest?> getPartsRequestById(String id) async {
    final allRequests = await getAllPartsRequests();
    try {
      return allRequests.firstWhere((request) => request.id == id);
    } catch (e) {
      return null;
    }
  }

  // Update parts request
  Future<PartsRequest> updatePartsRequest(PartsRequest request) async {
    final updatedRequest = request.copyWith(updatedAt: DateTime.now());
    await sl<SupabaseDatabaseService>()
        .updatePartsRequest(updatedRequest.id, updatedRequest);
    await _savePartsRequest(updatedRequest);
    return updatedRequest;
  }

  // Delete parts request
  Future<void> deletePartsRequest(String id) async {
    // Try cloud delete (if you add it later), then local prune
    final allRequests = await getAllPartsRequests();
    final filteredRequests =
        allRequests.where((request) => request.id != id).toList();
    await _savePartsRequests(filteredRequests);
  }

  // Check if parts are available
  Future<bool> checkPartsAvailability(
    String inventoryItemId,
    int quantity,
  ) async {
    // Prefer cloud when available
    try {
      final item = await sl<SupabaseDatabaseService>()
          .getInventoryItem(inventoryItemId);
      if (item != null) {
        return item.quantity >= quantity;
      }
    } catch (_) {}

    // Fallback to Firestore directly
    final inventoryItem = await sl<SupabaseDatabaseService>()
        .getInventoryItem(inventoryItemId);
    if (inventoryItem == null) return false;

    return inventoryItem.quantity >= quantity;
  }

  /// Convenience: check whether an item is at/under its minimum stock
  Future<bool> isItemLowStock(String inventoryItemId) async {
    try {
      final item = await sl<SupabaseDatabaseService>()
          .getInventoryItem(inventoryItemId);
      if (item != null) {
        if (item.minimumStock == null) return false;
        return item.quantity <= item.minimumStock!;
      }
    } catch (_) {}

    // Fallback to Firestore directly
    final item = await sl<SupabaseDatabaseService>()
        .getInventoryItem(inventoryItemId);
    if (item == null || item.minimumStock == null) return false;
    return item.quantity <= item.minimumStock!;
  }

  // Get low stock alerts
  Future<List<InventoryItem>> getLowStockItems({int threshold = 10}) async {
    final allItems = await sl<SupabaseDatabaseService>().getAllInventoryItems();
    return allItems.where((item) => item.quantity <= threshold).toList();
  }

  // Get parts usage statistics
  Future<Map<String, dynamic>> getPartsUsageStats() async {
    final allRequests = await getAllPartsRequests();
    final fulfilledRequests = allRequests
        .where((r) => r.status == PartsRequestStatus.fulfilled)
        .toList();

    final totalRequests = allRequests.length;
    final totalFulfilled = fulfilledRequests.length;
    final totalQuantity =
        fulfilledRequests.fold<int>(0, (sum, r) => sum + r.quantity);

    final requestsByPriority = <PartsRequestPriority, int>{};
    for (final priority in PartsRequestPriority.values) {
      requestsByPriority[priority] =
          allRequests.where((r) => r.priority == priority).length;
    }

    final requestsByStatus = <PartsRequestStatus, int>{};
    for (final status in PartsRequestStatus.values) {
      requestsByStatus[status] =
          allRequests.where((r) => r.status == status).length;
    }

    return {
      'totalRequests': totalRequests,
      'totalFulfilled': totalFulfilled,
      'fulfillmentRate':
          totalRequests > 0 ? (totalFulfilled / totalRequests) * 100 : 0.0,
      'totalQuantity': totalQuantity,
      'requestsByPriority': requestsByPriority,
      'requestsByStatus': requestsByStatus,
    };
  }

  // Private methods
  Future<void> _savePartsRequest(PartsRequest request) async {
    final allRequests = await getAllPartsRequests();
    final index = allRequests.indexWhere((r) => r.id == request.id);

    if (index != -1) {
      allRequests[index] = request;
    } else {
      allRequests.add(request);
    }

    await _savePartsRequests(allRequests);
  }

  Future<void> _savePartsRequests(List<PartsRequest> requests) async {
    final requestsJson = requests.map((r) => jsonEncode(r.toMap())).toList();
    await _prefs.setStringList('parts_requests', requestsJson);
  }

  Future<PartsRequest> _enrichPartsRequest(PartsRequest request) async {
    // Use Firestore to fetch related objects
    final workOrder = await sl<SupabaseDatabaseService>()
        .getWorkOrder(request.workOrderId);
    final technician = await sl<SupabaseDatabaseService>()
        .getUserById(request.technicianId);
    final inventoryItem = await sl<SupabaseDatabaseService>()
        .getInventoryItem(request.inventoryItemId);
    final approver = request.approvedBy != null
        ? await sl<SupabaseDatabaseService>().getUserById(request.approvedBy!)
        : null;

    return request.copyWith(
      workOrder: workOrder,
      technician: technician,
      inventoryItem: inventoryItem,
      approver: approver,
    );
  }

  // Decrement inventory quantity in Firestore
  Future<void> _decrementInventoryQuantity(
    String inventoryItemId,
    int quantity,
  ) async {
    try {
      final item = await sl<SupabaseDatabaseService>()
          .getInventoryItem(inventoryItemId);
      if (item != null) {
        final newQty =
            (item.quantity - quantity).clamp(0.0, double.infinity);
        final updated = item.copyWith(
          quantity: newQty,
          updatedAt: DateTime.now(),
        );
        await sl<SupabaseDatabaseService>()
            .updateInventoryItem(item.id, updated);
      }
    } catch (e) {
      // Log error but don't throw - best effort inventory update
      print('Error decrementing inventory quantity: $e');
    }
  }

  Future<void> _notifyRequester({
    required String userId,
    required String title,
    required String message,
    required NotificationPriority priority,
    required String workOrderId,
    required String inventoryItemId,
    required int quantity,
    required String status,
  }) async {
    if (userId.isEmpty) return;
    try {
      await sl<EnhancedNotificationService>().createNotification(
        title: title,
        message: message,
        type: NotificationType.inventoryRequest,
        priority: priority,
        userId: userId,
        relatedId: workOrderId,
        relatedType: 'parts_request',
        data: {
          'inventoryItemId': inventoryItemId,
          'quantity': quantity,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint('PartsRequestService: notification failed: $e');
    }
  }

  Future<void> _notifyManagersOfNewRequest(PartsRequest r) async {
    try {
      final users = await sl<SupabaseDatabaseService>().getAllUsers();
      final managers =
          users.where((u) => u.role == 'manager' || u.role == 'admin').toList();
      for (final m in managers) {
        await _notifyRequester(
          userId: m.id,
          title: 'New Parts Request',
          message:
              'Technician requested ${r.quantity} of ${r.inventoryItem?.name ?? r.inventoryItemId} for WO ${r.workOrder?.ticketNumber ?? r.workOrderId}.',
          priority: NotificationPriority.high,
          workOrderId: r.workOrderId,
          inventoryItemId: r.inventoryItemId,
          quantity: r.quantity,
          status: r.status.name,
        );
      }
    } catch (_) {
      // best-effort notifications
    }
  }
}
