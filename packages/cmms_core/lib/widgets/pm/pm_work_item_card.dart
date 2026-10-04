import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/pm_work_item.dart';
import '../../utils/app_theme.dart';
import 'requestor_pm_confirm_action.dart';

/// Unified PM inbox row for legacy tasks and scheduled occurrences.
class PmWorkItemCard extends StatelessWidget {
  const PmWorkItemCard({
    required this.item,
    super.key,
    this.onTap,
    this.showRequestorConfirm = false,
  });

  final PmWorkItem item;
  final VoidCallback? onTap;
  final bool showRequestorConfirm;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.displayStatus);
    final isOverdue = item.displayStatus == PmWorkItemDisplayStatus.overdue;
    final occurrence = item.occurrence;
    final confirmAction = showRequestorConfirm &&
            occurrence != null &&
            item.isOccurrence
        ? RequestorPmConfirmAction(
            occurrence: occurrence,
            compact: true,
          )
        : null;

    return Container(
      key: Key('pm-work-item-${item.source.name}-${item.id}'),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.red.shade300 : statusColor.withValues(alpha: 0.35),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(
                        label: _statusLabel(item.displayStatus),
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Due ${DateFormat.yMMMd().format(item.dueDate.toLocal())}',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.isLegacy ? 'Legacy PM' : 'Scheduled PM',
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (confirmAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: confirmAction,
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
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

Color _statusColor(PmWorkItemDisplayStatus status) {
  switch (status) {
    case PmWorkItemDisplayStatus.upcoming:
      return AppTheme.accentBlue;
    case PmWorkItemDisplayStatus.overdue:
      return AppTheme.accentRed;
    case PmWorkItemDisplayStatus.completed:
      return AppTheme.accentGreen;
    case PmWorkItemDisplayStatus.cancelled:
      return AppTheme.secondaryTextColor;
  }
}
