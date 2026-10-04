import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/pm_work_item.dart';
import '../../../providers/asset_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pm_inbox_provider.dart';
import '../../../providers/pm_occurrence_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/pm_work_item_filter.dart';
import '../../../utils/pm_work_item_navigation.dart';
import '../../../utils/requestor_pm_work_item_scope.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/pm/pm_work_item_card.dart';
import 'requestor_pm_shared.dart';

enum RequestorPmListMode {
  upcoming,
  overdue,
  history,
  byCharger,
}

/// Read-only requestor PM list backed by [PmInboxProvider].
class RequestorPmListScreen extends StatelessWidget {
  const RequestorPmListScreen({
    required this.mode,
    super.key,
  });

  final RequestorPmListMode mode;

  String get _title {
    switch (mode) {
      case RequestorPmListMode.upcoming:
        return 'Upcoming PM';
      case RequestorPmListMode.overdue:
        return 'Overdue PM';
      case RequestorPmListMode.history:
        return 'PM History';
      case RequestorPmListMode.byCharger:
        return 'PM by Charger';
    }
  }

  List<PmWorkItem> _itemsForMode(List<PmWorkItem> scoped) {
    switch (mode) {
      case RequestorPmListMode.upcoming:
        return filterPmWorkItemsUpcoming(scoped);
      case RequestorPmListMode.overdue:
        return filterPmWorkItemsOverdue(scoped);
      case RequestorPmListMode.history:
        return filterRequestorPmHistory(scoped);
      case RequestorPmListMode.byCharger:
        return scoped;
    }
  }

  String _emptyMessage() {
    switch (mode) {
      case RequestorPmListMode.upcoming:
        return 'No upcoming preventive maintenance.';
      case RequestorPmListMode.overdue:
        return 'No overdue preventive maintenance.';
      case RequestorPmListMode.history:
        return 'No PM history yet.';
      case RequestorPmListMode.byCharger:
        return 'No preventive maintenance for your chargers.';
    }
  }

  void _openItem(BuildContext context, PmWorkItem item) {
    PmWorkItemNavigation.openRequestorDetail(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PmInboxProvider, PmOccurrenceProvider, AssetProvider>(
      builder: (context, inboxProvider, pmOccurrences, assets, _) {
        if (!pmOccurrences.isEnabled) {
          return Scaffold(
            appBar: buildRequestorPmAppBar(context, title: _title),
            body: buildRequestorPmUnavailableBody(),
          );
        }

        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.currentUser == null) {
          return Scaffold(
            appBar: buildRequestorPmAppBar(context, title: _title),
            body: const Center(
              child: Text('Sign in to view preventive maintenance.'),
            ),
          );
        }

        if (pmOccurrences.isLoading && !pmOccurrences.hasLoaded) {
          return Scaffold(
            appBar: buildRequestorPmAppBar(context, title: _title),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final companyId = auth.currentUser!.companyId;
        final authorizedAssets = filterRequestorAuthorizedAssets(
          assets.assets,
          companyId: companyId,
        );
        final scoped = scopeRequestorPmWorkItems(
          inboxProvider.inbox,
          authorizedAssets: authorizedAssets,
        );
        final items = _itemsForMode(scoped);

        final body = mode == RequestorPmListMode.byCharger
            ? _ByChargerList(
                grouped: groupRequestorPmWorkItemsByAsset(items),
                emptyMessage: _emptyMessage(),
                onTap: (item) => _openItem(context, item),
              )
            : _FlatPmList(
                items: items,
                emptyMessage: _emptyMessage(),
                onTap: (item) => _openItem(context, item),
              );

        return Scaffold(
          appBar: buildRequestorPmAppBar(context, title: _title),
          body: RefreshIndicator(
            onRefresh: () => refreshRequestorPmData(context),
            child: body,
          ),
        );
      },
    );
  }
}

class _FlatPmList extends StatelessWidget {
  const _FlatPmList({
    required this.items,
    required this.emptyMessage,
    required this.onTap,
  });

  final List<PmWorkItem> items;
  final String emptyMessage;
  final ValueChanged<PmWorkItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.4,
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.getResponsivePadding(context),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return PmWorkItemCard(
          item: item,
          showRequestorConfirm: true,
          onTap: () => onTap(item),
        );
      },
    );
  }
}

class _ByChargerList extends StatelessWidget {
  const _ByChargerList({
    required this.grouped,
    required this.emptyMessage,
    required this.onTap,
  });

  final Map<String, List<PmWorkItem>> grouped;
  final String emptyMessage;
  final ValueChanged<PmWorkItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (grouped.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.4,
            child: Center(
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final assetNames = grouped.keys.toList()..sort();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.getResponsivePadding(context),
      itemCount: assetNames.length,
      itemBuilder: (context, index) {
        final assetName = assetNames[index];
        final items = grouped[assetName] ?? const [];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                assetName,
                style: AppTheme.bodyText.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              ...items.map(
                (item) => PmWorkItemCard(
                  item: item,
                  showRequestorConfirm: true,
                  onTap: () => onTap(item),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
