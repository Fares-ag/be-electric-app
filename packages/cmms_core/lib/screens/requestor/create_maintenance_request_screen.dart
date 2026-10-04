import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/asset.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../theme/design_tokens.dart';
import '../../utils/app_theme.dart';
import '../../utils/charger_asset_filter.dart';
import '../../utils/cmms_package_assets.dart';
import '../../utils/requestor_work_order_asset.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/requestor_more_menu.dart';
import 'requestor_status_screen.dart';
import 'review_maintenance_request_screen.dart';
import '../../utils/user_facing_errors.dart';

class CreateMaintenanceRequestScreen extends StatefulWidget {
  const CreateMaintenanceRequestScreen({
    required this.asset,
    required this.qrCode,
    this.chargerType,
    super.key,
  });
  final Asset asset;
  final String qrCode;
  final String? chargerType; // 'Siemens' or 'Kostad'

  @override
  State<CreateMaintenanceRequestScreen> createState() =>
      _CreateMaintenanceRequestScreenState();
}

class _CreateMaintenanceRequestScreenState
    extends State<CreateMaintenanceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _problemDescriptionController = TextEditingController();

  bool _isLoading = false;
  String? _selectedCharger;
  String? _selectedCategoryIssue;

  // Charger selection
  Asset? _selectedChargerAsset;
  List<Asset> _companyChargers = [];
  bool _isLoadingChargers = false;
  bool _chargersLoadAttempted = false;

  // Photo upload
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedPhotos = [];
  List<Uint8List> _selectedPhotoBytes = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill charger if provided
    if (widget.chargerType != null) {
      _selectedCharger = widget.chargerType;
      // Load chargers for the selected type
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCompanyChargers(widget.chargerType!);
      });
    }
    // Pre-fill user info - use WidgetsBinding to access context safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final user =
            Provider.of<AuthProvider>(context, listen: false).currentUser;
        if (user != null) {
          setState(() {
            _nameController.text = user.name;
            _emailController.text = user.email;
            if (user.workEmail != null) {
              _emailController.text = user.workEmail!;
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _problemDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _addPhotos(List<XFile> photos) async {
    if (photos.isEmpty || !mounted) return;

    try {
      final bytes = await Future.wait(photos.map((p) => p.readAsBytes()));
      if (!mounted) return;
      setState(() {
        _selectedPhotos.addAll(photos);
        _selectedPhotoBytes.addAll(bytes);
      });
    } catch (e, st) {
      if (!mounted) return;
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not read the selected photo. Please try again.',
        stackTrace: st,
        contextLabel: 'create_maintenance_request_screen: photo bytes',
        backgroundColor: AppTheme.accentRed,
      );
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photo != null) {
        await _addPhotos([photo]);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not capture photo. Please try again.',
          stackTrace: st,
          contextLabel: 'create_maintenance_request_screen: Could not capture photo. Pleas',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    try {
      // Try to pick multiple images first (if supported)
      final List<XFile>? photos = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photos != null && photos.isNotEmpty) {
        await _addPhotos(photos);
      } else {
        // Fallback to single image picker if multi-image is not supported
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
        );

        if (photo != null) {
          await _addPhotos([photo]);
        }
      }
    } catch (e, st) {
      // If multi-image fails, try single image picker
      try {
        final XFile? photo = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1920,
        );

        if (photo != null) {
          await _addPhotos([photo]);
        }
      } catch (e2, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e2,
          genericMessage: 'Could not pick photo. Please try again.',
          stackTrace: st,
          contextLabel: 'create_maintenance_request_screen: Could not pick photo. Please t',
          backgroundColor: AppTheme.accentRed,
        );
        }
      }
    }
  }

  Future<void> _removePhoto(int index) async {
    if (mounted) {
      setState(() {
        _selectedPhotos.removeAt(index);
        if (index < _selectedPhotoBytes.length) {
          _selectedPhotoBytes.removeAt(index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine charger image based on charger type
    final chargerImagePath = widget.chargerType == 'Siemens'
        ? 'assets/images/SiemensCharger.png'
        : widget.chargerType == 'Kostad'
            ? 'assets/images/KostadCharger.png'
            : null;

    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: 'Your Details',
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: isDesktop
              ? _buildDesktopLayout(context, chargerImagePath)
              : _buildMobileTabletLayout(context, chargerImagePath),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, String? chargerImagePath) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.getResponsivePadding(context).horizontal,
        vertical: ResponsiveLayout.getResponsivePadding(context).vertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section with charger image
          if (chargerImagePath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Image.asset(
                  chargerImagePath,
                  package: kCmmsCoreAssetPackage,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

          const SizedBox(height: 40),

          // Two-column layout for desktop
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormField(
                        label: 'NAME',
                        controller: _nameController,
                        hintText: 'Enter name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildFormField(
                        label: 'CONTACT NUMBER',
                        controller: _contactNumberController,
                        hintText: 'Enter number',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      // CHARGER dropdown - show actual chargers if type is pre-selected
                      if (widget.chargerType != null &&
                          _companyChargers.isNotEmpty)
                        _buildChargerSelectionDropdown()
                      else if (widget.chargerType != null && _isLoadingChargers)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CHARGER',
                              style: AppTheme.smallText.copyWith(
                                color: AppTheme.secondaryTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Center(child: CircularProgressIndicator()),
                          ],
                        )
                      else
                        _buildDropdownField<String>(
                          label: 'CHARGER',
                          value: _selectedCharger,
                          hintText: 'Select your charger',
                          items: const ['Siemens', 'Kostad'],
                          onChanged: (value) {
                            setState(() {
                              _selectedCharger = value;
                              _selectedChargerAsset = null;
                              _companyChargers = [];
                            });
                            if (value != null) {
                              _loadCompanyChargers(value);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a charger';
                            }
                            return null;
                          },
                        ),

                      // Show asset details when a charger is selected
                      if (_selectedChargerAsset != null) ...[
                        const SizedBox(height: AppTheme.spacingL),
                        _buildAssetDetailsFields(),
                      ],
                    ],
                  ),
                ),
              ),

              // Right column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormField(
                        label: 'EMAIL',
                        controller: _emailController,
                        hintText: 'Enter your work email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildDropdownField<String>(
                        label: 'CATEGORY ISSUE',
                        value: _selectedCategoryIssue,
                        hintText: 'Select type of issue',
                        items: const [
                          'Electrical',
                          'Mechanical',
                          'Software',
                          'Hardware',
                          'Other',
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryIssue = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildPhotoSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // Full-width problem description
          _buildFormField(
            label: 'PROBLEM DESCRIPTION',
            controller: _problemDescriptionController,
            hintText: 'Enter a detailed description of the issue...',
            maxLines: 5,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe the problem';
              }
              if (value.trim().length < 10) {
                return 'Please provide a more detailed description';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spacingXXL),

          // Action button - full width on desktop
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF424242),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingL,
                ),
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 32),
        ],
      ),
    );
  }

  Widget _buildMobileTabletLayout(
    BuildContext context,
    String? chargerImagePath,
  ) {
    return ResponsiveContainer(
      maxWidth: ResponsiveLayout.getFormMaxWidth(context),
      padding: ResponsiveLayout.getResponsivePadding(context),
      centerContent: ResponsiveLayout.isTablet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Charger image at top (centered)
          if (chargerImagePath != null)
            Center(
              child: Image.asset(
                chargerImagePath,
                package: kCmmsCoreAssetPackage,
                height: ResponsiveLayout.getResponsiveSpacing(
                  context,
                  mobile: 120,
                  tablet: 140,
                  desktop: 160,
                ),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),

          SizedBox(
            height: ResponsiveLayout.getResponsiveSpacing(
              context,
              mobile: AppTheme.spacingXL,
              tablet: AppTheme.spacingXXL,
              desktop: AppTheme.spacingXXL * 1.5,
            ),
          ),

          // NAME field
          _buildFormField(
            label: 'NAME',
            controller: _nameController,
            hintText: 'Enter name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spacingL),

          // CHARGER dropdown - show actual chargers if type is pre-selected
          if (widget.chargerType != null && _companyChargers.isNotEmpty)
            _buildChargerSelectionDropdown()
          else if (widget.chargerType != null && _isLoadingChargers)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHARGER',
                  style: AppTheme.smallText.copyWith(
                    color: AppTheme.secondaryTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveLayout.isDesktop(context) ? 13 : 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                const Center(child: CircularProgressIndicator()),
              ],
            )
          else
            _buildDropdownField<String>(
              label: 'CHARGER',
              value: _selectedCharger,
              hintText: 'Select your charger',
              items: const ['Siemens', 'Kostad'],
              onChanged: (value) {
                setState(() {
                  _selectedCharger = value;
                  _selectedChargerAsset = null;
                  _companyChargers = [];
                });
                if (value != null) {
                  _loadCompanyChargers(value);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a charger';
                }
                return null;
              },
            ),

          // Show asset details when a charger is selected
          if (_selectedChargerAsset != null) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildAssetDetailsFields(),
          ],

          const SizedBox(height: AppTheme.spacingL),

          // CONTACT NUMBER field
          _buildFormField(
            label: 'CONTACT NUMBER',
            controller: _contactNumberController,
            hintText: 'Enter number',
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: AppTheme.spacingL),

          // EMAIL field
          _buildFormField(
            label: 'EMAIL',
            controller: _emailController,
            hintText: 'Enter your work email',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spacingL),

          // CATEGORY ISSUE dropdown
          _buildDropdownField<String>(
            label: 'CATEGORY ISSUE',
            value: _selectedCategoryIssue,
            hintText: 'Select type of issue',
            items: const [
              'Electrical',
              'Mechanical',
              'Software',
              'Hardware',
              'Other',
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategoryIssue = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a category';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spacingL),

          // PHOTO section
          _buildPhotoSection(),

          const SizedBox(height: AppTheme.spacingL),

          // PROBLEM DESCRIPTION field
          _buildFormField(
            label: 'PROBLEM DESCRIPTION',
            controller: _problemDescriptionController,
            hintText: 'Enter a description...',
            maxLines: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please describe the problem';
              }
              if (value.trim().length < 10) {
                return 'Please provide a more detailed description';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // NEXT button
          ElevatedButton(
            onPressed: _isLoading ? null : _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF424242), // Dark grey
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingM,
              ),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('NEXT'),
          ),

          // Add bottom padding to prevent overflow when keyboard is open
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(
            color: Colors.black,
            fontSize: isDesktop ? 15 : 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontFamily: DesignTokens.fontFamily,
              fontSize: isDesktop ? 15 : 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: isDesktop ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: const Color(0xFF424242),
                width: isDesktop ? 2.5 : 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required String hintText,
    required List<T> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        DropdownButtonFormField<T>(
          initialValue: value,
          style: TextStyle(
            color: Colors.black,
            fontSize: isDesktop ? 15 : 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontFamily: DesignTokens.fontFamily,
              fontSize: isDesktop ? 15 : 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: isDesktop ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: const Color(0xFF424242),
                width: isDesktop ? 2.5 : 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                item.toString(),
                style: TextStyle(fontSize: isDesktop ? 15 : 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PHOTOS (optional)',
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add as many as you need — use the camera more than once, or '
          'open the gallery to select multiple images in one step.',
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontSize: isDesktop ? 12 : 11,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        if (_selectedPhotos.isNotEmpty) ...[
          SizedBox(
            height: isDesktop ? 120 : 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                final photoSize = isDesktop ? 120.0 : 100.0;
                return Container(
                  margin: EdgeInsets.only(
                    right: isDesktop ? 16 : AppTheme.spacingS,
                  ),
                  width: photoSize,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 8 : AppTheme.radiusS,
                        ),
                        child: Image.memory(
                          _selectedPhotoBytes[index],
                          height: photoSize,
                          width: photoSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: photoSize,
                              width: photoSize,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image_outlined),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _removePhoto(index),
                          child: Container(
                            padding: EdgeInsets.all(isDesktop ? 6 : 4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: isDesktop ? 18 : 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: isDesktop ? 16 : AppTheme.spacingM),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _capturePhoto,
                icon: Icon(Icons.camera_alt, size: isDesktop ? 20 : 18),
                label: Text(
                  'Take photo',
                  style: TextStyle(fontSize: isDesktop ? 14 : 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: isDesktop ? 16 : AppTheme.spacingM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      isDesktop ? 8 : AppTheme.radiusS,
                    ),
                    side: BorderSide(
                      color: Colors.grey[300]!,
                      width: isDesktop ? 1.5 : 1,
                    ),
                  ),
                  elevation: isDesktop ? 1 : 0,
                ),
              ),
            ),
            SizedBox(width: isDesktop ? 12 : AppTheme.spacingS),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickPhotoFromGallery,
                icon: Icon(Icons.photo_library, size: isDesktop ? 20 : 18),
                label: Text(
                  'Gallery (multi)',
                  style: TextStyle(fontSize: isDesktop ? 14 : 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: isDesktop ? 16 : AppTheme.spacingM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      isDesktop ? 8 : AppTheme.radiusS,
                    ),
                    side: BorderSide(
                      color: Colors.grey[300]!,
                      width: isDesktop ? 1.5 : 1,
                    ),
                  ),
                  elevation: isDesktop ? 1 : 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Load chargers filtered by company and manufacturer
  Future<void> _loadCompanyChargers(String manufacturer) async {
    setState(() {
      _isLoadingChargers = true;
      _companyChargers = [];
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final companyId = user?.companyId;

      if (companyId == null) {
        if (mounted) {
          setState(() {
            _isLoadingChargers = false;
            _chargersLoadAttempted = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No company assigned to your account'),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
        return;
      }

      final company = await CmmsRepositories.users.getCompanyById(
        companyId,
      );
      final allAssets =
          await CmmsRepositories.assets.getAssetsByCompanyId(
        companyId,
      );
      final chargers = allAssets.where((asset) {
        return assetBelongsToUserCompany(
              asset,
              companyId,
              resolvedCompanyName: company?.name,
            ) &&
            isChargerLikeAsset(asset) &&
            matchesChargerBrand(asset, manufacturer);
      }).toList();

      if (mounted) {
        setState(() {
          _companyChargers = chargers;
          _isLoadingChargers = false;
          _chargersLoadAttempted = true;
          if (chargers.length == 1) {
            _selectedChargerAsset = chargers.first;
          }
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isLoadingChargers = false;
          _chargersLoadAttempted = true;
        });
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load chargers. Please try again.',
          stackTrace: st,
          contextLabel: 'create_maintenance_request_screen: Could not load chargers. Pleas',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  // Build asset details fields (read-only)
  Widget _buildAssetDetailsFields() {
    final asset = _selectedChargerAsset!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Asset Tag
        if (asset.qrCode != null && asset.qrCode!.isNotEmpty)
          _buildReadOnlyField(
            label: 'ASSET TAG',
            value: asset.qrCode!,
          ),

        // Asset Number (if different from tag)
        if (asset.qrCodeId != null &&
            asset.qrCodeId!.isNotEmpty &&
            asset.qrCodeId != asset.qrCode) ...[
          const SizedBox(height: AppTheme.spacingL),
          _buildReadOnlyField(
            label: 'ASSET NUMBER',
            value: asset.qrCodeId!,
          ),
        ],

        // Serial Number
        if (asset.serialNumber != null && asset.serialNumber!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingL),
          _buildReadOnlyField(
            label: 'SERIAL NUMBER',
            value: asset.serialNumber!,
          ),
        ],

        // Location
        if (asset.location.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingL),
          _buildReadOnlyField(
            label: 'LOCATION',
            value: asset.location,
          ),
        ],

        // Manufacturer (derived from charger name; matches Supabase trigger)
        const SizedBox(height: AppTheme.spacingL),
        _buildReadOnlyField(
          label: 'MANUFACTURER',
          value: resolveChargerManufacturer(asset),
        ),

        // Model
        if (asset.model != null && asset.model!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingL),
          _buildReadOnlyField(
            label: 'MODEL',
            value: asset.model!,
          ),
        ],
      ],
    );
  }

  // Build read-only field for asset details
  Widget _buildReadOnlyField({
    required String label,
    required String value,
  }) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 16,
            vertical: isDesktop ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius:
                BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
            border: Border.all(
              color: Colors.grey[300]!,
              width: isDesktop ? 1.5 : 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: isDesktop ? 15 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Build charger selection dropdown with all details
  Widget _buildChargerSelectionDropdown() {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHARGER',
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        DropdownButtonFormField<Asset>(
          initialValue: _selectedChargerAsset,
          isExpanded: true, // Prevent overflow by expanding to available width
          style: TextStyle(
            color: Colors.black,
            fontSize: isDesktop ? 15 : 14,
          ),
          selectedItemBuilder: (context) {
            // Custom builder for selected item to prevent overflow
            return _companyChargers.map((charger) {
              return Text(
                charger.name,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: isDesktop ? 15 : 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              );
            }).toList();
          },
          decoration: InputDecoration(
            hintText: 'Select a charger',
            helperText:
                '${_companyChargers.length} charger${_companyChargers.length != 1 ? 's' : ''} available',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontFamily: DesignTokens.fontFamily,
              fontSize: isDesktop ? 15 : 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: isDesktop ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: BorderSide(
                color: const Color(0xFF424242),
                width: isDesktop ? 2.5 : 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 16,
              vertical: isDesktop ? 16 : 12,
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          ),
          items: _companyChargers.map((charger) {
            // Build display text with all important details
            final details = <String>[];
            if (charger.qrCode != null && charger.qrCode!.isNotEmpty) {
              details.add('Tag: ${charger.qrCode}');
            }
            if (charger.qrCodeId != null && charger.qrCodeId!.isNotEmpty) {
              details.add('Asset #: ${charger.qrCodeId}');
            }
            if (charger.serialNumber != null &&
                charger.serialNumber!.isNotEmpty) {
              details.add('Serial: ${charger.serialNumber}');
            }
            if (charger.location.isNotEmpty) {
              details.add('Location: ${charger.location}');
            }
            final detailText =
                details.isNotEmpty ? ' (${details.join(', ')})' : '';

            return DropdownMenuItem<Asset>(
              value: charger,
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 60, // Limit height to prevent overflow
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      charger.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isDesktop ? 15 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (detailText.isNotEmpty)
                      Flexible(
                        child: Text(
                          detailText,
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedChargerAsset = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a charger';
            }
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final reviewAsset = _selectedChargerAsset ?? widget.asset;
    final assetValidationError = validateRequestorReviewAsset(
      asset: reviewAsset,
      isChargerTypeFlow: widget.chargerType != null,
      isLoadingChargers: _isLoadingChargers,
      chargersLoadAttempted: _chargersLoadAttempted,
      companyChargerCount: _companyChargers.length,
    );
    if (assetValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(assetValidationError),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    final chargerImagePath = widget.chargerType == 'Siemens'
        ? 'assets/images/SiemensCharger.png'
        : widget.chargerType == 'Kostad'
            ? 'assets/images/KostadCharger.png'
            : null;

    // Get charger ID from selected asset or fallback
    final chargerId = _selectedChargerAsset != null
        ? (_selectedChargerAsset!.qrCode ??
            _selectedChargerAsset!.qrCodeId ??
            _selectedChargerAsset!.id)
        : (widget.asset.id.isNotEmpty
            ? widget.asset.id
            : (_selectedCharger ?? 'UNKNOWN').toUpperCase());

    // Navigate to review screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewMaintenanceRequestScreen(
            asset: reviewAsset,
            name: _nameController.text.trim(),
            chargerId: chargerId,
            department: '', // Department field removed
            contactNumber: _contactNumberController.text.trim(),
            email: _emailController.text.trim(),
            category: _selectedCategoryIssue ?? '',
            problemDescription: _problemDescriptionController.text.trim(),
            selectedPhotos: _selectedPhotos,
            photoPreviewBytes: _selectedPhotoBytes,
            chargerType: _selectedCharger ?? '',
            chargerImagePath: chargerImagePath,
          ),
        ),
      );
    }
  }
}
