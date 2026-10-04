import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/orphan_cleanup_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/cmms_package_assets.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/complete_database_wipe.dart';
import '../../utils/comprehensive_duplicate_cleanup.dart';
import '../../utils/database_reset_utility.dart';
import '../../utils/fix_unknown_admin.dart';
import '../../utils/kill_duplicates_now.dart';
import '../../utils/remove_all_sample_data.dart';
import '../../utils/user_id_diagnostic.dart';
import '../../widgets/notification_widget.dart';
import '../analytics/consolidated_analytics_dashboard.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_list_screen.dart';
import '../inventory/low_stock_alerts_screen.dart';
import '../inventory/parts_request_queue_screen.dart';
import '../inventory/purchase_order_screen.dart';
import '../pm_tasks/pm_task_list_screen.dart';
import '../profile/user_profile_screen.dart';
import '../settings/settings_screen.dart';
import '../work_orders/work_order_list_screen.dart';
import 'assignment_diagnostic_screen.dart';
import 'cleanup_users_screen.dart';
import 'company_management_screen.dart';
import 'duplicate_monitor_screen.dart';
import 'performance_diagnostic_screen.dart';
import 'reporting_screen.dart';
import 'seed_general_assets_screen.dart';
import 'technician_viewer_screen.dart';
import 'user_management_screen.dart';
import '../../config/locator.dart';
import '../../config/release_safety.dart';
import '../../utils/user_facing_errors.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    // Responsive breakpoints using ResponsiveLayout utilities
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);

    // Use side navigation for desktop/tablet
    final useSideNav = isDesktop || isTablet;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: useSideNav
          ? _buildDesktopAppBar(context, user)
          : AppBar(
              title: Text(
                user?.role == 'manager'
                    ? 'Manager Dashboard'
                    : 'Admin Dashboard',
              ),
              backgroundColor: AppTheme.surfaceColor,
              foregroundColor: AppTheme.darkTextColor,
              elevation: AppTheme.elevationS,
              actions: [
                NotificationBadge(
                  userId: user?.id,
                  child: IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationListScreen(),
                        ),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                ),
                // Sync status widget removed - using Supabase now
                const SizedBox(width: 8),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (ReleaseSafety.isDevToolMenuAction(value) &&
                        !ReleaseSafety.showDevTools) {
                      return;
                    }
                    if (ReleaseSafety.isDestructiveMenuAction(value) &&
                        !ReleaseSafety.allowDestructiveAdminTools) {
                      return;
                    }
                    if (value == 'logout') {
                      Provider.of<AuthProvider>(context, listen: false)
                          .logout();
                    } else if (value == 'profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfileScreen(),
                        ),
                      );
                    } else if (value == 'reporting') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportingScreen(),
                        ),
                      );
                    } else if (value == 'purchase_orders') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PurchaseOrderScreen(),
                        ),
                      );
                    } else if (value == 'parts_requests') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PartsRequestQueueScreen(),
                        ),
                      );
                    } else if (value == 'low_stock') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LowStockAlertsScreen(),
                        ),
                      );
                    } else if (value == 'seed_assets') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SeedGeneralAssetsScreen(),
                        ),
                      );
                    } else if (value == 'clear_database') {
                      CompleteDatabaseWipe.showWipeConfirmationDialog(context);
                    } else if (value == 'nuclear_option') {
                      KillDuplicatesNow.showNuclearOptionDialog(context);
                    } else if (value == 'fix_admin') {
                      FixUnknownAdmin.showFixDialog(context);
                    } else if (value == 'cleanup_users') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CleanupUsersScreen(),
                        ),
                      );
                    } else if (value == 'assignment_diagnostic') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AssignmentDiagnosticScreen(),
                        ),
                      );
                    } else if (value == 'user_id_diagnostic') {
                      final unifiedProvider = Provider.of<UnifiedDataProvider>(
                        context,
                        listen: false,
                      );
                      UserIdDiagnostic.showDiagnosticDialog(
                        context,
                        unifiedProvider,
                      );
                    } else if (value == 'remove_sample_data') {
                      RemoveAllSampleData.showRemovalConfirmationDialog(
                        context,
                      );
                    } else if (value == 'performance_diagnostic') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PerformanceDiagnosticScreen(),
                        ),
                      );
                    } else if (value == 'cleanup_duplicates') {
                      _showDuplicateCleanupDialog(context);
                    } else if (value == 'orphan_cleanup_dry') {
                      _showOrphanCleanupDialog(delete: false);
                    } else if (value == 'orphan_cleanup_delete') {
                      _showOrphanCleanupDialog(delete: true);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reporting',
                      child: Row(
                        children: [
                          Icon(Icons.assessment, color: AppTheme.accentBlue),
                          SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Reports',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'purchase_orders',
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(width: AppTheme.spacingS),
                          Text('Purchase Orders'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'parts_requests',
                      child: Row(
                        children: [
                          Icon(Icons.inventory, color: AppTheme.accentBlue),
                          SizedBox(width: AppTheme.spacingS),
                          Text('Parts Requests'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'low_stock',
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: AppTheme.spacingS),
                          Text('Low Stock Alerts'),
                        ],
                      ),
                    ),
                    if (ReleaseSafety.showDevTools) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'seed_assets',
                        child: Row(
                          children: [
                            Icon(Icons.construction, color: AppTheme.accentGreen),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Setup General Assets'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'cleanup_users',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cleaning_services,
                              color: AppTheme.accentOrange,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Cleanup Unknown Users'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'data_diagnostic',
                        child: Row(
                          children: [
                            Icon(
                              Icons.troubleshoot,
                              color: AppTheme.accentBlue,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Data Sync Diagnostic'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'assignment_diagnostic',
                        child: Row(
                          children: [
                            Icon(
                              Icons.assignment_ind,
                              color: AppTheme.accentOrange,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Assignment Diagnostic'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'user_id_diagnostic',
                        child: Row(
                          children: [
                            Icon(
                              Icons.fingerprint,
                              color: Colors.purple,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('User ID Diagnostic'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'performance_diagnostic',
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed,
                              color: Colors.deepPurple,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Performance Diagnostic'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'orphan_cleanup_dry',
                        child: Row(
                          children: [
                            Icon(
                              Icons.fact_check,
                              color: AppTheme.accentGreen,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Orphan Cleanup (Dry Run)'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'fix_admin',
                        child: Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              color: AppTheme.accentBlue,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Fix "Unknown User" Admin'),
                          ],
                        ),
                      ),
                    ],
                    if (ReleaseSafety.allowDestructiveAdminTools) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'remove_sample_data',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cleaning_services,
                              color: Colors.orange,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Remove All Sample Data'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'cleanup_duplicates',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cleaning_services,
                              color: AppTheme.accentOrange,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text('Remove Duplicates'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'orphan_cleanup_delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cleaning_services_outlined,
                              color: AppTheme.accentRed,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Orphan Cleanup (Delete)',
                              style: TextStyle(color: AppTheme.accentRed),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear_database',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, color: Colors.red),
                            SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Clear Database',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'nuclear_option',
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.deepOrange,
                            ),
                            SizedBox(width: AppTheme.spacingS),
                            Text(
                              '☢️ Nuclear Option',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: AppTheme.accentGreen),
                          SizedBox(width: AppTheme.spacingS),
                          Text('Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: AppTheme.accentRed),
                          SizedBox(width: AppTheme.spacingS),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: useSideNav
          ? Row(
              children: [
                // Side Navigation Rail for Desktop/Tablet
                _buildNavigationRail(isDesktop),
                // Vertical Divider
                const VerticalDivider(width: 1, thickness: 1),
                // Main Content Area
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: const [
                          DashboardScreen(showNavigation: false),
                          WorkOrderListScreen(),
                          PMTaskListScreen(),
                          InventoryListScreen(),
                          ConsolidatedAnalyticsDashboard(),
                          TechnicianViewerScreen(),
                          UserManagementScreen(),
                          CompanyManagementScreen(),
                          SettingsScreen(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : IndexedStack(
              index: _currentIndex,
              children: const [
                DashboardScreen(showNavigation: false),
                WorkOrderListScreen(),
                PMTaskListScreen(),
                InventoryListScreen(),
                ConsolidatedAnalyticsDashboard(),
                TechnicianViewerScreen(),
                UserManagementScreen(),
                CompanyManagementScreen(),
                SettingsScreen(),
              ],
            ),
      bottomNavigationBar: useSideNav
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: AppTheme.surfaceColor,
              selectedItemColor: AppTheme.accentBlue,
              unselectedItemColor: AppTheme.secondaryTextColor,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.work),
                  label: 'Work Orders',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'PM Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory_2),
                  label: 'Inventory',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics),
                  label: 'Analytics',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt),
                  label: 'Technicians',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Users',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.business),
                  label: 'Companies',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }

  // Desktop AppBar with extended functionality
  PreferredSizeWidget _buildDesktopAppBar(BuildContext context, user) => AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.admin_panel_settings,
              color: AppTheme.accentGreen, // Be Electric brand green
              size: 28,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Text(
              user?.role == 'manager' ? 'Manager Dashboard' : 'Admin Dashboard',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withValues(alpha: 0.1), // Be Electric brand green
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(color: AppTheme.accentGreen), // Be Electric brand green
              ),
              child: Text(
                user?.name ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accentGreen, // Be Electric brand green
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        elevation: 2,
        actions: [
          // Quick Actions for Desktop
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportingScreen(),
                ),
              );
            },
            icon: const Icon(Icons.assessment, size: 20),
            label: const Text('Reports'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.darkTextColor,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PurchaseOrderScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long, size: 20),
            label: const Text('Purchase Orders'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.darkTextColor,
            ),
          ),
          const SizedBox(width: 8),
          NotificationBadge(
            userId: user?.id,
            child: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationListScreen(),
                  ),
                );
              },
              tooltip: 'Notifications',
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (ReleaseSafety.isDevToolMenuAction(value) &&
                  !ReleaseSafety.showDevTools) {
                return;
              }
              if (ReleaseSafety.isDestructiveMenuAction(value) &&
                  !ReleaseSafety.allowDestructiveAdminTools) {
                return;
              }
              if (value == 'logout') {
                Provider.of<AuthProvider>(context, listen: false).logout();
              } else if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              } else if (value == 'parts_requests') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PartsRequestQueueScreen(),
                  ),
                );
              } else if (value == 'low_stock') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LowStockAlertsScreen(),
                  ),
                );
              } else if (value == 'duplicate_monitor') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DuplicateMonitorScreen(),
                  ),
                );
              } else if (value == 'seed_assets') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SeedGeneralAssetsScreen(),
                  ),
                );
              } else if (value == 'clear_database') {
                DatabaseResetUtility.showResetConfirmationDialog(context);
              } else if (value == 'remove_sample_data') {
                RemoveAllSampleData.showRemovalConfirmationDialog(context);
              }
            },
            icon: const Icon(Icons.more_vert),
            tooltip: 'More Options',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: AppTheme.accentGreen),
                    SizedBox(width: AppTheme.spacingS),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'parts_requests',
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: AppTheme.accentBlue),
                    SizedBox(width: AppTheme.spacingS),
                    Text('Parts Requests'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'low_stock',
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: AppTheme.spacingS),
                    Text('Low Stock Alerts'),
                  ],
                ),
              ),
              if (ReleaseSafety.showDevTools) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'duplicate_monitor',
                  child: Row(
                    children: [
                      Icon(Icons.copy_all, color: Color(0xFF7B1FA2)),
                      SizedBox(width: AppTheme.spacingS),
                      Text('Duplicate Monitor'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'seed_assets',
                  child: Row(
                    children: [
                      Icon(Icons.construction, color: AppTheme.accentGreen),
                      SizedBox(width: AppTheme.spacingS),
                      Text('Setup General Assets'),
                    ],
                  ),
                ),
              ],
              if (ReleaseSafety.allowDestructiveAdminTools) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'clear_database',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: AppTheme.spacingS),
                      Text('Clear Database', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove_sample_data',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.orange),
                      SizedBox(width: AppTheme.spacingS),
                      Text('Remove Sample Data'),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppTheme.accentRed),
                    SizedBox(width: AppTheme.spacingS),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      );

  // Navigation Rail for Desktop/Tablet
  Widget _buildNavigationRail(bool isDesktop) {
    final destinations = [
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.work_outline),
        selectedIcon: Icon(Icons.work),
        label: Text('Work Orders'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.schedule_outlined),
        selectedIcon: Icon(Icons.schedule),
        label: Text('PM Tasks'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: Text('Inventory'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics),
        label: Text('Analytics'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt),
        label: Text('Technicians'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.people_outlined),
        selectedIcon: Icon(Icons.people),
        label: Text('Users'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.business_outlined),
        selectedIcon: Icon(Icons.business),
        label: Text('Companies'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
    ];

    return NavigationRail(
      selectedIndex: _currentIndex,
      onDestinationSelected: (int index) {
        setState(() {
          _currentIndex = index;
        });
      },
      extended: isDesktop,
      labelType: isDesktop
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      backgroundColor: AppTheme.surfaceColor,
      selectedIconTheme: const IconThemeData(
        color: AppTheme.accentGreen, // Be Electric brand green
        size: 28,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppTheme.accentGreen, // Be Electric brand green
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppTheme.secondaryTextColor,
        size: 24,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppTheme.secondaryTextColor,
        fontSize: 12,
      ),
      destinations: destinations,
      leading: isDesktop
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingL),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/beElectricLogo.png',
                    package: kCmmsCoreAssetPackage,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accentGreen, width: 2),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: AppTheme.accentGreen,
                          size: 28,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  const Text(
                    'Be Electric',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGreen, // Be Electric brand green
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  /// Show duplicate cleanup confirmation dialog
  static Future<void> _showDuplicateCleanupDialog(BuildContext context) async {
    if (!ReleaseSafety.allowDestructiveAdminTools) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: AppTheme.accentOrange),
            SizedBox(width: 8),
            Text('Remove All Duplicates?'),
          ],
        ),
        content: const Text(
          'This will scan Firestore and remove ALL duplicate entries for:\n\n'
          '• Users (by email & ID)\n'
          '• Work Orders (by ID)\n'
          '• PM Tasks (by ID)\n'
          '• Assets (by ID)\n'
          '• Inventory Items (by ID)\n\n'
          'For each duplicate, the NEWEST entry will be kept.\n\n'
          'This may take a few minutes and cannot be undone!',
          style: AppTheme.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Remove Duplicates'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Cleaning up duplicates...\nThis may take a few minutes.',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Run cleanup
      final cleanup = ComprehensiveDuplicateCleanup();
      final results = await cleanup.cleanupAll();

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show results
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.accentGreen),
                SizedBox(width: 8),
                Text('Cleanup Complete!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Removed ${results['totalDuplicatesRemoved']} duplicates total:',
                  style: AppTheme.heading2,
                ),
                const SizedBox(height: 16),
                _buildResultRow(
                  'Users',
                  results['users']!['duplicatesRemoved'] as int,
                ),
                _buildResultRow(
                  'Work Orders',
                  results['workOrders']!['duplicatesRemoved'] as int,
                ),
                _buildResultRow(
                  'PM Tasks',
                  results['pmTasks']!['duplicatesRemoved'] as int,
                ),
                _buildResultRow(
                  'Assets',
                  results['assets']!['duplicatesRemoved'] as int,
                ),
                _buildResultRow(
                  'Inventory',
                  results['inventory']!['duplicatesRemoved'] as int,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }

      // Show success snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Removed ${results['totalDuplicatesRemoved']} duplicates!',
            ),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error
      if (context.mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Cleanup failed. Please try again.',
          stackTrace: st,
          contextLabel: 'AdminMain: orphan cleanup',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  static Widget _buildResultRow(String label, int count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('• $label:', style: AppTheme.bodyText),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0
                    ? AppTheme.accentRed.withValues(alpha: 0.2)
                    : AppTheme.accentGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                count > 0 ? '-$count' : 'Clean ✓',
                style: AppTheme.bodyText.copyWith(
                  color: count > 0 ? AppTheme.accentRed : AppTheme.accentGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
  Future<void> _showOrphanCleanupDialog({required bool delete}) async {
    if (delete && !ReleaseSafety.allowDestructiveAdminTools) return;
    if (!delete && !ReleaseSafety.showDevTools) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            delete ? 'Delete Orphaned Records?' : 'Dry Run Orphan Cleanup'),
        content: Text(
          delete
              ? 'This will permanently delete work orders and PM tasks whose requestors, technicians, or assets no longer exist. Continue?'
              : 'Run a scan to see how many orphaned work orders and PM tasks exist without deleting them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  delete ? AppTheme.errorColor : AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(delete ? 'Delete' : 'Run'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final report = await sl<OrphanCleanupService>().run(delete: delete);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close progress dialog
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(delete ? 'Cleanup Complete' : 'Dry Run Complete'),
          content: Text(
            'Work Orders: ${report.orphanedWorkOrders}/${report.totalWorkOrders} orphaned\n'
            'PM Tasks: ${report.orphanedPMTasks}/${report.totalPMTasks} orphaned',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close progress
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cleanup Failed'),
          content: Text(
            userFacingErrorMessage(
              e,
              genericMessage: 'Cleanup failed. Please try again.',
              stackTrace: st,
              contextLabel: 'AdminMain: orphan cleanup',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
