import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../providers/asset_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pm_inbox_provider.dart';
import '../../../providers/pm_occurrence_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/pm_work_item_filter.dart';
import '../../../utils/requestor_pm_work_item_scope.dart';
import 'requestor_pm_list_screen.dart';
import 'requestor_pm_shared.dart';

/// Requestor read-only PM hub: counts, status breakdown, and shortcuts.
class RequestorPmDashboardScreen extends StatefulWidget {
  const RequestorPmDashboardScreen({super.key});

  @override
  State<RequestorPmDashboardScreen> createState() =>
      _RequestorPmDashboardScreenState();
}

class _RequestorPmDashboardScreenState extends State<RequestorPmDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshRequestorPmData(context);
    });
  }

  void _openList(RequestorPmListMode mode) {
    final auth = context.read<AuthProvider>();
    final users = context.read<UserProvider>();
    final assets = context.read<AssetProvider>();
    final pmOccurrences = context.read<PmOccurrenceProvider>();
    final inbox = context.read<PmInboxProvider>();

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<UserProvider>.value(value: users),
            ChangeNotifierProvider<AssetProvider>.value(value: assets),
            ChangeNotifierProvider<PmOccurrenceProvider>.value(
              value: pmOccurrences,
            ),
            ChangeNotifierProvider<PmInboxProvider>.value(value: inbox),
          ],
          child: RequestorPmListScreen(mode: mode),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<PmInboxProvider, PmOccurrenceProvider, AssetProvider>(
      builder: (context, inboxProvider, pmOccurrences, assets, _) {
        if (!pmOccurrences.isEnabled) {
          return Scaffold(
            appBar: buildRequestorPmAppBar(
              context,
              title: 'Preventive Maintenance',
            ),
            body: buildRequestorPmUnavailableBody(),
          );
        }

        final auth = Provider.of<AuthProvider>(context, listen: false);
        if (auth.currentUser == null) {
          return Scaffold(
            appBar: buildRequestorPmAppBar(
              context,
              title: 'Preventive Maintenance',
            ),
            body: const Center(
              child: Text('Sign in to view preventive maintenance.'),
            ),
          );
        }

        if (pmOccurrences.isLoading && !pmOccurrences.hasLoaded) {
          return Scaffold(
            appBar: buildRequestorPmAppBar(
              context,
              title: 'Preventive Maintenance',
            ),
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

        final upcoming = filterPmWorkItemsUpcoming(scoped);
        final overdue = filterPmWorkItemsOverdue(scoped);
        final history = filterRequestorPmHistory(scoped);

        return Scaffold(
          appBar: buildRequestorPmAppBar(
            context,
            title: 'Preventive Maintenance',
          ),
          body: RefreshIndicator(
            onRefresh: () => refreshRequestorPmData(context),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Text(
                  'Overview',
                  style: AppTheme.heading2.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                _SummaryGrid(
                  upcomingCount: upcoming.length,
                  overdueCount: overdue.length,
                  historyCount: history.length,
                  totalCount: scoped.length,
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Browse',
                  style: AppTheme.bodyText.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                _ShortcutTile(
                  tileKey: const Key('requestor_pm_shortcut_upcoming'),
                  icon: Icons.schedule_outlined,
                  title: 'Upcoming',
                  subtitle: '${upcoming.length} scheduled',
                  onTap: () => _openList(RequestorPmListMode.upcoming),
                ),
                _ShortcutTile(
                  tileKey: const Key('requestor_pm_shortcut_overdue'),
                  icon: Icons.warning_amber_outlined,
                  title: 'Overdue',
                  subtitle: '${overdue.length} need attention',
                  onTap: () => _openList(RequestorPmListMode.overdue),
                ),
                _ShortcutTile(
                  tileKey: const Key('requestor_pm_shortcut_history'),
                  icon: Icons.history,
                  title: 'History',
                  subtitle: '${history.length} completed or cancelled',
                  onTap: () => _openList(RequestorPmListMode.history),
                ),
                _ShortcutTile(
                  tileKey: const Key('requestor_pm_shortcut_by_charger'),
                  icon: Icons.ev_station_outlined,
                  title: 'By Charger',
                  subtitle: 'Asset-centric view',
                  onTap: () => _openList(RequestorPmListMode.byCharger),
                ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.upcomingCount,
    required this.overdueCount,
    required this.historyCount,
    required this.totalCount,
  });

  final int upcomingCount;
  final int overdueCount;
  final int historyCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppTheme.spacingS,
        crossAxisSpacing: AppTheme.spacingS,
        childAspectRatio: 1.6,
        children: [
          _SummaryCard(label: 'Total', value: totalCount),
          _SummaryCard(label: 'Upcoming', value: upcomingCount),
          _SummaryCard(label: 'Overdue', value: overdueCount),
          _SummaryCard(label: 'History', value: historyCount),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
              ),
              Text(
                label,
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: ListTile(
          key: tileKey,
          leading: Icon(icon, color: AppTheme.accentGreen),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
