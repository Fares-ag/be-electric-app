import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/asset.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../utils/app_theme.dart';
import '../../utils/charger_asset_filter.dart';
import '../../utils/cmms_package_assets.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/requestor_category_mapper.dart';
import '../../utils/requestor_submit_readiness.dart';
import '../../utils/requestor_work_order_asset.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/requestor_more_menu.dart';
import 'submission_success_screen.dart';
import 'requestor_status_screen.dart';
import '../../utils/user_facing_errors.dart';

class ReviewMaintenanceRequestScreen extends StatefulWidget {
  const ReviewMaintenanceRequestScreen({
    required this.asset,
    required this.name,
    required this.chargerId,
    required this.department,
    required this.contactNumber,
    required this.email,
    required this.category,
    required this.problemDescription,
    required this.selectedPhotos,
    required this.photoPreviewBytes,
    required this.chargerType,
    super.key,
    this.chargerImagePath,
  });

  final Asset asset;
  final String name;
  final String chargerId;
  final String department;
  final String contactNumber;
  final String email;
  final String category;
  final String problemDescription;
  final List<XFile> selectedPhotos;
  final List<Uint8List> photoPreviewBytes;
  final String chargerType;
  final String? chargerImagePath;

  @override
  State<ReviewMaintenanceRequestScreen> createState() =>
      _ReviewMaintenanceRequestScreenState();
}

