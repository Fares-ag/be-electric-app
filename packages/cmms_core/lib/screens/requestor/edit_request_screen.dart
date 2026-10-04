import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../app/cmms_app_mode_scope.dart';
import '../../config/cmms_app_mode.dart';
import '../../models/work_order.dart';
import '../../providers/unified_data_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../utils/app_theme.dart';
import '../../utils/edit_photo_upload_decision.dart';
import '../../utils/requestor_category_mapper.dart';
import '../../utils/requestor_home_navigation.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/requestor_more_menu.dart';
import '../../utils/user_facing_errors.dart';

class EditRequestScreen extends StatefulWidget {
  const EditRequestScreen({
    required this.workOrder,
    super.key,
  });
  final WorkOrder workOrder;

  @override
  State<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends State<EditRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemDescriptionController = TextEditingController();
  bool _isLoading = false;
  String _selectedCategoryIssue = kRequestorCategoryIssueOptions.last;

  // Photos: keep existing URLs editable + new captures/uploads
  final ImagePicker _picker = ImagePicker();
  final _workOrderRepository = CmmsRepositories.workOrders;
  late List<String> _existingProblemPhotoUrls;
  final List<XFile> _newLocalPhotos = [];

  @override
  void initState() {
    super.initState();
    _problemDescriptionController.text = widget.workOrder.problemDescription;
    _selectedCategoryIssue = resolveRequestorCategoryIssueLabel(
      widget.workOrder.category,
    );
    _existingProblemPhotoUrls = widget.workOrder.photoPaths != null &&
            widget.workOrder.photoPaths!.isNotEmpty
        ? List<String>.from(widget.workOrder.photoPaths!)
        : (widget.workOrder.photoPath != null &&
                widget.workOrder.photoPath!.isNotEmpty
            ? [widget.workOrder.photoPath!]
            : <String>[]);
  }

