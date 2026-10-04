import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/locator.dart';
import '../../models/asset.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../services/connectivity_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/offline_network.dart';
import '../../widgets/asset_search_widget.dart';
import '../../widgets/mobile_qr_scanner_widget.dart';
import '../../utils/user_facing_errors.dart';

class MobileCreateWorkRequestScreen extends StatefulWidget {
  const MobileCreateWorkRequestScreen({super.key});

  @override
  State<MobileCreateWorkRequestScreen> createState() =>
      _MobileCreateWorkRequestScreenState();
}

class _MobileCreateWorkRequestScreenState
    extends State<MobileCreateWorkRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();

  String? _selectedAssetId;
  String? _selectedAssetName;
  String? _selectedLocation;
  Asset? _selectedAsset; // Store the full asset object
  String? _photoPath;
  final Set<String> _selectedTechnicianIds = <String>{};
  WorkOrderPriority _selectedPriority = WorkOrderPriority.medium;
  bool _isLoading = false;

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _photoPath = pickedFile.path;
      });
    }
  }

  Future<void> _selectImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _photoPath = pickedFile.path;
      });
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
    if (_selectedAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an asset'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
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

      var finalPhotoPath = _photoPath;
      final offlineMode = AppConfig.isOfflineModeEnabled;
      final isOnline = sl<ConnectivityService>().isOnline;
      final wasOffline = offlineMode && !isOnline;

      if (_photoPath != null && !(offlineMode && !isOnline)) {
        try {
          final workOrderRepository = CmmsRepositories.workOrders;
          final photoFile = XFile(_photoPath!);
          final uploadedUrl = await workOrderRepository.uploadWorkOrderPhoto(
            photoFile: photoFile,
            workOrderId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (uploadedUrl != null) {
            finalPhotoPath = uploadedUrl;
          }
        } catch (e, st) {
          if (offlineMode && isLikelyNetworkError(e)) {
            finalPhotoPath = _photoPath;
          }
        }
      }

      await unifiedProvider.createWorkOrder(
        assetId: _selectedAssetId,
        asset: _selectedAsset, // Pass the full asset object
        problemDescription: _problemController.text.trim(),
        requestorId: authProvider.currentUser!.id,
        photoPath: finalPhotoPath,
        priority: _selectedPriority,
        assignedTechnicianIds: _selectedTechnicianIds.isEmpty
            ? null
            : _selectedTechnicianIds.toList(),
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
        Navigator.pop(context);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not create work request. Please try again.',
          stackTrace: st,
          contextLabel: 'mobile_create_work_request_screen: Could not create work request.',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
                          'Asset Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // QR Scanner Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MobileQRScannerWidget(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan QR Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Manual Search Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            final unifiedProvider =
                                Provider.of<UnifiedDataProvider>(
                              context,
                              listen: false,
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AssetSearchWidget(),
                              ),
                            );

                            if (!mounted) return;
                            if (result != null) {
                              final asset = unifiedProvider.assets.firstWhere(
                                (a) => a.id == result['assetId'],
                                orElse: () => Asset(
                                  id: result['assetId'],
                                  name: result['assetName'] ?? 'Unknown Asset',
                                  location: result['location'] ?? '',
                                  category: '',
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                ),
                              );

                              setState(() {
                                _selectedAssetId = result['assetId'];
                                _selectedAssetName = result['assetName'];
                                _selectedLocation = result['location'];
                                _selectedAsset =
                                    asset; // Store the full asset object
                              });

                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Asset selected: ${result['assetName']}',
                                  ),
                                  backgroundColor: AppTheme.accentGreen,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Search Asset'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selected Asset Display
                        if (_selectedAssetId != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Selected Asset:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Asset: $_selectedAssetName'),
                                Text('Location: $_selectedLocation'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Problem Description Card
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
                            hintText: 'Describe the problem or issue...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please describe the problem';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Selection Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Priority',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<WorkOrderPriority>(
                          initialValue: _selectedPriority,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          items: WorkOrderPriority.values
                              .map(
                                (priority) => DropdownMenuItem(
                                  value: priority,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: AppTheme.getPriorityColor(
                                            priority.name,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(priority.name.toUpperCase()),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedPriority = value;
                              });
                            }
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
                              child: FutureBuilder<Uint8List>(
                                future: XFile(_photoPath!).readAsBytes(),
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
                    backgroundColor: AppTheme.accentGreen, // Be Electric brand green
                    foregroundColor: Colors.white,
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
      );

  Widget _buildTechnicianAssignmentCard() =>
      Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, _) {
          final technicians = unifiedProvider.users
              .where((user) => user.isTechnician)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

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
                        'Assign Technicians',
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
                        return FilterChip(
                          selected: isSelected,
                          showCheckmark: true,
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
                            width: 140,
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
}
