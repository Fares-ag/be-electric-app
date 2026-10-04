import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/inventory_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class CreateInventoryItemScreen extends StatefulWidget {
  const CreateInventoryItemScreen({super.key});

  @override
  State<CreateInventoryItemScreen> createState() =>
      _CreateInventoryItemScreenState();
}

class _CreateInventoryItemScreenState extends State<CreateInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _supplierController = TextEditingController();
  final _costController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _maximumStockController = TextEditingController();
  final _locationController = TextEditingController();
  final _shelfController = TextEditingController();
  final _binController = TextEditingController();
  final _warrantyController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = 'spare_parts';
  String _selectedUnit = 'pieces';
  bool _isLoading = false;

  final List<String> _categories = [
    'spare_parts',
    'consumables',
    'tools',
    'safety_equipment',
    'cleaning_supplies',
    'office_supplies',
    'electrical',
    'mechanical',
    'hydraulic',
    'pneumatic',
    'other',
  ];

  final List<String> _units = [
    'pieces',
    'kg',
    'liters',
    'meters',
    'boxes',
    'packs',
    'rolls',
    'sheets',
    'units',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _partNumberController.dispose();
    _manufacturerController.dispose();
    _supplierController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _minimumStockController.dispose();
    _maximumStockController.dispose();
    _locationController.dispose();
    _shelfController.dispose();
    _binController.dispose();
    _warrantyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createInventoryItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      await inventoryProvider.createInventoryItem(
        name: _nameController.text.trim(),
        category: _selectedCategory,
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        sku: _skuController.text.trim().isNotEmpty
            ? _skuController.text.trim()
            : null,
        partNumber: _partNumberController.text.trim().isNotEmpty
            ? _partNumberController.text.trim()
            : null,
        manufacturer: _manufacturerController.text.trim().isNotEmpty
            ? _manufacturerController.text.trim()
            : null,
        supplier: _supplierController.text.trim().isNotEmpty
            ? _supplierController.text.trim()
            : null,
        cost: _costController.text.trim().isNotEmpty
            ? double.parse(_costController.text)
            : null,
        minimumStock: _minimumStockController.text.trim().isNotEmpty
            ? double.parse(_minimumStockController.text)
            : null,
        maximumStock: _maximumStockController.text.trim().isNotEmpty
            ? double.parse(_maximumStockController.text)
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        shelf: _shelfController.text.trim().isNotEmpty
            ? _shelfController.text.trim()
            : null,
        bin: _binController.text.trim().isNotEmpty
            ? _binController.text.trim()
            : null,
        warranty: _warrantyController.text.trim().isNotEmpty
            ? _warrantyController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory item created successfully'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not create inventory item. Please try again.',
          stackTrace: st,
          contextLabel: 'CreateInventoryItem: create',
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Create Inventory Item'),
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
                // Basic Information Card
                _buildSectionCard(
                  title: 'Basic Information',
                  icon: Icons.info_outline,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name *',
                        hintText: 'e.g., Oil Filter',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.inventory_2),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.category),
                            ),
                            items: _categories
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(_formatCategoryName(category)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedCategory = value;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedUnit,
                            decoration: InputDecoration(
                              labelText: 'Unit *',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.straighten),
                            ),
                            items: _units
                                .map(
                                  (unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedUnit = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Detailed description of the item',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Identification Card
                _buildSectionCard(
                  title: 'Identification',
                  icon: Icons.qr_code,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _skuController,
                            decoration: InputDecoration(
                              labelText: 'SKU',
                              hintText: 'Stock Keeping Unit',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.tag),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: TextFormField(
                            controller: _partNumberController,
                            decoration: InputDecoration(
                              labelText: 'Part Number',
                              hintText: 'Manufacturer part number',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.numbers),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _manufacturerController,
                            decoration: InputDecoration(
                              labelText: 'Manufacturer',
                              hintText: 'e.g., Bosch, Siemens',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.business),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: TextFormField(
                            controller: _supplierController,
                            decoration: InputDecoration(
                              labelText: 'Supplier',
                              hintText: 'Vendor name',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.local_shipping),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Stock & Cost Card
                _buildSectionCard(
                  title: 'Stock & Cost',
                  icon: Icons.analytics,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: 'Current Quantity *',
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.inventory),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter quantity';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Invalid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: TextFormField(
                            controller: _costController,
                            decoration: InputDecoration(
                              labelText: 'Unit Cost',
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minimumStockController,
                            decoration: InputDecoration(
                              labelText: 'Minimum Stock',
                              hintText: 'Reorder level',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.trending_down),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: TextFormField(
                            controller: _maximumStockController,
                            decoration: InputDecoration(
                              labelText: 'Maximum Stock',
                              hintText: 'Max capacity',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.trending_up),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.trim().isNotEmpty) {
                                if (double.tryParse(value) == null) {
                                  return 'Invalid number';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Location Card
                _buildSectionCard(
                  title: 'Location',
                  icon: Icons.location_on,
                  children: [
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'e.g., Warehouse A, Building 1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.place),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _shelfController,
                            decoration: InputDecoration(
                              labelText: 'Shelf',
                              hintText: 'Shelf number',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.view_module),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Expanded(
                          child: TextFormField(
                            controller: _binController,
                            decoration: InputDecoration(
                              labelText: 'Bin',
                              hintText: 'Bin number',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.inbox),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Additional Information Card
                _buildSectionCard(
                  title: 'Additional Information',
                  icon: Icons.note,
                  children: [
                    TextFormField(
                      controller: _warrantyController,
                      decoration: InputDecoration(
                        labelText: 'Warranty',
                        hintText: 'e.g., 1 year, 6 months',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.verified),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Additional notes or comments',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.note_add),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingL),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createInventoryItem,
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
                            'Create Inventory Item',
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
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
              Row(
                children: [
                  Icon(icon, color: AppTheme.accentBlue),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    title,
                    style: AppTheme.heading2,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              ...children,
            ],
          ),
        ),
      );

  String _formatCategoryName(String category) => category
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
