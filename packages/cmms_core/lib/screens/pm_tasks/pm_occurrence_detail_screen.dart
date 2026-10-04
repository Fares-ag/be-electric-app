import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/pm_occurrence.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pm_occurrence_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/pm_work_item_display_status.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/pm/requestor_pm_confirm_action.dart';
import 'pm_occurrence_completion_screen.dart';

/// Read-only detail view for a scheduled PM occurrence (Option A).
class PmOccurrenceDetailScreen extends StatelessWidget {
  const PmOccurrenceDetailScreen({
    required this.occurrence,
    this.readOnly = false,
    super.key,
  });

  final PmOccurrence occurrence;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(readOnly ? 'Preventive Maintenance' : 'Scheduled PM'),
        ),
        body: PmOccurrenceDetailContent(
          occurrence: occurrence,
          readOnly: readOnly,
        ),
      );
}

/// Shared occurrence detail body for technician and requestor views.
class PmOccurrenceDetailContent extends StatelessWidget {
  const PmOccurrenceDetailContent({
    required this.occurrence,
    this.readOnly = false,
    super.key,
  });

  final PmOccurrence occurrence;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final displayStatus = normalizeOccurrenceDisplayStatus(occurrence);
    final scheduleName = occurrence.taskName.isNotEmpty
        ? occurrence.taskName
        : 'Preventive maintenance';

    return Consumer<UserProvider>(
      builder: (context, users, _) {
        final assigneeLabel = _formatAssignees(
          occurrence.assignedTechnicianIds,
          users.users,
        );

        return ListView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          children: [
            Text(
              scheduleName,
              style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _DetailRow(label: 'Schedule', value: scheduleName),
            _DetailRow(
              label: 'Due date',
              value: DateFormat.yMMMd().format(occurrence.dueDate.toLocal()),
            ),
            _DetailRow(
              label: 'Status',
              value: _statusLabel(displayStatus),
            ),
            if (assigneeLabel.isNotEmpty)
              _DetailRow(label: 'Assigned', value: assigneeLabel),
            if (occurrence.assetName?.isNotEmpty ?? false)
              _DetailRow(label: 'Asset', value: occurrence.assetName!),
            if (occurrence.assetSerialNumber?.isNotEmpty ?? false)
              _DetailRow(
                label: 'Serial',
                value: occurrence.assetSerialNumber!,
              ),
            if (occurrence.assetManufacturer?.isNotEmpty ?? false)
              _DetailRow(
                label: 'Manufacturer',
                value: occurrence.assetManufacturer!,
              ),
            if (occurrence.assetModel?.isNotEmpty ?? false)
              _DetailRow(label: 'Model', value: occurrence.assetModel!),
            if (occurrence.assetLocation?.isNotEmpty ?? false)
              _DetailRow(label: 'Location', value: occurrence.assetLocation!),
            if (occurrence.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Description',
                style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                occurrence.description!,
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
            if (occurrence.checklist.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Checklist',
                style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingS),
              ...occurrence.checklist.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_box_outline_blank,
                        size: 18,
                        color: AppTheme.secondaryTextColor,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          item,
                          style: AppTheme.bodyText.copyWith(
                            color: AppTheme.darkTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (displayStatus == PmWorkItemDisplayStatus.completed) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Completion',
                style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingS),
              if (occurrence.completedAt != null)
                _DetailRow(
                  label: 'Completed',
                  value: DateFormat.yMMMd().add_jm().format(
                        occurrence.completedAt!.toLocal(),
                      ),
                ),
              if (occurrence.completionNotes?.isNotEmpty ?? false)
                _DetailRow(
                  label: 'Notes',
                  value: occurrence.completionNotes!,
                ),
              if (occurrence.completionPhotoReference != null) ...[
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Photo',
                  style: AppTheme.smallText.copyWith(
                    color: AppTheme.secondaryTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  child: AuthenticatedImage(
                    imageUrl: occurrence.completionPhotoReference!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
            if (readOnly && isPmWorkItemDisplayStatusOpen(displayStatus))
              RequestorPmConfirmAction(occurrence: occurrence),
            if (!readOnly &&
                AppConfig.enablePmOccurrences &&
                isPmWorkItemDisplayStatusOpen(displayStatus))
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingL),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('pm_occurrence_complete_button'),
                    onPressed: () => _openCompletionScreen(context),
                    child: const Text('Complete'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openCompletionScreen(BuildContext context) async {
    final pmOccurrences = context.read<PmOccurrenceProvider>();
    final auth = context.read<AuthProvider>();
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MultiProvider(
          providers: [
            ChangeNotifierProvider<PmOccurrenceProvider>.value(
              value: pmOccurrences,
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: PmOccurrenceCompletionScreen(
            occurrence: occurrence,
          ),
        ),
      ),
    );
    if (completed == true && context.mounted) {
      Navigator.pop(context, true);
    }
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

String _formatAssignees(List<String> assigneeIds, List<User> users) {
  if (assigneeIds.isEmpty) {
    return 'Unassigned';
  }

  final labels = assigneeIds.map((id) {
    for (final user in users) {
      if (user.id == id) {
        return user.name;
      }
    }
    return id;
  });

  return labels.join(', ');
}

String _statusLabel(PmWorkItemDisplayStatus status) {
  switch (status) {
    case PmWorkItemDisplayStatus.upcoming:
      return 'Upcoming';
    case PmWorkItemDisplayStatus.overdue:
      return 'Overdue';
    case PmWorkItemDisplayStatus.completed:
      return 'Completed';
    case PmWorkItemDisplayStatus.cancelled:
      return 'Cancelled';
  }
}
