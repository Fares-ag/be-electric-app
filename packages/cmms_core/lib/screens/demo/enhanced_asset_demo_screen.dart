// Enhanced Asset Display Demo Screen
// Demonstrates the Enhanced Asset Display System in action

import 'package:flutter/material.dart';

import '../../models/asset.dart';
import '../../screens/assets/professional_asset_details_screen.dart';
import '../../services/hybrid_dam_service.dart';
import '../../theme/unified_design_system.dart';
import '../../utils/app_theme.dart';
import '../../widgets/professional_asset_display_widget.dart';
import '../../widgets/professional_asset_selection_widget.dart';
import '../../config/locator.dart';

class EnhancedAssetDemoScreen extends StatefulWidget {
  const EnhancedAssetDemoScreen({super.key});

  @override
  State<EnhancedAssetDemoScreen> createState() =>
      _EnhancedAssetDemoScreenState();
}

class _EnhancedAssetDemoScreenState extends State<EnhancedAssetDemoScreen> {
  final HybridDamService _hybridService = sl<HybridDamService>();
  List<Asset> _assets = [];
  bool _isLoading = false;
  Asset? _selectedAsset;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _hybridService.initialize();
      final assets = await _hybridService.getAllAssets(limit: 20);
      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    } on Exception catch (e) {
      debugPrint('Error loading assets: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('ðŸš€ Enhanced Asset Display Demo'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAssets,
              tooltip: 'Refresh Assets',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDemoHeader(),
              const SizedBox(height: 24),
              _buildAssetSelectionDemo(),
              const SizedBox(height: 24),
              _buildAssetDisplayDemo(),
              const SizedBox(height: 24),
              _buildAssetListDemo(),
            ],
          ),
        ),
      );

  Widget _buildDemoHeader() => Card(
        elevation: UnifiedDesignSystem.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
          child: Column(
            children: [
              const Icon(
                Icons.rocket_launch,
                size: 48,
                color: UnifiedDesignSystem.primary,
              ),
              const SizedBox(height: UnifiedDesignSystem.spaceM),
              const Text(
                'Enhanced Asset Display System',
                style: UnifiedDesignSystem.heading1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: UnifiedDesignSystem.spaceS),
              const Text(
                'Complete asset information display with rich formatting and advanced search capabilities',
                textAlign: TextAlign.center,
                style: UnifiedDesignSystem.bodyLarge,
              ),
              const SizedBox(height: UnifiedDesignSystem.spaceM),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Assets Loaded', '${_assets.length}'),
                  _buildStatCard('Connection', 'Direct Firestore'),
                  _buildStatCard('Performance', 'Ultra Fast'),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildStatCard(String label, String value) => Column(
        children: [
          Text(
            value,
            style: UnifiedDesignSystem.heading3,
          ),
          Text(
            label,
            style: UnifiedDesignSystem.caption,
          ),
        ],
      );

  Widget _buildAssetSelectionDemo() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ðŸš€ Enhanced Asset Selection',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Advanced search and filtering with real-time results',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _selectAsset,
                icon: const Icon(Icons.search),
                label: const Text('Open Enhanced Asset Selection'),
                style: UnifiedDesignSystem.successButton,
              ),
            ],
          ),
        ),
      );

  Widget _buildAssetDisplayDemo() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ðŸ“Š Comprehensive Asset Display',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Rich asset information with expandable sections and action buttons',
              ),
              const SizedBox(height: 16),
              if (_selectedAsset != null) ...[
                ProfessionalAssetDisplayWidget(
                  asset: _selectedAsset!,
                  onViewDetails: _viewAssetDetails,
                  onSelectAsset: (asset) => _selectAsset(),
                  onEditAsset: (asset) => _selectAsset(),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No asset selected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use the Enhanced Asset Selection to choose an asset',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildAssetListDemo() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ðŸ“‹ Asset List Demo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Compact asset display in list format',
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_assets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  child: const Center(
                    child: Text('No assets available'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _assets.take(3).length,
                  itemBuilder: (context, index) {
                    final asset = _assets[index];
                    return ProfessionalAssetDisplayWidget(
                      asset: asset,
                      isCompact: true,
                      onViewDetails: _viewAssetDetails,
                      onSelectAsset: (asset) =>
                          setState(() => _selectedAsset = asset),
                      onEditAsset: (asset) => _selectAsset(),
                    );
                  },
                ),
            ],
          ),
        ),
      );

  Future<void> _selectAsset() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfessionalAssetSelectionWidget(
          title: 'Select Asset for Demo',
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
        builder: (context) => ProfessionalAssetDetailsScreen(
          asset: asset,
        ),
      ),
    );
  }
}
