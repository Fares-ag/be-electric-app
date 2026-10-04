// Professional Asset Demo Screen - Showcase the new minimalistic design
// Demonstrates the professional asset display system

import 'package:flutter/material.dart';

import '../../models/asset.dart';
import '../../screens/assets/professional_asset_details_screen.dart';
import '../../services/hybrid_dam_service.dart';
import '../../theme/unified_design_system.dart';
import '../../widgets/professional_asset_display_widget.dart';
import '../../widgets/professional_asset_selection_widget.dart';
import '../../config/locator.dart';

class ProfessionalAssetDemoScreen extends StatefulWidget {
  const ProfessionalAssetDemoScreen({super.key});

  @override
  State<ProfessionalAssetDemoScreen> createState() =>
      _ProfessionalAssetDemoScreenState();
}

class _ProfessionalAssetDemoScreenState
    extends State<ProfessionalAssetDemoScreen> {
  final HybridDamService _hybridService = sl<HybridDamService>();
  List<Asset> _assets = [];
  Asset? _selectedAsset;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);

    try {
      await _hybridService.initialize();
      final assets = await _hybridService.getAllAssets(limit: 20);

      setState(() {
        _assets = assets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load assets: $e'),
            backgroundColor: UnifiedDesignSystem.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Professional Asset Display'),
          backgroundColor: UnifiedDesignSystem.surface,
          foregroundColor: UnifiedDesignSystem.primary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAssets,
              tooltip: 'Refresh Assets',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: UnifiedDesignSystem.accentBlue,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDemoHeader(),
                    const SizedBox(height: UnifiedDesignSystem.spaceXL),
                    _buildAssetSelectionDemo(),
                    const SizedBox(height: UnifiedDesignSystem.spaceXL),
                    _buildAssetDisplayDemo(),
                    const SizedBox(height: UnifiedDesignSystem.spaceXL),
                    _buildAssetListDemo(),
                  ],
                ),
              ),
      );

  Widget _buildDemoHeader() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceL),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.surface,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          border: Border.all(
            color: UnifiedDesignSystem.borderColor,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.design_services,
              size: 48,
              color: UnifiedDesignSystem.accentBlue,
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceM),
            const Text(
              'Professional Asset Display System',
              style: UnifiedDesignSystem.heading1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            const Text(
              'Clean, minimalistic design with sophisticated UI patterns',
              style: UnifiedDesignSystem.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard('Assets Loaded', '${_assets.length}'),
                _buildStatCard('Design', 'Professional'),
                _buildStatCard('Style', 'Minimalistic'),
              ],
            ),
          ],
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

  Widget _buildAssetSelectionDemo() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceL),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.surface,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          border: Border.all(
            color: UnifiedDesignSystem.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.search,
                  color: UnifiedDesignSystem.accentBlue,
                  size: 20,
                ),
                SizedBox(width: UnifiedDesignSystem.spaceS),
                Text(
                  'Professional Asset Selection',
                  style: UnifiedDesignSystem.heading3,
                ),
              ],
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            const Text(
              'Clean search interface with advanced filtering and sorting',
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceL),
            ElevatedButton.icon(
              onPressed: _selectAsset,
              icon: const Icon(Icons.search),
              label: const Text('Open Professional Asset Selection'),
              style: UnifiedDesignSystem.primaryButton,
            ),
          ],
        ),
      );

  Widget _buildAssetDisplayDemo() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceL),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.surface,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          border: Border.all(
            color: UnifiedDesignSystem.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.display_settings,
                  color: UnifiedDesignSystem.accentBlue,
                  size: 20,
                ),
                SizedBox(width: UnifiedDesignSystem.spaceS),
                Text(
                  'Professional Asset Display',
                  style: UnifiedDesignSystem.heading3,
                ),
              ],
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            const Text(
              'Clean, minimalistic asset information with modern UI patterns',
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceL),
            if (_selectedAsset != null) ...[
              ProfessionalAssetDisplayWidget(
                asset: _selectedAsset!,
                onViewDetails: _viewAssetDetails,
                onSelectAsset: (asset) => _selectAsset(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(UnifiedDesignSystem.spaceL),
                decoration: BoxDecoration(
                  color: UnifiedDesignSystem.background,
                  borderRadius:
                      BorderRadius.circular(UnifiedDesignSystem.radiusM),
                  border: Border.all(
                    color: UnifiedDesignSystem.borderColor,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 48,
                      color: UnifiedDesignSystem.textSecondary,
                    ),
                    SizedBox(height: UnifiedDesignSystem.spaceM),
                    Text(
                      'No Asset Selected',
                      style: UnifiedDesignSystem.heading4,
                    ),
                    SizedBox(height: UnifiedDesignSystem.spaceS),
                    Text(
                      'Select an asset to see the professional display',
                      style: UnifiedDesignSystem.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildAssetListDemo() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceL),
        decoration: BoxDecoration(
          color: UnifiedDesignSystem.surface,
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
          border: Border.all(
            color: UnifiedDesignSystem.borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.list,
                  color: UnifiedDesignSystem.accentBlue,
                  size: 20,
                ),
                SizedBox(width: UnifiedDesignSystem.spaceS),
                Text(
                  'Asset List Preview',
                  style: UnifiedDesignSystem.heading3,
                ),
              ],
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceS),
            const Text(
              'Clean list view with professional styling',
            ),
            const SizedBox(height: UnifiedDesignSystem.spaceL),
            ..._assets.take(3).map(
                  (asset) => Padding(
                    padding: const EdgeInsets.only(
                        bottom: UnifiedDesignSystem.spaceS,),
                    child: ProfessionalAssetDisplayWidget(
                      asset: asset,
                      isCompact: true,
                      onViewDetails: _viewAssetDetails,
                      onSelectAsset: (asset) => _selectAsset(),
                    ),
                  ),
                ),
            if (_assets.length > 3) ...[
              const SizedBox(height: UnifiedDesignSystem.spaceM),
              Center(
                child: Text(
                  '... and ${_assets.length - 3} more assets',
                  style: UnifiedDesignSystem.bodyMedium.copyWith(
                    color: UnifiedDesignSystem.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Future<void> _selectAsset() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfessionalAssetSelectionWidget(
          title: 'Select Asset',
          onAssetSelected: _handleAssetSelection,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAsset = result;
      });
    }
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
