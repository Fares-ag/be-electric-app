import '../models/asset.dart';
import '../models/work_order.dart';

/// Kostad chargers use asset names starting with `KOS`; all others are Siemens.
/// Matches Supabase trigger + admin web [charger-manufacturer.ts].
String deriveChargerManufacturerFromName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return 'Siemens';
  }
  if (trimmed.toUpperCase().startsWith('KOS')) {
    return 'Kostad';
  }
  return 'Siemens';
}

/// Normalizes admin-set manufacturer/vendor to Siemens or Kostad when recognizable.
String normalizeChargerBrand(String value) {
  final v = value.trim().toLowerCase();
  if (v.contains('kostad')) {
    return 'Kostad';
  }
  if (v.contains('siemens') ||
      v.contains('sicharge') ||
      v.contains('versicharge')) {
    return 'Siemens';
  }
  return value.trim();
}

/// Manufacturer for display/filtering: prefer admin DB fields, then name heuristics.
String resolveChargerManufacturer(Asset asset) {
  if (isChargerLikeAsset(asset)) {
    final fromDb =
        _nonEmptyTrim(asset.manufacturer) ?? _nonEmptyTrim(asset.vendor);
    if (fromDb != null) {
      return normalizeChargerBrand(fromDb);
    }
    return deriveChargerManufacturerFromName(asset.name);
  }
  return _nonEmptyTrim(asset.manufacturer) ??
      _nonEmptyTrim(asset.vendor) ??
      deriveChargerManufacturerFromName(asset.name);
}

/// Work order detail: derived from linked asset when hydrated.
String? resolveWorkOrderChargerManufacturer(WorkOrder workOrder) {
  final asset = workOrder.asset;
  if (asset == null) {
    return null;
  }
  return resolveChargerManufacturer(asset);
}

/// Treat as charger if name/type/category contains "charger" or EV power pattern
/// (e.g. 60kW.DC). Same rules as the admin company chargers list.
bool isChargerLikeAsset(Asset asset) {
  const charger = 'charger';
  const evPower = 'kw';
  final name = asset.name.toLowerCase();
  final itemType = asset.itemType?.toLowerCase() ?? '';
  final category = asset.category?.toLowerCase() ?? '';
  if (name.contains(charger) ||
      itemType.contains(charger) ||
      category.contains(charger) ||
      name.contains(evPower) ||
      itemType.contains(evPower) ||
      category.contains(evPower)) {
    return true;
  }
  // Manufacturer / vendor often set even when name is only an asset code (e.g. "KEC00067")
  final m = '${asset.manufacturer ?? ''} ${asset.vendor ?? ''} ${asset.model ?? ''}'
      .toLowerCase();
  if (m.contains('charg') ||
      m.contains('siemens') ||
      m.contains('kostad') ||
      m.contains('evse') ||
      m.contains('wallbox') ||
      m.contains('cbox') ||
      m.contains('kec') ||
      m.contains('sicharge') ||
      m.contains('versicharge')) {
    return true;
  }
  if (name.toUpperCase().startsWith('KOS')) {
    return true;
  }
  final extra = '${asset.description ?? ''} ${asset.notes ?? ''}'.toLowerCase();
  if (extra.contains(charger) ||
      extra.contains(evPower) ||
      extra.contains('sicharge') ||
      extra.contains('evse')) {
    return true;
  }
  return false;
}

