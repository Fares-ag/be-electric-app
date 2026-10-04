import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/locator.dart';
import '../../models/asset.dart';
import '../../models/pm_task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../services/connectivity_service.dart';
import '../../screens/assets/enhanced_asset_details_screen.dart';
import '../../utils/app_theme.dart';
import '../../widgets/enhanced_asset_display_widget.dart';
import '../../widgets/enhanced_asset_selection_widget.dart';
import '../../utils/user_facing_errors.dart';

class CreatePMTaskScreen extends StatefulWidget {
  const CreatePMTaskScreen({super.key, this.initialAsset});

  final Asset? initialAsset;

  @override
  State<CreatePMTaskScreen> createState() => _CreatePMTaskScreenState();
}

class _ChecklistTemplateItem {
  _ChecklistTemplateItem({
    required this.text,
    required this.isRequired,
  });

  final String text;
  final bool isRequired;
}

class _CreatePMTaskScreenState extends State<CreatePMTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _checklistController = TextEditingController();
  final _locationController = TextEditingController();

  Asset? _selectedAsset;
  final Set<String> _selectedTechnicianIds = <String>{};
  PMTaskFrequency _selectedFrequency = PMTaskFrequency.monthly;
  DateTime? _nextDueDate;
  bool _isLoading = false;
  bool _newChecklistRequired = true;
  List<_ChecklistTemplateItem> _checklistItems = [];
  bool _isGeneralMaintenance = false;
  String? _facilityType;

  // Facility type options (same as work order screen)
  static const Map<String, String> _facilityTypes = {
    'Civil': 'Wall Paint, Wall Repairs, Ceiling, etc.',
    'MEP': 'Plumbing, Sliding Door, etc.',
    'Appliances': 'Kettle, Fridge, Microwaves, TV, etc.',
    'Electrical': 'Lights, Sockets, Wires, etc.',
    'Carpentry': 'Ceiling, Wooden Door, etc.',
    'Others': 'Plants, etc.',
  };

  @override
  void initState() {
    super.initState();
    _intervalDaysController.text = '30'; // Default to 30 days
    _nextDueDate = DateTime.now().add(const Duration(days: 30));
    // Prefill asset when provided (e.g., from QR scan)
    if (widget.initialAsset != null) {
      _selectedAsset = widget.initialAsset;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _intervalDaysController.dispose();
    _checklistController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _addChecklistItem() {
    final text = _checklistController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _checklistItems.add(
          _ChecklistTemplateItem(text: text, isRequired: _newChecklistRequired),
        );
        _checklistController.clear();
        _newChecklistRequired = true;
      });
    }
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
    });
  }

  void _updateNextDueDate() {
    final intervalDays = int.tryParse(_intervalDaysController.text) ?? 30;
    setState(() {
      _nextDueDate = DateTime.now().add(Duration(days: intervalDays));
    });
  }

  List<_ChecklistTemplateItem> _defaultChecklistTemplates() => [
        _ChecklistTemplateItem(
          text: 'Inspect equipment condition',
          isRequired: true,
        ),
        _ChecklistTemplateItem(
          text: 'Check for any visible damage',
          isRequired: true,
        ),
        _ChecklistTemplateItem(
          text: 'Test equipment functionality',
          isRequired: true,
        ),
        _ChecklistTemplateItem(
          text: 'Clean and lubricate as needed',
          isRequired: false,
        ),
        _ChecklistTemplateItem(
          text: 'Document findings',
          isRequired: true,
        ),
      ];

  String _serializeChecklist() {
    // Guard against any unexpected nulls or invalid items
    final items = _checklistItems
        .where((item) => item.text.trim().isNotEmpty)
        .map(
          (item) => {
            'text': item.text,
            'required': item.isRequired,
          },
        )
        .toList();
    return jsonEncode(items);
  }

  Future<void> _createPMTask() async {
    if (!_formKey.currentState!.validate()) return;
    // Asset selection is now optional - removed validation

    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Create default checklist if none provided AND not general maintenance
      if (_checklistItems.isEmpty && !_isGeneralMaintenance) {
        _checklistItems = _defaultChecklistTemplates();
      }

      // Debug: Print checklist items before serialization
      debugPrint('📋 CreatePMTask: Checklist items count: ${_checklistItems.length}');
      for (var i = 0; i < _checklistItems.length; i++) {
        debugPrint('   Item $i: ${_checklistItems[i].text} (required: ${_checklistItems[i].isRequired})');
      }
      
      final checklistJson = _serializeChecklist();
      debugPrint('📋 CreatePMTask: Serialized checklist JSON: $checklistJson');

      final creatorId = authProvider.currentUser?.id;
      debugPrint('🔍 CreatePMTask: Creator ID from authProvider: $creatorId');
      debugPrint(
        '🔍 CreatePMTask: Creator name: ${authProvider.currentUser?.name}',
      );
      debugPrint(
        '🔍 CreatePMTask: Creator email: ${authProvider.currentUser?.email}',
      );
      debugPrint(
        '🔍 CreatePMTask: Creator role: ${authProvider.currentUser?.role}',
      );

      // If the current user is a technician, don't pass assignedTechnicianIds
      // The provider will auto-assign to them
      final isTechnician = authProvider.currentUser?.role == 'technician';

      // Base description entered by user
      final description = _descriptionController.text.trim();

      // Determine asset and location information
      Asset? assetForCreation = _selectedAsset;
      String assetIdForCreation = _selectedAsset?.id ?? '';

      if (_isGeneralMaintenance) {
        // For general facility maintenance, we don't tie to a real assetId,
        // but we still want to show a friendly "asset" name and location.
        final location = _locationController.text.trim();
        final facilityLabel =
            _facilityType != null && _facilityType!.isNotEmpty
                ? 'General Facility - $_facilityType'
                : 'General Facility Maintenance';

        assetForCreation = Asset(
          id: '', // Keep assetId empty so it's not treated as a real asset
          name: facilityLabel,
          location: location,
          status: 'general',
          category: 'facility',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        assetIdForCreation = '';
      }

      // Use description as task name (or generate from description if needed)
      final taskName = description.isNotEmpty 
          ? (description.length > 50 ? '${description.substring(0, 50)}...' : description)
          : 'PM Task';
      
      final wasOffline = AppConfig.isOfflineModeEnabled &&
          !sl<ConnectivityService>().isOnline;

      await unifiedProvider.createPMTask(
        taskName: taskName,
        assetId: assetIdForCreation, // Empty string for general facility tasks
        asset: assetForCreation, // Pass synthetic asset for general facility
        description: description,
        checklistJson: checklistJson,
        frequency: _selectedFrequency,
        nextDue: _nextDueDate ?? DateTime.now().add(const Duration(days: 30)),
        // Technicians can't assign others - they're auto-assigned
        assignedTechnicianIds: isTechnician
            ? null
            : (_selectedTechnicianIds.isEmpty
                ? null
                : _selectedTechnicianIds.toList()),
        createdById: creatorId, // Pass creator ID for auto-assignment
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasOffline
                  ? 'PM task saved locally — will sync when online'
                  : 'PM task created successfully',
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
          genericMessage: 'Could not create PM task. Please try again.',
          stackTrace: st,
          contextLabel: 'CreatePmTask: create',
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
          title: const Text('Create PM Task'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.darkTextColor,
          elevation: AppTheme.elevationS,
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Asset Selection
                Card(
                  elevation: AppTheme.elevationS,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2, color: AppTheme.accentBlue),
                            SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Asset (Optional)',
                              style: AppTheme.heading2,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        // General Facility Maintenance toggle (no specific asset)
                        CheckboxListTile(
                          title: const Text(
                            'General Facility Maintenance',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'For work not tied to a specific asset (e.g., painting walls, plumbing)',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _isGeneralMaintenance,
                          onChanged: (value) {
                            setState(() {
                              _isGeneralMaintenance = value ?? false;
                              if (_isGeneralMaintenance) {
                                // Clear asset selection when switching to general maintenance
                                _selectedAsset = null;
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        if (_isGeneralMaintenance) ...[
                          // Info box
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
                                    'This PM task will not be linked to a specific asset',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          // Facility Type Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _facilityType,
                            decoration: const InputDecoration(
                              labelText: 'Facility Type',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.construction),
                            ),
                            hint: const Text('Select facility type'),
                            items: _facilityTypes.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          entry.value,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _facilityType = value;
                              });
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          // Location field (optional but recommended)
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Location',
                              hintText:
                                  'e.g., Conference Room 3B, Main Lobby',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                          ),
                        ] else if (_selectedAsset == null)
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EnhancedAssetSelectionWidget(
                                    title: 'Select Asset for PM Task',
                                    onAssetSelected: _handleAssetSelection,
                                  ),
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _selectedAsset = result;
                                });
                              }
                            },
                            icon: const Icon(Icons.search),
                            label: const Text('🚀 Enhanced Asset Search'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          Column(
                            children: [
                              const SizedBox(height: 8),
                              ComprehensiveAssetDisplayWidget(
                                asset: _selectedAsset!,
                                isCompact: true,
                                onViewDetails: _viewAssetDetails,
                                onSelectAsset: (asset) => _selectAsset(),
                                onEditAsset: (asset) => _selectAsset(),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                // Technician assignment
                Consumer<UnifiedDataProvider>(
                  builder: (context, unifiedProvider, _) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final isTechnician = authProvider.currentUser?.role == 'technician';
                    
                    // Hide assignment section for technicians - they're auto-assigned
                    if (isTechnician) {
                      return Card(
                        elevation: AppTheme.elevationS,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: AppTheme.successColor,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  'This PM task will be automatically assigned to you',
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
                    
                    final technicians = unifiedProvider
                        .getTechnicians()
                        .where((tech) => tech.role == 'technician')
                        .toList();
                    return Card(
                      elevation: AppTheme.elevationS,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.group_add),
                                const SizedBox(width: AppTheme.spacingS),
                                const Text(
                                  'Assign Technicians (optional)',
                                  style: AppTheme.heading2,
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => setState(
                                    _selectedTechnicianIds.clear,
                                  ),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            if (technicians.isEmpty)
                              Text(
                                'No technicians available',
                                style: AppTheme.smallText.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                ),
                              )
                            else
                              Wrap(
                                spacing: AppTheme.spacingS,
                                runSpacing: AppTheme.spacingS,
                                children: technicians
                                    .map(
                                      (tech) => FilterChip(
                                        selected: _selectedTechnicianIds
                                            .contains(tech.id),
                                        showCheckmark: true,
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedTechnicianIds
                                                  .add(tech.id);
                                            } else {
                                              _selectedTechnicianIds
                                                  .remove(tech.id);
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
                                                backgroundColor:
                                                    AppTheme.accentBlue,
                                                child: Text(
                                                  tech.name.isNotEmpty
                                                      ? tech.name[0]
                                                          .toUpperCase()
                                                      : 'T',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: AppTheme.spacingXS,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  tech.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTheme.smallText
                                                      .copyWith(
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
                            const SizedBox(height: AppTheme.spacingS),
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
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Describe the maintenance task in detail',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    prefixIcon: const Icon(Icons.description),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Frequency and Interval
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<PMTaskFrequency>(
                        initialValue: _selectedFrequency,
                        decoration: InputDecoration(
                          labelText: 'Frequency *',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                          ),
                          prefixIcon: const Icon(Icons.schedule),
                        ),
                        items: PMTaskFrequency.values
                            .map(
                              (frequency) => DropdownMenuItem(
                                value: frequency,
                                child:
                                    Text(_getFrequencyDisplayName(frequency)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedFrequency = value;
                              _intervalDaysController.text =
                                  _getDefaultIntervalDays(value).toString();
                              _updateNextDueDate();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: TextFormField(
                        controller: _intervalDaysController,
                        decoration: InputDecoration(
                          labelText: 'Interval (Days)',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusS),
                          ),
                          prefixIcon: const Icon(Icons.calendar_today),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _updateNextDueDate(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final days = int.tryParse(value);
                          if (days == null || days <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),

                // Next Due Date
                if (_nextDueDate != null)
                  Card(
                    color: AppTheme.accentBlue.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingS),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: AppTheme.accentBlue),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Next Due Date: ${_formatDate(_nextDueDate!)}',
                            style: AppTheme.bodyText,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingM),

                // Checklist
                Card(
                  elevation: AppTheme.elevationS,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.checklist, color: AppTheme.accentBlue),
                            SizedBox(width: AppTheme.spacingS),
                            Text(
                              'Checklist Items',
                              style: AppTheme.heading2,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _checklistController,
                                decoration: InputDecoration(
                                  labelText: 'Add checklist item',
                                  hintText: 'e.g., Check oil levels',
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  prefixIcon: const Icon(Icons.add),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            ElevatedButton(
                              onPressed: _addChecklistItem,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGreen,
                                foregroundColor: Colors.white,
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _newChecklistRequired,
                              onChanged: (value) => setState(
                                () => _newChecklistRequired = value ?? true,
                              ),
                            ),
                            const Text('Mark as required'),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        if (_checklistItems.isNotEmpty)
                          ...(_checklistItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppTheme.spacingXS,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  item.isRequired
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: item.isRequired
                                      ? AppTheme.accentBlue
                                      : Colors.grey,
                                ),
                                title: Text(item.text),
                                subtitle: Text(
                                  item.isRequired ? 'Required' : 'Optional',
                                  style: AppTheme.smallText.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: IconButton(
                                  onPressed: () => _removeChecklistItem(index),
                                  icon: const Icon(Icons.delete),
                                  color: AppTheme.accentRed,
                                ),
                              ),
                            );
                          })),
                        if (_checklistItems.isEmpty)
                          const Text(
                            'No checklist items added. Default items will be used.',
                            style: AppTheme.secondaryText,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createPMTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen, // Be Electric brand green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingM,
                      ),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Create PM Task',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  String _getFrequencyDisplayName(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return 'Daily';
      case PMTaskFrequency.weekly:
        return 'Weekly';
      case PMTaskFrequency.monthly:
        return 'Monthly';
      case PMTaskFrequency.quarterly:
        return 'Quarterly';
      case PMTaskFrequency.semiAnnually:
        return 'Semi-Annually';
      case PMTaskFrequency.annually:
        return 'Annually';
      case PMTaskFrequency.asNeeded:
        return 'As Needed';
    }
  }

  int _getDefaultIntervalDays(PMTaskFrequency frequency) {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return 1;
      case PMTaskFrequency.weekly:
        return 7;
      case PMTaskFrequency.monthly:
        return 30;
      case PMTaskFrequency.quarterly:
        return 90;
      case PMTaskFrequency.semiAnnually:
        return 180;
      case PMTaskFrequency.annually:
        return 365;
      case PMTaskFrequency.asNeeded:
        return 30; // Default fallback
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  // Handler for Enhanced Asset Selection
  void _handleAssetSelection(Asset asset) {
    setState(() {
      _selectedAsset = asset;
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
}
