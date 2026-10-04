import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
// import 'package:open_file/open_file.dart'; // Disabled for web compatibility
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../models/user.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/activity_log_service.dart';
import '../../repositories/cmms_repositories.dart';
import '../../services/work_order_completion_report_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/charger_asset_filter.dart';
import '../../utils/work_order_duration.dart';
import '../../widgets/activity_history_timeline.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/pause_reason_dialog.dart';
import '../../widgets/reopen_work_order_dialog.dart';
import '../../widgets/technician_assignment_dialog.dart';
import '../../widgets/work_timer.dart';
import '../requestor/edit_request_screen.dart';
import 'work_order_completion_screen.dart';
import '../../config/locator.dart';
import '../../utils/offline_service_access.dart';
import '../../utils/user_facing_errors.dart';

class WorkOrderDetailScreen extends StatefulWidget {
  const WorkOrderDetailScreen({
    required this.workOrder,
    super.key,
  });
  final WorkOrder workOrder;

  @override
  State<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends State<WorkOrderDetailScreen> {
  bool _isLoading = false;
  late WorkOrder _currentWorkOrder;
  final ActivityLogService _activityLogService = sl<ActivityLogService>();
  String? _companyName;
  bool _isLoadingCompany = false;

  @override
  void initState() {
    super.initState();
    _currentWorkOrder = widget.workOrder;
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateWorkOrderFromServerThenProvider();
    });
  }

  /// Supabase row is authoritative for photo URLs (metadata + columns). The
  /// in-memory realtime cache can briefly miss `metadata` merges.
  Future<void> _hydrateWorkOrderFromServerThenProvider() async {
    try {
      if (await resolveOfflineQueueService()
          .hasPendingMutationForWorkOrder(_currentWorkOrder.id)) {
        debugPrint(
          'WorkOrderDetail: Skipping server hydrate for ${_currentWorkOrder.id} '
          '— pending offline mutation',
        );
        if (mounted) {
          _refreshWorkOrderFromProvider();
          _loadCompanyName();
        }
        return;
      }

      final fresh = await CmmsRepositories.workOrders
          .getWorkOrder(_currentWorkOrder.id);
      if (!mounted) return;

      if (fresh != null) {
        debugPrint(
          '📸 Detail hydrate: photoPath=${fresh.photoPath}, '
          'photoPaths=${fresh.photoPaths}, count=${fresh.photoPaths?.length ?? 0}',
        );
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);
        WorkOrder merged = fresh;
        if (fresh.asset == null &&
            fresh.assetId != null &&
            fresh.assetId!.isNotEmpty) {
          try {
            final asset = unifiedProvider.assets.firstWhere(
              (a) => a.id == fresh.assetId,
            );
            merged = merged.copyWith(asset: asset);
          } catch (_) {
            debugPrint(
              '⚠️ Asset ${fresh.assetId} not found when hydrating work order',
            );
          }
        }
        try {
          final u = unifiedProvider.users.firstWhere(
            (x) => x.id == fresh.requestorId,
          );
          merged = merged.copyWith(requestor: u);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _currentWorkOrder = merged;
          });
          // Push the server-fresh version into the provider so the list and
          // dashboard are immediately consistent (no stale status badge).
          unifiedProvider.updateCachedWorkOrder(merged);
        }
      }
    } catch (e, st) {
      debugPrint('WorkOrderDetail: hydrate from server failed: $e\n$st');
    }

    if (mounted) {
      _refreshWorkOrderFromProvider();
      _loadCompanyName();
    }
  }

  List<String> _problemPhotoPathsList(WorkOrder wo) {
    if (wo.photoPaths != null && wo.photoPaths!.isNotEmpty) {
      return List<String>.from(wo.photoPaths!);
    }
    if (wo.photoPath != null && wo.photoPath!.isNotEmpty) {
      return [wo.photoPath!];
    }
    return [];
  }

  Future<void> _loadCompanyName() async {
    if (_currentWorkOrder.companyId == null ||
        _currentWorkOrder.companyId!.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingCompany = true;
    });

    try {
      final company =
          await CmmsRepositories.users.getCompanyById(_currentWorkOrder.companyId!);

      if (mounted) {
        setState(() {
          _companyName = company?.name ?? _currentWorkOrder.companyId;
          _isLoadingCompany = false;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading company name: $e');
      if (mounted) {
        setState(() {
          _companyName = _currentWorkOrder.companyId;
          _isLoadingCompany = false;
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    await _activityLogService.initialize();
  }

  void _refreshWorkOrderFromProvider() {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    var cached = unifiedProvider.workOrders.firstWhere(
      (wo) => wo.id == _currentWorkOrder.id,
      orElse: () => _currentWorkOrder,
    );

    if (_currentWorkOrder.isPaused && !cached.isPaused) {
      cached = cached.copyWith(
        isPaused: true,
        pausedAt: _currentWorkOrder.pausedAt,
        pauseReason: _currentWorkOrder.pauseReason,
        pauseHistory: _currentWorkOrder.pauseHistory,
      );
    }

    if (_currentWorkOrder.isCompleted && !cached.isCompleted) {
      cached = _currentWorkOrder;
    }

    if (cached.isCompleted) {
      debugPrint(
        '📸 Work Order ${cached.id} completion photo path: ${cached.completionPhotoPath}',
      );
      debugPrint('📸 Before photo: ${cached.beforePhotoPath}');
      debugPrint('📸 After photo: ${cached.afterPhotoPath}');
    }

    // Prefer populated asset from local cache without swapping in a stale WO.
    if (_currentWorkOrder.asset == null &&
        _currentWorkOrder.assetId != null &&
        _currentWorkOrder.assetId!.isNotEmpty) {
      try {
        final asset = unifiedProvider.assets.firstWhere(
          (a) => a.id == _currentWorkOrder.assetId,
        );
        if (mounted) {
          setState(() {
            _currentWorkOrder = _currentWorkOrder.copyWith(asset: asset);
          });
        }
      } catch (e, st) {
        debugPrint(
          '⚠️ Asset ${_currentWorkOrder.assetId} not found in provider assets',
        );
      }
    }

    // Same for requestor display name
    if (_currentWorkOrder.requestor == null) {
      try {
        final u = unifiedProvider.users.firstWhere(
          (x) => x.id == _currentWorkOrder.requestorId,
        );
        if (mounted) {
          setState(() {
            _currentWorkOrder = _currentWorkOrder.copyWith(requestor: u);
          });
        }
      } catch (_) {}
    }

    // Only replace the whole work order if cache is strictly newer (realtime).
    if (cached != _currentWorkOrder &&
        mounted &&
        cached.updatedAt.isAfter(_currentWorkOrder.updatedAt)) {
      setState(() {
        _currentWorkOrder = cached;
      });
      if (cached.companyId != null &&
          cached.companyId != widget.workOrder.companyId) {
        _loadCompanyName();
      }
    }
  }

  Future<void> _loadActivityHistory() async {
    await _activityLogService.initialize();
  }

  Future<void> _startWork() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Ensure the current technician is assigned when they start work
      final currentUserId = authProvider.currentUser?.id ?? '';
      final assignedIds =
          List<String>.from(_currentWorkOrder.assignedTechnicianIds);
      if (currentUserId.isNotEmpty && !assignedIds.contains(currentUserId)) {
        assignedIds.add(currentUserId);
      }

      final updatedWorkOrder = _currentWorkOrder.copyWith(
        status: WorkOrderStatus.inProgress,
        startedAt: DateTime.now(),
        assignedTechnicianIds: assignedIds,
        primaryTechnicianId: assignedIds.isNotEmpty
            ? assignedIds.first
            : _currentWorkOrder.primaryTechnicianId,
        // If work order was paused, resume it when starting
        isPaused: false,
        resumedAt: _currentWorkOrder.isPaused
            ? DateTime.now()
            : _currentWorkOrder.resumedAt,
      );

      await unifiedProvider.updateWorkOrder(updatedWorkOrder);

      if (mounted) {
        // Log activity
        if (authProvider.currentUser != null) {
          await _activityLogService.logActivity(
            entityId: _currentWorkOrder.id,
            entityType: 'work_order',
            activityType: ActivityType.started,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work started successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        setState(() {
          _currentWorkOrder = updatedWorkOrder;
        });
      }
    } on Exception catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not start work. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: start work',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pauseWork() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const PauseReasonDialog(),
    );

    if (reason != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // Get the updated work order directly from the pause operation
        final updatedWorkOrder = await unifiedProvider.pauseWorkOrder(
          _currentWorkOrder.id,
          reason,
        );

        if (mounted) {
          // Log activity
          if (authProvider.currentUser != null) {
            await _activityLogService.logActivity(
              entityId: _currentWorkOrder.id,
              entityType: 'work_order',
              activityType: ActivityType.paused,
              userId: authProvider.currentUser!.id,
              userName: authProvider.currentUser!.name,
              description: reason,
            );
          }

          // Update local state immediately with the returned work order
          setState(() {
            _currentWorkOrder = updatedWorkOrder;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work paused'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      } on Exception catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not pause work. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: pause work',
          backgroundColor: AppTheme.errorColor,
        );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _resumeWork() async {
    setState(() => _isLoading = true);
    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get the updated work order directly from the resume operation
      final updatedWorkOrder = await unifiedProvider.resumeWorkOrder(
        _currentWorkOrder.id,
      );

      if (mounted) {
        // Log activity
        if (authProvider.currentUser != null) {
          await _activityLogService.logActivity(
            entityId: _currentWorkOrder.id,
            entityType: 'work_order',
            activityType: ActivityType.resumed,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
          );
        }

        // Update local state immediately with the returned work order
        setState(() {
          _currentWorkOrder = updatedWorkOrder;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work resumed'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } on Exception catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not resume work. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: resume work',
          backgroundColor: AppTheme.errorColor,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeWork() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WorkOrderCompletionScreen(workOrder: _currentWorkOrder),
      ),
    );

    if (result ?? false && mounted) {
      // Work order was completed, wait for Supabase to sync
      await Future.delayed(const Duration(milliseconds: 500));

      // Force refresh from provider
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      await unifiedProvider.refreshAll();

      // Wait a bit more for real-time listener to update
      await Future.delayed(const Duration(milliseconds: 300));

      // Get the latest work order from provider
      final updatedWorkOrder = unifiedProvider.workOrders.firstWhere(
        (wo) => wo.id == _currentWorkOrder.id,
        orElse: () => _currentWorkOrder,
      );

      debugPrint('🔄 After completion - Work Order ${updatedWorkOrder.id}:');
      debugPrint('   - Status: ${updatedWorkOrder.status}');
      debugPrint(
          '   - Completion Photo Path: ${updatedWorkOrder.completionPhotoPath}');
      debugPrint('   - Before Photo Path: ${updatedWorkOrder.beforePhotoPath}');
      debugPrint('   - After Photo Path: ${updatedWorkOrder.afterPhotoPath}');

      if (mounted) {
        setState(() {
          _currentWorkOrder = updatedWorkOrder;
        });

        // Also refresh using the helper method to ensure we get the latest data
        _refreshWorkOrderFromProvider();

        // Force another refresh after a short delay to catch any late updates
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _refreshWorkOrderFromProvider();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_currentWorkOrder.ticketNumber),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            // Only show menu for admins and managers - requestors have their own action buttons in the body
            Builder(
              builder: (context) {
                final currentUser =
                    Provider.of<AuthProvider>(context, listen: false)
                        .currentUser;
                final isAdminOrManager = currentUser?.role == 'admin' ||
                    currentUser?.role == 'manager';
                final isRequestor = currentUser?.role == 'requestor';

                // Hide menu completely for requestors (they have Edit/Cancel buttons in the body)
                if (isRequestor) {
                  return const SizedBox.shrink();
                }

                // Only show menu for admins/managers if work order is editable
                if (!isAdminOrManager) {
                  return const SizedBox.shrink();
                }

                // Show menu only if work order is not completed/cancelled/closed
                if (_currentWorkOrder.status == WorkOrderStatus.completed ||
                    _currentWorkOrder.status == WorkOrderStatus.cancelled ||
                    _currentWorkOrder.status == WorkOrderStatus.closed) {
                  return const SizedBox.shrink();
                }

                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editRequestAsRequestor(); // This works for admins/managers too
                    } else if (value == 'reassign') {
                      _showAssignmentDialog();
                    } else if (value == 'delete') {
                      _deleteWorkOrder();
                    }
                  },
                  itemBuilder: (context) {
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit Work Order'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reassign',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add,
                              size: 20,
                              color: AppTheme.accentGreen,
                            ),
                            SizedBox(width: 8),
                            Text('Reassign Technician'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Delete Work Order',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and Priority Card — coloured left-border hero
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Coloured accent bar
                        Container(
                          width: 6,
                          color: AppTheme.getStatusColor(
                            _currentWorkOrder.status.name,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: AppTheme.getStatusContainerDecoration(
                                    AppTheme.getStatusColor(
                                      _currentWorkOrder.status.name,
                                    ),
                                  ),
                                  child: Text(
                                    _currentWorkOrder.status.name.toUpperCase(),
                                    style: TextStyle(
                                      color: AppTheme.getStatusColor(
                                        _currentWorkOrder.status.name,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: AppTheme.getStatusContainerDecoration(
                                    AppTheme.getPriorityColor(
                                      _currentWorkOrder.priority.name,
                                    ),
                                  ),
                                  child: Text(
                                    _currentWorkOrder.priority.name.toUpperCase(),
                                    style: TextStyle(
                                      color: AppTheme.getPriorityColor(
                                        _currentWorkOrder.priority.name,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Work Order Information
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Work Order Information',
                              style: AppTheme.titleStyle.copyWith(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          // Show timer if work is in progress
                          if (_currentWorkOrder.isInProgress &&
                              _currentWorkOrder.startedAt != null)
                            WorkTimer(
                              startTime: _currentWorkOrder.startedAt!,
                              isActive: !_currentWorkOrder.isPaused,
                              pauseHistory: _currentWorkOrder.pauseHistory,
                              pausedAt: _currentWorkOrder.pausedAt,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        'Ticket Number',
                        _currentWorkOrder.ticketNumber,
                      ),
                      // Only show Asset if it has a value or is general maintenance
                      if (_currentWorkOrder.assetId == null ||
                          _currentWorkOrder.assetId!.isEmpty ||
                          _currentWorkOrder.asset?.name != null ||
                          _currentWorkOrder.assetName != null)
                        _buildInfoRow(
                          'Asset',
                          _currentWorkOrder.asset?.name ??
                              _currentWorkOrder.assetName ??
                              'General Maintenance (No Asset)',
                        ),
                      if (_resolveChargerManufacturerLabel() != null)
                        _buildInfoRow(
                          'Manufacturer',
                          _resolveChargerManufacturerLabel()!,
                        ),
                      // Only show Location if it has a value
                      if (_getWorkOrderLocation(_currentWorkOrder) != null)
                        _buildInfoRow(
                          'Location',
                          _getWorkOrderLocation(_currentWorkOrder)!,
                        ),
                      _buildInfoRow(
                        'Problem Description',
                        _currentWorkOrder.problemDescription,
                      ),
                      // Display multiple photos if available, otherwise fall back to single photoPath
                      if ((_currentWorkOrder.photoPaths != null &&
                              _currentWorkOrder.photoPaths!.isNotEmpty) ||
                          _currentWorkOrder.photoPath != null) ...[
                        const SizedBox(height: 16),
                        _buildMultiplePhotosSection(
                          'Problem Photos',
                          _currentWorkOrder.photoPaths ??
                              (_currentWorkOrder.photoPath != null
                                  ? [_currentWorkOrder.photoPath!]
                                  : []),
                        ),
                      ],
                      if (_currentWorkOrder.category != null)
                        _buildInfoRow(
                          'Category',
                          _currentWorkOrder.categoryDisplayName,
                        ),
                      if (_currentWorkOrder.requestorName != null &&
                          _currentWorkOrder.requestorName!.isNotEmpty)
                        _buildInfoRow(
                          'Requestor Name',
                          _currentWorkOrder.requestorName!,
                        ),
                      _buildInfoRow(
                        'Created By',
                        _currentWorkOrder.requestor?.name ?? 'Unknown',
                      ),
                      // Show company name if available
                      if (_currentWorkOrder.companyId != null &&
                          _currentWorkOrder.companyId!.isNotEmpty) ...[
                        _buildInfoRow(
                          'Company',
                          _isLoadingCompany
                              ? 'Loading...'
                              : (_companyName ??
                                  _currentWorkOrder.companyId ??
                                  'N/A'),
                        ),
                      ],
                      if (_currentWorkOrder.assignedTechnicians != null &&
                          _currentWorkOrder.assignedTechnicians!.isNotEmpty)
                        _buildInfoRow(
                          'Assigned To',
                          _formatTechniciansList(
                              _currentWorkOrder.assignedTechnicians!),
                        ),
                      _buildInfoRow(
                        'Created',
                        _formatDate(_currentWorkOrder.createdAt),
                      ),
                      if (_currentWorkOrder.startedAt != null)
                        _buildInfoRow(
                          'Started',
                          _formatDate(_currentWorkOrder.startedAt!),
                        ),
                      if (_currentWorkOrder.completedAt != null)
                        _buildInfoRow(
                          'Completed',
                          _formatDate(_currentWorkOrder.completedAt!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Completion Log (if completed)
              if (_currentWorkOrder.isCompleted) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.successColor,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Completion Log',
                              style: AppTheme.titleStyle.copyWith(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Divider(height: 24),

                        // Timeline Section
                        _buildCompletionSection(
                          'Timeline',
                          [
                            _buildCompletionRow(
                              'Created',
                              _formatDate(_currentWorkOrder.createdAt),
                              Icons.add_circle_outline,
                            ),
                            if (_currentWorkOrder.assignedAt != null)
                              _buildCompletionRow(
                                'Assigned',
                                _formatDate(_currentWorkOrder.assignedAt!),
                                Icons.person_add_outlined,
                              ),
                            if (_currentWorkOrder.startedAt != null)
                              _buildCompletionRow(
                                'Started',
                                _formatDate(_currentWorkOrder.startedAt!),
                                Icons.play_arrow,
                              ),
                            if (_currentWorkOrder.completedAt != null)
                              _buildCompletionRow(
                                'Completed',
                                _formatDate(_currentWorkOrder.completedAt!),
                                Icons.check_circle,
                                isHighlight: true,
                              ),
                            if (_currentWorkOrder.closedAt != null)
                              _buildCompletionRow(
                                'Closed',
                                _formatDate(_currentWorkOrder.closedAt!),
                                Icons.lock_outline,
                              ),
                          ],
                        ),

                        // Duration Section
                        if (_currentWorkOrder.startedAt != null ||
                            _currentWorkOrder.completedAt != null) ...[
                          const SizedBox(height: 16),
                          _buildCompletionSection(
                            'Duration',
                            [
                              if (_currentWorkOrder.startedAt != null &&
                                  _currentWorkOrder.completedAt != null)
                                _buildCompletionRow(
                                  'Total Duration',
                                  formatWorkDurationSeconds(
                                    calculateWorkDurationSeconds(
                                          _currentWorkOrder,
                                        ) ??
                                        0,
                                  ),
                                  Icons.timer_outlined,
                                ),
                              if (_currentWorkOrder.startedAt != null)
                                _buildCompletionRow(
                                  'Time to Start',
                                  formatWorkDurationSeconds(
                                    elapsedSecondsBetween(
                                      _currentWorkOrder.createdAt,
                                      _currentWorkOrder.startedAt!,
                                    ),
                                  ),
                                  Icons.schedule,
                                ),
                              if (_currentWorkOrder.completedAt != null)
                                _buildCompletionRow(
                                  'Total Time',
                                  formatWorkDurationSeconds(
                                    elapsedSecondsBetween(
                                      _currentWorkOrder.createdAt,
                                      _currentWorkOrder.completedAt!,
                                    ),
                                  ),
                                  Icons.access_time,
                                ),
                            ],
                          ),
                        ],

                        // Root Cause & Failure Analysis
                        if (_currentWorkOrder.rootCause != null ||
                            _currentWorkOrder.failureMode != null) ...[
                          const SizedBox(height: 16),
                          _buildCompletionSection(
                            'Root Cause & Failure Analysis',
                            [
                              if (_currentWorkOrder.rootCause != null &&
                                  _currentWorkOrder.rootCause!.isNotEmpty)
                                _buildCompletionRow(
                                  'Root Cause',
                                  _currentWorkOrder.rootCause!,
                                  Icons.search,
                                ),
                              if (_currentWorkOrder.failureMode != null &&
                                  _currentWorkOrder.failureMode!.isNotEmpty)
                                _buildCompletionRow(
                                  'Failure Mode',
                                  _currentWorkOrder.failureMode!,
                                  Icons.warning_outlined,
                                ),
                            ],
                          ),
                        ],

                        // Completion Details
                        const SizedBox(height: 16),
                        _buildCompletionSection(
                          'Completion Details',
                          [
                            if (_currentWorkOrder.correctiveActions != null &&
                                _currentWorkOrder.correctiveActions!.isNotEmpty)
                              _buildCompletionRow(
                                'Corrective Actions',
                                _currentWorkOrder.correctiveActions!,
                                Icons.build_outlined,
                              ),
                            if (_currentWorkOrder.recommendations != null &&
                                _currentWorkOrder.recommendations!.isNotEmpty)
                              _buildCompletionRow(
                                'Recommendations',
                                _currentWorkOrder.recommendations!,
                                Icons.lightbulb_outline,
                              ),
                            if (_currentWorkOrder.nextMaintenanceDate != null)
                              _buildCompletionRow(
                                'Next Maintenance',
                                _formatDate(
                                  _currentWorkOrder.nextMaintenanceDate!,
                                ),
                                Icons.calendar_today,
                              ),
                          ],
                        ),

                        // Cost: requestors only see their own estimated cost, not job financials
                        if (_isRequestor()) ...[
                          if (_currentWorkOrder.estimatedCost != null) ...[
                            const SizedBox(height: 16),
                            _buildCompletionSection(
                              'Your estimate',
                              [
                                _buildCompletionRow(
                                  'Estimated cost',
                                  'QAR ${_currentWorkOrder.estimatedCost!.toStringAsFixed(2)}',
                                  Icons.attach_money,
                                ),
                              ],
                            ),
                          ],
                        ] else if (_currentWorkOrder.laborCost != null ||
                            _currentWorkOrder.partsCost != null ||
                            _currentWorkOrder.totalCost != null ||
                            _currentWorkOrder.actualCost != null ||
                            _currentWorkOrder.estimatedCost != null) ...[
                          const SizedBox(height: 16),
                          _buildCompletionSection(
                            'Cost Breakdown',
                            [
                              if (_currentWorkOrder.estimatedCost != null)
                                _buildCompletionRow(
                                  'Estimated Cost',
                                  'QAR ${_currentWorkOrder.estimatedCost!.toStringAsFixed(2)}',
                                  Icons.attach_money,
                                ),
                              if (_currentWorkOrder.laborCost != null)
                                _buildCompletionRow(
                                  'Labor Cost',
                                  'QAR ${_currentWorkOrder.laborCost!.toStringAsFixed(2)}',
                                  Icons.work_outline,
                                ),
                              if (_currentWorkOrder.partsCost != null)
                                _buildCompletionRow(
                                  'Parts Cost',
                                  'QAR ${_currentWorkOrder.partsCost!.toStringAsFixed(2)}',
                                  Icons.inventory_2_outlined,
                                ),
                              if (_currentWorkOrder.actualCost != null)
                                _buildCompletionRow(
                                  'Actual Cost',
                                  'QAR ${_currentWorkOrder.actualCost!.toStringAsFixed(2)}',
                                  Icons.account_balance_wallet_outlined,
                                ),
                              if (_currentWorkOrder.totalCost != null)
                                _buildCompletionRow(
                                  'Total Cost',
                                  'QAR ${_currentWorkOrder.totalCost!.toStringAsFixed(2)}',
                                  Icons.calculate,
                                  isHighlight: true,
                                ),
                            ],
                          ),
                        ],

                        // Parts Used
                        if (_currentWorkOrder.partsUsed != null &&
                            _currentWorkOrder.partsUsed!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCompletionSection(
                            'Parts Used',
                            [
                              _buildCompletionRow(
                                'Parts List',
                                _currentWorkOrder.partsUsed!.join(', '),
                                Icons.list,
                              ),
                            ],
                          ),
                        ],

                        // Notes
                        if (_currentWorkOrder.notes != null &&
                            _currentWorkOrder.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCompletionSection(
                            'Notes',
                            [
                              _buildCompletionRow(
                                'Additional Notes',
                                _currentWorkOrder.notes!,
                                Icons.note_outlined,
                              ),
                            ],
                          ),
                        ],

                        // Photos: repeat problem/request shots here next to
                        // technician completion media so requestors see both
                        // without scrolling back to the top.
                        Builder(
                          builder: (context) {
                            final problemPaths =
                                _problemPhotoPathsList(_currentWorkOrder);
                            final hasProblemPhotos = problemPaths.isNotEmpty;

                            final hasBefore =
                                _currentWorkOrder.beforePhotoPath != null &&
                                    _currentWorkOrder
                                        .beforePhotoPath!.isNotEmpty;
                            final hasAfter = _currentWorkOrder.afterPhotoPath !=
                                    null &&
                                _currentWorkOrder.afterPhotoPath!.isNotEmpty;
                            final completionPaths =
                                _currentWorkOrder.completionPhotoPaths ??
                                    (_currentWorkOrder.completionPhotoPath !=
                                            null
                                        ? [
                                            _currentWorkOrder
                                                .completionPhotoPath!
                                          ]
                                        : <String>[]);
                            final hasCompletion = completionPaths.isNotEmpty;

                            final showTechnicianMedia =
                                hasBefore || hasAfter || hasCompletion;

                            if (!hasProblemPhotos && !showTechnicianMedia) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 16),
                                Text(
                                  'Photos',
                                  style: AppTheme.titleStyle.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (hasProblemPhotos) ...[
                                  _buildMultiplePhotosSection(
                                    'Problem / photos you submitted',
                                    problemPaths,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (showTechnicianMedia) ...[
                                  if (hasBefore) ...[
                                    _buildPhotoSection(
                                      'Before work (technician)',
                                      _currentWorkOrder.beforePhotoPath!,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (hasAfter) ...[
                                    _buildPhotoSection(
                                      'After work (technician)',
                                      _currentWorkOrder.afterPhotoPath!,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (hasCompletion) ...[
                                    _buildMultiplePhotosSection(
                                      'Completion (technician)',
                                      completionPaths,
                                    ),
                                  ],
                                ],
                              ],
                            );
                          },
                        ),

                        // Pause History
                        if (_currentWorkOrder.pauseHistory != null &&
                            _currentWorkOrder.pauseHistory!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          _buildCompletionSection(
                            'Work Pause History',
                            _currentWorkOrder.pauseHistory!.map((pause) {
                              final pausedAt = pause['pausedAt'] != null
                                  ? DateTime.parse(pause['pausedAt'] as String)
                                  : null;
                              final resumedAt = pause['resumedAt'] != null
                                  ? DateTime.parse(pause['resumedAt'] as String)
                                  : null;
                              final reason = pause['reason'] as String? ??
                                  'No reason provided';
                              final duration =
                                  pausedAt != null && resumedAt != null
                                      ? formatWorkDurationSeconds(
                                          elapsedSecondsBetween(
                                            pausedAt,
                                            resumedAt,
                                          ),
                                        )
                                      : 'Ongoing';
                              final index = _currentWorkOrder.pauseHistory!
                                  .indexOf(pause);

                              return _buildCompletionRow(
                                'Pause ${index + 1}',
                                'Paused: ${pausedAt != null ? _formatDate(pausedAt) : 'N/A'}\n'
                                    'Resumed: ${resumedAt != null ? _formatDate(resumedAt) : 'N/A'}\n'
                                    'Duration: $duration\n'
                                    'Reason: $reason',
                                Icons.pause_circle_outline,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Generate Completion Report Button
                if (_currentWorkOrder.isCompleted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _generateCompletionReport,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Generate Completion Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              if (!_currentWorkOrder.isCompleted &&
                  !_currentWorkOrder.isClosed) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt_outlined,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Actions',
                              style: AppTheme.titleStyle.copyWith(
                                color: AppTheme.primaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Assignment Actions (for managers only)
                        if (_shouldShowAssignmentActions()) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showAssignmentDialog,
                                  icon: Icon(
                                    _currentWorkOrder.assignedTechnician != null
                                        ? Icons.person_remove
                                        : Icons.person_add,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _currentWorkOrder.assignedTechnician != null
                                        ? 'Reassign Technician'
                                        : 'Assign Technician',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accentBlue,
                                    side: const BorderSide(
                                      color: AppTheme.accentBlue,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              if (_currentWorkOrder.assignedTechnician !=
                                  null) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: _unassignTechnician,
                                  icon:
                                      const Icon(Icons.person_remove, size: 24),
                                  color: AppTheme.errorColor,
                                  tooltip: 'Unassign Technician',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Start Work button - only for technicians, admins, and managers
                        if ((_currentWorkOrder.isOpen ||
                                _currentWorkOrder.isAssigned) &&
                            _canPerformWorkActions()) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _startWork,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow),
                              label: Text(
                                _isLoading ? 'Starting...' : 'Start Work',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                        // Work control buttons (pause/resume/complete) - only for technicians, admins, and managers
                        if (_currentWorkOrder.isInProgress &&
                            _canPerformWorkActions()) ...[
                          // Pause/Resume button
                          if (_currentWorkOrder.isPaused) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _resumeWork,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Resume Work'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Show pause reason
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppTheme.warningColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.pause_circle,
                                    color: AppTheme.warningColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Paused: ${_currentWorkOrder.pauseReason ?? "No reason provided"}',
                                      style: const TextStyle(
                                        color: AppTheme.warningColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _pauseWork,
                                icon: const Icon(Icons.pause),
                                label: const Text('Pause Work'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.warningColor,
                                  side: const BorderSide(
                                    color: AppTheme.warningColor,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _completeWork,
                              icon: const Icon(Icons.check),
                              label: const Text('Complete Work'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],

                        // Requestor actions - Edit and Cancel (only for OPEN or ASSIGNED status)
                        if ((_currentWorkOrder.isOpen ||
                                _currentWorkOrder.isAssigned) &&
                            _isRequestor()) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _editRequestAsRequestor,
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Edit Request'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accentBlue,
                                    side: const BorderSide(
                                      color: AppTheme.accentBlue,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _cancelWorkOrder,
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text('Cancel Request'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accentRed,
                                    side: const BorderSide(
                                      color: AppTheme.accentRed,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Requestor actions - Reopen (only for COMPLETED or CLOSED status)
                        if ((_currentWorkOrder.isCompleted ||
                                _currentWorkOrder.isClosed) &&
                            _isRequestor()) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _reopenWorkOrder,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.restore),
                              label: Text(
                                _isLoading
                                    ? 'Reopening...'
                                    : 'Reopen Work Order',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // Activity History Section
              const SizedBox(height: 14),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Activity History',
                            style: AppTheme.titleStyle.copyWith(
                              color: AppTheme.primaryColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder(
                        future: _loadActivityHistory(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          // Use the initialized service instance
                          final activityLogs = _activityLogService
                              .getActivityLogs(_currentWorkOrder.id);

                          if (activityLogs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'No activity history available',
                                  style: AppTheme.bodyText.copyWith(
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ActivityHistoryTimeline(
                            activityLogs: activityLogs,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      );

  String? _resolveChargerManufacturerLabel() {
    if (_currentWorkOrder.asset == null) {
      return null;
    }
    return resolveWorkOrderChargerManufacturer(_currentWorkOrder);
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String? _getWorkOrderLocation(WorkOrder workOrder) {
    final location = workOrder.asset?.location ?? workOrder.assetLocation;
    if (location != null && location.isNotEmpty) {
      return location;
    }
    return null;
  }

  String _formatTechniciansList(List<User> technicians) {
    if (technicians.isEmpty) {
      return 'Unassigned';
    }
    if (technicians.length == 1) {
      return technicians.first.name;
    }
    if (technicians.length == 2) {
      // Show both names for 2 technicians
      return '${technicians[0].name}, ${technicians[1].name}';
    }
    // For 3+ technicians, show first two and count of others
    return '${technicians[0].name}, ${technicians[1].name} +${technicians.length - 2}';
  }

  Widget _buildCompletionSection(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      );

  Widget _buildCompletionRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isHighlight ? AppTheme.successColor : AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isHighlight
                          ? AppTheme.successColor
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isHighlight ? FontWeight.w600 : FontWeight.normal,
                      color: isHighlight
                          ? AppTheme.successColor
                          : AppTheme.darkTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  bool _shouldShowAssignmentActions() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    // Requestors cannot assign technicians - only admins and managers can
    if (currentUser?.role == 'requestor') {
      return false;
    }

    // Only admins and managers can assign/reassign
    if (!authProvider.isManager && !(currentUser?.isAdmin ?? false)) {
      return false;
    }

    // If current user is a technician who created this work order, they can't reassign
    if (currentUser?.role == 'technician' &&
        currentUser != null &&
        _currentWorkOrder.requestorId == currentUser.id) {
      return false;
    }

    return true;
  }

  /// Check if the current user can perform work actions (start, pause, resume, complete)
  /// Requestors cannot perform work actions - only technicians, admins, and managers can
  bool _canPerformWorkActions() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    // Requestors cannot perform work actions
    if (currentUser?.role == 'requestor') {
      return false;
    }

    // Technicians, admins, and managers can perform work actions
    return currentUser?.role == 'technician' ||
        currentUser?.role == 'admin' ||
        currentUser?.role == 'manager' ||
        authProvider.isManager ||
        (currentUser?.isAdmin ?? false);
  }

  /// Check if the current user is a requestor
  bool _isRequestor() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.currentUser?.role == 'requestor';
  }

  /// Navigate to edit request screen for requestors
  Future<void> _editRequestAsRequestor() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditRequestScreen(workOrder: _currentWorkOrder),
      ),
    );

    if (result == true && mounted) {
      // Refresh work order after edit
      _refreshWorkOrderFromProvider();
    }
  }

  /// Reopen work order (for requestors only)
  Future<void> _reopenWorkOrder() async {
    // Show confirmation dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ReopenWorkOrderDialog(
        workOrder: _currentWorkOrder,
      ),
    );

    if (result == null || result['reopen'] != true || !mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final reason = result['reason'] as String;
      final editedDescription = result['editedDescription'] as String?;

      // Call reopen method
      final reopenedWorkOrder = await unifiedProvider.reopenWorkOrder(
        workOrderId: _currentWorkOrder.id,
        currentUserId: authProvider.currentUser!.id,
        reason: reason,
        editedDescription: editedDescription,
      );

      // Log activity
      await _activityLogService.logActivity(
        entityId: _currentWorkOrder.id,
        entityType: 'work_order',
        activityType: ActivityType.reopened,
        userId: authProvider.currentUser!.id,
        userName: authProvider.currentUser!.name,
        description: 'Work order reopened: $reason',
        oldValue: _currentWorkOrder.status.name,
        newValue: reopenedWorkOrder.status.name,
        additionalData: {
          'reopenReason': reason,
          'reopenCount': reopenedWorkOrder.reopenCount,
          'previousStatus': _currentWorkOrder.status.name,
        },
      );

      if (mounted) {
        setState(() {
          _currentWorkOrder = reopenedWorkOrder;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work order reopened successfully'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );

        // Refresh work order to get latest data
        _refreshWorkOrderFromProvider();
      }
    } on Exception catch (e, st) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reopening work order: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Cancel work order (for requestors only)
  Future<void> _cancelWorkOrder() async {
    // Check if work order can still be cancelled
    if (_currentWorkOrder.isInProgress ||
        _currentWorkOrder.isCompleted ||
        _currentWorkOrder.isClosed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This work order cannot be cancelled as work has already started'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Cancel Work Order?'),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel work order ${_currentWorkOrder.ticketNumber}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed ?? false && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);

        final updatedWorkOrder = _currentWorkOrder.copyWith(
          status: WorkOrderStatus.cancelled,
          updatedAt: DateTime.now(),
        );

        await unifiedProvider.updateWorkOrder(updatedWorkOrder);

        // Log activity
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          await _activityLogService.logActivity(
            entityId: _currentWorkOrder.id,
            entityType: 'work_order',
            activityType: ActivityType.cancelled,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            description: 'Cancelled work order',
          );
        }

        setState(() {
          _currentWorkOrder = updatedWorkOrder;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work order cancelled successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } on Exception catch (e, st) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not cancel work order. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: cancel work order',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  Future<void> _showAssignmentDialog() async {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TechnicianAssignmentDialog(
        workOrderId: _currentWorkOrder.id,
        currentTechnicianId: _currentWorkOrder.assignedTechnicianId,
        currentTechnicianIds: _currentWorkOrder.assignedTechnicianIds,
      ),
    );

    if (result ?? false && mounted) {
      // Use optimized refresh method - only refreshes this work order
      await unifiedProvider.refreshWorkOrder(_currentWorkOrder.id);

      // Get the updated work order from provider
      final updatedWorkOrder = unifiedProvider.workOrders.firstWhere(
        (wo) => wo.id == _currentWorkOrder.id,
        orElse: () => _currentWorkOrder,
      );

      if (mounted) {
        setState(() {
          _currentWorkOrder = updatedWorkOrder;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Technician assignment updated successfully'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _unassignTechnician() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign Technician'),
        content: Text(
          'Are you sure you want to unassign ${_currentWorkOrder.assignedTechnician?.name ?? 'the technician'} from this work order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);
        await unifiedProvider
            .unassignTechnicianFromWorkOrder(_currentWorkOrder.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Technician unassigned successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          // Refresh the work order data
          final unifiedProvider =
              Provider.of<UnifiedDataProvider>(context, listen: false);
          final updatedWorkOrder = unifiedProvider.workOrders.firstWhere(
            (wo) => wo.id == _currentWorkOrder.id,
            orElse: () => _currentWorkOrder,
          );
          setState(() {
            _currentWorkOrder = updatedWorkOrder;
          });
        }
      } on Exception catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not unassign technician. Please try again.',
          stackTrace: st,
          contextLabel: 'work_order_detail_screen: Could not unassign technician.',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  Widget _buildPhotoSection(String title, String photoPath) {
    // Check if it's a URL or local file path
    final isUrl =
        photoPath.startsWith('http://') || photoPath.startsWith('https://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showFullScreenImage(photoPath),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isUrl
                  ? AuthenticatedImage(
                      imageUrl: photoPath,
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                      errorWidget: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(height: 8),
                            Text('Failed to load image'),
                          ],
                        ),
                      ),
                    )
                  : kIsWeb
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text('Local files not supported on web'),
                            ],
                          ),
                        )
                      : File(photoPath).existsSync()
                          ? Image.file(
                              File(photoPath),
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text('Image not found'),
                                ],
                              ),
                            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiplePhotosSection(String title, List<String> photoPaths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${photoPaths.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: photoPaths.length,
            itemBuilder: (context, index) {
              final photoPath = photoPaths[index];
              final isUrl = photoPath.startsWith('http://') ||
                  photoPath.startsWith('https://');

              return Container(
                margin: EdgeInsets.only(
                    right: index < photoPaths.length - 1 ? 10 : 0),
                width: 200,
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(photoPath),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isUrl
                          ? AuthenticatedImage(
                              imageUrl: photoPath,
                              fit: BoxFit.cover,
                              height: 200,
                              width: 200,
                              errorWidget: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red, size: 24),
                                    SizedBox(height: 8),
                                    Text('Failed to load',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            )
                          : kIsWeb
                              ? const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Local files not supported on web',
                                          style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                )
                              : File(photoPath).existsSync()
                                  ? Image.file(
                                      File(photoPath),
                                      fit: BoxFit.cover,
                                    )
                                  : const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_not_supported,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 8),
                                          Text('Image not found',
                                              style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String photoPath) {
    final isUrl =
        photoPath.startsWith('http://') || photoPath.startsWith('https://');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: isUrl
                  ? AuthenticatedImage(
                      imageUrl: photoPath,
                      fit: BoxFit.contain,
                      errorWidget: const Icon(Icons.error, color: Colors.white),
                    )
                  : kIsWeb
                      ? const Icon(Icons.error, color: Colors.white)
                      : File(photoPath).existsSync()
                          ? Image.file(File(photoPath))
                          : const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateCompletionReport() async {
    try {
      // Ensure we have the latest work order with populated references
      _refreshWorkOrderFromProvider();

      // Get the latest work order from provider to ensure references are populated
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final latestWorkOrder = unifiedProvider.workOrders.firstWhere(
        (wo) => wo.id == _currentWorkOrder.id,
        orElse: () => _currentWorkOrder,
      );

      if (!latestWorkOrder.isCompleted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Work order must be completed to generate a report'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating completion report...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final filePath =
          await WorkOrderCompletionReportService.generateCompletionReport(
        latestWorkOrder,
      );

      if (mounted) {
        if (kIsWeb) {
          // On web, download is already triggered by the service
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Completion report downloaded successfully!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // On mobile/desktop, show option to open
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Completion report generated successfully!'),
              backgroundColor: AppTheme.successColor,
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    // File opening disabled for web compatibility
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'File opening not available on web. Please download the file manually.'),
                        ),
                      );
                    }
                  } catch (e, st) {
                    if (mounted) {
                      showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not open file. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: open file',
          backgroundColor: AppTheme.errorColor,
        );
                    }
                  }
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, st) {
      debugPrint('Error generating completion report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _editWorkOrder() async {
    // Show edit dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditWorkOrderDialog(workOrder: _currentWorkOrder),
    );

    if (result != null && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);

        final updatedWorkOrder = _currentWorkOrder.copyWith(
          problemDescription: result['problemDescription'],
          priority: result['priority'],
          category: result['category'],
          updatedAt: DateTime.now(),
        );

        await unifiedProvider.updateWorkOrder(updatedWorkOrder);

        // Log activity
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          await _activityLogService.logActivity(
            entityId: _currentWorkOrder.id,
            entityType: 'work_order',
            activityType: ActivityType.updated,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            description: 'Updated work order details',
            additionalData: {
              'priority': result['priority'].toString().split('.').last,
              if (result['category'] != null)
                'category': result['category'].toString().split('.').last,
            },
          );
        }

        setState(() {
          _currentWorkOrder = updatedWorkOrder;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work order updated successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } on Exception catch (e, st) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update work order. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: update work order',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  Future<void> _deleteWorkOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Work Order?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete work order ${_currentWorkOrder.ticketNumber}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);

        await unifiedProvider.deleteWorkOrder(_currentWorkOrder.id);

        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate deletion
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Work order deleted successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } on Exception catch (e, st) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not delete work order. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderDetail: delete work order',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  // Reassign Technician
  Future<void> _reassignTechnician() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);

    if (authProvider.currentUser?.role != 'admin' &&
        authProvider.currentUser?.role != 'manager') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Only administrators and managers can reassign technicians',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final beforeSet = _currentWorkOrder.assignedTechnicianIds.toSet();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TechnicianAssignmentDialog(
        workOrderId: _currentWorkOrder.id,
        currentTechnicianIds: _currentWorkOrder.assignedTechnicianIds,
      ),
    );

    if (!(result ?? false) || !mounted) return;

    try {
      final updatedWorkOrder = unifiedProvider.workOrders.firstWhere(
        (wo) => wo.id == _currentWorkOrder.id,
        orElse: () => _currentWorkOrder,
      );

      final afterSet = updatedWorkOrder.assignedTechnicianIds.toSet();

      if (authProvider.currentUser != null) {
        final activityType = afterSet.isEmpty && beforeSet.isNotEmpty
            ? ActivityType.unassigned
            : (beforeSet.isEmpty && afterSet.isNotEmpty)
                ? ActivityType.assigned
                : ActivityType.reassigned;

        String namesFor(Set<String> ids) {
          if (ids.isEmpty) return 'Unassigned';
          return ids
              .map(
                (id) => unifiedProvider.users
                    .firstWhere(
                      (user) => user.id == id,
                      orElse: () => User(
                        id: id,
                        email: '',
                        name: id,
                        role: 'technician',
                        createdAt: DateTime.now(),
                      ),
                    )
                    .name,
              )
              .join(', ');
        }

        await _activityLogService.logActivity(
          entityId: _currentWorkOrder.id,
          entityType: 'work_order',
          activityType: activityType,
          userId: authProvider.currentUser!.id,
          userName: authProvider.currentUser!.name,
          oldValue: namesFor(beforeSet),
          newValue: namesFor(afterSet),
        );
      }

      setState(() {
        _currentWorkOrder = updatedWorkOrder;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Technician assignments updated'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not reassign technician. Please try again.',
          stackTrace: st,
          contextLabel: 'work_order_detail_screen: Could not reassign technician.',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }
}

// Reassign Technician Dialog
// Edit Work Order Dialog
class _EditWorkOrderDialog extends StatefulWidget {
  const _EditWorkOrderDialog({required this.workOrder});
  final WorkOrder workOrder;

  @override
  State<_EditWorkOrderDialog> createState() => _EditWorkOrderDialogState();
}

class _EditWorkOrderDialogState extends State<_EditWorkOrderDialog> {
  late TextEditingController _problemController;
  late WorkOrderPriority _priority;
  RepairCategory? _category;

  @override
  void initState() {
    super.initState();
    _problemController =
        TextEditingController(text: widget.workOrder.problemDescription);
    _priority = widget.workOrder.priority;
    _category = widget.workOrder.category;
  }

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit Work Order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _problemController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Problem Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WorkOrderPriority>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: WorkOrderPriority.values
                    .map(
                      (priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority.toString().split('.').last),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _priority = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RepairCategory?>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<RepairCategory?>(
                    child: Text('None'),
                  ),
                  ...RepairCategory.values.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.toString().split('.').last),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _category = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_problemController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a problem description'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop({
                'problemDescription': _problemController.text.trim(),
                'priority': _priority,
                'category': _category,
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}
