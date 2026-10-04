import '../../models/inventory_item.dart';
import '../../services/supabase_database_service.dart';
import '../inventory_repository.dart';
import '../../config/locator.dart';

class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository({SupabaseDatabaseService? database})
      : _database = database ?? sl<SupabaseDatabaseService>();

  final SupabaseDatabaseService _database;

  @override
  Future<String> createInventoryItem(InventoryItem item) =>
      _database.createInventoryItem(item);

  @override
  Future<void> updateInventoryItem(String itemId, InventoryItem item) =>
      _database.updateInventoryItem(itemId, item);

  @override
  Future<void> deleteInventoryItem(String itemId) =>
      _database.deleteInventoryItem(itemId);

  @override
  Future<InventoryItem?> getInventoryItem(String itemId) =>
      _database.getInventoryItem(itemId);

  @override
  Future<InventoryItem?> getInventoryItemById(String itemId) =>
      _database.getInventoryItemById(itemId);

  @override
  Future<List<InventoryItem>> getAllInventoryItems() =>
      _database.getAllInventoryItems();
}
