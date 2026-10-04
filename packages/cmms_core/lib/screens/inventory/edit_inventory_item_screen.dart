import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../providers/inventory_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class EditInventoryItemScreen extends StatefulWidget {
  const EditInventoryItemScreen({
    required this.item,
    super.key,
  });
  final InventoryItem item;

  @override
  State<EditInventoryItemScreen> createState() =>
      _EditInventoryItemScreenState();
}

class _EditInventoryItemScreenState extends State<EditInventoryItemScreen> {
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
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    _nameController.text = widget.item.name;
    _descriptionController.text = widget.item.description ?? '';
    _skuController.text = widget.item.sku ?? '';
    _partNumberController.text = widget.item.partNumber ?? '';
    _manufacturerController.text = widget.item.manufacturer ?? '';
    _supplierController.text = widget.item.supplier ?? '';
    _costController.text = widget.item.cost?.toString() ?? '';
    _quantityController.text = widget.item.quantity.toString();
    _minimumStockController.text = widget.item.minimumStock?.toString() ?? '';
    _maximumStockController.text = widget.item.maximumStock?.toString() ?? '';
    _locationController.text = widget.item.location ?? '';
    _shelfController.text = widget.item.shelf ?? '';
    _binController.text = widget.item.bin ?? '';
    _warrantyController.text = widget.item.warranty ?? '';
    _notesController.text = widget.item.notes ?? '';

    _selectedCategory = widget.item.category;
    _selectedUnit = widget.item.unit;
  }

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

  Future<void> _updateInventoryItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final inventoryProvider =
          Provider.of<InventoryProvider>(context, listen: false);

      // Create updated item
      final updatedItem = widget.item.copyWith(
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
        updatedAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      await inventoryProvider.updateInventoryItem(updatedItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory item updated successfully'),
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
          genericMessage: 'Could not update inventory item. Please try again.',
          stackTrace: st,
          contextLabel: 'EditInventoryItem: update',
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
          title: const Text('Edit Inventory Item'),
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
                                    child: Text(
                                      category
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
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
                                    child: Text(unit.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUnit = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Item description...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Stock Information Card
                _buildSectionCard(
                  title: 'Stock Information',
                  icon: Icons.inventory,
                  children: [
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Current Quantity *',
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter current quantity';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minimumStockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Minimum Stock',
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.trending_down),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: TextFormField(
                            controller: _maximumStockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Maximum Stock',
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.trending_up),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Product Information Card
                _buildSectionCard(
                  title: 'Product Information',
                  icon: Icons.shopping_cart,
                  children: [
                    TextFormField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        labelText: 'SKU',
                        hintText: 'Stock Keeping Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _partNumberController,
                      decoration: InputDecoration(
                        labelText: 'Part Number',
                        hintText: 'Manufacturer part number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _manufacturerController,
                            decoration: InputDecoration(
                              labelText: 'Manufacturer',
                              hintText: 'e.g., Bosch',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.business),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: TextFormField(
                            controller: _supplierController,
                            decoration: InputDecoration(
                              labelText: 'Supplier',
                              hintText: 'e.g., ABC Parts',
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
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cost',
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),

                // Location Information Card
                _buildSectionCard(
                  title: 'Location Information',
                  icon: Icons.location_on,
                  children: [
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'e.g., Warehouse A',
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
                              hintText: 'A1',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusS),
                              ),
                              prefixIcon: const Icon(Icons.shelves),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: TextFormField(
                            controller: _binController,
                            decoration: InputDecoration(
                              labelText: 'Bin',
                              hintText: 'B1',
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
                  icon: Icons.info,
                  children: [
                    TextFormField(
                      controller: _warrantyController,
                      decoration: InputDecoration(
                        labelText: 'Warranty',
                        hintText: 'e.g., 1 year',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.verified_user),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Additional notes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXL),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateInventoryItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Update Inventory Item',
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
                  Icon(
                    icon,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    title,
                    style: AppTheme.titleStyle.copyWith(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              ...children,
            ],
          ),
        ),
      );
}
