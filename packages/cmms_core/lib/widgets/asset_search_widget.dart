import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../services/hybrid_dam_service.dart';
import '../utils/app_theme.dart';
import '../config/locator.dart';
import '../utils/user_facing_errors.dart';

class _AssetDetailsSheet extends StatelessWidget {
  const _AssetDetailsSheet({
    required this.asset,
    required this.onSelect,
  });
  final Asset asset;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppTheme.spacingS),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Asset Details',
                      style: AppTheme.heading1,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Asset Image
                    if (asset.imageUrl != null && asset.imageUrl!.isNotEmpty)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          child: CachedNetworkImage(
                            imageUrl: asset.imageUrl!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusM),
                              ),
                              child: const Icon(
                                Icons.inventory_2,
                                size: 80,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Basic Information
                    _buildDetailSection('Basic Information', [
                      _buildDetailRow('Name', asset.name),
                      if (asset.description != null &&
                          asset.description!.isNotEmpty)
                        _buildDetailRow('Description', asset.description!),
                      if (asset.category != null && asset.category!.isNotEmpty)
                        _buildDetailRow('Category', asset.category!),
                      if (asset.location.isNotEmpty)
                        _buildDetailRow('Location', asset.location),
                      if (asset.department != null &&
                          asset.department!.isNotEmpty)
                        _buildDetailRow('Department', asset.department!),
                      if (asset.assignedStaff != null &&
                          asset.assignedStaff!.isNotEmpty)
                        _buildDetailRow('Assigned Staff', asset.assignedStaff!),
                      if (asset.condition != null &&
                          asset.condition!.isNotEmpty)
                        _buildDetailRow('Condition', asset.condition!),
                    ]),

                    // Vehicle Information (if applicable)
                    if (asset.licPlate != null ||
                        asset.vehicleIdNo != null ||
                        asset.modelDesc != null)
                      _buildDetailSection('Vehicle Information', [
                        if (asset.licPlate != null &&
                            asset.licPlate!.isNotEmpty)
                          _buildDetailRow('License Plate', asset.licPlate!),
                        if (asset.vehicleIdNo != null &&
                            asset.vehicleIdNo!.isNotEmpty)
                          _buildDetailRow('Vehicle ID', asset.vehicleIdNo!),
                        if (asset.modelDesc != null &&
                            asset.modelDesc!.isNotEmpty)
                          _buildDetailRow('Model', asset.modelDesc!),
                        if (asset.mileage != null)
                          _buildDetailRow('Mileage', '${asset.mileage} km'),
                      ]),

                    // Maintenance Information
                    if (asset.lastMaintenanceDate != null ||
                        asset.nextMaintenanceDate != null)
                      _buildDetailSection('Maintenance', [
                        if (asset.lastMaintenanceDate != null)
                          _buildDetailRow(
                            'Last Maintenance',
                            _formatDate(asset.lastMaintenanceDate!),
                          ),
                        if (asset.nextMaintenanceDate != null)
                          _buildDetailRow(
                            'Next Maintenance',
                            _formatDate(asset.nextMaintenanceDate!),
                          ),
                        if (asset.maintenanceSchedule != null &&
                            asset.maintenanceSchedule!.isNotEmpty)
                          _buildDetailRow(
                            'Schedule',
                            asset.maintenanceSchedule!,
                          ),
                      ]),

                    // Financial Information
                    if (asset.purchasePrice != null ||
                        asset.currentValue != null)
                      _buildDetailSection('Financial', [
                        if (asset.purchasePrice != null)
                          _buildDetailRow(
                            'Purchase Price',
                            'QAR ${asset.purchasePrice}',
                          ),
                        if (asset.currentValue != null)
                          _buildDetailRow(
                            'Current Value',
                            'QAR ${asset.currentValue}',
                          ),
                      ]),

                    // Vendor Information
                    if (asset.vendor != null && asset.vendor!.isNotEmpty)
                      _buildDetailSection('Vendor', [
                        _buildDetailRow('Vendor', asset.vendor!),
                      ]),

                    const SizedBox(height: AppTheme.spacingXL),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: AppTheme.outlinedButtonStyle,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSelect,
                      style: AppTheme.elevatedButtonStyle,
                      child: const Text('Select Asset'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDetailSection(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.heading2.copyWith(
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          ...children,
          const SizedBox(height: AppTheme.spacingL),
        ],
      );

  Widget _buildDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: AppTheme.secondaryText.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTheme.bodyText,
              ),
            ),
          ],
        ),
      );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class AssetSearchWidget extends StatefulWidget {
  const AssetSearchWidget({super.key});

  @override
  State<AssetSearchWidget> createState() => _AssetSearchWidgetState();
}

