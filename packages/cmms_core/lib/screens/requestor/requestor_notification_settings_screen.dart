import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_theme.dart';
import '../../utils/requestor_home_navigation.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/requestor_more_menu.dart';
import '../../utils/user_facing_errors.dart';

class RequestorNotificationSettingsScreen extends StatefulWidget {
  const RequestorNotificationSettingsScreen({super.key});

  @override
  State<RequestorNotificationSettingsScreen> createState() =>
      _RequestorNotificationSettingsScreenState();
}

class _RequestorNotificationSettingsScreenState
    extends State<RequestorNotificationSettingsScreen> {
  bool _isLoading = true;
  
  // Notification preferences
  bool _notifyOnAssigned = true;
  bool _notifyOnStarted = true;
  bool _notifyOnCompleted = true;
  bool _notifyOnCancelled = true;
  bool _notifyOnUpdated = true;
  bool _notifyOnOverdue = true;
  bool _enablePushNotifications = true;
  bool _enableEmailNotifications = false;
  bool _enableSMSNotifications = false;
  
  // Notification frequency
  String _frequency = 'immediate'; // immediate, daily, weekly

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifyOnAssigned = prefs.getBool('notify_on_assigned') ?? true;
        _notifyOnStarted = prefs.getBool('notify_on_started') ?? true;
        _notifyOnCompleted = prefs.getBool('notify_on_completed') ?? true;
        _notifyOnCancelled = prefs.getBool('notify_on_cancelled') ?? true;
        _notifyOnUpdated = prefs.getBool('notify_on_updated') ?? true;
        _notifyOnOverdue = prefs.getBool('notify_on_overdue') ?? true;
        _enablePushNotifications = prefs.getBool('enable_push_notifications') ?? true;
        _enableEmailNotifications = prefs.getBool('enable_email_notifications') ?? false;
        _enableSMSNotifications = prefs.getBool('enable_sms_notifications') ?? false;
        _frequency = prefs.getString('notification_frequency') ?? 'immediate';
      });
    } catch (e, st) {
      // Use defaults if error loading
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_on_assigned', _notifyOnAssigned);
      await prefs.setBool('notify_on_started', _notifyOnStarted);
      await prefs.setBool('notify_on_completed', _notifyOnCompleted);
      await prefs.setBool('notify_on_cancelled', _notifyOnCancelled);
      await prefs.setBool('notify_on_updated', _notifyOnUpdated);
      await prefs.setBool('notify_on_overdue', _notifyOnOverdue);
      await prefs.setBool('enable_push_notifications', _enablePushNotifications);
      await prefs.setBool('enable_email_notifications', _enableEmailNotifications);
      await prefs.setBool('enable_sms_notifications', _enableSMSNotifications);
      await prefs.setString('notification_frequency', _frequency);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences saved'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not save preferences. Please try again.',
          stackTrace: st,
          contextLabel: 'RequestorNotificationSettings: save',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'Notification Settings',
        usePageTitle: true,
        showMenu: false,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePreferences,
            tooltip: 'Save',
          ),
        ],
        onMoreTap: () {
          showRequestorMoreMenu(
            context,
            primaryLabel: 'Home',
            primaryIcon: Icons.home_outlined,
            onPrimaryNav: () => navigateToRequestorMain(context),
          );
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: padding,
                  child: isDesktop
                      ? _buildDesktopLayout(context)
                      : _buildMobileLayout(context),
                ),
              ),
            ),
    );
  }

  Widget _buildChannelAvailabilityBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              'In-app notifications are available in this version. '
              'Push, email, and SMS delivery will be enabled in a future update.',
              style: AppTheme.bodyText.copyWith(
                fontSize: 13,
                color: AppTheme.darkTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChannelAvailabilityBanner(),
              _buildSection(
                title: 'Notification Channels',
                children: [
                  _buildSwitchTile(
                    title: 'Push Notifications',
                    subtitle: 'Coming soon — not available in this version',
                    value: _enablePushNotifications,
                    onChanged: null,
                  ),
                  _buildSwitchTile(
                    title: 'Email Notifications',
                    subtitle: 'Coming soon — not available in this version',
                    value: _enableEmailNotifications,
                    onChanged: null,
                  ),
                  _buildSwitchTile(
                    title: 'SMS Notifications',
                    subtitle: 'Coming soon — not available in this version',
                    value: _enableSMSNotifications,
                    onChanged: null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spacingL),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                title: 'What to Notify Me About',
                children: [
                  _buildSwitchTile(
                    title: 'When Request is Assigned',
                    subtitle: 'Get notified when a technician is assigned',
                    value: _notifyOnAssigned,
                    onChanged: (value) {
                      setState(() {
                        _notifyOnAssigned = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'When Work Starts',
                    subtitle: 'Get notified when work begins on your request',
                    value: _notifyOnStarted,
                    onChanged: (value) {
                      setState(() {
                        _notifyOnStarted = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'When Request is Completed',
                    subtitle: 'Get notified when your request is completed',
                    value: _notifyOnCompleted,
                    onChanged: (value) {
                      setState(() {
                        _notifyOnCompleted = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'When Request is Cancelled',
                    subtitle: 'Get notified if your request is cancelled',
                    value: _notifyOnCancelled,
                    onChanged: (value) {
                      setState(() {
                        _notifyOnCancelled = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'When Request is Updated',
                    subtitle: 'Get notified of any updates to your request',
                    value: _notifyOnUpdated,
                    onChanged: (value) {
                      setState(() {
                        _notifyOnUpdated = value;
                      });
                    },
                  ),
                  _buildSwitchTile(
                    title: 'When Request is Overdue',
                    subtitle: 'Get notified if your request becomes overdue',
                    value: _notifyOnOverdue,
                    onChanged: (value) {
                      setState(() {
                        _notifyOnOverdue = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingL),
              _buildSection(
                title: 'Notification Frequency',
                children: [
                  _buildFrequencySelector(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                    _buildChannelAvailabilityBanner(),
                    // Notification Channels
                    _buildSection(
                      title: 'Notification Channels',
                      children: [
                        _buildSwitchTile(
                          title: 'Push Notifications',
                          subtitle: 'Coming soon — not available in this version',
                          value: _enablePushNotifications,
                          onChanged: null,
                        ),
                        _buildSwitchTile(
                          title: 'Email Notifications',
                          subtitle: 'Coming soon — not available in this version',
                          value: _enableEmailNotifications,
                          onChanged: null,
                        ),
                        _buildSwitchTile(
                          title: 'SMS Notifications',
                          subtitle: 'Coming soon — not available in this version',
                          value: _enableSMSNotifications,
                          onChanged: null,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Notification Types
                    _buildSection(
                      title: 'What to Notify Me About',
                      children: [
                        _buildSwitchTile(
                          title: 'When Request is Assigned',
                          subtitle: 'Get notified when a technician is assigned',
                          value: _notifyOnAssigned,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnAssigned = value;
                            });
                          },
                        ),
                        _buildSwitchTile(
                          title: 'When Work Starts',
                          subtitle: 'Get notified when work begins on your request',
                          value: _notifyOnStarted,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnStarted = value;
                            });
                          },
                        ),
                        _buildSwitchTile(
                          title: 'When Request is Completed',
                          subtitle: 'Get notified when your request is completed',
                          value: _notifyOnCompleted,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnCompleted = value;
                            });
                          },
                        ),
                        _buildSwitchTile(
                          title: 'When Request is Cancelled',
                          subtitle: 'Get notified if your request is cancelled',
                          value: _notifyOnCancelled,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnCancelled = value;
                            });
                          },
                        ),
                        _buildSwitchTile(
                          title: 'When Request is Updated',
                          subtitle: 'Get notified when request details are updated',
                          value: _notifyOnUpdated,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnUpdated = value;
                            });
                          },
                        ),
                        _buildSwitchTile(
                          title: 'When Request is Overdue',
                          subtitle: 'Get notified if your request becomes overdue',
                          value: _notifyOnOverdue,
                          onChanged: (value) {
                            setState(() {
                              _notifyOnOverdue = value;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Notification Frequency
                    _buildSection(
                      title: 'Notification Frequency',
                      children: [
                        RadioListTile<String>(
                          title: const Text('Immediate'),
                          subtitle: const Text('Receive notifications as they happen'),
                          value: 'immediate',
                          groupValue: _frequency,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _frequency = value;
                              });
                            }
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Daily Digest'),
                          subtitle: const Text('Receive a summary once per day'),
                          value: 'daily',
                          groupValue: _frequency,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _frequency = value;
                              });
                            }
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Weekly Digest'),
                          subtitle: const Text('Receive a summary once per week'),
                          value: 'weekly',
                          groupValue: _frequency,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _frequency = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingXL),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _savePreferences,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Preferences'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingL,
                          vertical: AppTheme.spacingM,
                        ),
                        minimumSize: const Size(0, 50),
                      ),
                    ),
      ],
    );
  }

  Widget _buildFrequencySelector() {
    return Column(
      children: [
        RadioListTile<String>(
          title: const Text('Immediate'),
          subtitle: const Text('Receive notifications as they happen'),
          value: 'immediate',
          groupValue: _frequency,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _frequency = value;
              });
            }
          },
        ),
        RadioListTile<String>(
          title: const Text('Daily Digest'),
          subtitle: const Text('Receive a summary once per day'),
          value: 'daily',
          groupValue: _frequency,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _frequency = value;
              });
            }
          },
        ),
        RadioListTile<String>(
          title: const Text('Weekly Digest'),
          subtitle: const Text('Receive a summary once per week'),
          value: 'weekly',
          groupValue: _frequency,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _frequency = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              ...children,
            ],
          ),
        ),
      );

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) =>
      SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}


