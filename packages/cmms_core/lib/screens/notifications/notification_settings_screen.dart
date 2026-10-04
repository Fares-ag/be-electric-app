import 'package:flutter/material.dart';

import '../../config/service_locator.dart';
import '../../models/analytics_models.dart';
import '../../services/analytics/analytics_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<NotificationType, bool> _notificationSettings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final analyticsService = getIt<AnalyticsService>();
      final settings = await analyticsService.getNotificationSettings();
      setState(() {
        _notificationSettings = settings;
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
          genericMessage: 'Could not load notification settings. Please try again.',
          stackTrace: st,
          contextLabel: 'NotificationSettings: load',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _updateNotificationSetting(
    NotificationType type,
    bool enabled,
  ) async {
    try {
      final analyticsService = getIt<AnalyticsService>();
      await analyticsService.updateNotificationSetting(type, enabled);
      setState(() {
        _notificationSettings[type] = enabled;
      });
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update notification setting. Please try again.',
          stackTrace: st,
          contextLabel: 'NotificationSettings: update',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Notification Settings',
            style: TextStyle(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textColor),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // General Settings
                    _buildSectionHeader('General Settings'),
                    const SizedBox(height: 16),

                    _buildSettingCard(
                      'Enable Notifications',
                      'Receive in-app notifications for important events',
                      Icons.notifications,
                      true, // This would be a general setting
                      (value) {
                        // Handle general notification toggle
                      },
                    ),

                    const SizedBox(height: 24),

                    // Work Order Notifications
                    _buildSectionHeader('Work Order Notifications'),
                    const SizedBox(height: 16),

                    _buildNotificationTypeCard(
                      NotificationType.workOrderAssigned,
                      'New Work Order Assignment',
                      'Get notified when a new work order is assigned to you',
                      Icons.assignment,
                    ),

                    _buildNotificationTypeCard(
                      NotificationType.workOrderCompleted,
                      'Work Order Completed',
                      'Get notified when a work order you created is completed',
                      Icons.check_circle,
                    ),

                    _buildNotificationTypeCard(
                      NotificationType.workOrderOverdue,
                      'Work Order Overdue',
                      'Get notified when a work order becomes overdue',
                      Icons.warning,
                    ),

                    const SizedBox(height: 24),

                    // PM Task Notifications
                    _buildSectionHeader('Preventive Maintenance Notifications'),
                    const SizedBox(height: 16),

                    _buildNotificationTypeCard(
                      NotificationType.pmTaskDue,
                      'PM Task Due',
                      'Get notified when a preventive maintenance task is due',
                      Icons.schedule,
                    ),

                    _buildNotificationTypeCard(
                      NotificationType.pmTaskOverdue,
                      'PM Task Overdue',
                      'Get notified when a preventive maintenance task becomes overdue',
                      Icons.warning,
                    ),

                    const SizedBox(height: 24),

                    // Asset Notifications
                    _buildSectionHeader('Asset Notifications'),
                    const SizedBox(height: 16),

                    _buildNotificationTypeCard(
                      NotificationType.assetFailure,
                      'Asset Failure',
                      'Get notified when an asset fails or requires immediate attention',
                      Icons.error,
                    ),

                    _buildNotificationTypeCard(
                      NotificationType.criticalAlert,
                      'Critical Alerts',
                      'Get notified about critical system alerts and emergencies',
                      Icons.priority_high,
                    ),

                    const SizedBox(height: 24),

                    // System Notifications
                    _buildSectionHeader('System Notifications'),
                    const SizedBox(height: 16),

                    _buildNotificationTypeCard(
                      NotificationType.systemUpdate,
                      'System Updates',
                      'Get notified about system updates and maintenance',
                      Icons.system_update,
                    ),

                    _buildNotificationTypeCard(
                      NotificationType.maintenanceReminder,
                      'Maintenance Reminders',
                      'Get notified about upcoming maintenance schedules',
                      Icons.remember_me,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      );

  Widget _buildSectionHeader(String title) => Text(
        title,
        style: const TextStyle(
          color: AppTheme.textColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _buildSettingCard(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Card(
        color: AppTheme.cardColor,
        elevation: 2,
        child: SwitchListTile(
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.textColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          secondary: Icon(
            icon,
            color: AppTheme.primaryColor,
          ),
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.primaryColor,
        ),
      );

  Widget _buildNotificationTypeCard(
    NotificationType type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isEnabled = _notificationSettings[type] ?? true;

    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.textColor.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        secondary: Icon(
          icon,
          color: AppTheme.primaryColor,
        ),
        value: isEnabled,
        onChanged: (value) => _updateNotificationSetting(type, value),
        activeThumbColor: AppTheme.primaryColor,
      ),
    );
  }
}
