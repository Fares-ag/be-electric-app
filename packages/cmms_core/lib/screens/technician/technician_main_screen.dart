import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/release_safety.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/offline_service_access.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/user_facing_errors.dart';
import '../../widgets/mobile_qr_scanner_widget.dart';
import '../../widgets/offline_sync_indicators.dart';
import '../../widgets/quick_create_menu_sheet.dart';
import '../admin/seed_general_assets_screen.dart';
import '../analytics/consolidated_analytics_dashboard.dart';
import '../inventory/parts_request_screen.dart';
import '../pm_tasks/create_pm_task_screen.dart';
import '../pm_tasks/pm_technician_inbox_screen.dart';
import '../profile/user_profile_screen.dart';
import '../settings/sync_queue_status_screen.dart';
import '../work_orders/create_work_request_screen.dart';
import '../work_orders/work_order_list_screen.dart';

class TechnicianMainScreen extends StatefulWidget {
  const TechnicianMainScreen({super.key});

  @override
  State<TechnicianMainScreen> createState() => _TechnicianMainScreenState();
}

class _TechnicianMainScreenState extends State<TechnicianMainScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  /// When on Work Orders tab, filter/sort row (filters left, title center) from WorkOrderListScreen.
  Widget? _workOrderAppBarContent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTechnicianData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final unified =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      unawaited(_onResumeSync(unified));
    }
  }

  Future<void> _onResumeSync(UnifiedDataProvider unified) async {
    await resolveConnectivityService().refresh();
    await resolveOfflineQueueService().processQueue();
    await unified.refreshTechnicianSurface();
  }

  void _loadTechnicianData() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      // Data is now loaded from unified provider automatically
      print(
        '🔧 Technician Dashboard: Loading data for ${user.name} (${user.id})',
      );
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MobileQRScannerWidget(),
        ),
      );

      if (result != null && mounted) {
        // Show asset information and related maintenance tasks
        _showAssetMaintenanceInfo(result);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not scan QR code. Please try again.',
          stackTrace: st,
          contextLabel: 'TechnicianMain: scan QR',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _navigateToPartsRequest() async {
    final workOrder = await _showWorkOrderSelectionDialog();
    if (workOrder != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PartsRequestScreen(workOrder: workOrder),
        ),
      );
    }
  }

  Future<dynamic> _showWorkOrderSelectionDialog() async {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    final currentTechId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id ?? '';
    final workOrders = unifiedProvider.workOrders
        .where((wo) => wo.hasTechnician(currentTechId))
        .toList();

    if (workOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assigned work orders found'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return null;
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Work Order'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: workOrders.length,
            itemBuilder: (context, index) {
              final workOrder = workOrders[index];
              return ListTile(
                title: Text(
                  workOrder.ticketNumber,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  workOrder.problemDescription,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                onTap: () => Navigator.of(context).pop(workOrder),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showQuickCreateMenu() {
    final canCreatePmTask =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.canCreatePmTasks ??
            false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
      ),
      builder: (context) => QuickCreateMenuSheet(
        canCreatePmTask: canCreatePmTask,
        onCreateWorkOrder: () {
          Navigator.pop(context);
          _navigateToCreateWorkOrder();
        },
        onCreatePmTask: () {
          Navigator.pop(context);
          _navigateToCreatePMTask();
        },
        onScanQr: () {
          Navigator.pop(context);
          _scanQRCode();
        },
      ),
    );
  }

  Future<void> _navigateToCreateWorkOrder() async {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateWorkRequestScreen(),
      ),
    );
    if (result == true && mounted) {
      await unifiedProvider.refreshAll();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work order created successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreatePMTask() async {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePMTaskScreen(),
      ),
    );
    if (result == true && mounted) {
      await unifiedProvider.refreshAll();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PM task created successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    }
  }

  void _showAssetMaintenanceInfo(Map<String, dynamic> assetData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Asset: ${assetData['assetName'] ?? 'Unknown'}',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (assetData['location'] != null)
                _buildInfoRow('Location', assetData['location']),
              if (assetData['description'] != null)
                _buildInfoRow('Description', assetData['description']),
              if (assetData['category'] != null)
                _buildInfoRow('Category', assetData['category']),
              if (assetData['manufacturer'] != null)
                _buildInfoRow('Manufacturer', assetData['manufacturer']),
              if (assetData['model'] != null)
                _buildInfoRow('Model', assetData['model']),
              if (assetData['serialNumber'] != null)
                _buildInfoRow('Serial Number', assetData['serialNumber']),
              if (assetData['status'] != null)
                _buildInfoRow('Status', assetData['status']),
              const SizedBox(height: AppTheme.spacingM),
              const Text(
                'Related Maintenance:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              // Show related work orders and PM tasks
              _buildMaintenanceTasks(assetData['assetId']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              final assetId = assetData['assetId'];
              Navigator.pop(context);
              _navigateToAssetWorkOrders(assetId);
            },
            child: const Text('View Tasks'),
          ),
        ],
      ),
    );
  }

  void _navigateToAssetWorkOrders(String? assetId) {
    if (!mounted || assetId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkOrderListScreen(
          isTechnicianView: true,
          assetId: assetId,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _buildMaintenanceTasks(String? assetId) {
    if (assetId == null) {
      return const Text('No asset ID available');
    }

    // Get work orders and PM tasks for this asset
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    final workOrders = unifiedProvider.workOrders
        .where((wo) => wo.assetId == assetId)
        .toList();

    final pmTasks =
        unifiedProvider.pmTasks.where((pm) => pm.assetId == assetId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Work Orders: ${workOrders.length}'),
        Text('PM Tasks: ${pmTasks.length}'),
        if (workOrders.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingS),
          const Text('Recent Work Orders:'),
          ...workOrders.take(3).map(
                (wo) => Padding(
                  padding: const EdgeInsets.only(left: AppTheme.spacingS),
                  child: Text(
                    '• ${wo.problemDescription} (${wo.status})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
        if (pmTasks.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingS),
          const Text('PM Tasks:'),
          ...pmTasks.take(3).map(
                (pm) => Padding(
                  padding: const EdgeInsets.only(left: AppTheme.spacingS),
                  child: Text(
                    '• ${pm.taskName} (${pm.status})',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
      ],
    );
  }

  static const List<String> _tabTitles = [
    'Dashboard',
    'Work Orders',
    'PM Tasks',
    'Analytics',
  ];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: _currentIndex == 1 && _workOrderAppBarContent != null
            ? _workOrderAppBarContent
            : Text(_tabTitles[_currentIndex]),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        elevation: AppTheme.elevationS,
        titleTextStyle: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Quick Create',
            onPressed: _showQuickCreateMenu,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Provider.of<AuthProvider>(context, listen: false).logout();
              } else if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              } else if (value == 'sync_queue') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SyncQueueStatusScreen(),
                  ),
                );
              } else if (value == 'seed_assets') {
                if (!ReleaseSafety.allowDataSeeding) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SeedGeneralAssetsScreen(),
                  ),
                );
              }
            },
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
              const PopupMenuItem(
                value: 'sync_queue',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined, color: AppTheme.accentGreen),
                    SizedBox(width: AppTheme.spacingS),
                    Text('Sync queue'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (ReleaseSafety.allowDataSeeding)
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
      body: SafeArea(
        child: Column(
          children: [
            const OfflineSyncGlobalBanner(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildDashboardTab(user),
                  _buildWorkOrdersTab(),
                  _buildPMTasksTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.surfaceColor,
        selectedItemColor: AppTheme.accentGreen,
        unselectedItemColor: AppTheme.secondaryTextColor,
        elevation: AppTheme.elevationL,
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
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(dynamic user) => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          final workOrders = unifiedProvider.getWorkOrdersByTechnician(user.id);
          final pmTasks = unifiedProvider.getPMTasksByTechnician(user.id);

          // Responsive layout
          final isMobile = ResponsiveLayout.isMobile(context);
          final padding = ResponsiveLayout.getResponsivePadding(context);
          final maxWidth = ResponsiveLayout.getMaxContentWidth(context);

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card (brand: card radius 16, elevation 2)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(
                          isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusL),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user?.name ?? 'Technician'}!',
                              style: (isMobile ? AppTheme.heading2 : AppTheme.heading1)
                                  .copyWith(color: AppTheme.darkTextColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                              height: isMobile ? AppTheme.spacingXS : AppTheme.spacingS,
                            ),
                            Text(
                              'Here are your assigned tasks and analytics',
                              style: (isMobile ? AppTheme.smallText : AppTheme.bodyText)
                                  .copyWith(color: AppTheme.secondaryTextColor),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),

                      // Primary CTA: Scan QR (brand: accentGreen, button radius 8)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          bottom: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _scanQRCode,
                          icon: Icon(Icons.qr_code_scanner, size: isMobile ? 20 : 24),
                          label: Text(
                            'Scan Asset QR Code',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: AppTheme.surfaceColor,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? AppTheme.spacingS : AppTheme.spacingM,
                              horizontal: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusS),
                            ),
                            elevation: AppTheme.elevationS,
                          ),
                        ),
                      ),

                      // Quick Stats (brand: card radius 16, elevation 2)
                      if (isMobile)
                        Column(
                          children: [
                            _buildStatCard(
                              'Assigned Work Orders',
                              workOrders.length.toString(),
                              Icons.work,
                              AppTheme.accentBlue,
                              isMobile,
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            _buildStatCard(
                              'PM Tasks',
                              pmTasks.length.toString(),
                              Icons.schedule,
                              AppTheme.accentGreen,
                              isMobile,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Assigned Work Orders',
                                workOrders.length.toString(),
                                Icons.work,
                                AppTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: _buildStatCard(
                                'PM Tasks',
                                pmTasks.length.toString(),
                                Icons.schedule,
                                AppTheme.accentGreen,
                              ),
                            ),
                          ],
                        ),

                      SizedBox(
                        height: isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),

                      // Action Buttons (brand: accentGreen primary, radius 8)
                      if (isMobile)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _navigateToPartsRequest,
                                icon: const Icon(Icons.inventory_2_outlined),
                                label: const Text('Request Parts'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGreen,
                                  foregroundColor: AppTheme.surfaceColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingM,
                                    horizontal: AppTheme.spacingL,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  elevation: AppTheme.elevationS,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _scanQRCode,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan QR Code'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGreen,
                                  foregroundColor: AppTheme.surfaceColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingM,
                                    horizontal: AppTheme.spacingL,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  elevation: AppTheme.elevationS,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _navigateToPartsRequest,
                                icon: const Icon(Icons.inventory_2_outlined),
                                label: const Text('Request Parts'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGreen,
                                  foregroundColor: AppTheme.surfaceColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingM,
                                    horizontal: AppTheme.spacingL,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  elevation: AppTheme.elevationS,
                                ),
                              ),
                            ),
                          ],
                        ),

                      SizedBox(
                        height: ResponsiveLayout.getResponsiveSpacing(
                          context,
                          mobile: AppTheme.spacingL,
                          tablet: AppTheme.spacingXL,
                          desktop: AppTheme.spacingXXL,
                        ),
                      ),

                      // Recent Tasks (brand: card radius 16)
                      Text(
                        'Recent Tasks',
                        style: AppTheme.heading2.copyWith(
                          color: AppTheme.darkTextColor,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(AppTheme.radiusL),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your assigned tasks will appear here',
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _currentIndex = 1;
                                  });
                                },
                                icon: const Icon(Icons.work_outline),
                                label: const Text('View Work Orders'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGreen,
                                  foregroundColor: AppTheme.surfaceColor,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingS,
                                    horizontal: AppTheme.spacingL,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  elevation: AppTheme.elevationS,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: padding.bottom + AppTheme.spacingL),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Widget _buildWorkOrdersTab() => WorkOrderListScreen(
        isTechnicianView: true,
        showAppBar: false,
        onAppBarContent: (widget) {
          setState(() => _workOrderAppBarContent = widget);
        },
      );

  Widget _buildPMTasksTab() => const PmTechnicianInboxScreen();

  Widget _buildAnalyticsTab() =>
      const ConsolidatedAnalyticsDashboard(isTechnicianView: true);

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, [
    bool isMobile = false,
  ]) =>
      Container(
        width: isMobile ? double.infinity : null,
        padding:
            EdgeInsets.all(isMobile ? AppTheme.spacingM : AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isMobile
            ? Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTheme.smallText.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          value,
                          style: AppTheme.heading2.copyWith(
                            color: AppTheme.darkTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    value,
                    style: AppTheme.heading1.copyWith(
                      color: AppTheme.darkTextColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    title,
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      );
}