  @override
  void dispose() {
    _problemDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photo != null && mounted) {
        setState(() {
          _newLocalPhotos.add(photo);
        });
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not capture photo. Please try again.',
          stackTrace: st,
          contextLabel: 'edit_request_screen: Could not capture photo. Pleas',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _pickPhotosFromGallery() async {
    try {
      final List<XFile>? photos = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photos != null && photos.isNotEmpty && mounted) {
        setState(() {
          _newLocalPhotos.addAll(photos);
        });
        return;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photo != null && mounted) {
        setState(() {
          _newLocalPhotos.add(photo);
        });
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not pick photos. Please try again.',
          stackTrace: st,
          contextLabel: 'edit_request_screen: Could not pick photos. Please ',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  void _removeExistingUrl(int index) {
    setState(() {
      _existingProblemPhotoUrls.removeAt(index);
    });
  }

  void _removeNewLocal(int index) {
    setState(() {
      _newLocalPhotos.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if request can still be edited
    if (widget.workOrder.status != WorkOrderStatus.open &&
        widget.workOrder.status != WorkOrderStatus.assigned) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This request can no longer be edited'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);

      final photoUrls = List<String>.from(_existingProblemPhotoUrls);
      var newPhotoFailCount = 0;
      var newPhotoUploadedCount = 0;
      for (var i = 0; i < _newLocalPhotos.length; i++) {
        try {
          final url = await _workOrderRepository.uploadFile(
            file: _newLocalPhotos[i],
            fileName:
                'request_${widget.workOrder.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
            folder: 'work_orders/request_photos',
          );
          if (url != null && url.isNotEmpty) {
            photoUrls.add(url);
            newPhotoUploadedCount++;
          } else {
            newPhotoFailCount++;
          }
        } catch (e, st) {
          newPhotoFailCount++;
          debugPrint('Error uploading edit photo $i: $e');
        }
      }

      final uploadDecision = evaluateEditPhotoUpload(
        newPhotoCount: _newLocalPhotos.length,
        uploadedCount: newPhotoUploadedCount,
        failCount: newPhotoFailCount,
      );

      if (!uploadDecision.shouldSaveChanges) {
        return;
      }

      final submissionFields =
          mapRequestorCategoryIssue(_selectedCategoryIssue);

      final updatedWorkOrder = widget.workOrder.copyWith(
        problemDescription: _problemDescriptionController.text.trim(),
        priority: submissionFields.priority,
        category: submissionFields.category,
        photoPath: photoUrls.isNotEmpty ? photoUrls.first : null,
        photoPaths: photoUrls,
        updatedAt: DateTime.now(),
      );

      await unifiedProvider.updateWorkOrder(updatedWorkOrder);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        if (uploadDecision.partialSuccessMessage != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(uploadDecision.partialSuccessMessage!),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        } else if (uploadDecision.allNewPhotosFailedMessage != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(uploadDecision.allNewPhotosFailedMessage!),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Request updated successfully!'),
              backgroundColor: AppTheme.accentGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update request. Please try again.',
          stackTrace: st,
          contextLabel: 'edit_request_screen: Could not update request. Plea',
          backgroundColor: AppTheme.accentRed,
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
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'Edit Request',
        usePageTitle: true,
        showMenu: false,
        showBackButton: true,
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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: padding,
              child: isDesktop
                  ? _buildDesktopLayout(context)
                  : _buildMobileLayout(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildTicketNumber(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildProblemDescriptionField(),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCategoryIssueField(),
                  const SizedBox(height: AppTheme.spacingL),
                  _buildPhotoSection(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingL),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoBanner(),
        const SizedBox(height: AppTheme.spacingL),
        _buildTicketNumber(),
        const SizedBox(height: AppTheme.spacingL),
        _buildProblemDescriptionField(),
        const SizedBox(height: AppTheme.spacingL),
        _buildCategoryIssueField(),
        const SizedBox(height: AppTheme.spacingL),
        _buildPhotoSection(),
        const SizedBox(height: AppTheme.spacingL),
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.accentBlue,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              'You can only edit requests that are Open or Assigned. Once work has started, editing is no longer available.',
              style: AppTheme.smallText.copyWith(
                color: AppTheme.accentBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketNumber() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number,
            color: AppTheme.accentBlue,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            widget.workOrder.ticketNumber,
            style: AppTheme.heading2.copyWith(
              color: AppTheme.darkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemDescriptionField() {
    return TextFormField(
      controller: _problemDescriptionController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Problem Description *',
        hintText: 'Describe the issue or maintenance needed...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          borderSide: const BorderSide(
            color: AppTheme.accentBlue,
            width: 2,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please describe the problem';
        }
        if (value.trim().length < 10) {
          return 'Please provide a more detailed description';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryIssueField() {
    return DropdownButtonFormField<String>(
      value: _selectedCategoryIssue,
      decoration: InputDecoration(
        labelText: 'Category Issue *',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          borderSide: const BorderSide(
            color: AppTheme.accentBlue,
            width: 2,
          ),
        ),
      ),
      items: kRequestorCategoryIssueOptions
          .map(
            (label) => DropdownMenuItem(
              value: label,
              child: Text(label),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategoryIssue = value;
          });
        }
      },
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.accentBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera,
                color: AppTheme.accentBlue,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  'Photos (optional)',
                  style: AppTheme.heading2.copyWith(
                    color: AppTheme.darkTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Add multiple photos of the issue. Tap the camera again or use '
            'the gallery to select several images at once.',
            style: AppTheme.smallText.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          if (_existingProblemPhotoUrls.isNotEmpty ||
              _newLocalPhotos.isNotEmpty) ...[
            SizedBox(
              height: 108,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...List.generate(_existingProblemPhotoUrls.length, (index) {
                    final url = _existingProblemPhotoUrls[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTheme.spacingS),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                            child: AuthenticatedImage(
                              imageUrl: url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeExistingUrl(index),
                            icon: const Icon(Icons.close, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(28, 28),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  ...List.generate(_newLocalPhotos.length, (index) {
                    final f = _newLocalPhotos[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTheme.spacingS),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                            child: FutureBuilder<Uint8List>(
                              future: f.readAsBytes(),
                              builder: (context, snap) {
                                if (snap.hasData) {
                                  return Image.memory(
                                    snap.data!,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removeNewLocal(index),
                            icon: const Icon(Icons.close, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(28, 28),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _capturePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Add photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentBlue,
                    side: const BorderSide(color: AppTheme.accentBlue),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickPhotosFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery (multi)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentBlue,
                    side: const BorderSide(color: AppTheme.accentBlue),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text('Save Changes'),
    );
  }
}

