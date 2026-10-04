// Admin screen for seeding general maintenance assets

import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../utils/app_theme.dart';
import '../../config/release_safety.dart';
import '../../utils/seed_general_maintenance_assets.dart';
import '../../utils/user_facing_errors.dart';

class SeedGeneralAssetsScreen extends StatefulWidget {
  const SeedGeneralAssetsScreen({super.key});

  @override
  State<SeedGeneralAssetsScreen> createState() =>
      _SeedGeneralAssetsScreenState();
}

class _SeedGeneralAssetsScreenState extends State<SeedGeneralAssetsScreen> {
  final GeneralMaintenanceAssetSeeder _seeder = GeneralMaintenanceAssetSeeder();
  bool _isSeeding = false;
  bool _isChecking = true;
  bool _assetsExist = false;
  int _existingCount = 0;
  List<Asset>? _seededAssets;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingAssets();
  }

  Future<void> _checkExistingAssets() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final exists = await _seeder.assetsExist();
      final count = _seeder.getExistingAssetsCount();

      setState(() {
        _assetsExist = exists;
        _existingCount = count;
        _isChecking = false;
      });
    } catch (e, st) {
      setState(() {
        _isChecking = false;
        _errorMessage = 'Error checking assets: $e';
      });
    }
  }

  Future<void> _runSeeder() async {
    setState(() {
      _isSeeding = true;
      _errorMessage = null;
      _seededAssets = null;
    });

    try {
      final assets = await _seeder.seedAssets();

      setState(() {
        _isSeeding = false;
        _seededAssets = assets;
        _assetsExist = true;
        _existingCount = _seeder.getExistingAssetsCount();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('âœ… Successfully seeded ${assets.length} assets!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, st) {
      setState(() {
        _isSeeding = false;
        _errorMessage = 'Error seeding assets: $e';
      });

      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not seed assets. Please try again.',
          stackTrace: st,
          contextLabel: 'SeedGeneralAssets: seed assets',
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  Future<void> _deleteAssets() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete all general maintenance assets? '
          'This action cannot be undone.\n\n'
          'Note: Any work orders associated with these assets will become invalid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSeeding = true;
      _errorMessage = null;
    });

    try {
      await _seeder.deleteAllGeneralMaintenanceAssets();

      setState(() {
        _isSeeding = false;
        _assetsExist = false;
        _existingCount = 0;
        _seededAssets = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ðŸ—‘ï¸ All general maintenance assets deleted'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } catch (e, st) {
      setState(() {
        _isSeeding = false;
        _errorMessage = 'Error deleting assets: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ReleaseSafety.allowDataSeeding) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('General Maintenance Assets Setup'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This setup tool is not available in production builds.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('General Maintenance Assets Setup'),
          elevation: 2,
        ),
        body: _isChecking
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Card(
                      color: AppTheme.accentBlue.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.accentBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'About General Maintenance Assets',
                                  style: AppTheme.heading2
                                      .copyWith(color: AppTheme.accentBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'These 9 facility infrastructure assets allow you to create work orders for '
                              "maintenance tasks that aren't tied to specific equipment (e.g., wall painting, "
                              'plumbing repairs, landscaping).\n\n'
                              'This seeder creates:\n'
                              'â€¢ Building - General Maintenance\n'
                              'â€¢ Building - Painting & Walls\n'
                              'â€¢ Building - Flooring & Surfaces\n'
                              'â€¢ Facility - Plumbing System\n'
                              'â€¢ Facility - Electrical System\n'
                              'â€¢ Facility - HVAC System\n'
                              'â€¢ Facility - Grounds & Landscaping\n'
                              'â€¢ Facility - Roofing System\n'
                              'â€¢ Facility - Safety Systems',
                              style: AppTheme.bodyText,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Status Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _assetsExist
                                      ? Icons.check_circle
                                      : Icons.warning_amber,
                                  color: _assetsExist
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Current Status',
                                  style: AppTheme.heading2,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Existing Assets: ',
                                  style: AppTheme.bodyText,
                                ),
                                Text(
                                  '$_existingCount / 9',
                                  style: AppTheme.bodyText.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _existingCount >= 9
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _assetsExist
                                  ? 'âœ… All general maintenance assets are already created.'
                                  : 'âš ï¸ General maintenance assets not found. Click "Seed Assets" to create them.',
                              style: AppTheme.bodyText.copyWith(
                                color: _assetsExist
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Card(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.error,
                                  color: AppTheme.errorColor,),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      color: AppTheme.errorColor,),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSeeding ? null : _runSeeder,
                        icon: _isSeeding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,),
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(
                          _isSeeding
                              ? 'Seeding Assets...'
                              : _assetsExist
                                  ? 'Re-seed Assets'
                                  : 'Seed Assets',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_existingCount > 0) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSeeding ? null : _deleteAssets,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete All General Assets'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(color: AppTheme.errorColor),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],

                    // Seeded Assets List
                    if (_seededAssets != null) ...[
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.successColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Seeded Assets (${_seededAssets!.length})',
                                    style: AppTheme.heading2,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ..._seededAssets!.map(
                                (asset) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check,
                                        color: AppTheme.successColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              asset.name,
                                              style: AppTheme.bodyText.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              asset.id,
                                              style: AppTheme.smallText,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      );
  }
}
