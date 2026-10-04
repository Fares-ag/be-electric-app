import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/locator.dart';
import '../../models/activity_log.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../services/activity_log_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/offline_network.dart';
import '../../utils/user_facing_errors.dart';
import '../../utils/work_order_completion_policy.dart';
import '../../utils/work_order_duration.dart';
import '../../widgets/signature_widget.dart';

class WorkOrderCompletionScreen extends StatefulWidget {
  const WorkOrderCompletionScreen({
    required this.workOrder,
    super.key,
  });
  final WorkOrder workOrder;

  @override
  State<WorkOrderCompletionScreen> createState() =>
      _WorkOrderCompletionScreenState();
}

class _WorkOrderCompletionScreenState extends State<WorkOrderCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correctiveActionsController = TextEditingController();
  final _recommendationsController = TextEditingController();
  final _laborCostController = TextEditingController();
  final _partsCostController = TextEditingController();

  DateTime? _nextMaintenanceDate;
  String? _technicianSignature;
  bool _isLoading = false;

  // Image capture variables
  final ImagePicker _picker = ImagePicker();
  final List<String> _completionPhotoPaths = [];
  final ActivityLogService _activityLogService = sl<ActivityLogService>();

  @override
  void dispose() {
    _correctiveActionsController.dispose();
    _recommendationsController.dispose();
    _laborCostController.dispose();
    _partsCostController.dispose();
    super.dispose();
  }

  Future<void> _selectNextMaintenanceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _nextMaintenanceDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _nextMaintenanceDate) {
      setState(() {
        _nextMaintenanceDate = picked;
      });
    }
  }

  Future<void> _captureTechnicianSignature() async {
    final signature = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const SignatureWidget(
          title: 'Technician Signature',
          description: 'Please sign to confirm work completion',
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
      debugPrint('📸 Completion photo captured: ${pickedFile.path}');
      setState(() {
        _completionPhotoPaths.add(pickedFile.path);
      });
    }
  }

  void _removeCompletionPhoto(int index) {
    setState(() {
      _completionPhotoPaths.removeAt(index);
    });
  }


  Future<ImageSource?> _showImageSourceDialog() async =>
      showModalBottomSheet<ImageSource>(
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

  Future<void> _closeTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final blockMessage = WorkOrderCompletionPolicy.blockingMessage(
      technicianSignature: _technicianSignature,
    );
    if (blockMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blockMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);

      // Parse cost values
      final laborCost = _laborCostController.text.isNotEmpty
          ? double.tryParse(_laborCostController.text)
          : null;
      final partsCost = _partsCostController.text.isNotEmpty
          ? double.tryParse(_partsCostController.text)
          : null;
      final totalCost = (laborCost ?? 0.0) + (partsCost ?? 0.0);

      // Upload completion photos when online; otherwise stage local paths for sync queue.
      List<String> completionPhotoRefs = [];
      final pendingLocalPhotoPaths = <String>[];
      final offlineMode = AppConfig.isOfflineModeEnabled;
      final isOnline = sl<ConnectivityService>().isOnline;
      debugPrint('📷 Photo capture status:');
      debugPrint('   - _completionPhotoPaths count: ${_completionPhotoPaths.length}');
      debugPrint('   - online=$isOnline offlineMode=$offlineMode');

      if (_completionPhotoPaths.isNotEmpty) {
        if (offlineMode && !isOnline) {
          pendingLocalPhotoPaths.addAll(_completionPhotoPaths);
          completionPhotoRefs = List<String>.from(_completionPhotoPaths);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Photos saved on device. They will upload when you are back online.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          try {
            final workOrderRepository = CmmsRepositories.workOrders;

            for (final path in _completionPhotoPaths) {
              final photoFile = XFile(path);
              debugPrint(
                '📸 Uploading completion photo for work order ${widget.workOrder.id}',
              );
              final url = await workOrderRepository.uploadCompletionPhoto(
                photoFile: photoFile,
                workOrderId: widget.workOrder.id,
                photoType: 'completion',
              );
              if (url != null && url.isNotEmpty) {
                completionPhotoRefs.add(url);
              }
            }
            debugPrint(
              '✅ Completion photos uploaded: ${completionPhotoRefs.length}',
            );
          } catch (e, st) {
            debugPrint('Error uploading completion photos: $e');
            if (offlineMode && isLikelyNetworkError(e)) {
              pendingLocalPhotoPaths.addAll(_completionPhotoPaths);
              completionPhotoRefs = List<String>.from(_completionPhotoPaths);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Photos staged offline. They will upload when connectivity returns.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Warning: Photos could not be uploaded. Work order will be saved without photos.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }
      }

      // Update work order with completion details
      debugPrint(
        '💾 Saving work order with completionPhotoPaths: $completionPhotoRefs',
      );

      final completionTime = DateTime.now();
      final workDurationSeconds = calculateWorkDurationSeconds(
        widget.workOrder,
        endTime: completionTime,
      );

      final updatedWorkOrder = widget.workOrder.copyWith(
        status: WorkOrderStatus.completed,
        correctiveActions: _correctiveActionsController.text.trim(),
        recommendations: _recommendationsController.text.trim(),
        nextMaintenanceDate: _nextMaintenanceDate,
        technicianSignature: _technicianSignature,
        completedAt: completionTime,
        workDurationSeconds: workDurationSeconds,
        laborCost: laborCost,
        partsCost: partsCost,
        totalCost: totalCost > 0 ? totalCost : null,
        completionPhotoPath: completionPhotoRefs.isNotEmpty
            ? completionPhotoRefs.first
            : (pendingLocalPhotoPaths.isNotEmpty
                ? pendingLocalPhotoPaths.first
                : null),
        completionPhotoPaths: completionPhotoRefs.isNotEmpty
            ? completionPhotoRefs
            : (pendingLocalPhotoPaths.isNotEmpty ? pendingLocalPhotoPaths : null),
        beforePhotoPath: null,
        afterPhotoPath: null,
      );

      debugPrint('📝 Work order copyWith result:');
      debugPrint('   - completionPhotoPath: ${updatedWorkOrder.completionPhotoPath}');
      debugPrint('   - completionPhotoPaths: ${updatedWorkOrder.completionPhotoPaths}');
      debugPrint('   - pendingLocalPhotoPaths: $pendingLocalPhotoPaths');

      final useAtomicOfflineQueue =
          pendingLocalPhotoPaths.isNotEmpty || (offlineMode && !isOnline);

      if (useAtomicOfflineQueue) {
        await unifiedProvider.completeWorkOrder(
          updatedWorkOrder,
          pendingLocalPhotoPaths: pendingLocalPhotoPaths,
        );
        debugPrint('✅ Work order completion queued atomically for sync');
      } else {
        await unifiedProvider.updateWorkOrder(updatedWorkOrder);
        debugPrint('✅ Work order updated online');
      }

      if (mounted) {
        // Initialize activity log service if needed
        await _activityLogService.initialize();
        
        // Log activity
        if (authProvider.currentUser != null) {
          await _activityLogService.logActivity(
            entityId: widget.workOrder.id,
            entityType: 'work_order',
            activityType: ActivityType.completed,
            userId: authProvider.currentUser!.id,
            userName: authProvider.currentUser!.name,
            description: 'Work order completed',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                useAtomicOfflineQueue
                    ? (pendingLocalPhotoPaths.isNotEmpty
                        ? 'Work order completed — photos and changes pending sync'
                        : 'Work order completed locally — pending sync when online')
                    : 'Work order completed successfully',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not complete work order. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkOrderCompletion: complete work order',
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Complete Work Order'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket Information Section (Read-only)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ticket Information',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        _buildInfoRow(
                          'Ticket No',
                          widget.workOrder.ticketNumber,
                        ),
                        _buildInfoRow(
                          'Asset',
                          widget.workOrder.assetName ??
                              (widget.workOrder.assetId == null
                                  ? 'General Maintenance (No Asset)'
                                  : 'Unknown Asset'),
                        ),
                        _buildInfoRow(
                          'Location',
                          widget.workOrder.assetLocation ?? 'Unknown Location',
                        ),
                        _buildInfoRow(
                          'Problem Description',
                          widget.workOrder.problemDescription,
                        ),
                        _buildInfoRow(
                          'Priority',
                          widget.workOrder.priority.name.toUpperCase(),
                        ),
                        _buildInfoRow(
                          'Status',
                          widget.workOrder.status.name.toUpperCase(),
                        ),
                        if (widget.workOrder.assignedTechnicianName != null)
                          _buildInfoRow(
                            'Assigned To',
                            widget.workOrder.assignedTechnicianName!,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Work Log Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Log',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Corrective Actions Taken
                        TextFormField(
                          controller: _correctiveActionsController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Corrective Actions Taken',
                            hintText:
                                'Describe the actions taken to resolve the issue...',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please describe the corrective actions taken';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Recommendations for Prevention
                        TextFormField(
                          controller: _recommendationsController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Recommendations for Prevention',
                            hintText:
                                'Suggestions to prevent this issue from recurring...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Cost Information Section
                        const Text(
                          'Cost Information (QAR)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Labor Cost
                        TextFormField(
                          controller: _laborCostController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Labor Cost (QAR)',
                            hintText: 'Enter labor cost in Qatari Riyals',
                            prefixText: 'QAR ',
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final cost = double.tryParse(value);
                              if (cost == null || cost < 0) {
                                return 'Please enter a valid cost amount';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Parts Cost
                        TextFormField(
                          controller: _partsCostController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Parts Cost (QAR)',
                            hintText: 'Enter parts cost in Qatari Riyals',
                            prefixText: 'QAR ',
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final cost = double.tryParse(value);
                              if (cost == null || cost < 0) {
                                return 'Please enter a valid cost amount';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Next Maintenance Schedule
                        InkWell(
                          onTap: _selectNextMaintenanceDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Next Maintenance Schedule',
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _nextMaintenanceDate != null
                                  ? '${_nextMaintenanceDate!.day}/${_nextMaintenanceDate!.month}/${_nextMaintenanceDate!.year}'
                                  : 'Select date',
                              style: TextStyle(
                                color: _nextMaintenanceDate != null
                                    ? Colors.black
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Signatures Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Technician Signature',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        const Text(
                          'Sign to confirm work completion. Requestor sign-off is not required on site.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: AppTheme.spacingM),

                        // Technician Signature
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Signature of Technician',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  Container(
                                    height: 60,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusS,
                                      ),
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
                                                    color:
                                                        AppTheme.successColor,
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
                const SizedBox(height: AppTheme.spacingM),

                // Completion Photos Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completion Photos',
                          style: AppTheme.titleStyle.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        const Text(
                          'Document the work completion with photos (optional). You can add multiple.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        if (_completionPhotoPaths.isNotEmpty) ...[
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _completionPhotoPaths.length,
                              itemBuilder: (context, index) {
                                final path = _completionPhotoPaths[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: FutureBuilder<Uint8List>(
                                            future: XFile(path).readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: CircularProgressIndicator(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: IconButton(
                                          onPressed: () => _removeCompletionPhoto(index),
                                          icon: const Icon(Icons.close),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black54,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.all(4),
                                            minimumSize: const Size(28, 28),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        OutlinedButton.icon(
                          onPressed: _captureCompletionPhoto,
                          icon: const Icon(Icons.add_a_photo),
                          label: Text(
                            _completionPhotoPaths.isEmpty
                                ? 'Add Completion Photo'
                                : 'Add Another Photo',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Close Ticket Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _closeTicket,
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
                            'Close Ticket',
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

}
