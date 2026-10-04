import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/pm_work_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pm_occurrence_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/app_theme.dart';
import '../../pm_tasks/pm_occurrence_detail_screen.dart';
import 'requestor_pm_shared.dart';

/// Read-only requestor wrapper for PM work item detail.
class RequestorPmDetailScreen extends StatelessWidget {
  const RequestorPmDetailScreen({
    required this.item,
    super.key,
  });

  final PmWorkItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isOccurrence && item.occurrence != null) {
      final users = context.read<UserProvider>();
      final auth = context.read<AuthProvider>();
      final pmOccurrences = context.read<PmOccurrenceProvider>();
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: users),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<PmOccurrenceProvider>.value(
            value: pmOccurrences,
          ),
        ],
        child: PmOccurrenceDetailScreen(
          occurrence: item.occurrence!,
          readOnly: true,
        ),
      );
    }

    final legacy = item.legacyTask;
    if (legacy == null) {
      return Scaffold(
        appBar: buildRequestorPmAppBar(
          context,
          title: 'Preventive Maintenance',
        ),
        body: const Center(
          child: Text('PM details are not available.'),
        ),
      );
    }

    return Scaffold(
      appBar: buildRequestorPmAppBar(
        context,
        title: 'Preventive Maintenance',
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          Text(
            legacy.taskName,
            style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
          ),
          const SizedBox(height: AppTheme.spacingM),
          _DetailRow(label: 'Type', value: 'Legacy PM'),
          _DetailRow(label: 'Status', value: legacy.status.name),
          if (legacy.nextDueDate != null)
            _DetailRow(
              label: 'Due date',
              value: DateFormat.yMMMd().format(legacy.nextDueDate!.toLocal()),
            ),
          if (legacy.assetName?.isNotEmpty ?? false)
            _DetailRow(label: 'Asset', value: legacy.assetName!),
          if (legacy.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Description',
              style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              legacy.description,
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTheme.bodyText.copyWith(color: AppTheme.darkTextColor),
              ),
            ),
          ],
        ),
      );
}
