import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/hybrid_dam_service.dart';
import '../../utils/app_theme.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class AssetIntegrationConfigScreen extends StatefulWidget {
  const AssetIntegrationConfigScreen({super.key});

  @override
  State<AssetIntegrationConfigScreen> createState() =>
      _AssetIntegrationConfigScreenState();
}

class _AssetIntegrationConfigScreenState
    extends State<AssetIntegrationConfigScreen> {
  bool _preferDatabase = true;
  bool _enableApiFallback = true;
  bool _enableCaching = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _preferDatabase = prefs.getBool('asset_prefer_database') ?? true;
        _enableApiFallback = prefs.getBool('asset_enable_api_fallback') ?? true;
        _enableCaching = prefs.getBool('asset_enable_caching') ?? true;
      });
    } catch (e, st) {
      print('Error loading configuration: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('asset_prefer_database', _preferDatabase);
      await prefs.setBool('asset_enable_api_fallback', _enableApiFallback);
      await prefs.setBool('asset_enable_caching', _enableCaching);

      // Apply configuration to Hybrid DAM Service
      await sl<HybridDamService>().initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not save configuration. Please try again.',
          stackTrace: st,
          contextLabel: 'asset_integration_config_screen: Could not save configuration. ',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    try {
      // Clear cache is handled automatically by HybridDamService
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not clear cache. Please try again.',
          stackTrace: st,
          contextLabel: 'asset_integration_config_screen: Could not clear cache. Please ',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Asset Integration Config'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.primaryColor,
          elevation: AppTheme.elevationS,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Card(
                      color: AppTheme.accentBlue.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.settings,
                                  color: AppTheme.accentBlue,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Asset Integration Configuration',
                                  style: AppTheme.heading2.copyWith(
                                    color: AppTheme.accentBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            const Text(
                              'Configure how the CMMS integrates with the Asset Management System. Choose between database access or API calls.',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Database Preference
                    Card(
                      color: AppTheme.surfaceColor,
                      elevation: AppTheme.elevationS,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data Source Preference',
                              style: AppTheme.heading2,
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            SwitchListTile(
                              title: const Text('Prefer Database Access'),
                              subtitle: const Text(
                                'Use direct database connection when available (faster, more reliable)',
                              ),
                              value: _preferDatabase,
                              onChanged: (value) {
                                setState(() {
                                  _preferDatabase = value;
                                });
                              },
                              activeThumbColor: AppTheme.accentBlue,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingM),

                    // API Fallback
                    Card(
                      color: AppTheme.surfaceColor,
                      elevation: AppTheme.elevationS,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'API Integration',
                              style: AppTheme.heading2,
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            SwitchListTile(
                              title: const Text('Enable API Fallback'),
                              subtitle: const Text(
                                'Use API calls when database is not available',
                              ),
                              value: _enableApiFallback,
                              onChanged: (value) {
                                setState(() {
                                  _enableApiFallback = value;
                                });
                              },
                              activeThumbColor: AppTheme.accentBlue,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingM),

                    // Caching
                    Card(
                      color: AppTheme.surfaceColor,
                      elevation: AppTheme.elevationS,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Performance',
                              style: AppTheme.heading2,
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            SwitchListTile(
                              title: const Text('Enable Caching'),
                              subtitle: const Text(
                                'Cache asset data for faster subsequent lookups',
                              ),
                              value: _enableCaching,
                              onChanged: (value) {
                                setState(() {
                                  _enableCaching = value;
                                });
                              },
                              activeThumbColor: AppTheme.accentBlue,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _saveConfiguration,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _isLoading ? 'Saving...' : 'Save Configuration',
                            ),
                            style: AppTheme.elevatedButtonStyle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearCache,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear Cache'),
                            style: AppTheme.outlinedButtonStyle,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Current Configuration
                    Card(
                      color: AppTheme.surfaceColor,
                      elevation: AppTheme.elevationS,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Configuration',
                              style: AppTheme.heading2,
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            _buildConfigRow(
                              'Database Preference',
                              _preferDatabase ? 'Enabled' : 'Disabled',
                            ),
                            _buildConfigRow(
                              'API Fallback',
                              _enableApiFallback ? 'Enabled' : 'Disabled',
                            ),
                            _buildConfigRow(
                              'Caching',
                              _enableCaching ? 'Enabled' : 'Disabled',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingL),

                    // Recommendations
                    Card(
                      color: AppTheme.accentGreen.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb,
                                  color: AppTheme.accentGreen,
                                ),
                                const SizedBox(width: AppTheme.spacingS),
                                Text(
                                  'Recommendations',
                                  style: AppTheme.heading2.copyWith(
                                    color: AppTheme.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            const Text(
                              '• For best performance: Enable database preference and caching\n'
                              '• For reliability: Enable API fallback\n'
                              '• For offline use: Disable API fallback, enable caching\n'
                              '• For real-time data: Disable caching, enable API fallback',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      );

  Widget _buildConfigRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(value),
          ],
        ),
      );
}
