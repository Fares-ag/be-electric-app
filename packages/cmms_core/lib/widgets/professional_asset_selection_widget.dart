// Professional Asset Selection Widget - Clean and minimalistic design
// Sophisticated asset selection with modern UI patterns

import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/hybrid_dam_service.dart';
import '../theme/unified_design_system.dart';
import 'professional_asset_display_widget.dart';
import '../config/locator.dart';
import '../utils/user_facing_errors.dart';

class ProfessionalAssetSelectionWidget extends StatefulWidget {
  const ProfessionalAssetSelectionWidget({
    required this.title,
    required this.onAssetSelected,
    super.key,
    this.showSearchBar = true,
    this.showFilters = true,
  });

  final String title;
  final Function(Asset) onAssetSelected;
  final bool showSearchBar;
  final bool showFilters;

  @override
  State<ProfessionalAssetSelectionWidget> createState() =>
      _ProfessionalAssetSelectionWidgetState();
}

class _ProfessionalAssetSelectionWidgetState
    extends State<ProfessionalAssetSelectionWidget> {
  final HybridDamService _hybridService = sl<HybridDamService>();
  final TextEditingController _searchController = TextEditingController();

  List<Asset> _assets = [];
  List<Asset> _filteredAssets = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _selectedLocation = 'All';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() => _isLoading = true);

    try {
      await _hybridService.initialize();
      final assets = await _hybridService.getAllAssets();

      setState(() {
        _assets = assets;
        _filteredAssets = assets;
        _isLoading = false;
      });
    } catch (e, st) {
      setState(() => _isLoading = false);
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load assets. Please try again.',
          stackTrace: st,
          contextLabel: 'professional_asset_selection_widget: Could not load assets. Please ',
          backgroundColor: UnifiedDesignSystem.accentRed,
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAssets = _assets.where((asset) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          if (!asset.name.toLowerCase().contains(query) &&
              !asset.location.toLowerCase().contains(query) &&
              !asset.id.toLowerCase().contains(query) &&
              !(asset.category?.toLowerCase().contains(query) ?? false)) {
            return false;
          }
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
          backgroundColor: UnifiedDesignSystem.surface,
          foregroundColor: UnifiedDesignSystem.primary,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: UnifiedDesignSystem.borderColor,
            ),
          ),
        ),
        body: Column(
          children: [
            if (widget.showSearchBar) _buildSearchBar(),
            if (widget.showFilters) _buildFilters(),
            Expanded(child: _buildAssetList()),
          ],
        ),
      );

  Widget _buildSearchBar() => Container(
        padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
        decoration: const BoxDecoration(
          color: UnifiedDesignSystem.surface,
          border: Border(
            bottom: BorderSide(
              color: UnifiedDesignSystem.borderColor,
            ),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _applyFilters();
          },
          decoration: InputDecoration(
            hintText: 'Search assets...',
            prefixIcon: const Icon(
              Icons.search,
              color: UnifiedDesignSystem.textSecondary,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: UnifiedDesignSystem.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _applyFilters();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusS),
              borderSide: const BorderSide(
                color: UnifiedDesignSystem.borderColor,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusS),
              borderSide: const BorderSide(
                color: UnifiedDesignSystem.borderColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusS),
              borderSide: const BorderSide(
                color: UnifiedDesignSystem.accentBlue,
              ),
            ),
            filled: true,
            fillColor: UnifiedDesignSystem.background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: UnifiedDesignSystem.spaceM,
              vertical: UnifiedDesignSystem.spaceM,
            ),
          ),
        ),
      );

  Widget _buildFilters() => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedDesignSystem.spaceM,
          vertical: UnifiedDesignSystem.spaceS,
        ),
        decoration: const BoxDecoration(
          color: UnifiedDesignSystem.surface,
          border: Border(
            bottom: BorderSide(
              color: UnifiedDesignSystem.borderColor,
            ),
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('Category', _selectedCategory, _getCategories()),
              const SizedBox(width: UnifiedDesignSystem.spaceS),
              _buildFilterChip('Status', _selectedStatus, _getStatuses()),
              const SizedBox(width: UnifiedDesignSystem.spaceS),
              _buildFilterChip('Location', _selectedLocation, _getLocations()),
              const SizedBox(width: UnifiedDesignSystem.spaceS),
              _buildSortChip(),
            ],
          ),
        ),
      );

  Widget _buildFilterChip(
    String label,
    String selected,
    List<String> options,
  ) =>
      PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            switch (label) {
              case 'Category':
                _selectedCategory = value;
                break;
              case 'Status':
                _selectedStatus = value;
                break;
              case 'Location':
                _selectedLocation = value;
                break;
            }
            _applyFilters();
          });
        },
        itemBuilder: (context) => options
            .map(
              (option) => PopupMenuItem(
                value: option,
                child: Text(option),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UnifiedDesignSystem.spaceM,
            vertical: UnifiedDesignSystem.spaceS,
          ),
          decoration: BoxDecoration(
            color: selected == 'All'
                ? UnifiedDesignSystem.background
                : UnifiedDesignSystem.accentBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusS),
            border: Border.all(
              color: selected == 'All'
                  ? UnifiedDesignSystem.borderColor
                  : UnifiedDesignSystem.accentBlue,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: $selected',
                style: UnifiedDesignSystem.bodySmall.copyWith(
                  color: selected == 'All'
                      ? UnifiedDesignSystem.textSecondary
                      : UnifiedDesignSystem.accentBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: UnifiedDesignSystem.spaceXS),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: selected == 'All'
                    ? UnifiedDesignSystem.textSecondary
                    : UnifiedDesignSystem.accentBlue,
              ),
            ],
          ),
        ),
      );

  Widget _buildSortChip() => PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            if (_sortBy == value) {
              _sortAscending = !_sortAscending;
            } else {
              _sortBy = value;
              _sortAscending = true;
            }
            _applyFilters();
          });
        },
        itemBuilder: (context) => [
          'name',
          'location',
          'category',
          'status',
          'assignedStaff',
        ]
            .map(
              (option) => PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Text(option.toUpperCase()),
                    if (_sortBy == option) ...[
                      const SizedBox(width: UnifiedDesignSystem.spaceS),
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UnifiedDesignSystem.spaceM,
            vertical: UnifiedDesignSystem.spaceS,
          ),
          decoration: BoxDecoration(
            color: UnifiedDesignSystem.background,
            borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusS),
            border: Border.all(color: UnifiedDesignSystem.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sort,
                size: 16,
                color: UnifiedDesignSystem.textSecondary,
              ),
              const SizedBox(width: UnifiedDesignSystem.spaceXS),
              Text(
                'Sort',
                style: UnifiedDesignSystem.bodySmall.copyWith(
                  color: UnifiedDesignSystem.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildAssetList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: UnifiedDesignSystem.accentBlue,
        ),
      );
    }

    if (_filteredAssets.isEmpty) {
      return UnifiedDesignSystem.emptyState(
        title: 'No Assets Found',
        description: _searchQuery.isNotEmpty
            ? 'Try adjusting your search criteria'
            : 'No assets available at the moment',
        icon: Icons.search_off,
        action: _searchQuery.isNotEmpty
            ? ElevatedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _applyFilters();
                },
                style: UnifiedDesignSystem.secondaryButton,
                child: const Text('Clear Search'),
              )
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
      itemCount: _filteredAssets.length,
      itemBuilder: (context, index) {
        final asset = _filteredAssets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: UnifiedDesignSystem.spaceS),
          child: ProfessionalAssetDisplayWidget(
            asset: asset,
            isCompact: true,
            onViewDetails: _showAssetDetails,
            onSelectAsset: (asset) => widget.onAssetSelected(asset),
          ),
        );
      },
    );
  }

  void _showAssetDetails(Asset asset) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedDesignSystem.radiusL),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
                decoration: const BoxDecoration(
                  color: UnifiedDesignSystem.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(UnifiedDesignSystem.radiusL),
                    topRight: Radius.circular(UnifiedDesignSystem.radiusL),
                  ),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Asset Details',
                        style: UnifiedDesignSystem.heading3,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: UnifiedDesignSystem.textSecondary,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(UnifiedDesignSystem.spaceM),
                  child: ProfessionalAssetDisplayWidget(
                    asset: asset,
                    showActions: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getCategories() {
    final categories = _assets
        .map((a) => a.category)
        .where((c) => c != null)
        .cast<String>()
        .toSet()
        .toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<String> _getStatuses() {
    final statuses = _assets.map((a) => a.status).toSet().toList();
    statuses.sort();
    return ['All', ...statuses];
  }

  List<String> _getLocations() {
    final locations = _assets.map((a) => a.location).toSet().toList();
    locations.sort();
    return ['All', ...locations];
  }
}
