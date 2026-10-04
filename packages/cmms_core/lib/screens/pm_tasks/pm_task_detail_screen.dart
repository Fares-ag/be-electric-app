import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_log.dart';
import '../../models/pm_task.dart';
import '../../models/user.dart';
import '../../config/app_config.dart';
import '../../config/locator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/activity_log_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/work_order_duration.dart';
import '../../widgets/activity_history_timeline.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/pause_reason_dialog.dart';
import '../../widgets/work_timer.dart';
import '../../services/pm_task_completion_report_service.dart';
import 'pm_task_completion_screen.dart';
import '../../utils/user_facing_errors.dart';

class PMTaskDetailScreen extends StatefulWidget {
  const PMTaskDetailScreen({
    required this.pmTask,
    super.key,
  });
  final PMTask pmTask;

  @override
  State<PMTaskDetailScreen> createState() => _PMTaskDetailScreenState();
}

class _PMTaskDetailScreenState extends State<PMTaskDetailScreen> {
  bool _isLoading = false;
  late PMTask _currentPMTask;
  final ActivityLogService _activityLogService = sl<ActivityLogService>();

  @override
  void initState() {
    super.initState();
    _currentPMTask = widget.pmTask;
    _initializeServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshPMTaskFromProvider();
      }
    });
  }

  Future<void> _initializeServices() async {
    await _activityLogService.initialize();
  }

  void _refreshPMTaskFromProvider() {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    final latestPMTask = unifiedProvider.pmTasks.firstWhere(
      (pm) => pm.id == _currentPMTask.id,
      orElse: () => _currentPMTask,
    );
    if (latestPMTask != _currentPMTask && mounted) {
      setState(() {
        _currentPMTask = latestPMTask;
      });
    }
  }

  Future<void> _loadActivityHistory() async {
    await _activityLogService.initialize();
  }

  /// Determine the current completion cycle number
  /// Returns the next completion cycle number if task is in progress, or 0 if not started
  int _getCurrentCompletionCycle() {
    // If task is in progress (started but not completed), it's the next completion cycle
    if (_currentPMTask.status == PMTaskStatus.inProgress && 
        _currentPMTask.startedAt != null) {
      return (_currentPMTask.completionHistory?.length ?? 0) + 1;
    }
    // If task is pending and has been started before, it might be a new cycle
    // Otherwise, return 0 to indicate no active completion cycle
    return 0;
  }

  Future<void> _startTask() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);

      // Ensure the current technician is assigned when they start work
      final currentUserId = authProvider.currentUser?.id ?? '';
      final assignedIds = List<String>.from(_currentPMTask.assignedTechnicianIds);
      if (currentUserId.isNotEmpty && !assignedIds.contains(currentUserId)) {
        assignedIds.add(currentUserId);
      }

      final updatedPMTask = _currentPMTask.copyWith(
        status: PMTaskStatus.inProgress,
        startedAt: DateTime.now(),
        assignedTechnicianIds: assignedIds,
        primaryTechnicianId: assignedIds.isNotEmpty ? assignedIds.first : _currentPMTask.primaryTechnicianId,
      );

      final resultPMTask = await unifiedProvider.updatePMTask(updatedPMTask);
      if (!mounted) return;

      if (authProvider.currentUser != null) {
          // Determine completion cycle number
          final completionCycle = _getCurrentCompletionCycle();
          await _activityLogService.logActivity(
            entityId: _currentPMTask.id,
            entityType: 'pm_task',
            activityType: ActivityType.started,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            description: completionCycle > 0 
                ? 'Started work (Completion #$completionCycle)'
                : 'Started work',
            additionalData: completionCycle > 0 
                ? {'completionCycle': completionCycle}
                : null,
          );
        }

      setState(() {
        _currentPMTask = resultPMTask;
      });

      _refreshPMTaskFromProvider();

      if (mounted) {
        final startedOffline = AppConfig.isOfflineModeEnabled &&
            (!sl<ConnectivityService>().isOnline || resultPMTask.isOffline);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              startedOffline
                  ? 'PM task started locally — pending sync when online'
                  : 'PM task started successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not start PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'PmTaskDetail: start PM task',
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

  Future<void> _pauseTask() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const PauseReasonDialog(),
    );

    if (reason != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);
        final updatedPMTask = await unifiedProvider.pausePMTask(_currentPMTask.id, reason);

        if (mounted) {
          // Log activity with completion cycle number
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          if (authProvider.currentUser != null) {
            // Determine completion cycle number
            final completionCycle = _getCurrentCompletionCycle();
            await _activityLogService.logActivity(
              entityId: _currentPMTask.id,
              entityType: 'pm_task',
              activityType: ActivityType.paused,
              userId: authProvider.currentUser!.id,
              userName: authProvider.currentUser!.name,
              description: completionCycle > 0 
                  ? 'Work paused (Completion #$completionCycle): $reason'
                  : 'Work paused: $reason',
              additionalData: completionCycle > 0 
                  ? {'completionCycle': completionCycle, 'reason': reason}
                  : {'reason': reason},
            );
          }

          setState(() {
            _currentPMTask = updatedPMTask;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (AppConfig.isOfflineModeEnabled &&
                        (!sl<ConnectivityService>().isOnline ||
                            updatedPMTask.isOffline))
                    ? 'PM task paused locally — pending sync when online'
                    : 'PM task paused',
              ),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      } catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not pause PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'PmTaskDetail: pause PM task',
          backgroundColor: AppTheme.errorColor,
        );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resumeTask() async {
    setState(() => _isLoading = true);
    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final updatedPMTask = await unifiedProvider.resumePMTask(_currentPMTask.id);

      if (mounted) {
        // Log activity with completion cycle number
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          // Determine completion cycle number
          final completionCycle = _getCurrentCompletionCycle();
          await _activityLogService.logActivity(
            entityId: _currentPMTask.id,
            entityType: 'pm_task',
            activityType: ActivityType.resumed,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            description: completionCycle > 0 
                ? 'Work resumed (Completion #$completionCycle)'
                : 'Work resumed',
            additionalData: completionCycle > 0 
                ? {'completionCycle': completionCycle}
                : null,
          );
        }

        setState(() {
          _currentPMTask = updatedPMTask;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (AppConfig.isOfflineModeEnabled &&
                      (!sl<ConnectivityService>().isOnline ||
                          updatedPMTask.isOffline))
                  ? 'PM task resumed locally — pending sync when online'
                  : 'PM task resumed',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not resume PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'PmTaskDetail: resume PM task',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeTask() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PMTaskCompletionScreen(pmTask: _currentPMTask),
      ),
    );

    if (result ?? false && mounted) {
      // PM task was completed, refresh the data
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      // Get the latest PM task from the provider
      final updatedPMTask = unifiedProvider.pmTasks.firstWhere(
        (pm) => pm.id == _currentPMTask.id,
        orElse: () => _currentPMTask,
      );
      setState(() {
        _currentPMTask = updatedPMTask;
      });
      // Also refresh from provider to ensure we have the latest data
      _refreshPMTaskFromProvider();
    }
  }

  Future<void> _generateCompletionReport() async {
    // Check if PM task has been completed at least once
    if (_currentPMTask.status != PMTaskStatus.completed &&
        (_currentPMTask.completionHistory == null ||
            _currentPMTask.completionHistory!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PM task must be completed at least once to generate a report'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Generating completion report...'),
              ],
            ),
          ),
        );
      }

      // Generate the report
      await PMTaskCompletionReportService.generateCompletionReport(_currentPMTask);

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completion report generated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error generating completion report: $e');
      if (mounted) {
        // Close loading dialog if still open
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
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

  Future<void> _generateCompletionReportForCycle(int cycleIndex) async {
    // Validate cycle index
    if (_currentPMTask.completionHistory == null ||
        _currentPMTask.completionHistory!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PM task has no completion history'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      return;
    }

    if (cycleIndex < 0 || cycleIndex >= _currentPMTask.completionHistory!.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid completion cycle'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text('Generating report for Completion #${cycleIndex + 1}...'),
              ],
            ),
          ),
        );
      }

      // Generate the report for the specific cycle
      await PMTaskCompletionReportService.generateCompletionReportForCycle(
        _currentPMTask,
        cycleIndex,
      );

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report for Completion #${cycleIndex + 1} generated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error generating completion report for cycle: $e');
      if (mounted) {
        // Close loading dialog if still open
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
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

  @override
  Widget build(BuildContext context) {
    final isOverdue = _currentPMTask.isOverdue;
    final isDueToday = _currentPMTask.isDueToday;
    final isDueSoon = _currentPMTask.isDueSoon;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPMTask.taskName),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Only show edit/delete if PM task is not completed
          if (_currentPMTask.status != PMTaskStatus.completed &&
              _currentPMTask.status != PMTaskStatus.cancelled)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _editPMTask();
                } else if (value == 'reassign') {
                  _reassignTechnician();
                } else if (value == 'delete') {
                  _deletePMTask();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit PM Task'),
                    ],
                  ),
                ),
                if (_shouldShowReassignOption())
                  PopupMenuItem(
                    value: 'reassign',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add,
                          size: 20,
                          color: AppTheme.accentBlue,
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
                        'Delete PM Task',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Due Date Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: AppTheme.getStatusContainerDecoration(
                            AppTheme.getPMTaskStatusColor(
                              _currentPMTask.status.name,
                            ),
                          ),
                          child: Text(
                            _currentPMTask.status.name.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.getPMTaskStatusColor(
                                _currentPMTask.status.name,
                              ),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: AppTheme.getStatusContainerDecoration(
                              AppTheme.errorColor,
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else if (isDueToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: AppTheme.getStatusContainerDecoration(
                              AppTheme.warningColor,
                            ),
                            child: const Text(
                              'DUE TODAY',
                              style: TextStyle(
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else if (isDueSoon)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: AppTheme.getStatusContainerDecoration(
                              AppTheme.infoColor,
                            ),
                            child: const Text(
                              'DUE SOON',
                              style: TextStyle(
                                color: AppTheme.infoColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // PM Task Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'PM Task Information',
                            style: AppTheme.titleStyle.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        // Show timer if task is in progress
                        if (_currentPMTask.isInProgress &&
                            _currentPMTask.startedAt != null)
                          WorkTimer(
                            startTime: _currentPMTask.startedAt!,
                            isActive: !_currentPMTask.isPaused,
                            pauseHistory: _currentPMTask.pauseHistory,
                            pausedAt: _currentPMTask.pausedAt,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Task Name', _currentPMTask.taskName),
                    _buildInfoRow(
                      'Asset',
                      _currentPMTask.assetName ??
                          (_currentPMTask.assetId.isEmpty
                              ? 'General Maintenance (No Asset)'
                              : 'Unknown Asset'),
                    ),
                    if (_currentPMTask.assetLocation != null &&
                        _currentPMTask.assetLocation!.isNotEmpty)
                      _buildInfoRow(
                        'Location',
                        _currentPMTask.assetLocation!,
                      ),
                    _buildInfoRow('Description', _currentPMTask.description),
                    _buildInfoRow(
                      'Frequency',
                      _currentPMTask.frequencyDisplayName,
                    ),
                    if (_currentPMTask.assignedTechnicianName != null)
                      _buildInfoRow(
                        'Assigned To',
                        _currentPMTask.assignedTechnicianName!,
                      ),
                    if (_currentPMTask.createdBy != null)
                      _buildInfoRow(
                        'Created By',
                        _currentPMTask.createdBy!.name,
                      ),
                    _buildInfoRow(
                      'Created',
                      _formatDate(_currentPMTask.createdAt),
                    ),
                    if (_currentPMTask.lastCompletedAt != null)
                      _buildInfoRow(
                        'Last Completed',
                        _formatDate(_currentPMTask.lastCompletedAt!),
                      ),
                    if (_currentPMTask.nextDueDate != null)
                      _buildInfoRow(
                        'Next Due',
                        _formatDate(_currentPMTask.nextDueDate!),
                      ),
                    if (_currentPMTask.startedAt != null)
                      _buildInfoRow(
                        'Started',
                        _formatDate(_currentPMTask.startedAt!),
                      ),
                    if (_currentPMTask.completedAt != null)
                      _buildInfoRow(
                        'Completed',
                        _formatDate(_currentPMTask.completedAt!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Checklist Preview
            if (_currentPMTask.checklist != null &&
                _currentPMTask.checklist!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checklist',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._parseChecklist(_currentPMTask.checklist).map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_box_outline_blank,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: const TextStyle(fontSize: 14),
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
              const SizedBox(height: 16),
            ],

            // Completion History Section
            if (_currentPMTask.completionHistory != null &&
                _currentPMTask.completionHistory!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Completion History',
                            style: AppTheme.titleStyle.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_currentPMTask.completionHistory!.length} completion${_currentPMTask.completionHistory!.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      ..._currentPMTask.completionHistory!.asMap().entries.map((entry) {
                        final originalIndex = entry.key;
                        final completion = entry.value;
                        // Display index (most recent first)
                        final displayIndex = _currentPMTask.completionHistory!.length - originalIndex;
                        
                        final completedAt = completion['completedAt'] != null
                            ? DateTime.tryParse(completion['completedAt'] as String)
                            : null;
                        final completedBy = completion['completedByName'] as String? ?? 'Unknown';
                        final completedById = completion['completedBy'] as String?;
                        final notes = completion['notes'] as String?;
                        final durationMinutes = completion['durationMinutes'] as int?;
                        final durationSeconds = completion['durationSeconds'] as int? ??
                            (durationMinutes != null ? durationMinutes * 60 : null);
                        final laborCost = completion['laborCost'] as double?;
                        final partsCost = completion['partsCost'] as double?;
                        final totalCost = completion['totalCost'] as double?;
                        final checklist = completion['checklist'] as List<dynamic>?;
                        final technicianSignature = completion['technicianSignature'] as String?;
                        final technicianEffort = completion['technicianEffort'] as Map<String, dynamic>?;
                        final completionPhotoPath = completion['completionPhotoPath'] as String?;
                        
                        // Debug: Log completion photo path
                        debugPrint('📸 PM Task Completion #$displayIndex:');
                        debugPrint('   - completionPhotoPath: $completionPhotoPath');
                        debugPrint('   - completionPhotoPath type: ${completionPhotoPath.runtimeType}');
                        debugPrint('   - completionPhotoPath isNotEmpty: ${completionPhotoPath?.isNotEmpty ?? false}');
                        
                        // Get startedAt from PM task (since it's cleared after completion)
                        // We'll need to calculate it from completedAt and duration
                        final startedAt = completedAt != null && durationSeconds != null
                            ? completedAt.subtract(Duration(seconds: durationSeconds))
                            : _currentPMTask.startedAt;
                        
                        return _buildCompletionHistoryItem(
                          completedAt: completedAt,
                          completedBy: completedBy,
                          completedById: completedById,
                          notes: notes,
                          duration: durationSeconds,
                          laborCost: laborCost,
                          partsCost: partsCost,
                          totalCost: totalCost,
                          checklist: checklist,
                          technicianSignature: technicianSignature,
                          technicianEffort: technicianEffort,
                          completionPhotoPath: completionPhotoPath,
                          startedAt: startedAt,
                          index: displayIndex,
                          originalIndex: originalIndex, // Pass original index for report generation
                        );
                      }).toList().reversed,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Current Completion Notes (if currently completed)
            if (_currentPMTask.isCompleted &&
                _currentPMTask.completionNotes != null &&
                _currentPMTask.completionNotes!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Completion Notes',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentPMTask.completionNotes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (!_currentPMTask.isCompleted && !_currentPMTask.isCancelled) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actions',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_currentPMTask.isPending) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _startTask,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label:
                                Text(_isLoading ? 'Starting...' : 'Start Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                      if (_currentPMTask.isInProgress) ...[
                        // Pause/Resume button
                        if (_currentPMTask.isPaused) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _resumeTask,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Resume Task'),
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
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.warningColor),
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
                                    'Paused: ${_currentPMTask.pauseReason ?? "No reason provided"}',
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
                              onPressed: _isLoading ? null : _pauseTask,
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause Task'),
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
                            onPressed: _completeTask,
                            icon: const Icon(Icons.check),
                            label: const Text('Complete Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Generate Report Button
              if (_currentPMTask.status == PMTaskStatus.completed ||
                  (_currentPMTask.completionHistory != null &&
                      _currentPMTask.completionHistory!.isNotEmpty))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generateCompletionReport,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Generate Completion Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                ),

              // Activity History Section
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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

                          final activityLogs = _activityLogService
                              .getActivityLogs(_currentPMTask.id);

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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  String _formatDuration(int totalSeconds) =>
      formatWorkDurationSeconds(totalSeconds);

  Widget _buildCompletionHistoryItem({
    required DateTime? completedAt,
    required String completedBy,
    String? completedById,
    String? notes,
    int? duration,
    double? laborCost,
    double? partsCost,
    double? totalCost,
    List<dynamic>? checklist,
    String? technicianSignature,
    Map<String, dynamic>? technicianEffort,
    String? completionPhotoPath,
    DateTime? startedAt,
    required int index,
    required int originalIndex, // Original index in completionHistory list
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Completion #$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const Spacer(),
              if (completedAt != null)
                Text(
                  _formatDate(completedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCompletionRow(
            Icons.person_outline,
            'Completed by',
            completedBy,
          ),
          if (duration != null) ...[
            const SizedBox(height: 8),
            _buildCompletionRow(
              Icons.timer_outlined,
              'Duration',
              _formatDuration(duration),
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildCompletionRow(
              Icons.note_outlined,
              'Notes',
              notes,
            ),
          ],
          
          // Signature Section
          if (technicianSignature != null && technicianSignature.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCompletionSection(
              'Signature',
              [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: _buildSignatureImage(technicianSignature),
                ),
              ],
            ),
          ],
          
          // Generate Report Button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () => _generateCompletionReportForCycle(originalIndex),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: Text('Generate Report for Completion #$index'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentBlue,
                side: const BorderSide(color: AppTheme.accentBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Images Section
          Builder(
            builder: (context) {
              final hasCompletionPhoto = completionPhotoPath != null && 
                  completionPhotoPath.isNotEmpty;
              
              debugPrint('🖼️ Building PM Task Completion Photo Section:');
              debugPrint('   - completionPhotoPath: $completionPhotoPath');
              debugPrint('   - hasCompletionPhoto: $hasCompletionPhoto');
              
              if (hasCompletionPhoto) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildPhotoSection('Completion Photo', completionPhotoPath!),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Checklist Section
          if (checklist != null && checklist.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCompletionSection(
              'Checklist Items',
              [
                ...checklist.map((item) {
              final isCompleted = item is Map
                  ? (item['completed'] as bool? ?? false)
                  : false;
              final text = item is Map
                  ? (item['text'] as String? ?? item.toString())
                  : item.toString();
              return Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: isCompleted ? AppTheme.successColor : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? Colors.grey[700]
                              : Colors.grey[600],
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
                }).toList(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isHighlight
                  ? AppTheme.primaryColor
                  : Colors.grey[800],
              fontWeight: isHighlight
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildSignatureImage(String? signatureData) {
    if (signatureData == null || signatureData.isEmpty) {
      return const Center(
        child: Icon(Icons.draw, color: Colors.grey),
      );
    }

    // Check if it's a data URL (base64) - new format
    if (signatureData.startsWith('data:image')) {
      try {
        // Extract base64 string from data URL
        final base64String = signatureData.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error displaying signature from memory: $error');
            return const Center(
              child: Icon(Icons.draw, color: Colors.grey),
            );
          },
        );
      } catch (e, st) {
        debugPrint('Error decoding signature data URL: $e');
        return const Center(
          child: Icon(Icons.draw, color: Colors.grey),
        );
      }
    } else if (signatureData.startsWith('[') && signatureData.endsWith(']')) {
      // Old format: bytes.toString() - try to parse and convert
      try {
        // Parse the string representation of bytes list
        final bytesList = signatureData
            .replaceAll('[', '')
            .replaceAll(']', '')
            .split(',')
            .map((s) => int.parse(s.trim()))
            .toList();
        final bytes = Uint8List.fromList(bytesList);
        return Image.memory(
          bytes,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error displaying signature from old format: $error');
            return const Center(
              child: Icon(Icons.draw, color: Colors.grey),
            );
          },
        );
      } catch (e, st) {
        debugPrint('Error parsing old signature format: $e');
        return const Center(
          child: Icon(Icons.draw, color: Colors.grey),
        );
      }
    } else {
      // Assume it's a network URL or base64 string without data URL prefix
      try {
        // Try as base64 string first
        final bytes = base64Decode(signatureData);
        return Image.memory(
          bytes,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // If base64 decode fails, try as network URL
            return Image.network(
              signatureData,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.draw, color: Colors.grey),
                );
              },
            );
          },
        );
      } catch (e, st) {
        // Not base64, try as network URL
        return Image.network(
          signatureData,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading signature from network: $error');
            return const Center(
              child: Icon(Icons.draw, color: Colors.grey),
            );
          },
        );
      }
    }
  }

  Widget _buildPhotoSection(String title, String photoPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AuthenticatedImage(
              imageUrl: photoPath,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
              errorWidget: Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _parseChecklist(String? checklistJson) {
    if (checklistJson == null || checklistJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> checklistData = jsonDecode(checklistJson);
      return checklistData.map<String>((item) {
        if (item is String) {
          return item;
        } else if (item is Map<String, dynamic>) {
          final text = item['text'] ?? '';
          final required = item['required'] as bool? ?? false;
          return required ? '$text (Required)' : text;
        }
        return item.toString();
      }).toList();
    } catch (e, st) {
      return [];
    }
  }

  Future<void> _editPMTask() async {
    // Show edit dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditPMTaskDialog(pmTask: _currentPMTask),
    );

    if (result != null && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final unifiedProvider =
            Provider.of<UnifiedDataProvider>(context, listen: false);

        final updatedPMTask = _currentPMTask.copyWith(
          taskName: result['taskName'],
          description: result['description'],
          frequency: result['frequency'],
        );

        await unifiedProvider.updatePMTask(updatedPMTask);

        // Log activity
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          await _activityLogService.logActivity(
            entityId: _currentPMTask.id,
            entityType: 'pm_task',
            activityType: ActivityType.updated,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            description: 'Updated PM task details',
            additionalData: {
              'task_name': result['taskName'],
              'frequency': result['frequency'].toString().split('.').last,
            },
          );
        }

        setState(() {
          _currentPMTask = updatedPMTask;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PM task updated successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e, st) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'PmTaskDetail: update PM task',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  Future<void> _deletePMTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete PM Task?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete PM task "${_currentPMTask.taskName}"?\n\nThis action cannot be undone.',
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

        await unifiedProvider.deletePMTask(_currentPMTask.id);

        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate deletion
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PM task deleted successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e, st) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not delete PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'PmTaskDetail: delete PM task',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  // Reassign Technician
  Future<void> _reassignTechnician() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);

    // If current user is a technician who is assigned to this PM task, prevent reassignment
    if (currentUser?.role == 'technician' &&
        currentUser != null &&
        _currentPMTask.assignedTechnicianIds.contains(currentUser.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot reassign a PM task that is assigned to you',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Only admins and managers can reassign
    if (currentUser?.role != 'admin' && currentUser?.role != 'manager') {
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

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ReassignTechnicianDialog(
        currentTechnicianIds: _currentPMTask.assignedTechnicianIds,
        pmTaskId: _currentPMTask.id,
      ),
    );

    if (result != null && mounted) {
      final newTechnicianIds =
          (result['technicianIds'] as List?)?.cast<String>();

      setState(() {
        _isLoading = true;
      });

      try {
        await unifiedProvider.updatePMTaskTechnicians(
          _currentPMTask.id,
          newTechnicianIds ?? <String>[],
        );

        // Reload PM task data
        final updatedPMTask = unifiedProvider.pmTasks.firstWhere(
          (pm) => pm.id == _currentPMTask.id,
          orElse: () => _currentPMTask,
        );

        // Log activity
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          final oldSet = _currentPMTask.assignedTechnicianIds.toSet();
          final newSet = (newTechnicianIds ?? <String>[])
              .where((id) => id.isNotEmpty)
              .toSet();
          final activityType = newSet.isEmpty && oldSet.isNotEmpty
              ? ActivityType.unassigned
              : (oldSet.isEmpty && newSet.isNotEmpty)
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

          final oldTech = namesFor(oldSet);
          final newTech = namesFor(newSet);

          await _activityLogService.logActivity(
            entityId: _currentPMTask.id,
            entityType: 'pm_task',
            activityType: activityType,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            oldValue: oldTech,
            newValue: newTech,
          );
        }

        setState(() {
          _currentPMTask = updatedPMTask;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (newTechnicianIds == null || newTechnicianIds.isEmpty)
                    ? 'Technicians cleared successfully'
                    : 'Technician assignments updated',
              ),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
        }
      } catch (e, st) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not reassign technician. Please try again.',
          stackTrace: st,
          contextLabel: 'pm_task_detail_screen: Could not reassign technician.',
          backgroundColor: AppTheme.errorColor,
        );
        }
      }
    }
  }

  bool _shouldShowReassignOption() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    
    // Only admins and managers can see reassign option
    if (currentUser?.role != 'admin' && currentUser?.role != 'manager') {
      return false;
    }
    
    // If current user is a technician who is assigned to this PM task, hide reassign option
    if (currentUser?.role == 'technician' &&
        currentUser != null &&
        _currentPMTask.assignedTechnicianIds.contains(currentUser.id)) {
      return false;
    }
    
    return true;
  }
}

// Reassign Technician Dialog for PM Tasks
class _ReassignTechnicianDialog extends StatefulWidget {
  const _ReassignTechnicianDialog({
    required this.currentTechnicianIds,
    required this.pmTaskId,
  });
  final List<String>? currentTechnicianIds;
  final String pmTaskId;

  @override
  State<_ReassignTechnicianDialog> createState() =>
      _ReassignTechnicianDialogState();
}

class _ReassignTechnicianDialogState extends State<_ReassignTechnicianDialog> {
  final Set<String> _selectedTechnicianIds = <String>{};
  bool _isLoading = true;
  List<User> _technicians = [];

  @override
  void initState() {
    super.initState();
    if (widget.currentTechnicianIds != null) {
      _selectedTechnicianIds
          .addAll(widget.currentTechnicianIds!.where((id) => id.isNotEmpty));
    }
    _loadTechnicians();
  }

  Future<void> _loadTechnicians() async {
    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final technicians = unifiedProvider.users
          .where((user) => user.role == 'technician')
          .toList();

      setState(() {
        _technicians = technicians;
        _isLoading = false;
      });
    } catch (e, st) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Reassign Technician'),
        content: _isLoading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select one or more technicians for this PM task:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: AppTheme.spacingS,
                    runSpacing: AppTheme.spacingS,
                    children: _technicians
                        .map(
                          (tech) => FilterChip(
                            selected: _selectedTechnicianIds.contains(tech.id),
                            showCheckmark: true,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTechnicianIds.add(tech.id);
                                } else {
                                  _selectedTechnicianIds.remove(tech.id);
                                }
                              });
                            },
                            label: SizedBox(
                              width: 150,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppTheme.accentBlue,
                                    child: Text(
                                      tech.name.isNotEmpty
                                          ? tech.name[0].toUpperCase()
                                          : 'T',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tech.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.smallText.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (_selectedTechnicianIds.isEmpty) Text(
                          'No technicians selected',
                          style: AppTheme.smallText.copyWith(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ) else Text(
                          'Selected: ${_selectedTechnicianIds.length}',
                          style: AppTheme.smallText.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => setState(_selectedTechnicianIds.clear),
            child: const Text('Clear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop({
                'technicianIds': _selectedTechnicianIds.toList(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}

// Edit PM Task Dialog
class _EditPMTaskDialog extends StatefulWidget {
  const _EditPMTaskDialog({required this.pmTask});
  final PMTask pmTask;

  @override
  State<_EditPMTaskDialog> createState() => _EditPMTaskDialogState();
}

class _EditPMTaskDialogState extends State<_EditPMTaskDialog> {
  late TextEditingController _taskNameController;
  late TextEditingController _descriptionController;
  late PMTaskFrequency _frequency;

  @override
  void initState() {
    super.initState();
    _taskNameController = TextEditingController(text: widget.pmTask.taskName);
    _descriptionController =
        TextEditingController(text: widget.pmTask.description);
    _frequency = widget.pmTask.frequency;
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit PM Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _taskNameController,
                decoration: const InputDecoration(
                  labelText: 'Task Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PMTaskFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: PMTaskFrequency.values
                    .map(
                      (frequency) => DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency.toString().split('.').last),
                      ),
                    )
                    .toList(),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_taskNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a task name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop({
                'taskName': _taskNameController.text.trim(),
                'description': _descriptionController.text.trim(),
                'frequency': _frequency,
              });
            },
            child: const Text('Save'),
          ),
        ],
      );
}
