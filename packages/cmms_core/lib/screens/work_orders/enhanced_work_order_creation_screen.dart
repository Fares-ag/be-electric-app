// Enhanced Work Order Creation Screen - Guided work order builder

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../models/work_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/enhanced_asset_display_widget.dart';
import '../../widgets/enhanced_asset_selection_widget.dart';
import '../assets/asset_detail_screen.dart';
import '../../utils/user_facing_errors.dart';

class EnhancedWorkOrderCreationScreen extends StatefulWidget {
  const EnhancedWorkOrderCreationScreen({super.key});

  @override
  State<EnhancedWorkOrderCreationScreen> createState() =>
      _EnhancedWorkOrderCreationScreenState();
}

class _EnhancedWorkOrderCreationScreenState
    extends State<EnhancedWorkOrderCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();

  Asset? _selectedAsset;
  WorkOrderPriority _selectedPriority = WorkOrderPriority.medium;
  RepairCategory? _selectedCategory;
  bool _isLoading = false;
  final Set<String> _selectedTechnicianIds = <String>{};

  @override
  void dispose() {
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Create Work Order'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAssetSelectionCard(),
                const SizedBox(height: 16),
                _buildProblemDescriptionCard(),
                const SizedBox(height: 16),
                _buildPriorityCard(),
                const SizedBox(height: 16),
                _buildCategoryCard(),
                const SizedBox(height: 16),
                _buildTechnicianAssignmentCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      );

  Widget _buildAssetSelectionCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Asset Selection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedAsset == null) ...[
                ElevatedButton.icon(
                  onPressed: _selectAsset,
                  icon: const Icon(Icons.search),
                  label: const Text('Select Asset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                ComprehensiveAssetDisplayWidget(
                  asset: _selectedAsset!,
                  isCompact: true,
                  onViewDetails: _viewAssetDetails,
                  onSelectAsset: (asset) => _selectAsset(),
                  onEditAsset: (asset) => _selectAsset(),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildProblemDescriptionCard() => Card(
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
      );

  Widget _buildPriorityCard() => Card(
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
                                color: AppTheme.getPriorityColor(priority.name),
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
      );

  Widget _buildCategoryCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Repair Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RepairCategory>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select repair category',
                ),
                items: RepairCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(_getCategoryDisplayName(category)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildSubmitButton() => ElevatedButton(
        onPressed: _isLoading ? null : _submitWorkOrder,
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Create Work Order',
                style: TextStyle(fontSize: 16),
              ),
      );

  Future<void> _selectAsset() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedAssetSelectionWidget(
          title: 'Select Asset for Work Order',
          onAssetSelected: _handleAssetSelection,
        ),
      ),
    );
  }

  static void _handleAssetSelection(Asset asset) {
    // This will be handled by the navigation result
  }

  void _viewAssetDetails(Asset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssetDetailScreen(asset: asset),
      ),
    );
  }

  Future<void> _submitWorkOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAsset == null) {
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
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);

      await unifiedProvider.createWorkOrder(
        assetId: _selectedAsset!.id,
        asset: _selectedAsset,
        problemDescription: _problemController.text.trim(),
        requestorId: authProvider.currentUser!.id,
        priority: _selectedPriority,
        category: _selectedCategory,
        assignedTechnicianIds:
            _selectedTechnicianIds.isEmpty ? null : _selectedTechnicianIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work order created successfully'),
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
          genericMessage: 'Could not create work order. Please try again.',
          stackTrace: st,
          contextLabel: 'enhanced_work_order_creation_screen: Could not create work order. P',
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
                          width: 180,
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
                              const SizedBox(width: 8),
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

  String _getCategoryDisplayName(RepairCategory category) {
    switch (category) {
      case RepairCategory.mechanicalHvac:
        return 'Mechanical & HVAC Repairs';
      case RepairCategory.electrical:
        return 'Electrical Repairs';
      case RepairCategory.structural:
        return 'Structural Repairs';
      case RepairCategory.plumbing:
        return 'Plumbing and Water System Repairs';
      case RepairCategory.interior:
        return 'Interior Repairs';
      case RepairCategory.exterior:
        return 'Exterior Repairs';
      case RepairCategory.itLowVoltage:
        return 'IT & Low Voltage System Repairs';
      case RepairCategory.specializedEquipment:
        return 'Specialized Equipment Repairs';
      case RepairCategory.safetyCompliance:
        return 'Safety & Compliance Repairs';
      case RepairCategory.emergency:
        return 'Emergency or Unscheduled Repairs';
      case RepairCategory.preventive:
        return 'Preventive Maintenance';
      case RepairCategory.reactive:
        return 'Reactive Maintenance';
    }
  }
}