class _ReviewMaintenanceRequestScreenState
    extends State<ReviewMaintenanceRequestScreen> {
  bool _isLoading = false;
  final _workOrderRepository = CmmsRepositories.workOrders;
  String? _companyName;
  bool _isLoadingCompany = false;

  Future<void> _submitRequest() async {
    setState(() {
      _isLoading = true;
    });

    // Show loading screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const _SubmissionLoadingScreen(),
          fullscreenDialog: true,
        ),
      );
    }

    try {
      final user =
          Provider.of<AuthProvider>(context, listen: false).currentUser;

      final requestor = user;
      if (requestor == null) {
        throw Exception(kRequestorSubmitNotAuthenticatedMessage);
      }

      final preUpload = evaluateRequestorSubmitPreUpload(user: requestor);
      if (!preUpload.canProceed) {
        if (mounted) {
          Navigator.pop(context);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(preUpload.dialogTitle ?? 'Unable to submit'),
              content: Text(preUpload.dialogMessage!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Upload photos if any (use cached bytes — iOS gallery paths may not survive navigation)
      List<String> photoUrls = [];
      int photoFailCount = 0;
      for (var i = 0; i < widget.photoPreviewBytes.length; i++) {
        try {
          final uploadFile = XFile.fromData(
            widget.photoPreviewBytes[i],
            name: widget.selectedPhotos.length > i
                ? widget.selectedPhotos[i].name
                : 'request_photo_$i.jpg',
            mimeType: 'image/jpeg',
          );
          final photoUrl = await _workOrderRepository.uploadFile(
            file: uploadFile,
            fileName:
                'request_${DateTime.now().millisecondsSinceEpoch}_${photoUrls.length}.jpg',
            folder: 'work_orders/request_photos',
          );
          if (photoUrl != null) {
            photoUrls.add(photoUrl);
          } else {
            photoFailCount++;
            debugPrint('⚠️ Photo upload returned null (auth or bucket issue)');
          }
        } catch (e, st) {
          photoFailCount++;
          debugPrint('Error uploading photo: $e');
        }
      }

      final postUpload = evaluateRequestorSubmitPostUpload(
        asset: widget.asset,
        selectedPhotoCount: widget.photoPreviewBytes.length,
        uploadedCount: photoUrls.length,
        failCount: photoFailCount,
      );

      if (!postUpload.canProceed) {
        if (mounted) {
          Navigator.pop(context);
          if (postUpload.dialogTitle == 'Photos not uploaded') {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(postUpload.dialogTitle!),
                content: Text(postUpload.dialogMessage!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _submitRequest();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            await showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(postUpload.dialogTitle ?? 'Unable to submit'),
                content: Text(postUpload.dialogMessage!),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
        return;
      }

      // Create work order using UnifiedDataProvider
      if (!mounted) return;
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);

      final notes = buildMaintenanceRequestNotes(
        chargerType: widget.chargerType,
        chargerId: widget.chargerId,
        categoryIssue: widget.category,
        department: widget.department,
      );

      final assetSubmission =
          resolveRequestorWorkOrderAssetSubmission(widget.asset)!;

      final submissionFields = mapRequestorCategoryIssue(widget.category);

      await unifiedProvider.createWorkOrder(
        problemDescription:
            widget.problemDescription, // Just the problem description
        requestorId: requestor.id,
        assetId: assetSubmission.assetId,
        asset: assetSubmission.asset,
        location: null,
        priority: submissionFields.priority,
        category: submissionFields.category,
        photoPaths:
            photoUrls.isNotEmpty ? photoUrls : null, // Pass all photo URLs
        customerName: widget.name.isNotEmpty ? widget.name : null,
        customerPhone:
            widget.contactNumber.isNotEmpty ? widget.contactNumber : null,
        customerEmail: widget.email.isNotEmpty ? widget.email : null,
        notes: notes.trim(),
      );

      if (mounted) {
        // Pop loading screen
        Navigator.pop(context);

        if (postUpload.partialPhotoMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(postUpload.partialPhotoMessage!),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Navigate to success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SubmissionSuccessScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        // Pop loading screen
        Navigator.pop(context);

        showUserErrorSnackBar(
          context,
          e,
          genericMessage: e is StateError && e.message.isNotEmpty
              ? e.message
              : 'Could not submit request. Please try again.',
          stackTrace: st,
          contextLabel: 'ReviewMaintenanceRequest: submit',
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
  void initState() {
    super.initState();
    _loadCompanyName();
  }

  Future<void> _loadCompanyName() async {
    setState(() {
      _isLoadingCompany = true;
    });

    try {
      String? companyId;

      // First try to get from asset's company field (if it's already a name)
      if (widget.asset.company != null && widget.asset.company!.isNotEmpty) {
        // Check if it looks like an ID or a name
        if (!widget.asset.company!.contains('-') &&
            widget.asset.company!.length > 3) {
          // Likely a name, not an ID
          setState(() {
            _companyName = widget.asset.company;
            _isLoadingCompany = false;
          });
          return;
        }
        companyId = widget.asset.company;
      }

      // Try user's companyId
      if (companyId == null) {
        final user =
            Provider.of<AuthProvider>(context, listen: false).currentUser;
        if (user?.companyId != null && user!.companyId!.isNotEmpty) {
          companyId = user.companyId;
        }
      }

      if (companyId != null) {
        final response = await Supabase.instance.client
            .from('companies')
            .select('name')
            .eq('id', companyId)
            .maybeSingle();

        if (!mounted) return;
        if (response != null && response['name'] != null) {
          _companyName = response['name'] as String;
        } else {
          _companyName = companyId;
        }
      } else {
        _companyName = 'N/A';
      }
    } catch (e, st) {
      debugPrint('Error loading company name: $e');
      if (!mounted) return;
      _companyName = 'N/A';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCompany = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'Review your Details',
        usePageTitle: true,
        showMenu: false,
        showBackButton: true,
        onMoreTap: () {
          showRequestorMoreMenu(
            context,
            primaryLabel: 'View My Requests',
            primaryIcon: Icons.history,
            onPrimaryNav: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RequestorStatusScreen(),
                ),
              );
            },
          );
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF5F5F5),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop
                      ? ResponsiveLayout.getResponsivePadding(context)
                              .horizontal *
                          2
                      : ResponsiveLayout.getResponsivePadding(context)
                          .horizontal,
                  vertical: isDesktop
                      ? 40
                      : ResponsiveLayout.getResponsivePadding(context).vertical,
                ),
                child: isDesktop
                    ? _buildDesktopLayout(context)
                    : _buildMobileTabletLayout(context),
              ),
            ),
          ),

          // SEND REQUEST button
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop
                  ? ResponsiveLayout.getResponsivePadding(context).horizontal *
                      2
                  : ResponsiveLayout.getResponsivePadding(context).horizontal,
              vertical: 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal:
                      isDesktop ? AppTheme.spacingXL : AppTheme.spacingL,
                  vertical: isDesktop ? 18 : AppTheme.spacingM,
                ),
                minimumSize: Size(0, isDesktop ? 56 : 50),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: isDesktop ? 24 : 20,
                      height: isDesktop ? 24 : 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'SEND REQUEST',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with charger image
          if (widget.chargerImagePath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  widget.chargerImagePath!,
                  package: kCmmsCoreAssetPackage,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

          // Two-column layout for details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildDetailsCard([
                    _buildDetailRow(
                        'Name', widget.name.isNotEmpty ? widget.name : 'N/A'),
                    _buildDetailRow('Company', _getCompanyName()),
                    _buildDetailRow(
                        'Charger ID',
                        widget.chargerId.isNotEmpty
                            ? widget.chargerId.toUpperCase()
                            : 'N/A'),
                    // Asset details
                    if (widget.asset.qrCode != null &&
                        widget.asset.qrCode!.isNotEmpty)
                      _buildDetailRow('Asset Tag', widget.asset.qrCode!),
                    if (widget.asset.qrCodeId != null &&
                        widget.asset.qrCodeId!.isNotEmpty &&
                        widget.asset.qrCodeId != widget.asset.qrCode)
                      _buildDetailRow('Asset Number', widget.asset.qrCodeId!),
                    if (widget.asset.serialNumber != null &&
                        widget.asset.serialNumber!.isNotEmpty)
                      _buildDetailRow(
                          'Serial Number', widget.asset.serialNumber!),
                    if (widget.asset.location.isNotEmpty)
                      _buildDetailRow('Location', widget.asset.location),
                  ]),
                ),
              ),

              // Right column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _buildDetailsCard([
                    _buildDetailRow(
                        'Contact Number',
                        widget.contactNumber.isNotEmpty
                            ? widget.contactNumber
                            : 'N/A'),
                    _buildDetailRow('Email',
                        widget.email.isNotEmpty ? widget.email : 'N/A'),
                    _buildDetailRow('Category',
                        widget.category.isNotEmpty ? widget.category : 'N/A'),
                    // Additional asset details
                    _buildDetailRow(
                      'Manufacturer',
                      resolveChargerManufacturer(widget.asset),
                    ),
                    if (widget.asset.model != null &&
                        widget.asset.model!.isNotEmpty)
                      _buildDetailRow('Model', widget.asset.model!),
                  ]),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Photo section - full width
          _buildPhotoCard(),

          const SizedBox(height: 24),

          // Problem Description - full width
          _buildProblemDescriptionCard(),
        ],
      ),
    );
  }

  Widget _buildMobileTabletLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Charger image
          if (widget.chargerImagePath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  widget.chargerImagePath!,
                  package: kCmmsCoreAssetPackage,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

          // Details card
          _buildDetailsCard([
            _buildDetailRow(
                'Name', widget.name.isNotEmpty ? widget.name : 'N/A'),
            _buildDetailRow('Company', _getCompanyName()),
            _buildDetailRow(
                'Charger ID',
                widget.chargerId.isNotEmpty
                    ? widget.chargerId.toUpperCase()
                    : 'N/A'),
            // Asset details
            if (widget.asset.qrCode != null && widget.asset.qrCode!.isNotEmpty)
              _buildDetailRow('Asset Tag', widget.asset.qrCode!),
            if (widget.asset.qrCodeId != null &&
                widget.asset.qrCodeId!.isNotEmpty &&
                widget.asset.qrCodeId != widget.asset.qrCode)
              _buildDetailRow('Asset Number', widget.asset.qrCodeId!),
            if (widget.asset.serialNumber != null &&
                widget.asset.serialNumber!.isNotEmpty)
              _buildDetailRow('Serial Number', widget.asset.serialNumber!),
            if (widget.asset.location.isNotEmpty)
              _buildDetailRow('Location', widget.asset.location),
            if (widget.asset.manufacturer != null &&
                widget.asset.manufacturer!.isNotEmpty)
              _buildDetailRow(
                'Manufacturer',
                resolveChargerManufacturer(widget.asset),
              ),
            if (widget.asset.model != null && widget.asset.model!.isNotEmpty)
              _buildDetailRow('Model', widget.asset.model!),
            _buildDetailRow('Contact Number',
                widget.contactNumber.isNotEmpty ? widget.contactNumber : 'N/A'),
            _buildDetailRow(
                'Email', widget.email.isNotEmpty ? widget.email : 'N/A'),
            _buildDetailRow('Category',
                widget.category.isNotEmpty ? widget.category : 'N/A'),
          ]),

          const SizedBox(height: 24),

          // Photo section
          _buildPhotoCard(),

          const SizedBox(height: 24),

          // Problem Description
          _buildProblemDescriptionCard(),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library,
                size: 20,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                'PHOTO',
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.photoPreviewBytes.length} Attachment${widget.photoPreviewBytes.length != 1 ? 's' : ''}',
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (widget.photoPreviewBytes.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.photoPreviewBytes.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        widget.photoPreviewBytes[index],
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProblemDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description,
                size: 20,
                color: AppTheme.secondaryTextColor,
              ),
              const SizedBox(width: 8),
              Text(
                'PROBLEM DESCRIPTION',
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              widget.problemDescription,
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.darkTextColor,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: AppTheme.smallText.copyWith(
                color: AppTheme.secondaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyText.copyWith(
                color: AppTheme.darkTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Get company name (loaded asynchronously)
  String _getCompanyName() {
    if (_isLoadingCompany) {
      return 'Loading...';
    }
    return _companyName ?? 'N/A';
  }
}

/// Loading screen shown during request submission
class _SubmissionLoadingScreen extends StatelessWidget {
  const _SubmissionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF002D17), // Dark green background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'Submitting Request..',
              style: AppTheme.heading2.copyWith(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
