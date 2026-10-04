import 'package:flutter/material.dart';

import '../config/locator.dart';
import '../services/notification_service.dart' as notification_service;
import '../utils/app_theme.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    required this.child,
    super.key,
    this.userId,
  });
  final String? userId;
  final Widget child;

  notification_service.NotificationService get _notificationService =>
      sl<notification_service.NotificationService>();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<notification_service.Notification>>(
        stream: _notificationService.notificationsStream,
        initialData: _notificationService.notifications,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return child;
          }

          final notifications = snapshot.data!;
          final unreadCount = userId != null
              ? notifications
                  .where((n) => n.userId == userId && !n.isRead)
                  .length
              : notifications.where((n) => !n.isRead).length;

          if (unreadCount == 0) {
            return child;
          }

          return Stack(
            children: [
              child,
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.accentRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      );
}
