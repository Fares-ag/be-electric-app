import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/locator.dart';
import '../../models/activity_log.dart';
import '../../models/pm_task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/activity_log_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/offline_queue_service.dart';
import '../../repositories/cmms_repositories.dart';
import '../../utils/app_theme.dart';
import '../../utils/offline_network.dart';
import '../../utils/offline_service_access.dart';
import '../../utils/user_facing_errors.dart';
import '../../widgets/signature_widget.dart';

class PMTaskCompletionScreen extends StatefulWidget {
  const PMTaskCompletionScreen({
    required this.pmTask,
    super.key,
  });
  final PMTask pmTask;

  @override
  State<PMTaskCompletionScreen> createState() => _PMTaskCompletionScreenState();
}

class _PMTaskCompletionScreenState extends State<PMTaskCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final ActivityLogService _activityLogService = sl<ActivityLogService>();

  List<ChecklistItem> _checklistItems = [];
  String? _technicianSignature;
  bool _isLoading = false;

  // Image capture variables
  final ImagePicker _picker = ImagePicker();
  String? _completionPhotoPath;

  @override
  void initState() {
    super.initState();
    _initializeChecklist();
  }

  /// Calculate actual work duration accounting for paused time
  /// Returns duration in seconds for more precise calculation
  int? _calculateActualWorkDurationSeconds(PMTask pmTask, DateTime completionTime) {
    if (pmTask.startedAt == null) return null;

    // Total elapsed time from start to completion
    final totalElapsed = completionTime.difference(pmTask.startedAt!);

    // Calculate total paused time from pause history (in seconds)
    int totalPausedSeconds = 0;
    if (pmTask.pauseHistory != null && pmTask.pauseHistory!.isNotEmpty) {
      for (final pauseRecord in pmTask.pauseHistory!) {
        final pausedAt = _parseDateTimeFromPauseHistory(pauseRecord['pausedAt']);
        final resumedAt = _parseDateTimeFromPauseHistory(pauseRecord['resumedAt']);

        if (pausedAt != null && resumedAt != null) {
          final pausedDuration = resumedAt.difference(pausedAt);
          totalPausedSeconds += pausedDuration.inSeconds;
        }
      }
    }

    // If currently paused, add the current pause duration
    if (pmTask.isPaused && pmTask.pausedAt != null) {
      final currentPauseDuration = completionTime.difference(pmTask.pausedAt!);
      totalPausedSeconds += currentPauseDuration.inSeconds;
    }

    // Actual work duration = total elapsed - total paused (in seconds)
    final actualWorkDurationSeconds = totalElapsed.inSeconds - totalPausedSeconds;
    return actualWorkDurationSeconds > 0 ? actualWorkDurationSeconds : 0;
  }

  /// Format duration in seconds to "X min Y sec" format
  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) {
      return '$totalSeconds sec';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (seconds == 0) {
      return '$minutes min';
    }
    return '$minutes min $seconds sec';
  }

  /// Parse DateTime from pause history (handles Timestamp, DateTime, or String)
  DateTime? _parseDateTimeFromPauseHistory(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    // Handle Firestore Timestamp stored as map (from JSON)
    if (value is Map) {
      if (value.containsKey('_seconds')) {
        final seconds = value['_seconds'] as int?;
        final nanoseconds = value['_nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds ~/ 1000000),
          );
        }
      }
      // Try parsing as ISO string if it's a map with a string value
      if (value.containsKey('value') && value['value'] is String) {
        return DateTime.tryParse(value['value']);
      }
    }
    return null;
  }

  void _initializeChecklist() {
    if (widget.pmTask.checklist != null &&
        widget.pmTask.checklist!.isNotEmpty) {
      try {
        final List<dynamic> checklistData =
            jsonDecode(widget.pmTask.checklist!);
        _checklistItems = checklistData.map((item) {
          if (item is String) {
            return ChecklistItem(
              text: item,
              isRequired: true,
            );
          } else if (item is Map<String, dynamic>) {
            DateTime? completedAt;
            final completedAtRaw = item['completedAt'];
            if (completedAtRaw is String) {
              completedAt = DateTime.tryParse(completedAtRaw);
            }
            return ChecklistItem(
              text: item['text'] ?? '',
              isCompleted: item['completed'] ?? false,
              isRequired: item['required'] ?? false,
              completedAt: completedAt,
              notes: item['notes'] as String?,
            );
          }
          return ChecklistItem(
            text: item.toString(),
          );
        }).toList();
      } catch (e, st) {
        _checklistItems = _defaultChecklistItems();
      }
    } else {
      _checklistItems = _defaultChecklistItems();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _toggleChecklistItem(int index) {
    setState(() {
      final item = _checklistItems[index];
      final newValue = !item.isCompleted;
      item
        ..isCompleted = newValue
        ..completedAt = newValue ? DateTime.now() : null;
    });
  }

  List<ChecklistItem> _defaultChecklistItems() => [
        ChecklistItem(
          text: 'Inspect equipment condition',
          isRequired: true,
        ),
        ChecklistItem(
          text: 'Check for any visible damage',
          isRequired: true,
        ),
        ChecklistItem(
          text: 'Test equipment functionality',
          isRequired: true,
        ),
        ChecklistItem(
          text: 'Clean and lubricate as needed',
        ),
        ChecklistItem(
          text: 'Document findings',
          isRequired: true,
        ),
      ];

  Future<void> _captureTechnicianSignature() async {
    final signature = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const SignatureWidget(
          title: 'Technician Signature',
          description: 'Please sign to confirm PM task completion',
        ),
      ),
    );

    if (signature != null) {
      setState(() {
        _technicianSignature = signature;
      });
    }
  }

  Future<void> _captureCompletionPhoto() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _completionPhotoPath = pickedFile.path;
      });
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async => showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

  PMTask _stripPendingPhotoFromHistory(PMTask pmTask) {
    final history = pmTask.completionHistory;
    if (history == null || history.isEmpty) return pmTask;

    final patched = List<Map<String, dynamic>>.from(history);
    final last = Map<String, dynamic>.from(patched.last);
    last.remove('completionPhotoPath');
    last['photoPendingSync'] = true;
    patched[patched.length - 1] = last;
    return pmTask.copyWith(completionHistory: patched, isOffline: true);
  }

  Future<void> _completeTask() async {
    // Prevent double submission
    if (_isLoading) {
      debugPrint('⚠️ PMTaskCompletion: Already processing, ignoring duplicate submission');
      return;
    }
    
    if (!_formKey.currentState!.validate()) return;

    // Check required checklist items are completed
    final hasIncompleteRequired = _checklistItems.any(
      (item) => item.isRequired && !item.isCompleted,
    );
    if (hasIncompleteRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please finish all required checklist items before closing'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    if (_technicianSignature == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Technician signature is required'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get providers before async operations to avoid BuildContext issues
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Update checklist with completion status
      final updatedChecklist = _checklistItems.map((item) {
        final map = <String, dynamic>{
          'text': item.text,
          'required': item.isRequired,
          'completed': item.isCompleted,
        };
        if (item.completedAt != null) {
          map['completedAt'] = item.completedAt!.toIso8601String();
        }
        if (item.notes?.isNotEmpty ?? false) {
          map['notes'] = item.notes;
        }
        return map;
      }).toList();

      // Upload completion photo when online; defer to atomic offline queue otherwise.
      String? completionPhotoUrl;
      String? pendingLocalPhotoPath;

      if (_completionPhotoPath != null) {
        final offlineMode = AppConfig.isOfflineModeEnabled;
        final isOnline = sl<ConnectivityService>().isOnline;

        if (offlineMode && !isOnline) {
          pendingLocalPhotoPath = _completionPhotoPath;
        } else {
          try {
            final workOrderRepository = CmmsRepositories.workOrders;
            final xFile = XFile(_completionPhotoPath!);
            debugPrint(
              '📸 Uploading PM task completion photo for task ${widget.pmTask.id}',
            );

            completionPhotoUrl =
                await workOrderRepository.uploadPMTaskCompletionPhoto(
              photoFile: xFile,
              pmTaskId: widget.pmTask.id,
            );

            if (completionPhotoUrl != null) {
              debugPrint(
                '✅ PM task completion photo uploaded: $completionPhotoUrl',
              );
            }
          } catch (e, st) {
            debugPrint('❌ Error uploading PM task completion photo: $e');
            if (offlineMode && isLikelyNetworkError(e)) {
              pendingLocalPhotoPath = _completionPhotoPath;
            }
          }
        }
      }
      final completionTime = DateTime.now();
      // Calculate actual work duration accounting for paused time (in seconds)
      final durationSeconds = _calculateActualWorkDurationSeconds(
        widget.pmTask,
        completionTime,
      );
      final durationMinutes = durationSeconds != null ? durationSeconds ~/ 60 : null;
      Map<String, int>? technicianEffort;
      if ((durationMinutes ?? 0) > 0 &&
          widget.pmTask.assignedTechnicianIds.isNotEmpty) {
        technicianEffort = {
          for (final techId in widget.pmTask.assignedTechnicianIds)
            techId: durationMinutes!,
        };
      }

      // Create completion record for history
      final completionRecord = <String, dynamic>{
        'completedAt': completionTime.toIso8601String(),
        'completedBy': authProvider.currentUser?.id ?? '',
        'completedByName': authProvider.currentUser?.name ?? 'Unknown',
        'checklist': updatedChecklist,
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        'technicianSignature': _technicianSignature,
        'durationMinutes': durationMinutes,
        'durationSeconds': durationSeconds,
        'technicianEffort': technicianEffort,
        'laborCost': widget.pmTask.laborCost,
        'partsCost': widget.pmTask.partsCost,
        'totalCost': widget.pmTask.totalCost,
        'completionPhotoPath': completionPhotoUrl ?? pendingLocalPhotoPath,
        'photoPendingSync': pendingLocalPhotoPath != null,
      };

      // Add to completion history
      final existingHistory = widget.pmTask.completionHistory ?? [];
      final updatedHistory = [...existingHistory, completionRecord];

      // Calculate next due date based on frequency
      final nextDueDate = _calculateNextDueDate(
        widget.pmTask.frequency,
        widget.pmTask.intervalDays,
        completionTime,
      );

      // Update PM task: add to history, reset to pending, update next due date
      final updatedPMTask = widget.pmTask.copyWith(
        status: PMTaskStatus.pending, // Reset to pending for next cycle
        checklist: jsonEncode(updatedChecklist), // Keep checklist template
        technicianSignature: null, // Clear current signature
        completedAt: null, // Clear current completion
        completionNotes: null, // Clear current notes
        lastCompletedAt: completionTime, // Update last completed
        nextDueDate: nextDueDate, // Update next due date
        technicianEffortMinutes: null, // Clear current effort
        laborCost: null, // Clear current costs
        partsCost: null,
        totalCost: null,
        startedAt: null, // Clear start time
        completionHistory: updatedHistory, // Add to history
        isOffline: pendingLocalPhotoPath != null,
      );

      final offlineMode = AppConfig.isOfflineModeEnabled;
      final isOnline = sl<ConnectivityService>().isOnline;
      final useAtomicOfflineQueue =
          pendingLocalPhotoPath != null || (offlineMode && !isOnline);

      if (useAtomicOfflineQueue) {
        final pmForQueue = pendingLocalPhotoPath != null
            ? _stripPendingPhotoFromHistory(updatedPMTask)
            : updatedPMTask;

        final queueData = <String, dynamic>{
          'pmTask': pmForQueue.toMap(),
        };
        if (pendingLocalPhotoPath != null) {
          queueData['pendingPhotoFilePath'] = pendingLocalPhotoPath;
          queueData['pendingPhotoFileName'] =
              'pm_task_completion_${widget.pmTask.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        }

        await resolveOfflineQueueService().enqueue(
          QueuedOperation(
            id: 'complete_${updatedPMTask.id}',
            type: OperationType.completePMTask,
            data: queueData,
            createdAt: DateTime.now(),
          ),
        );

        await unifiedProvider.applyLocalPMTaskUpdate(updatedPMTask);
        debugPrint('✅ PM task completion queued atomically for sync');
      } else {
        await unifiedProvider.updatePMTask(updatedPMTask);
        debugPrint('✅ PM task updated online');
      }

      // Log activity with completion cycle number
      if (mounted && authProvider.currentUser != null) {
        // Determine completion cycle number (this will be the next completion)
        final completionCycle = (widget.pmTask.completionHistory?.length ?? 0) + 1;
        final durationText = durationSeconds != null 
            ? _formatDuration(durationSeconds)
            : null;
        await _activityLogService.logActivity(
          entityId: widget.pmTask.id,
          entityType: 'pm_task',
          activityType: ActivityType.completed,
          userId: authProvider.currentUser!.id,
          userName: authProvider.currentUser!.name,
          description: durationText != null 
              ? 'Completed (Completion #$completionCycle) in $durationText'
              : 'Completed (Completion #$completionCycle)',
          additionalData: {
            'completionCycle': completionCycle,
            if (durationMinutes != null) 'durationMinutes': durationMinutes,
            if (durationSeconds != null) 'durationSeconds': durationSeconds,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useAtomicOfflineQueue
                  ? (pendingLocalPhotoPath != null
                      ? 'PM task completed — photo and changes pending sync'
                      : 'PM task completed locally — pending sync when online')
                  : 'PM task completed successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not complete PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'PmTaskCompletion: complete PM task',
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

  @override
  Widget build(BuildContext context) {
    final completedCount =
        _checklistItems.where((item) => item.isCompleted).length;
    final totalCount = _checklistItems.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete PM Task'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task Information Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Information',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Task Name', widget.pmTask.taskName),
                      _buildInfoRow(
                        'Asset',
                        widget.pmTask.assetName ?? 'Unknown Asset',
                      ),
                      _buildInfoRow(
                        'Location',
                        widget.pmTask.assetLocation ?? 'Unknown Location',
                      ),
                      if (widget.pmTask.description.isNotEmpty)
                        _buildInfoRow(
                          'Description',
                          widget.pmTask.description,
                        ),
                      _buildInfoRow(
                        'Frequency',
                        widget.pmTask.frequencyDisplayName,
                      ),
                      _buildInfoRow(
                        'Due Date',
                        _formatDate(widget.pmTask.nextDue),
                      ),
                      _buildInfoRow(
                        'Status',
                        widget.pmTask.status.name.toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Progress Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Checklist Progress',
                            style: AppTheme.titleStyle.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            '$completedCount/$totalCount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}% Complete',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Checklist Section
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
                      ..._checklistItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _buildChecklistItem(index, item);
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes',
                          hintText:
                              'Add any additional observations or notes...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Signature Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signature',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Technician Signature',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 60,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _technicianSignature != null
                                      ? const Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: AppTheme.successColor,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Signed',
                                                style: TextStyle(
                                                  color: AppTheme.successColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const Center(
                                          child: Text(
                                            'Tap to sign',
                                            style:
                                                TextStyle(color: Colors.grey),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _captureTechnicianSignature,
                            child: const Text('Sign'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Completion Photos Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completion Photos',
                        style: AppTheme.titleStyle.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Document the PM task completion with photos (optional)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Completion Photo
                      _buildPhotoSection(
                        title: 'Completion Photo',
                        description: 'Photo showing the completed PM task',
                        photoPath: _completionPhotoPath,
                        onCapture: _captureCompletionPhoto,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Complete Task Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Complete Task',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
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
              width: 100,
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

  Widget _buildChecklistItem(int index, ChecklistItem item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => _toggleChecklistItem(index),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        item.isCompleted ? AppTheme.primaryColor : Colors.grey,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: item.isCompleted
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                ),
                child: item.isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 16,
                              decoration: item.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.isCompleted
                                  ? Colors.grey[600]
                                  : Colors.black,
                            ),
                          ),
                        ),
                        if (item.isRequired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Required',
                              style: TextStyle(
                                color: AppTheme.warningColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (item.completedAt != null)
                      Text(
                        'Completed ${_formatDate(item.completedAt)}',
                        style: AppTheme.smallText.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildPhotoSection({
    required String title,
    required String description,
    required String? photoPath,
    required VoidCallback onCapture,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (photoPath != null) ...[
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(photoPath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Photo'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _completionPhotoPath = null;
                  });
                },
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  /// Calculate next due date based on frequency
  DateTime _calculateNextDueDate(
    PMTaskFrequency frequency,
    int intervalDays,
    DateTime completionDate,
  ) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return completionDate.add(const Duration(days: 1));
      case PMTaskFrequency.weekly:
        return completionDate.add(const Duration(days: 7));
      case PMTaskFrequency.monthly:
        return completionDate.add(const Duration(days: 30));
      case PMTaskFrequency.quarterly:
        return completionDate.add(const Duration(days: 90));
      case PMTaskFrequency.semiAnnually:
        return completionDate.add(const Duration(days: 180));
      case PMTaskFrequency.annually:
        return completionDate.add(const Duration(days: 365));
      case PMTaskFrequency.asNeeded:
        // For "as needed", use intervalDays or default to 30 days
        return completionDate.add(Duration(days: intervalDays > 0 ? intervalDays : 30));
    }
  }
}

class ChecklistItem {
  ChecklistItem({
    required this.text,
    this.isCompleted = false,
    this.isRequired = false,
    this.completedAt,
    this.notes,
  });

  final String text;
  bool isCompleted;
  final bool isRequired;
  DateTime? completedAt;
  String? notes;
}
