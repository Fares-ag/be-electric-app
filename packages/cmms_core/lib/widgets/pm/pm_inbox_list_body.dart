import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pm_work_item.dart';
import '../../providers/pm_inbox_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/pm_work_item_navigation.dart';
import '../../utils/responsive_layout.dart';
import 'pm_work_item_card.dart';

/// Technician unified PM inbox list backed by [PmInboxProvider].
class PmInboxListBody extends StatelessWidget {
  const PmInboxListBody({
    super.key,
    this.onRefresh,
  });

  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => Consumer<PmInboxProvider>(
        builder: (context, inboxProvider, _) {
          final items = inboxProvider.inbox;

          if (items.isEmpty) {
            return _EmptyState(onRefresh: onRefresh);
          }

          final listView = ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: ResponsiveLayout.getResponsivePadding(context).left,
              right: ResponsiveLayout.getResponsivePadding(context).right,
              top: ResponsiveLayout.getResponsivePadding(context).top,
              bottom: ResponsiveLayout.getResponsivePadding(context).bottom +
                  56 +
                  MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return PmWorkItemCard(
                item: item,
                onTap: () =>
                    PmWorkItemNavigation.openTechnicianDetail(context, item),
              );
            },
          );

          if (onRefresh == null) {
            return listView;
          }

          return RefreshIndicator(
            onRefresh: onRefresh!,
            child: listView,
          );
        },
      );

}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onRefresh});

  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: ResponsiveLayout.getResponsivePadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.schedule,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No PM tasks found',
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (onRefresh == null) {
      return content;
    }

    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: content,
          ),
        ],
      ),
    );
  }
}
