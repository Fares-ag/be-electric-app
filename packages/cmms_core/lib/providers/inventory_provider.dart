import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/inventory_item.dart';
import '../repositories/cmms_repositories.dart';
import '../services/unified_data_service.dart';
import '../utils/performance_optimizer.dart';
import '../utils/stream_subscription_cancel.dart';
import 'domain/cmms_domain_provider.dart';
import '../config/locator.dart';

/// Inventory state: realtime cache, CRUD, and UI filtering.
class InventoryProvider with ChangeNotifier implements CmmsDomainProvider {
  InventoryProvider({UnifiedDataService? dataService})
      : _dataService = dataService ?? sl<UnifiedDataService>();

  final UnifiedDataService _dataService;
  bool _isDisposed = false;
  StreamSubscription<List<InventoryItem>>? _inventorySubscription;
  List<InventoryItem> _realtimeInventory = [];

  List<InventoryItem> _inventoryItems = [];
  List<InventoryItem> _filteredInventoryItems = [];
  bool _isLoading = false;
  String _selectedFilter = 'all';

  List<InventoryItem> get inventoryItems => _filteredInventoryItems;

  /// Canonical inventory list (realtime when available).
  List<InventoryItem> get items => _realtimeInventory.isNotEmpty
      ? _realtimeInventory
      : _dataService.inventoryItems;

  bool get isLoading => _isLoading || _dataService.isInventoryLoading;
  String get selectedFilter => _selectedFilter;

  Stream<List<InventoryItem>> get inventoryItemsStream =>
      _dataService.inventoryItemsStream;

  int get totalInventory => items.length;
  int get lowStockItems =>
      items.where((item) => item.quantity <= 10).length;

  int get totalItems => _inventoryItems.length;
  int get lowStockItemsFiltered =>
      _inventoryItems.where((item) => item.isLowStock).length;
  int get outOfStockItems =>
      _inventoryItems.where((item) => item.isOutOfStock).length;
  int get overstockedItems =>
      _inventoryItems.where((item) => item.isOverstocked).length;
  int get activeItems => _inventoryItems.where((item) => item.isActive).length;
  int get inactiveItems =>
      _inventoryItems.where((item) => item.isInactive).length;

  double get totalValue => _inventoryItems.fold(
        0,
        (sum, item) => sum + (item.quantity * (item.cost ?? 0)),
      );

  List<InventoryItem> getLowStockItems({double? threshold}) =>
      items.where((item) {
        final minThreshold = threshold ?? item.minimumStock ?? 0;
        return item.quantity < minThreshold;
      }).toList();

  List<InventoryItem> getInventoryByCategory(String category) {
    final target = category.toLowerCase();
    return items
        .where((item) => item.category.toLowerCase() == target)
        .toList();
  }

