// Enhanced Asset Selection Widget - Rich asset selection with search and filtering
// Provides comprehensive asset selection with advanced search and filtering capabilities

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/release_safety.dart';
import '../models/asset.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/seed_general_assets_screen.dart';
import '../services/hybrid_dam_service.dart';
import '../theme/unified_design_system.dart';
import '../utils/app_theme.dart';
import 'enhanced_asset_display_widget.dart';
import '../config/locator.dart';
import '../utils/user_facing_errors.dart';

class EnhancedAssetSelectionWidget extends StatefulWidget {
  const EnhancedAssetSelectionWidget({
    required this.title,
    required this.onAssetSelected,
    super.key,
    this.showSearchBar = true,
    this.showFilters = true,
    this.preloadedAssets,
    this.initialSearch,
  });
  final String title;
  final Function(Asset) onAssetSelected;
  final bool showSearchBar;
  final bool showFilters;
  final List<Asset>? preloadedAssets;
  final String? initialSearch;

  @override
  State<EnhancedAssetSelectionWidget> createState() =>
      _EnhancedAssetSelectionWidgetState();
}

class _EnhancedAssetSelectionWidgetState
    extends State<EnhancedAssetSelectionWidget> {
  final TextEditingController _searchController = TextEditingController();
  final HybridDamService _hybridService = sl<HybridDamService>();

  List<Asset> _allAssets = [];
  List<Asset> _filteredAssets = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _selectedLocation = 'All';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      _searchController.text = widget.initialSearch!;
    }
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.preloadedAssets != null) {
        _allAssets = widget.preloadedAssets!;
      } else {
        await _hybridService.initialize();
        var assets = await _hybridService.getAllAssets();
        
        // Filter assets by company if user is a requestor (multi-tenant isolation)
        if (mounted) {
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
          final companyId = user?.companyId;
          if (companyId != null && user?.role == 'requestor') {
            assets = assets.where((asset) => asset.companyId == companyId).toList();
            debugPrint('📋 EnhancedAssetSelection: Filtered assets by companyId: $companyId (${assets.length} assets)');
          }
        }
        
        _allAssets = assets;
      }

      _applyFilters();
    } on Exception catch (e, st) {
      debugPrint('Error loading assets: $e');
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load assets. Please try again.',
          stackTrace: st,
          contextLabel: 'enhanced_asset_selection_widget: Could not load assets. Please ',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAssets = _allAssets.where((asset) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        if (searchQuery.isNotEmpty) {
          final matchesSearch =
              asset.name.toLowerCase().contains(searchQuery) ||
                  asset.location.toLowerCase().contains(searchQuery) ||
                  asset.id.toLowerCase().contains(searchQuery) ||
                  (asset.category != null &&
                      asset.category!.toLowerCase().contains(searchQuery)) ||
                  (asset.description != null &&
                      asset.description!.toLowerCase().contains(searchQuery)) ||
                  (asset.assignedStaff != null &&
                      asset.assignedStaff!.toLowerCase().contains(searchQuery));
          if (!matchesSearch) return false;
        }

        // Category filter
        if (_selectedCategory != 'All' && asset.category != _selectedCategory) {
          return false;
        }

        // Status filter
        if (_selectedStatus != 'All' && asset.status != _selectedStatus) {
          return false;
        }

        // Location filter
        if (_selectedLocation != 'All' && asset.location != _selectedLocation) {
          return false;
        }

        return true;
      }).toList();

      // Sort assets
      _filteredAssets.sort((a, b) {
        var comparison = 0;
        switch (_sortBy) {
          case 'name':
            comparison = a.name.compareTo(b.name);
            break;
          case 'location':
            comparison = a.location.compareTo(b.location);
            break;
          case 'category':
            comparison = (a.category ?? '').compareTo(b.category ?? '');
            break;
          case 'status':
            comparison = a.status.compareTo(b.status);
            break;
          case 'assignedStaff':
            comparison =
                (a.assignedStaff ?? '').compareTo(b.assignedStaff ?? '');
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
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
        body: Column(
          children: [
            if (widget.showSearchBar) _buildSearchBar(),
            if (widget.showFilters) _buildFilters(),
            _buildSortOptions(),
            _buildAssetList(),
          ],
        ),
      );

  Widget _buildSearchBar() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => _applyFilters(),
          decoration: UnifiedDesignSystem.searchInputDecoration.copyWith(
            hintText: 'Search assets by name, location, ID, or category...',
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: UnifiedDesignSystem.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
          ),
        ),
      );

  Widget _buildFilters() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterDropdown(
                  'Category', _selectedCategory, _getCategories(), (value) {
                setState(() => _selectedCategory = value!);
                _applyFilters();
              }),
              const SizedBox(width: 8),
              _buildFilterDropdown('Status', _selectedStatus, _getStatuses(),
                  (value) {
                setState(() => _selectedStatus = value!);
                _applyFilters();
              }),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                  'Location', _selectedLocation, _getLocations(), (value) {
                setState(() => _selectedLocation = value!);
                _applyFilters();
              }),
            ],
          ),
        ),
      );

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          underline: const SizedBox(),
          items: options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
        ),
      );

  Widget _buildSortOptions() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Text('Sort by: '),
            DropdownButton<String>(
              value: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                _applyFilters();
              },
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(value: 'location', child: Text('Location')),
                DropdownMenuItem(value: 'category', child: Text('Category')),
                DropdownMenuItem(value: 'status', child: Text('Status')),
                DropdownMenuItem(
                  value: 'assignedStaff',
                  child: Text('Assigned Staff'),
                ),
              ],
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              ),
              onPressed: () {
                setState(() => _sortAscending = !_sortAscending);
                _applyFilters();
              },
              tooltip: _sortAscending ? 'Sort Descending' : 'Sort Ascending',
            ),
          ],
        ),
      );

  Widget _buildAssetList() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_filteredAssets.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No assets found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              _buildFacilityAssetButton(),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredAssets.length,
              itemBuilder: (context, index) {
                final asset = _filteredAssets[index];
                return ComprehensiveAssetDisplayWidget(
                  asset: asset,
                  isCompact: true,
                  onSelectAsset: (selectedAsset) {
                    widget.onAssetSelected(selectedAsset);
                    Navigator.pop(context);
                  },
                  onViewDetails: (selectedAsset) {
                    _showAssetDetails(selectedAsset);
                  },
                );
              },
            ),
          ),
          _buildFacilityAssetBanner(),
        ],
      ),
    );
  }

  void _showAssetDetails(Asset asset) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              AppBar(
                title: Text('Asset Details - ${asset.name}'),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: ComprehensiveAssetDisplayWidget(
                    asset: asset,
                    showActions: false,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAssetSelected(asset);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Select Asset'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getCategories() {
    final categories = _allAssets
        .map((asset) => asset.category)
        .where((category) => category != null && category.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<String> _getStatuses() {
    final statuses = _allAssets
        .map((asset) => asset.status)
        .where((status) => status.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    statuses.sort();
    return ['All', ...statuses];
  }

  List<String> _getLocations() {
    final locations = _allAssets
        .map((asset) => asset.location)
        .where((location) => location.isNotEmpty)
        .toSet()
        .toList();
    locations.sort();
    return ['All', ...locations];
  }

  /// Build the facility asset button (for empty state)
  Widget _buildFacilityAssetButton() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Divider(height: 32),
            const Icon(
              Icons.construction,
              size: 48,
              color: AppTheme.accentOrange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Need to create a work order for facility maintenance?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Like painting walls, plumbing, electrical work, etc.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            if (ReleaseSafety.allowDataSeeding)
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SeedGeneralAssetsScreen(),
                    ),
                  );
                  // Reload assets after returning
                  _loadAssets();
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Setup Facility Assets'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Filter to show infrastructure/facility assets
                setState(() {
                  _selectedCategory = 'Infrastructure';
                });
                _applyFilters();
              },
              child: const Text('Show Facility Assets'),
            ),
          ],
        ),
      );

  /// Build the facility asset banner (always visible at bottom)
  Widget _buildFacilityAssetBanner() => Container(
        decoration: BoxDecoration(
          color: Colors.orange[50],
          border: Border(
            top: BorderSide(
              color: Colors.orange[200]!,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange[700],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Can't find your asset?",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[900],
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Use facility assets for painting, plumbing, etc.',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (ReleaseSafety.allowDataSeeding)
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SeedGeneralAssetsScreen(),
                    ),
                  );
                  // Reload assets after returning
                  _loadAssets();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'Setup',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      );
}
