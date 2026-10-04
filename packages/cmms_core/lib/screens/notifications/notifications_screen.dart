import 'package:flutter/material.dart';

import '../../config/service_locator.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics/analytics_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationData> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analyticsService = getIt<AnalyticsService>();
      final notifications = await analyticsService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e, st) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load notifications. Please try again.',
          stackTrace: st,
          contextLabel: 'Notifications: load',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _markAsRead(NotificationData notification) async {
    if (!notification.isRead) {
      final analyticsService = getIt<AnalyticsService>();
      await analyticsService.markNotificationAsRead(notification.id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
      });
    }
  }

  Future<void> _clearAllNotifications() async {
    final analyticsService = getIt<AnalyticsService>();
    await analyticsService.clearAllNotifications();
    setState(() {
      _notifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Notifications',
            style: TextStyle(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textColor),
          actions: [
            if (_notifications.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_all, color: AppTheme.textColor),
                onPressed: _clearAllNotifications,
                tooltip: 'Clear all notifications',
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.textColor),
              onPressed: _loadNotifications,
              tooltip: 'Refresh notifications',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              )
            : _notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: AppTheme.textColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            color: AppTheme.textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "You're all caught up!",
                          style: TextStyle(
                            color: AppTheme.textColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: AppTheme.primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    ),
                  ),
      );

  Widget _buildNotificationCard(NotificationData notification) => Card(
        color: notification.isRead
            ? AppTheme.cardColor
            : AppTheme.primaryColor.withOpacity(0.1),
        elevation: notification.isRead ? 1 : 3,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _markAsRead(notification),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(notification.type.icon.codePoint),
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: notification.type.icon.fontFamily,
                        package: notification.type.icon.fontPackage,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Notification Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Priority
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: AppTheme.textColor,
                                fontSize: 16,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Body
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontSize: 14,
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Time and Priority
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.textColor.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(notification.createdAt),
                            style: TextStyle(
                              color: AppTheme.textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(notification.priority),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notification.priority.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Button
                if (!notification.isRead)
                  IconButton(
                    icon: const Icon(Icons.check, color: AppTheme.primaryColor),
                    onPressed: () => _markAsRead(notification),
                    tooltip: 'Mark as read',
                  ),
              ],
            ),
          ),
        ),
      );

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.workOrderAssigned:
        return Colors.blue;
      case NotificationType.workOrderCompleted:
        return Colors.green;
      case NotificationType.workOrderOverdue:
        return Colors.red;
      case NotificationType.pmTaskDue:
        return Colors.orange;
      case NotificationType.pmTaskOverdue:
        return Colors.red;
      case NotificationType.assetFailure:
        return Colors.red;
      case NotificationType.criticalAlert:
        return Colors.red;
      case NotificationType.systemUpdate:
        return Colors.purple;
      case NotificationType.maintenanceReminder:
        return Colors.blue;
    }
  }

  Color _getPriorityColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.green;
      case NotificationPriority.medium:
        return Colors.orange;
      case NotificationPriority.high:
        return Colors.red;
      case NotificationPriority.critical:
        return Colors.red;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