  Future<void> loadInventory() async {
    _isLoading = true;
    notifyListeners();

    try {
      _inventoryItems = items;
      _applyFilters();
    } catch (e, st) {
      debugPrint('Error loading inventory: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void syncFromRealtime() {
    _inventoryItems = items;
    _applyFilters();
    notifyListeners();
  }

  Future<String> createInventoryItem({
    required String name,
    required String category,
    required double quantity,
    required String unit,
    String? description,
    String? sku,
    String? partNumber,
    String? manufacturer,
    String? supplier,
    double? cost,
    double? minimumStock,
    double? maximumStock,
    String? location,
    String? shelf,
    String? bin,
    String? imageUrl,
    String? warranty,
    String? notes,
  }) async {
    try {
      const uuid = Uuid();
      final now = DateTime.now();

      final item = InventoryItem(
        id: uuid.v4(),
        name: name,
        category: category,
        quantity: quantity,
        unit: unit,
        description: description,
        sku: sku,
        partNumber: partNumber,
        manufacturer: manufacturer,
        supplier: supplier,
        cost: cost,
        minimumStock: minimumStock,
        maximumStock: maximumStock,
        location: location,
        shelf: shelf,
        bin: bin,
        imageUrl: imageUrl,
        warranty: warranty,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      );

      await CmmsRepositories.inventory.createInventoryItem(item);
      _inventoryItems.add(item);
      _applyFilters();
      notifyListeners();

      return item.id;
    } catch (e, st) {
      debugPrint('Error creating inventory item: $e');
      rethrow;
    }
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    try {
      final updatedItem = item.copyWith(
        updatedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      await CmmsRepositories.inventory.updateInventoryItem(
        updatedItem.id,
        updatedItem,
      );

      final index = _inventoryItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        _inventoryItems[index] = updatedItem;
        _applyFilters();
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('Error updating inventory item: $e');
      rethrow;
    }
  }

  Future<void> deleteInventoryItem(String itemId) async {
    try {
      await CmmsRepositories.inventory.deleteInventoryItem(itemId);
      _inventoryItems.removeWhere((item) => item.id == itemId);
      _applyFilters();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error deleting inventory item: $e');
      rethrow;
    }
  }

  Future<void> adjustInventory({
    required String itemId,
    required double quantity,
    required String type,
    String? notes,
    String? reference,
  }) async {
    try {
      final item = _inventoryItems.firstWhere((i) => i.id == itemId);
      var newQuantity = item.quantity;

      switch (type) {
        case 'in':
          newQuantity += quantity;
          break;
        case 'out':
          newQuantity -= quantity;
          break;
        case 'adjustment':
          newQuantity = quantity;
          break;
      }

      final updatedItem = item.copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      await CmmsRepositories.inventory.updateInventoryItem(
        updatedItem.id,
        updatedItem,
      );

      final index = _inventoryItems.indexWhere((i) => i.id == itemId);
      if (index != -1) {
        _inventoryItems[index] = updatedItem;
        _applyFilters();
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('Error adjusting inventory: $e');
      rethrow;
    }
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    switch (_selectedFilter) {
      case 'lowStock':
        _filteredInventoryItems =
            _inventoryItems.where((item) => item.isLowStock).toList();
        break;
      case 'outOfStock':
        _filteredInventoryItems =
            _inventoryItems.where((item) => item.isOutOfStock).toList();
        break;
      case 'overstocked':
        _filteredInventoryItems =
            _inventoryItems.where((item) => item.isOverstocked).toList();
        break;
      case 'active':
        _filteredInventoryItems =
            _inventoryItems.where((item) => item.isActive).toList();
        break;
      case 'inactive':
        _filteredInventoryItems =
            _inventoryItems.where((item) => item.isInactive).toList();
        break;
      default:
        _filteredInventoryItems = List.from(_inventoryItems);
    }
  }

  List<InventoryItem> searchInventory(String query) {
    if (query.isEmpty) return _inventoryItems;

    final lowerQuery = query.toLowerCase();
    return _inventoryItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(lowerQuery) ||
              item.category.toLowerCase().contains(lowerQuery) ||
              (item.sku?.toLowerCase().contains(lowerQuery) ?? false) ||
              (item.partNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
              (item.manufacturer?.toLowerCase().contains(lowerQuery) ??
                  false) ||
              (item.supplier?.toLowerCase().contains(lowerQuery) ?? false),
        )
        .toList();
  }

  List<InventoryItem> getLowStockItemsList() =>
      _inventoryItems.where((item) => item.isLowStock).toList();

  List<InventoryItem> getOutOfStockItems() =>
      _inventoryItems.where((item) => item.isOutOfStock).toList();

  List<InventoryItem> getItemsByCategory(String category) =>
      _inventoryItems.where((item) => item.category == category).toList();

  Map<String, int> getCategoryStats() {
    final stats = <String, int>{};
    for (final item in _inventoryItems) {
      stats[item.category] = (stats[item.category] ?? 0) + 1;
    }
    return stats;
  }

  @override
  void clearCache() {
    _realtimeInventory = [];
    _inventoryItems = [];
    _filteredInventoryItems = [];
  }

  @override
  Future<void> cancelRealtimeListeners() async {
    await cancelStreamSubscriptions([_inventorySubscription]);
    _inventorySubscription = null;
  }

  @override
  Future<void> startRealtimeListeners() async {
    if (_isDisposed) return;
    await cancelRealtimeListeners();
    if (_isDisposed) return;

    _inventorySubscription = _dataService.inventoryItemsStream.listen(
      (inventory) {
        _realtimeInventory = inventory;
        syncFromRealtime();
        if (!_isDisposed) {
          ChangeNotifierBatcher.batchNotify(
            () => notifyListeners(),
            batchKey: this,
          );
        }
      },
      onError: (error) {
        debugPrint('❌ Inventory stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    ChangeNotifierBatcher.cancel(this);
    unawaited(cancelRealtimeListeners());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
