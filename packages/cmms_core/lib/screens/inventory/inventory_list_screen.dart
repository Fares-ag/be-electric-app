import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_item.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import 'create_inventory_item_screen.dart';
import 'inventory_detail_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventory();
    });
  }

  Future<void> _loadInventory() async {
    final inventoryProvider =
        Provider.of<InventoryProvider>(context, listen: false);

    await inventoryProvider.loadInventory();
  }

  @override
  Widget build(BuildContext context) {
    // Use UnifiedDataProvider directly for real-time data!
    return Consumer<UnifiedDataProvider>(
      builder: (context, unifiedProvider, child) {
        final inventory = unifiedProvider.inventoryItems;
        final isLoading = unifiedProvider.isInventoryLoading;

        print(
            'ðŸ“¦ Inventory UI: Rendering ${inventory.length} items (real-time), loading: $isLoading',);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Inventory Management'),
            backgroundColor: AppTheme.surfaceColor,
            foregroundColor: AppTheme.darkTextColor,
            elevation: AppTheme.elevationS,
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateInventoryItemScreen(),
                    ),
                  );
                  // Real-time sync - no refresh needed!
                },
                tooltip: 'Add Inventory Item',
              ),
            ],
          ),
          body: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading inventory...'),
                    ],
                  ),
                )
              : inventory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      itemCount: inventory.length,
                      itemBuilder: (context, index) {
                        final item = inventory[index];
                        return _buildInventoryCard(item);
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'inventory_list_fab',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateInventoryItemScreen(),
                ),
              );
              // No refresh needed - real-time sync!
            },
            backgroundColor: AppTheme.accentGreen, // Be Electric brand green
            tooltip: 'Add Inventory Item',
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2,
              size: 64,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No inventory items found',
              style: AppTheme.heading2.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Add your first inventory item to get started',
              style: AppTheme.secondaryText.copyWith(
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateInventoryItemScreen(),
                  ),
                );
                if (result == true) {
                  _loadInventory();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Inventory Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen, // Be Electric brand green
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );

  Widget _buildInventoryCard(InventoryItem item) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        elevation: AppTheme.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryDetailScreen(item: item),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: AppTheme.heading2,
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            item.category,
                            style: AppTheme.secondaryText.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStockStatusBadge(item),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  children: [
                    const Icon(
                      Icons.inventory,
                      size: 16,
                      color: AppTheme.secondaryTextColor,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                      style: AppTheme.bodyText.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (item.cost != null) ...[
                      const Icon(
                        Icons.attach_money,
                        size: 16,
                        color: AppTheme.secondaryTextColor,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        'QAR ${item.cost!.toStringAsFixed(2)}',
                        style: AppTheme.bodyText.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.location != null) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppTheme.secondaryTextColor,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        item.location!,
                        style: AppTheme.secondaryText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildStockStatusBadge(InventoryItem item) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (item.isOutOfStock) {
      badgeColor = AppTheme.accentRed;
      badgeText = 'Out of Stock';
      badgeIcon = Icons.error;
    } else if (item.isLowStock) {
      badgeColor = AppTheme.accentOrange;
      badgeText = 'Low Stock';
      badgeIcon = Icons.warning;
    } else if (item.isOverstocked) {
      badgeColor = AppTheme.accentBlue;
      badgeText = 'Overstocked';
      badgeIcon = Icons.trending_up;
    } else {
      badgeColor = AppTheme.accentGreen;
      badgeText = 'In Stock';
      badgeIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            badgeText,
            style: AppTheme.smallText.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
