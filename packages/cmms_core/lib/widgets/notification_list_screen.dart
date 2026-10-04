import 'package:flutter/material.dart';

import '../app/cmms_app_mode_scope.dart';
import '../config/cmms_app_mode.dart';
import '../config/locator.dart';
import '../services/notification_service.dart' as notification_service;
import '../utils/app_theme.dart';
import '../utils/requestor_home_navigation.dart';
import 'custom_app_bar.dart';
import 'requestor_more_menu.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final notification_service.NotificationService _notificationService =
      sl<notification_service.NotificationService>();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: CustomAppBar(
          title: 'Notifications',
          usePageTitle: true,
          showMenu: false,
          showBackButton: true,
          actions: [
            StreamBuilder<List<notification_service.Notification>>(
              stream: _notificationService.notificationsStream,
              initialData: _notificationService.notifications,
              builder: (context, snapshot) {
                final unreadCount = _notificationService.unreadCount;
                if (unreadCount == 0) return const SizedBox.shrink();

                return TextButton(
                  onPressed: _notificationService.markAllAsRead,
                  child: Text('Mark All Read ($unreadCount)'),
                );
              },
            ),
          ],
          onMoreTap: CmmsAppModeScope.maybeOf(context) == CmmsAppMode.requestor
              ? () {
                  showRequestorMoreMenu(
                    context,
                    primaryLabel: 'Home',
                    primaryIcon: Icons.home_outlined,
                    onPrimaryNav: () => navigateToRequestorMain(context),
                  );
                }
              : null,
        ),
        body: StreamBuilder<List<notification_service.Notification>>(
          stream: _notificationService.notificationsStream,
          initialData: _notificationService.notifications,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accentBlue,
                ),
              );
            }

            final notifications = snapshot.data!;

            if (notifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: AppTheme.secondaryTextColor,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'Updates about your maintenance requests will appear here '
                        'when your request status changes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: ListTile(
                    title: Text(
                      n.title,
                      style: AppTheme.bodyText
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(n.message),
                        const SizedBox(height: 4),
                        Text(
                          n.createdAt.toLocal().toString(),
                          style: AppTheme.smallText
                              .copyWith(color: AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                    trailing: n.isRead
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.mark_email_read),
                            tooltip: 'Mark as read',
                            onPressed: () =>
                                _notificationService.markAsRead(n.id),
                          ),
                    onTap: () => _notificationService.markAsRead(n.id),
                  ),
                );
              },
            );
          },
        ),
      );
}
