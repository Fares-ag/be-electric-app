import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cmms_core/models/inventory_item.dart';
import 'package:cmms_core/providers/unified_data_provider.dart';
import 'package:cmms_core/utils/app_theme.dart';
import 'edit_inventory_item_screen.dart';

class LowStockAlertsScreen extends StatefulWidget {
  const LowStockAlertsScreen({super.key});

  @override
  State<LowStockAlertsScreen> createState() => _LowStockAlertsScreenState();
}

class _LowStockAlertsScreenState extends State<LowStockAlertsScreen> {
  int _threshold = 10;

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Consumer<UnifiedDataProvider>(
        builder: (context, unifiedProvider, child) {
          final lowStockItems = unifiedProvider.inventoryItems
              .where((item) => item.quantity <= _threshold)
              .toList();

          return Scaffold(
            appBar: AppBar(
              title: Text('Low Stock Alerts (${lowStockItems.length})'),
              backgroundColor: AppTheme.primaryWhite,
              foregroundColor: AppTheme.primaryBlack,
              elevation: AppTheme.elevationS,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _showThresholdDialog,
                  tooltip: 'Set Threshold',
                ),
                // No refresh needed - real-time sync!
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCard(lowStockItems),
                  const SizedBox(height: AppTheme.spacingXL),
                  _buildLowStockItemsList(lowStockItems),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildStatsCard(List<InventoryItem> lowStockItems) {
    final criticalItems =
        lowStockItems.where((item) => item.quantity <= 5).length;
    final warningItems = lowStockItems
        .where((item) => item.quantity > 5 && item.quantity <= _threshold)
        .length;

    return Card(
      elevation: AppTheme.elevationS,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Alert Summary',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Critical (≤5)',
                    '$criticalItems',
                    Colors.red,
                    Icons.warning,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatItem(
                    'Warning (≤$_threshold)',
                    '$warningItems',
                    Colors.orange,
                    Icons.info,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildStatItem(
                    'Total Alerts',
                    '${lowStockItems.length}',
                    AppTheme.accentBlue,
                    Icons.inventory,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) =>
      Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              value,
              style: AppTheme.heading2.copyWith(color: color),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              label,
              style: AppTheme.smallText,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildLowStockItemsList(List<InventoryItem> lowStockItems) {
    if (lowStockItems.isEmpty) {
      return Card(
        elevation: AppTheme.elevationS,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  'No low stock alerts',
                  style: AppTheme.heading2.copyWith(color: Colors.green),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'All inventory items are above the threshold of $_threshold',
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.secondaryTextGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: AppTheme.elevationS,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Low Stock Items (${lowStockItems.length})',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...lowStockItems.map(_buildLowStockItemCard),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockItemCard(InventoryItem item) {
    final isCritical = item.quantity <= 5;
    final color = isCritical ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.name,
                        style: AppTheme.bodyText.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        ),
                        child: Text(
                          isCritical ? 'CRITICAL' : 'WARNING',
                          style: AppTheme.smallText.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Current Stock: ${item.quantity}',
                    style: AppTheme.bodyText.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Category: ${item.category}',
                    style: AppTheme.smallText.copyWith(
                      color: AppTheme.secondaryTextGrey,
                    ),
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      item.description!,
                      style: AppTheme.smallText.copyWith(
                        color: AppTheme.secondaryTextGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: () => _showPurchaseOrderDialog(item),
                  tooltip: 'Create Purchase Order',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditItemDialog(item),
                  tooltip: 'Edit Item',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showThresholdDialog() async {
    final newThreshold = await showDialog<int>(
      context: context,
      builder: (context) => ThresholdDialog(currentThreshold: _threshold),
    );

    if (newThreshold != null && newThreshold != _threshold) {
      setState(() => _threshold = newThreshold);
      // No need to reload - Consumer auto-updates!
    }
  }

  Future<void> _showPurchaseOrderDialog(InventoryItem item) async {
    // TODO: Implement purchase order creation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Purchase order creation for ${item.name} - Coming soon!'),
        backgroundColor: AppTheme.accentBlue,
      ),
    );
  }

  Future<void> _showEditItemDialog(InventoryItem item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditInventoryItemScreen(item: item),
      ),
    );

    if (result == true) {
      // Consumer auto-updates - no manual refresh needed!
    }
  }
}

class ThresholdDialog extends StatefulWidget {
  const ThresholdDialog({
    required this.currentThreshold,
    super.key,
  });
  final int currentThreshold;

  @override
  State<ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<ThresholdDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.currentThreshold.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Set Low Stock Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the minimum stock level to trigger alerts:'),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Threshold',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final threshold = int.tryParse(_controller.text);
              if (threshold != null && threshold > 0) {
                Navigator.of(context).pop(threshold);
              }
            },
            child: const Text('Set'),
          ),
        ],
      );
}
