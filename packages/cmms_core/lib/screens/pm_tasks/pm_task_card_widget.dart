import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/pm_task.dart';
import '../../utils/app_theme.dart';
import '../../widgets/offline_sync_indicators.dart';
import 'pm_task_detail_screen.dart';

/// Professional PM Task Card Widget
class PMTaskCardWidget extends StatelessWidget {
  const PMTaskCardWidget({required this.task, super.key});

  final PMTask task;

  @override
  Widget build(BuildContext context) {
    final frequencyColor = _getFrequencyColor(task.frequency);
    final statusColor = AppTheme.pmTaskStatusColorFromEnum(task.status);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isOverdue
              ? Colors.red.shade300
              : frequencyColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PMTaskDetailScreen(pmTask: task),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with colored background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: task.isOverdue
                    ? Colors.red.shade50
                    : frequencyColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  // Frequency icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: frequencyColor.withOpacity(0.3)),
                    ),
                    child: Icon(
                      _getFrequencyIcon(task.frequency),
                      color: frequencyColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Task name and frequency
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.taskName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkTextColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: frequencyColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 12,
                                color: frequencyColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.frequencyDisplayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: frequencyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status badge (full text shown)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(task.status),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.statusDisplayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  PMTaskPendingSyncBadge(pmTask: task),
                ],
              ),
            ),

            // Body content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Asset information
                  if (task.assetName != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.precision_manufacturing,
                            size: 18,
                            color: AppTheme.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.assetName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkTextColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (task.assetLocation != null &&
                                  task.assetLocation!.isNotEmpty)
                                Text(
                                  task.assetLocation!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Description
                  if (task.description.isNotEmpty) ...[
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Footer with due date and technician
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: task.isOverdue
                          ? Colors.red.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        // Due date
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                task.isOverdue
                                    ? Icons.warning_rounded
                                    : task.isDueToday
                                        ? Icons.today
                                        : Icons.event,
                                size: 18,
                                color: task.isOverdue
                                    ? Colors.red
                                    : task.isDueToday
                                        ? Colors.orange
                                        : AppTheme.accentBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.isOverdue
                                          ? 'Overdue'
                                          : task.isDueToday
                                              ? 'Due Today'
                                              : 'Next Due',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(
                                          task.nextDue ?? DateTime.now(),),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: task.isOverdue
                                            ? Colors.red
                                            : AppTheme.darkTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Technician or unassigned indicator
                        if (task.assignedTechnician != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppTheme.accentGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.assignedTechnician!.name
                                      .split(' ')
                                      .first,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Unassigned',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MMM dd, yyyy').format(date);

  Color _getFrequencyColor(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return AppTheme.purple;
      case PMTaskFrequency.weekly:
        return AppTheme.accentBlue;
      case PMTaskFrequency.monthly:
        return AppTheme.accentGreen; // Be Electric brand green
      case PMTaskFrequency.quarterly:
        return AppTheme.accentOrange;
      case PMTaskFrequency.semiAnnually:
        return AppTheme.purple;
      case PMTaskFrequency.annually:
        return AppTheme.accentOrange;
      case PMTaskFrequency.asNeeded:
        return AppTheme.secondaryTextColor;
    }
  }

  IconData _getFrequencyIcon(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return Icons.today;
      case PMTaskFrequency.weekly:
        return Icons.view_week;
      case PMTaskFrequency.monthly:
        return Icons.calendar_month;
      case PMTaskFrequency.quarterly:
        return Icons.calendar_view_month;
      case PMTaskFrequency.semiAnnually:
        return Icons.calendar_today;
      case PMTaskFrequency.annually:
        return Icons.event_repeat;
      case PMTaskFrequency.asNeeded:
        return Icons.schedule;
    }
  }

  IconData _getStatusIcon(PMTaskStatus status) {
    switch (status) {
      case PMTaskStatus.pending:
        return Icons.pending;
      case PMTaskStatus.inProgress:
        return Icons.sync;
      case PMTaskStatus.completed:
        return Icons.check_circle;
      case PMTaskStatus.overdue:
        return Icons.warning;
      case PMTaskStatus.cancelled:
        return Icons.cancel;
    }
  }
}
