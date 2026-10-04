import '../../models/asset.dart';
import '../../services/supabase_database_service.dart';
import '../asset_repository.dart';
import '../../config/locator.dart';

class SupabaseAssetRepository implements AssetRepository {
  SupabaseAssetRepository({SupabaseDatabaseService? database})
      : _database = database ?? sl<SupabaseDatabaseService>();

  final SupabaseDatabaseService _database;

  @override
  Future<String> createAsset(Asset asset) => _database.createAsset(asset);

  @override
  Future<void> updateAsset(String assetId, Asset asset) =>
      _database.updateAsset(assetId, asset);

  @override
  Future<void> deleteAsset(String assetId) => _database.deleteAsset(assetId);

  @override
  Future<Asset?> getAsset(String assetId) => _database.getAsset(assetId);

  @override
  Future<List<Asset>> getAllAssets() => _database.getAllAssets();

  @override
  Future<List<Asset>> getAssetsByCompanyId(String companyId) =>
      _database.getAssetsByCompanyId(companyId);

  @override
  Future<Asset?> getAssetByQRCode(String qrCode) =>
      _database.getAssetByQRCode(qrCode);

  @override
  Future<List<Asset>> searchAssets(String query) =>
      _database.searchAssets(query);
}
