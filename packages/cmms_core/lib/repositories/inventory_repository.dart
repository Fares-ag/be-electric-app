import '../models/inventory_item.dart';

abstract class InventoryRepository {
  Future<String> createInventoryItem(InventoryItem item);
  Future<void> updateInventoryItem(String itemId, InventoryItem item);
  Future<void> deleteInventoryItem(String itemId);
  Future<InventoryItem?> getInventoryItem(String itemId);
  Future<InventoryItem?> getInventoryItemById(String itemId);
  Future<List<InventoryItem>> getAllInventoryItems();
}