String? _nonEmptyTrim(String? s) {
  if (s == null) return null;
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// True if [text] is associated with [brand] (Siemens includes Sicharge, etc.)
bool _textImpliesChargerBrand(String brandLower, String text) {
  final t = text.toLowerCase();
  if (t.contains(brandLower)) {
    return true;
  }
  if (brandLower == 'siemens') {
    if (t.contains('sicharge') ||
        t.contains('sicharger') ||
        t.contains('versicharge')) {
      return true;
    }
  }
  return false;
}

/// Matches [brand] (e.g. `Siemens`, `Kostad`) using name-derived manufacturer first,
/// then DB fields, then legacy text heuristics.
bool matchesChargerBrand(Asset asset, String brand) {
  final b = brand.trim().toLowerCase();
  if (b.isEmpty) {
    return false;
  }

  if (isChargerLikeAsset(asset)) {
    return resolveChargerManufacturer(asset).toLowerCase() == b;
  }

  final fromFields = _nonEmptyTrim(asset.manufacturer) ??
      _nonEmptyTrim(asset.vendor);
  if (fromFields != null) {
    final fl = fromFields.toLowerCase();
    if (fl == b || _textImpliesChargerBrand(b, fromFields)) {
      return true;
    }
    if (fl.length >= 3 && b.contains(fl)) {
      return true;
    }
  }

  final blob = [
    asset.name,
    asset.model,
    asset.description,
    asset.category,
    asset.itemType,
    asset.notes,
    asset.modelDesc,
  ].whereType<String>().join(' ');

  if (_textImpliesChargerBrand(b, blob)) {
    return true;
  }
  // Legacy simple substring in name / model
  return asset.name.toLowerCase().contains(b) ||
      (asset.model ?? '').toLowerCase().contains(b);
}

/// Chargers belonging to [companyId], regardless of Siemens/Kostad brand.
List<Asset> chargersForCompany({
  required Iterable<Asset> assets,
  required String companyId,
  String? resolvedCompanyName,
}) {
  final id = companyId.trim();
  if (id.isEmpty) {
    return const [];
  }

  return assets.where((asset) {
    if (!isChargerLikeAsset(asset)) {
      return false;
    }
    return assetBelongsToUserCompany(
      asset,
      id,
      resolvedCompanyName: resolvedCompanyName,
    );
  }).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

/// Technician create form: optional [companyId] filter; when omitted, all chargers.
List<Asset> chargersForTechnicianCreate({
  required Iterable<Asset> assets,
  String? companyId,
  String? resolvedCompanyName,
}) {
  final id = companyId?.trim() ?? '';
  if (id.isEmpty) {
    return assets.where(isChargerLikeAsset).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return chargersForCompany(
    assets: assets,
    companyId: id,
    resolvedCompanyName: resolvedCompanyName,
  );
}

/// Chargers shown on create-work-order: charger-like + brand, optionally company.
List<Asset> chargersForCreateForm({
  required Iterable<Asset> assets,
  required String manufacturer,
  String? companyId,
  bool restrictToCompany = false,
}) {
  final brand = manufacturer.trim();
  if (brand.isEmpty) {
    return const [];
  }

  final filtered = assets.where((asset) {
    if (!isChargerLikeAsset(asset)) {
      return false;
    }
    if (!matchesChargerBrand(asset, brand)) {
      return false;
    }
    if (restrictToCompany) {
      final id = companyId?.trim() ?? '';
      if (id.isEmpty) {
        return false;
      }
      return assetBelongsToUserCompany(asset, id);
    }
    return true;
  }).toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  return filtered;
}

/// Siemens or Kostad for create-form dropdowns. Falls back to the name rule.
String createFormChargerBrand(Asset asset) {
  final resolved = resolveChargerManufacturer(asset);
  if (resolved == 'Siemens' || resolved == 'Kostad') {
    return resolved;
  }
  return deriveChargerManufacturerFromName(asset.name);
}

/// Charger a technician adds when it is not already in the catalog.
Asset buildFieldAddedCharger({
  required String name,
  required String location,
  required String manufacturer,
  required String id,
  String? serialNumber,
  String? assetTag,
  String? companyId,
  DateTime? now,
}) {
  final stamp = now ?? DateTime.now();
  final serial = _nonEmptyTrim(serialNumber);
  final tag = _nonEmptyTrim(assetTag);
  final company = _nonEmptyTrim(companyId);
  return Asset(
    id: id,
    name: name.trim(),
    location: location.trim(),
    manufacturer: manufacturer.trim(),
    serialNumber: serial,
    qrCode: tag,
    qrCodeId: tag,
    status: 'active',
    itemType: 'charger',
    category: 'charger',
    companyId: company,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

/// True if [asset] is in the same tenant as the signed-in user.
/// Handles camelCase and legacy rows where the FK is in [Asset.company] or
/// the company name is stored instead of the UUID.
bool assetBelongsToUserCompany(
  Asset asset,
  String userCompanyId, {
  String? resolvedCompanyName,
}) {
  final uid = userCompanyId.trim();
  if (uid.isEmpty) {
    return false;
  }
  final aid = _nonEmptyTrim(asset.companyId);
  if (aid != null && aid == uid) {
    return true;
  }
  final ac = _nonEmptyTrim(asset.company);
  if (ac != null) {
    if (ac == uid) {
      return true;
    }
    if (resolvedCompanyName != null &&
        resolvedCompanyName.isNotEmpty &&
        ac.toLowerCase() == resolvedCompanyName.toLowerCase()) {
      return true;
    }
  }
  return false;
}
