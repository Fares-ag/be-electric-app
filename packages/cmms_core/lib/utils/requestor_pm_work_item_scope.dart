import '../models/asset.dart';
import '../models/pm_work_item.dart';
import 'charger_asset_filter.dart';

/// Assets visible to the signed-in requestor (matches maintenance request scoping).
List<Asset> filterRequestorAuthorizedAssets(
  Iterable<Asset> assets, {
  required String? companyId,
  String? resolvedCompanyName,
}) {
  final id = companyId?.trim() ?? '';
  if (id.isEmpty) {
    return const [];
  }
  return assets
      .where(
        (asset) => assetBelongsToUserCompany(
          asset,
          id,
          resolvedCompanyName: resolvedCompanyName,
        ),
      )
      .toList(growable: false);
}

/// Presentation-only scoping for requestor PM views (RLS-aligned asset visibility).
List<PmWorkItem> scopeRequestorPmWorkItems(
  List<PmWorkItem> inbox, {
  required Iterable<Asset> authorizedAssets,
}) {
  final authorizedAssetIds = authorizedAssets.map((asset) => asset.id).toSet();
  if (authorizedAssetIds.isEmpty) {
    return const [];
  }

  return inbox
      .where(
        (item) => _isItemVisibleToRequestor(item, authorizedAssetIds),
      )
      .toList(growable: false);
}

bool _isItemVisibleToRequestor(PmWorkItem item, Set<String> authorizedAssetIds) {
  final assetId = item.occurrence?.assetId ?? item.legacyTask?.assetId;
  if (assetId == null || assetId.isEmpty) {
    return false;
  }
  return authorizedAssetIds.contains(assetId);
}

String requestorPmAssetLabel(PmWorkItem item) {
  final occurrence = item.occurrence;
  if (occurrence?.assetName?.isNotEmpty ?? false) {
    return occurrence!.assetName!;
  }

  final legacy = item.legacyTask;
  if (legacy?.assetName?.isNotEmpty ?? false) {
    return legacy!.assetName!;
  }

  final assetId = occurrence?.assetId ?? legacy?.assetId;
  if (assetId != null && assetId.isNotEmpty) {
    return assetId;
  }

  return 'Unknown charger';
}

Map<String, List<PmWorkItem>> groupRequestorPmWorkItemsByAsset(
  List<PmWorkItem> items,
) {
  final grouped = <String, List<PmWorkItem>>{};
  for (final item in items) {
    final key = requestorPmAssetLabel(item);
    grouped.putIfAbsent(key, () => []).add(item);
  }
  return grouped;
}

List<PmWorkItem> filterRequestorPmHistory(List<PmWorkItem> items) =>
    items
        .where(
          (item) =>
              item.displayStatus == PmWorkItemDisplayStatus.completed ||
              item.displayStatus == PmWorkItemDisplayStatus.cancelled,
        )
        .toList(growable: false);
