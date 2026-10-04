import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/profile/user_profile_screen.dart';
import '../screens/requestor/pm/requestor_pm_dashboard_screen.dart';
import '../screens/requestor/requestor_analytics_screen.dart';
import '../screens/requestor/support/requestor_support_screen.dart';
import '../utils/app_theme.dart';
import 'notification_badge.dart';
import 'notification_list_screen.dart' deferred as notif_list;

/// Shared “more” menu for requestor flows: same options as the home screen overflow.
///
/// [onPrimaryNav] is the first row: e.g. open “View My Requests” (from home) or “Home” (from a subpage).
void showRequestorMoreMenu(
  BuildContext context, {
  required String primaryLabel,
  required IconData primaryIcon,
  required VoidCallback onPrimaryNav,
}) {
  final userId = Provider.of<AuthProvider>(context, listen: false)
      .currentUser
      ?.id;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(primaryIcon),
              title: Text(primaryLabel),
              onTap: () {
                Navigator.pop(sheetContext);
                onPrimaryNav();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
            ),
            if (userId != null)
              NotificationBadge(
                userId: userId,
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await notif_list.loadLibrary();
                    if (!context.mounted) return;
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            notif_list.NotificationListScreen(),
                      ),
                    );
                  },
                ),
              ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestorAnalyticsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Be Electric Support'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestorSupportScreen(),
                  ),
                );
              },
            ),
            if (AppConfig.enablePmOccurrences)
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('Preventive Maintenance'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestorPmDashboardScreen(),
                    ),
                  );
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.accentRed),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _confirmLogoutAndClearStack(context);
              },
            ),
            SizedBox(height: MediaQuery.of(sheetContext).viewPadding.bottom),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmLogoutAndClearStack(BuildContext context) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
          child: const Text('Logout'),
        ),
      ],
    ),
  );

  if (shouldLogout == true && context.mounted) {
    await authProvider.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
