import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../models/company.dart';
import '../../repositories/cmms_repositories.dart';
import '../../services/unified_data_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/charger_asset_filter.dart';
import '../../utils/responsive_layout.dart';
import 'create_charger_screen.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class CompanyChargersScreen extends StatefulWidget {
  const CompanyChargersScreen({
    required this.company,
    super.key,
  });

  final Company company;

  @override
  State<CompanyChargersScreen> createState() => _CompanyChargersScreenState();
}

class _CompanyChargersScreenState extends State<CompanyChargersScreen> {
  List<Asset> _chargers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChargers();
  }

  Future<void> _loadChargers() async {
    setState(() => _isLoading = true);
    try {
      final allAssets =
          await CmmsRepositories.assets.getAssetsByCompanyId(
        widget.company.id,
      );
      final chargers = allAssets
          .where(
            (asset) =>
                assetBelongsToUserCompany(
                  asset,
                  widget.company.id,
                  resolvedCompanyName: widget.company.name,
                ) &&
                isChargerLikeAsset(asset),
          )
          .toList();

      if (mounted) {
        setState(() {
          _chargers = chargers;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _isLoading = false);
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load chargers. Please try again.',
          stackTrace: st,
          contextLabel: 'company_chargers_screen: Could not load chargers. Pleas',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _deleteCharger(Asset charger) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Charger?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${charger.name}"?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final unifiedService = sl<UnifiedDataService>();
        await unifiedService.deleteAsset(charger.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Charger deleted successfully'),
              backgroundColor: AppTheme.accentGreen,
            ),
          );
          _loadChargers();
        }
      } catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not delete charger. Please try again.',
          stackTrace: st,
          contextLabel: 'company_chargers_screen: Could not delete charger. Plea',
          backgroundColor: AppTheme.accentRed,
        );
        }
      }
    }
  }

  List<Asset> get _filteredChargers {
    if (_searchQuery.isEmpty) return _chargers;
    final query = _searchQuery.toLowerCase();
    return _chargers.where((charger) {
      return charger.name.toLowerCase().contains(query) ||
          charger.location.toLowerCase().contains(query) ||
          (charger.serialNumber?.toLowerCase().contains(query) ?? false) ||
          (charger.model?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chargers - ${widget.company.name}'),
            Text(
              '${_chargers.length} charger${_chargers.length != 1 ? 's' : ''}',
              style: AppTheme.captionText,
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        elevation: AppTheme.elevationS,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChargers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search chargers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Chargers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChargers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.ev_station,
                              size: 64,
                              color: AppTheme.secondaryTextColor,
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No chargers found for this company'
                                  : 'No chargers match your search',
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                            if (_searchQuery.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: AppTheme.spacingM),
                                child: ElevatedButton.icon(
                                  onPressed: () => _navigateToCreateCharger(),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Charger'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop
                              ? AppTheme.spacingXL
                              : AppTheme.spacingM,
                          vertical: AppTheme.spacingM,
                        ),
                        itemCount: _filteredChargers.length,
                        itemBuilder: (context, index) {
                          final charger = _filteredChargers[index];
                          return Card(
                            margin: const EdgeInsets.only(
                                bottom: AppTheme.spacingM),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.accentGreen.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.ev_station,
                                  color: AppTheme.accentGreen,
                                ),
                              ),
                              title: Text(
                                charger.name,
                                style: AppTheme.heading2,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (charger.location.isNotEmpty)
                                    Text('Location: ${charger.location}'),
                                  Text(
                                    'Manufacturer: ${resolveChargerManufacturer(charger)}',
                                  ),
                                  if (charger.model != null)
                                    Text('Model: ${charger.model}'),
                                  if (charger.serialNumber != null)
                                    Text('Serial: ${charger.serialNumber}'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: charger.isActive
                                              ? AppTheme.accentGreen
                                                  .withValues(alpha: 0.1)
                                              : AppTheme.accentRed
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          charger.status.toUpperCase(),
                                          style: TextStyle(
                                            color: charger.isActive
                                                ? AppTheme.accentGreen
                                                : AppTheme.accentRed,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CreateChargerScreen(
                                          company: widget.company,
                                          charger: charger,
                                        ),
                                      ),
                                    ).then((_) => _loadChargers());
                                  } else if (value == 'delete') {
                                    _deleteCharger(charger);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateCharger,
        icon: const Icon(Icons.add),
        label: const Text('Add Charger'),
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _navigateToCreateCharger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateChargerScreen(company: widget.company),
      ),
    ).then((_) => _loadChargers());
  }
}
