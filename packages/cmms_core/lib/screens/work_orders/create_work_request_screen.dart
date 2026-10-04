import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../config/locator.dart';
import '../../models/asset.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/connectivity_service.dart';
import '../../screens/assets/enhanced_asset_details_screen.dart';
import '../../services/performance_service.dart';
import '../../services/unified_data_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/charger_asset_filter.dart';
import '../../utils/requestor_category_mapper.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/enhanced_asset_display_widget.dart';
import '../../widgets/enhanced_asset_selection_widget.dart';
import '../../widgets/mobile_qr_scanner_widget.dart';
import '../../utils/user_facing_errors.dart';

class CreateWorkRequestScreen extends StatefulWidget {
  const CreateWorkRequestScreen({super.key, this.initialAsset});

  final Asset? initialAsset;

  @override
  State<CreateWorkRequestScreen> createState() =>
      _CreateWorkRequestScreenState();
}

class _CreateWorkRequestScreenState extends State<CreateWorkRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();
  final _locationController = TextEditingController();
  final _requestorNameController = TextEditingController();

  String? _selectedAssetId;
  // Removed unused fields to satisfy linter
  Asset? _selectedAsset;
  String? _photoPath;
  final Set<String> _selectedTechnicianIds = <String>{};
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedCategoryIssue;
  bool _isLoading = false;

  bool _isUnregisteredCharger = false;
  final _unregisteredNameController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _assetTagController = TextEditingController();

  // NEW: For requestors - manufacturer selection and charger dropdown
  String? _selectedManufacturer; // 'Siemens' or 'Kostad'
  List<Asset> _companyChargers = []; // Chargers filtered by company and manufacturer
  bool _isLoadingChargers = false;

  @override
  void initState() {
    super.initState();
    // Prefill selection when an initial asset is provided (e.g., from QR scan)
    if (widget.initialAsset != null) {
      _selectedAsset = widget.initialAsset;
      _selectedAssetId = widget.initialAsset!.id;
      if (isChargerLikeAsset(widget.initialAsset!)) {
        _selectedManufacturer = createFormChargerBrand(widget.initialAsset!);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selectedManufacturer != null) {
        _loadCompanyChargers(_selectedManufacturer!);
      }
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        setState(() {
          if (_requestorNameController.text.isEmpty) {
            _requestorNameController.text = user.name;
          }
          _emailController.text =
              (user.workEmail != null && user.workEmail!.isNotEmpty)
                  ? user.workEmail!
                  : user.email;
        });
      }
    });
  }

  @override
  void dispose() {
    _problemController.dispose();
    _locationController.dispose();
    _requestorNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _unregisteredNameController.dispose();
    _serialNumberController.dispose();
    _assetTagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Compress the image for better performance
        final compressedPath = await PerformanceService.compressImage(
          pickedFile.path,
        );

        setState(() {
          _photoPath = compressedPath;
        });
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not capture image. Please try again.',
          stackTrace: st,
          contextLabel: 'create_work_request_screen: Could not capture image. Pleas',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _selectImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Compress the image for better performance
        final compressedPath = await PerformanceService.compressImage(
          pickedFile.path,
        );

        setState(() {
          _photoPath = compressedPath;
        });
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not select image. Please try again.',
          stackTrace: st,
          contextLabel: 'create_work_request_screen: Could not select image. Please',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _selectImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIssue == null || _selectedCategoryIssue!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Validate: either asset is selected OR general maintenance with location
    if (!_isUnregisteredCharger && _selectedAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a charger or add one that is not in the system',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_isUnregisteredCharger) {
      if (_selectedManufacturer == null || _selectedManufacturer!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select Siemens or Kostad'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      if (_unregisteredNameController.text.trim().isEmpty ||
          _locationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the charger name and location'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final unifiedProvider = Provider.of<UnifiedDataProvider>(
        context,
        listen: false,
      );

      final description = _problemController.text.trim();

      final isTechnician = authProvider.currentUser?.role == 'technician';
      final wasOffline = AppConfig.isOfflineModeEnabled &&
          !sl<ConnectivityService>().isOnline;

      var workAsset = _selectedAsset;
      var workAssetId = _selectedAssetId;

      if (_isUnregisteredCharger) {
        final draft = buildFieldAddedCharger(
          id: const Uuid().v4(),
          name: _unregisteredNameController.text.trim(),
          location: _locationController.text.trim(),
          manufacturer: _selectedManufacturer!,
          serialNumber: _serialNumberController.text.trim(),
          assetTag: _assetTagController.text.trim(),
          companyId: authProvider.currentUser?.companyId,
        );
        try {
          final createdId = await sl<UnifiedDataService>().createAsset(draft);
          workAsset = draft.copyWith(id: createdId);
          workAssetId = createdId;
        } catch (e) {
          if (wasOffline) {
            workAsset = draft;
            workAssetId = draft.id;
          } else {
            rethrow;
          }
        }
      }

      final categoryIssue = _selectedCategoryIssue ?? '';
      final submissionFields = mapRequestorCategoryIssue(categoryIssue);
      final chargerType = _selectedManufacturer ?? workAsset?.manufacturer ?? '';
      final chargerId = workAsset?.qrCode ??
          workAsset?.qrCodeId ??
          workAssetId ??
          '';
      final name = _requestorNameController.text.trim();
      final contact = _contactNumberController.text.trim();
      final email = _emailController.text.trim();
      final notes = buildMaintenanceRequestNotes(
        chargerType: chargerType,
        chargerId: chargerId,
        categoryIssue: categoryIssue,
      );

      await unifiedProvider.createWorkOrder(
        assetId: workAssetId,
        asset: workAsset,
        location: _isUnregisteredCharger
            ? _locationController.text.trim()
            : null,
        problemDescription: description,
        requestorId: authProvider.currentUser!.id,
        photoPath: _photoPath,
        priority: submissionFields.priority,
        category: submissionFields.category,
        requestorName: name.isEmpty ? null : name,
        customerName: name.isEmpty ? null : name,
        customerPhone: contact.isEmpty ? null : contact,
        customerEmail: email.isEmpty ? null : email,
        notes: notes,
        assignedTechnicianIds: isTechnician
            ? null
            : (_selectedTechnicianIds.isEmpty
                ? null
                : _selectedTechnicianIds.toList()),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasOffline
                  ? 'Work order saved locally — will sync when online'
                  : 'Work request created successfully',
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
          genericMessage: 'Could not create work request. Please try again.',
          stackTrace: st,
          contextLabel: 'create_work_request_screen: Could not create work request.',
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
        appBar: AppBar(title: const Text('New Work Request')),
        body: Form(
          key: _formKey,
          child: Center(
            child: SingleChildScrollView(
              child: ResponsiveContainer(
                maxWidth: ResponsiveLayout.getFormMaxWidth(context),
                padding: ResponsiveLayout.getResponsivePadding(context),
                centerContent: ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Asset Selection Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Charger',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        CheckboxListTile(
                          title: const Text(
                            'Charger not in the system',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Add a Siemens or Kostad charger that is not listed, then create the work order',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _isUnregisteredCharger,
                          onChanged: (value) {
                            setState(() {
                              _isUnregisteredCharger = value ?? false;
                              if (_isUnregisteredCharger) {
                                _selectedAsset = null;
                                _selectedAssetId = null;
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),

                        if (_isUnregisteredCharger) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedManufacturer,
                            decoration: const InputDecoration(
                              labelText: 'Charger type *',
                              hintText: 'Choose Siemens or Kostad',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.ev_station),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Siemens',
                                child: Text('Siemens Charger'),
                              ),
                              DropdownMenuItem(
                                value: 'Kostad',
                                child: Text('Kostad Charger'),
                              ),
                            ],
                            validator: (value) {
                              if (_isUnregisteredCharger &&
                                  (value == null || value.isEmpty)) {
                                return 'Please select Siemens or Kostad';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                _selectedManufacturer = value;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _unregisteredNameController,
                            decoration: const InputDecoration(
                              labelText: 'Charger name *',
                              hintText: 'e.g. Mall P2 charger 3',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) {
                              if (_isUnregisteredCharger &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Please enter the charger name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Location *',
                              hintText: 'e.g. Building A, P2 bay 4',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            validator: (value) {
                              if (_isUnregisteredCharger &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Please enter the charger location';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _serialNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Serial number',
                              hintText: 'If available',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _assetTagController,
                            decoration: const InputDecoration(
                              labelText: 'Asset tag / QR',
                              hintText: 'If available',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code_2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This charger will be added to the catalog, then the work order will be created on it',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (!_isUnregisteredCharger) ...[
                          // For requestors: Show manufacturer selector and charger dropdown
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              final role = authProvider.currentUser?.role;
                              final isRequestor = role == 'requestor';
                              final isTechnician = role == 'technician';

                              if (isRequestor || isTechnician) {
                                return Column(
                                  children: [
                                    if (isTechnician) ...[
                                      ElevatedButton.icon(
                                        onPressed: _scanChargerQr,
                                        icon: const Icon(Icons.qr_code_scanner),
                                        label: const Text('Scan charger QR'),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    _buildChargerSelection(),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _scanChargerQr,
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan QR Code'),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EnhancedAssetSelectionWidget(
                                            title: 'Select Asset for Work Order',
                                            onAssetSelected: _handleAssetSelection,
                                          ),
                                        ),
                                      );

                                      if (result != null && mounted) {
                                        setState(() {
                                          _selectedAsset = result;
                                          _selectedAssetId = result.id;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.search),
                                    label: const Text('Search assets'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Enhanced Selected Asset Display
                          if (_selectedAsset != null) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Selected charger:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ComprehensiveAssetDisplayWidget(
                              asset: _selectedAsset!,
                              isCompact: true,
                              onViewDetails: _viewAssetDetails,
                              onSelectAsset: (asset) => _selectAsset(),
                              onEditAsset: (asset) => _selectAsset(),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _requestorNameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'Enter name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    hintText: 'Enter number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'Enter your work email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryIssue,
                  decoration: const InputDecoration(
                    labelText: 'Category issue *',
                    hintText: 'Select type of issue',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: kRequestorCategoryIssueOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryIssue = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Problem Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _problemController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Enter a detailed description of the issue...',
                            border: OutlineInputBorder(),
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
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTechnicianAssignmentCard(),
                const SizedBox(height: 16),

                // Photo Attachment Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attach Photo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_photoPath != null) ...[
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(_photoPath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(Icons.edit),
                            label: const Text('Change Photo'),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: _showImageSourceDialog,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Attach Photo'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Submit Request',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
              ),
            ),
          ),
        ),
      );

  Future<void> _scanChargerQr() async {
    final result = await Navigator.push<Asset>(
      context,
      MaterialPageRoute(
        builder: (context) => const MobileQRScannerWidget(
          returnResolvedAsset: true,
        ),
      ),
    );
    if (result != null && mounted) {
      _applySelectedCharger(result);
    }
  }

  void _applySelectedCharger(Asset asset) {
    if (!isChargerLikeAsset(asset)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That QR is not a charger. Select a Siemens or Kostad charger.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _selectedAsset = asset;
      _selectedAssetId = asset.id;
      _selectedManufacturer = createFormChargerBrand(asset);
    });
    _loadCompanyChargers(_selectedManufacturer!);
  }

  // Handler for Enhanced Asset Selection
  void _handleAssetSelection(Asset asset) {
    if (isChargerLikeAsset(asset)) {
      _applySelectedCharger(asset);
      return;
    }
    setState(() {
      _selectedAsset = asset;
      _selectedAssetId = asset.id;
    });
  }

  // View asset details
  void _viewAssetDetails(Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedAssetDetailsScreen(
          asset: asset,
        ),
      ),
    );
  }

  // Select asset (reopen selection)
  void _selectAsset() {
    // This will trigger the asset selection again
    // The button press will handle this
  }

  Widget _buildChargerSelection() {
    return Consumer<UnifiedDataProvider>(
      builder: (context, unifiedProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Manufacturer Selection
            DropdownButtonFormField<String>(
              initialValue: _selectedManufacturer,
              decoration: const InputDecoration(
                labelText: 'Select Charger Type *',
                hintText: 'Choose Siemens or Kostad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.ev_station),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Siemens',
                  child: Text('Siemens Charger'),
                ),
                DropdownMenuItem(
                  value: 'Kostad',
                  child: Text('Kostad Charger'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedManufacturer = value;
                  _selectedAsset = null;
                  _selectedAssetId = null;
                  _companyChargers = [];
                });
                if (value != null) {
                  _loadCompanyChargers(value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Charger Dropdown (shown after manufacturer is selected)
            if (_selectedManufacturer != null) ...[
              if (_isLoadingChargers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_companyChargers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _chargerEmptyMessage(),
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<Asset>(
                  key: ValueKey(
                    '${_selectedManufacturer}_${_selectedAsset?.id}_${_companyChargers.length}',
                  ),
                  initialValue: _companyChargers.contains(_selectedAsset)
                      ? _selectedAsset
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Select Charger *',
                    hintText: 'Choose a charger',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.ev_station),
                    helperText: '${_companyChargers.length} charger${_companyChargers.length != 1 ? 's' : ''} available',
                  ),
                  selectedItemBuilder: (context) => _companyChargers
                      .map(
                        (charger) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            charger.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  items: _companyChargers.map((charger) {
                    // Build display text with all important details
                    final details = <String>[];
                    if (charger.qrCode != null && charger.qrCode!.isNotEmpty) {
                      details.add('Tag: ${charger.qrCode}');
                    }
                    if (charger.qrCodeId != null && charger.qrCodeId!.isNotEmpty) {
                      details.add('Asset #: ${charger.qrCodeId}');
                    }
                    if (charger.serialNumber != null && charger.serialNumber!.isNotEmpty) {
                      details.add('Serial: ${charger.serialNumber}');
                    }
                    if (charger.location.isNotEmpty) {
                      details.add('Location: ${charger.location}');
                    }
                    final detailText = details.isNotEmpty ? ' (${details.join(', ')})' : '';

                    return DropdownMenuItem<Asset>(
                      value: charger,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            charger.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (detailText.isNotEmpty)
                            Text(
                              detailText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAsset = value;
                      _selectedAssetId = value?.id;
                    });
                  },
                ),
            ],
          ],
        );
      },
    );
  }

  String _chargerEmptyMessage() {
    final isRequestor =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.role ==
            'requestor';
    if (isRequestor) {
      return 'No $_selectedManufacturer chargers found for your company';
    }
    return 'No $_selectedManufacturer chargers found';
  }

  Future<void> _loadCompanyChargers(String manufacturer) async {
    setState(() {
      _isLoadingChargers = true;
      _companyChargers = [];
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final isRequestor = user?.role == 'requestor';
      final companyId = user?.companyId;

      if (isRequestor && (companyId == null || companyId.trim().isEmpty)) {
        if (mounted) {
          setState(() {
            _isLoadingChargers = false;
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

      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final chargers = chargersForCreateForm(
        assets: unifiedProvider.assets,
        manufacturer: manufacturer,
        companyId: companyId,
        restrictToCompany: isRequestor,
      );

      if (mounted) {
        final selectedId = _selectedAssetId ?? _selectedAsset?.id;
        Asset? selectedInList;
        if (selectedId != null) {
          for (final charger in chargers) {
            if (charger.id == selectedId) {
              selectedInList = charger;
              break;
            }
          }
        }
        setState(() {
          _companyChargers = chargers;
          _isLoadingChargers = false;
          if (selectedInList != null) {
            _selectedAsset = selectedInList;
            _selectedAssetId = selectedInList.id;
          }
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isLoadingChargers = false;
        });
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load chargers. Please try again.',
          stackTrace: st,
          contextLabel: 'create_work_request_screen: Could not load chargers. Pleas',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Widget _buildTechnicianAssignmentCard() => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, _) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final isTechnician = authProvider.currentUser?.role == 'technician';
          
          // Hide assignment section for technicians - they're auto-assigned
          if (isTechnician) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This work order will be automatically assigned to you',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final technicians = unifiedProvider.users
              .where((user) => user.isTechnician)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_add, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Assign Technicians (optional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedTechnicianIds.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(
                            _selectedTechnicianIds.clear,
                          ),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (technicians.isEmpty)
                    Text(
                      'No technicians available',
                      style: AppTheme.smallText.copyWith(
                        color: AppTheme.secondaryTextColor,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: technicians.map((tech) {
                        final isSelected =
                            _selectedTechnicianIds.contains(tech.id);
                        final displayName = _technicianName(tech);
                        return FilterChip(
                          selected: isSelected,
                          showCheckmark: true,
                          backgroundColor:
                              isSelected ? AppTheme.accentBlue.withValues(alpha: 0.15) : null,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedTechnicianIds.add(tech.id);
                              } else {
                                _selectedTechnicianIds.remove(tech.id);
                              }
                            });
                          },
                          label: SizedBox(
                            width: 180,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppTheme.accentBlue,
                                  child: Text(
                                    tech.name.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : 'T',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedTechnicianIds.isEmpty
                        ? 'No technicians selected'
                        : 'Selected: ${_selectedTechnicianIds.length}',
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  String _technicianName(User tech) {
    if (tech.name.trim().isNotEmpty) return tech.name;
    if (tech.email.trim().isNotEmpty) return tech.email;
    return tech.id;
  }
}
