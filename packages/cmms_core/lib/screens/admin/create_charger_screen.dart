import 'package:flutter/material.dart';

import '../../models/asset.dart';
import '../../models/company.dart';
import '../../services/unified_data_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/charger_asset_filter.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class CreateChargerScreen extends StatefulWidget {
  final Company company;
  final Asset? charger; // If provided, we're editing

  const CreateChargerScreen({
    required this.company,
    this.charger,
    super.key,
  });

  @override
  State<CreateChargerScreen> createState() => _CreateChargerScreenState();
}

class _CreateChargerScreenState extends State<CreateChargerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _assetTagController = TextEditingController(); // Asset number/tag
  String _status = 'active';
  String? _chargerType; // 'Siemens' or 'Kostad'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_syncDerivedManufacturer);
    // Populate fields if editing
    if (widget.charger != null) {
      _nameController.text = widget.charger!.name;
      _locationController.text = widget.charger!.location;
      _modelController.text = widget.charger!.model ?? '';
      _serialNumberController.text = widget.charger!.serialNumber ?? '';
      _descriptionController.text = widget.charger!.description ?? '';
      _assetTagController.text = widget.charger!.qrCodeId ?? widget.charger!.qrCode ?? '';
      _status = widget.charger!.status;
      _chargerType = resolveChargerManufacturer(widget.charger!);
      _syncDerivedManufacturer();
    }
  }

  void _syncDerivedManufacturer() {
    _manufacturerController.text =
        deriveChargerManufacturerFromName(_nameController.text);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _descriptionController.dispose();
    _assetTagController.dispose();
    super.dispose();
  }

  Future<void> _saveCharger() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Safely get all controller values
      String name;
      String location;
      String description;
      String manufacturer;
      String model;
      String serialNumber;
      String assetTag;

      try {
        name = _nameController.text.trim();
        location = _locationController.text.trim();
        description = _descriptionController.text.trim();
        manufacturer = deriveChargerManufacturerFromName(name);
        model = _modelController.text.trim();
        serialNumber = _serialNumberController.text.trim();
        assetTag = _assetTagController.text.trim();
      } catch (e, st) {
        throw Exception('Error reading form fields: $e');
      }

      if (!mounted) return;

      // Validate required fields
      if (name.isEmpty) {
        throw Exception('Charger name is required');
      }
      if (location.isEmpty) {
        throw Exception('Location is required');
      }
      if (_chargerType == null || _chargerType!.isEmpty) {
        throw Exception('Charger type is required');
      }

      final now = DateTime.now();
      final charger = Asset(
        id: widget.charger?.id ?? '',
        name: name,
        location: location,
        description: description.isEmpty ? null : description,
        manufacturer: manufacturer.isEmpty ? null : manufacturer,
        model: model.isEmpty ? null : model,
        serialNumber: serialNumber.isEmpty ? null : serialNumber,
        qrCode: assetTag.isEmpty ? null : assetTag,
        qrCodeId: assetTag.isEmpty ? null : assetTag,
        status: _status,
        itemType: 'charger',
        category: 'charger',
        companyId: widget.company.id, // Link to company
        createdAt: widget.charger?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.charger == null) {
        // Create new charger
        final unifiedService = sl<UnifiedDataService>();
        await unifiedService.createAsset(charger);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Charger created successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Update existing charger via UnifiedDataService so local cache is refreshed
        await sl<UnifiedDataService>().updateAsset(
          widget.charger!.id,
          charger,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Charger updated successfully'),
              backgroundColor: AppTheme.accentGreen,
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
          genericMessage: 'Could not save charger. Please try again.',
          stackTrace: st,
          contextLabel: 'CreateCharger: save',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.charger == null
              ? 'Add Charger to ${widget.company.name}'
              : 'Edit Charger',
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        elevation: AppTheme.elevationS,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Company info card
              Card(
                color: AppTheme.accentGreen.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: AppTheme.accentGreen),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Company',
                              style: AppTheme.captionText,
                            ),
                            Text(
                              widget.company.name,
                              style: AppTheme.heading2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              // Charger Type - Required field at the top
              DropdownButtonFormField<String>(
                initialValue: _chargerType,
                decoration: const InputDecoration(
                  labelText: 'Charger Type *',
                  hintText: 'Select charger type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.ev_station),
                ),
                items: const [
                  DropdownMenuItem(value: 'Siemens', child: Text('Siemens Charger')),
                  DropdownMenuItem(value: 'Kostad', child: Text('Kostad Charger')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select charger type';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _chargerType = value;
                    if (value != null && _nameController.text.trim().isEmpty) {
                      _nameController.text = '$value Charger';
                    }
                    _syncDerivedManufacturer();
                  });
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Charger Name *',
                  hintText: _chargerType == 'Kostad'
                      ? 'e.g., Kostad Charger KEC00067'
                      : _chargerType == 'Siemens'
                          ? 'e.g., Siemens Charger #001'
                          : 'e.g., Charger Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter charger name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  hintText: 'e.g., C, FF or ME, GF or E, LG',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  helperText: 'Format: Section, Floor (e.g., C, FF = Section C, First Floor)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _assetTagController,
                decoration: InputDecoration(
                  labelText: 'Asset Tag / Asset Number *',
                  hintText: _chargerType == 'Kostad'
                      ? 'e.g., KEC00067, KEC00027'
                      : 'e.g., ASSET-001, TAG-12345',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code),
                  helperText: _chargerType == 'Kostad'
                      ? 'Kostad format: KEC followed by 5 digits (e.g., KEC00067)'
                      : 'Unique asset identifier or tag for this charger',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter asset tag';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _manufacturerController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Manufacturer',
                  hintText: 'Derived from charger name',
                  helperText:
                      'KOS* names → Kostad; all others → Siemens (matches Supabase)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'e.g., Model XYZ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _serialNumberController,
                decoration: InputDecoration(
                  labelText: 'Serial Number *',
                  hintText: _chargerType == 'Kostad'
                      ? 'e.g., KOS002220713QA, KOS002220714QA'
                      : 'e.g., Siemens serial number',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.confirmation_number),
                  helperText: _chargerType == 'Kostad'
                      ? 'Kostad format: KOS followed by numbers and letters (e.g., KOS002220713QA)'
                      : 'Manufacturer serial number',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter serial number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Additional notes about this charger',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppTheme.spacingM),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'active',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: 'inactive',
                    child: Text('Inactive'),
                  ),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCharger,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.charger == null
                            ? 'Create Charger'
                            : 'Update Charger',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

