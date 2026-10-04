// Notification Widget - Displays notifications and alerts

import 'package:flutter/material.dart';

import '../config/locator.dart';
import '../services/notification_service.dart' as notification_service;
import '../utils/app_theme.dart';
import 'notification_list_screen.dart';

export 'notification_badge.dart';
export 'notification_list_screen.dart';

class NotificationWidget extends StatefulWidget {
  const NotificationWidget({
    super.key,
    this.userId,
    this.showUnreadOnly = false,
    this.onNotificationTap,
  });
  final String? userId;
  final bool showUnreadOnly;
  final VoidCallback? onNotificationTap;

  @override
  State<NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<NotificationWidget> {
  final notification_service.NotificationService _notificationService =
      sl<notification_service.NotificationService>();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<notification_service.Notification>>(
        stream: _notificationService.notificationsStream,
        initialData: _notificationService.notifications,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          var notifications = snapshot.data!;

          if (widget.userId != null) {
            notifications =
                notifications.where((n) => n.userId == widget.userId).toList();
          }

          if (widget.showUnreadOnly) {
            notifications = notifications.where((n) => !n.isRead).toList();
          }

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              if (widget.showUnreadOnly && notifications.length > 3)
                _buildShowAllButton(),
              ...notifications
                  .take(widget.showUnreadOnly ? 3 : notifications.length)
                  .map(_buildNotificationItem),
            ],
          );
        },
      );

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(
              Icons.notifications_none,
              size: 48,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              widget.showUnreadOnly
                  ? 'No unread notifications'
                  : 'No notifications',
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      );

  Widget _buildShowAllButton() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: TextButton(
          onPressed: () {
            // Navigate to full notifications screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationListScreen(),
              ),
            );
          },
          child: const Text('Show All Notifications'),
        ),
      );

  Widget _buildNotificationItem(
    notification_service.Notification notification,
  ) =>
      Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        elevation: notification.isRead ? 1 : 3,
        child: InkWell(
          onTap: () {
            _notificationService.markAsRead(notification.id);
            widget.onNotificationTap?.call();
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: notification.isRead
                  ? null
                  : Border.all(
                      color: _getPriorityColor(notification.priority)
                          .withValues(alpha: 0.3),
                      width: 2,
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority indicator
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(notification.priority),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),

                // Notification icon
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color:
                        _getTypeColor(notification.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(
                    _getTypeIcon(notification.type),
                    color: _getTypeColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),

                // Notification content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: AppTheme.heading2.copyWith(
                                color: AppTheme.darkTextColor,
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        notification.message,
                        style: AppTheme.bodyText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        _formatTime(notification.createdAt),
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action button
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _notificationService.deleteNotification(notification.id);
                  },
                  iconSize: 16,
                  color: AppTheme.secondaryTextColor,
                ),
              ],
            ),
          ),
        ),
      );

  Color _getPriorityColor(notification_service.NotificationPriority priority) {
    switch (priority) {
      case notification_service.NotificationPriority.low:
        return Colors.green;
      case notification_service.NotificationPriority.medium:
        return Colors.orange;
      case notification_service.NotificationPriority.high:
        return Colors.red;
      case notification_service.NotificationPriority.critical:
        return Colors.purple;
    }
  }

  Color _getTypeColor(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.workOrderCreated:
        return Colors.blue;
      case notification_service.NotificationType.workOrderAssigned:
        return Colors.orange;
      case notification_service.NotificationType.workOrderStarted:
        return Colors.purple;
      case notification_service.NotificationType.workOrderCompleted:
        return Colors.green;
      case notification_service.NotificationType.pmTaskAssigned:
        return Colors.teal;
      case notification_service.NotificationType.pmTaskDue:
        return Colors.amber;
      case notification_service.NotificationType.pmTaskOverdue:
        return Colors.red;
      case notification_service.NotificationType.systemAlert:
        return Colors.grey;
      case notification_service.NotificationType.escalation:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.workOrderCreated:
        return Icons.add_task;
      case notification_service.NotificationType.workOrderAssigned:
        return Icons.assignment;
      case notification_service.NotificationType.workOrderStarted:
        return Icons.play_arrow;
      case notification_service.NotificationType.workOrderCompleted:
        return Icons.check_circle;
      case notification_service.NotificationType.pmTaskAssigned:
        return Icons.schedule;
      case notification_service.NotificationType.pmTaskDue:
        return Icons.schedule;
      case notification_service.NotificationType.pmTaskOverdue:
        return Icons.warning;
      case notification_service.NotificationType.systemAlert:
        return Icons.info;
      case notification_service.NotificationType.escalation:
        return Icons.priority_high;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