class _AssetSearchWidgetState extends State<AssetSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Asset> _assets = [];
  List<Asset> _filteredAssets = [];
  bool _isLoading = false;
  final HybridDamService _hybridService = sl<HybridDamService>();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();

    // Load assets using Hybrid DAM Service
    _loadAssetsFromHybridService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  /// Load assets using Hybrid DAM Service
  Future<void> _loadAssetsFromHybridService() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Loading assets using Hybrid DAM Service...');

      // Initialize the hybrid service
      await _hybridService.initialize();

      // Get all assets using the hybrid service
      final assets = await _hybridService.getAllAssets();

      if (assets.isNotEmpty) {
        setState(() {
          _assets = assets;
          _filteredAssets = assets;
          _isLoading = false;
        });

        debugPrint('Loaded ${assets.length} assets using Hybrid DAM Service');
        debugPrint('Connection method: ${_hybridService.connectionMethod}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Loaded ${assets.length} assets (${_hybridService.connectionMethod})',
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No assets found'),
              backgroundColor: AppTheme.accentRed,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on Exception catch (e, st) {
      debugPrint('Hybrid DAM Service loading failed: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load assets. Please try again.',
          stackTrace: st,
          contextLabel: 'asset_search_widget: Could not load assets. Please ',
          backgroundColor: AppTheme.accentRed,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  /// Clear cache and reload all assets
  void _clearCacheAndReload() {
    // Clear cache and reload from Hybrid DAM Service
    setState(() {
      _isLoading = true;
    });

    // Clear hybrid service cache
    _hybridService.clearCache();

    // Reload from Hybrid DAM Service
    _loadAssetsFromHybridService();
  }

  /// Check for asset changes manually
  Future<void> _checkForChanges() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Clear cache and reload from Hybrid DAM Service to get latest assets
      _hybridService.clearCache();
      await _loadAssetsFromHybridService();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ðŸ”„ Assets updated from database!'),
            backgroundColor: AppTheme.accentGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on Exception catch (e, st) {
      debugPrint('Error checking for changes: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not check for changes. Please try again.',
          stackTrace: st,
          contextLabel: 'AssetSearch: check changes',
          backgroundColor: AppTheme.accentRed,
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _filterAssets(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAssets = _assets;
      } else {
        // Fast local search first
        _filteredAssets = _assets
            .where(
              (asset) =>
                  asset.name.toLowerCase().contains(query.toLowerCase()) ||
                  asset.location.toLowerCase().contains(query.toLowerCase()) ||
                  asset.id.toLowerCase().contains(query.toLowerCase()) ||
                  (asset.description
                          ?.toLowerCase()
                          .contains(query.toLowerCase()) ??
                      false) ||
                  (asset.department
                          ?.toLowerCase()
                          .contains(query.toLowerCase()) ??
                      false) ||
                  (asset.assignedStaff
                          ?.toLowerCase()
                          .contains(query.toLowerCase()) ??
                      false) ||
                  (asset.category
                          ?.toLowerCase()
                          .contains(query.toLowerCase()) ??
                      false),
            )
            .toList();
      }
    });

    // Search Hybrid DAM Service with debounced search
    if (query.length >= 2) {
      _searchTimer?.cancel();
      _searchTimer = Timer(const Duration(milliseconds: 300), () {
        _searchWithHybridService(query);
      });
    }
  }

  /// Search with Hybrid DAM Service
  Future<void> _searchWithHybridService(String query) async {
    try {
      debugPrint('Searching for "$query" using Hybrid DAM Service');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('ðŸ” Searching database...'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final searchResults = await _hybridService.searchAssets(query);

      if (mounted) {
        setState(() {
          _filteredAssets = searchResults;
        });

        if (searchResults.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'âœ… Found ${searchResults.length} results (${_hybridService.connectionMethod})!',
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'âŒ No results found',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on Exception catch (e, st) {
      debugPrint('Hybrid DAM Service search error: $e');
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Search failed. Please try again.',
          stackTrace: st,
          contextLabel: 'AssetSearch: search',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        );
      }
      // Fallback to local filtering
      _filterAssets(query);
    }
  }

  void _selectAsset(Asset asset) {
    Navigator.pop(context, {
      'assetId': asset.id,
      'assetName': asset.name,
      'location': asset.location,
      'description': asset.description,
      'category': asset.category,
      'department': asset.department,
      'assignedStaff': asset.assignedStaff,
      'condition': asset.condition,
      'mileage': asset.mileage,
      'licPlate': asset.licPlate,
      'vehicleIdNo': asset.vehicleIdNo,
      'modelDesc': asset.modelDesc,
      'vendor': asset.vendor,
      'lastMaintenanceDate': asset.lastMaintenanceDate?.toIso8601String(),
      'nextMaintenanceDate': asset.nextMaintenanceDate?.toIso8601String(),
      'maintenanceSchedule': asset.maintenanceSchedule,
      'purchasePrice': asset.purchasePrice,
      'currentValue': asset.currentValue,
      'warranty': asset.warranty,
      'imageUrl': asset.imageUrl,
      'isFromAssetManagement': true,
    });
  }

  void _showAssetDetails(Asset asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssetDetailsSheet(
        asset: asset,
        onSelect: () {
          Navigator.of(context).pop(); // Close the details sheet
          _selectAsset(asset);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Search Asset'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.primaryColor,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.update),
              onPressed: _checkForChanges,
              tooltip: 'Check for asset updates',
              color: AppTheme.accentBlue,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearCacheAndReload,
              tooltip: 'Force refresh all assets',
              color: AppTheme.secondaryTextColor,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: TextField(
                controller: _searchController,
                onChanged: _filterAssets,
                decoration: InputDecoration(
                  hintText: 'Search assets by name, location, or category...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterAssets('');
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _clearCacheAndReload,
                        tooltip: 'Refresh assets',
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundColor,
                ),
              ),
            ),
            // Asset List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredAssets.isEmpty
                      ? const Center(
                          child: Text(
                            'No assets found',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM,
                          ),
                          itemCount: _filteredAssets.length,
                          itemBuilder: (context, index) {
                            final asset = _filteredAssets[index];
                            return _buildAssetCard(asset);
                          },
                        ),
            ),
          ],
        ),
      );

  Widget _buildAssetCard(Asset asset) => Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
        elevation: AppTheme.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: ListTile(
          leading: _buildAssetImage(asset),
          title: Text(
            asset.name,
            style: AppTheme.heading2,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asset.location.isNotEmpty)
                Text(
                  'Location: ${asset.location}',
                  style: AppTheme.secondaryText,
                ),
              if (asset.category != null && asset.category!.isNotEmpty)
                Text(
                  'Category: ${asset.category}',
                  style: AppTheme.secondaryText,
                ),
              if (asset.department != null && asset.department!.isNotEmpty)
                Text(
                  'Department: ${asset.department}',
                  style: AppTheme.secondaryText,
                ),
            ],
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.accentBlue,
            size: 16,
          ),
          onTap: () => _showAssetDetails(asset),
        ),
      );

  Widget _buildAssetImage(Asset asset) {
    if (asset.imageUrl != null && asset.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        child: Image.network(
          asset.imageUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('ðŸ–¼ï¸ Image load error for ${asset.id}: $error');
            return _buildFallbackIcon(asset);
          },
        ),
      );
    }
    return _buildFallbackIcon(asset);
  }

  Widget _buildFallbackIcon(Asset asset) => Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.accentBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: const Icon(
          Icons.inventory_2,
          color: AppTheme.accentBlue,
          size: 24,
        ),
      );
}
