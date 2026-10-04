import '../models/asset.dart';

abstract class AssetRepository {
  Future<String> createAsset(Asset asset);
  Future<void> updateAsset(String assetId, Asset asset);
  Future<void> deleteAsset(String assetId);
  Future<Asset?> getAsset(String assetId);
  Future<List<Asset>> getAllAssets();
  Future<List<Asset>> getAssetsByCompanyId(String companyId);
  Future<Asset?> getAssetByQRCode(String qrCode);
  Future<List<Asset>> searchAssets(String query);
}
