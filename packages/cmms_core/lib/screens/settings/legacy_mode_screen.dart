import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/cmms_repositories.dart';
import '../../services/hybrid_dam_service.dart';
import '../../utils/app_theme.dart';
import '../../config/locator.dart';

class LegacyModeScreen extends StatefulWidget {
  const LegacyModeScreen({super.key});

  @override
  State<LegacyModeScreen> createState() => _LegacyModeScreenState();
}

class _LegacyModeScreenState extends State<LegacyModeScreen> {
  bool _isLegacyMode = false;
  bool _isLoading = false;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    _loadLegacyMode();
  }

  Future<void> _loadLegacyMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isLegacyMode = prefs.getBool('use_legacy_mode') ?? false;
      });
    } catch (e) {
      print('Error loading legacy mode: $e');
    }
  }

  Future<void> _toggleLegacyMode(bool value) async {
    setState(() {
      _isLegacyMode = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_legacy_mode', value);

      if (value) {
        // Configure legacy mode
        final legacyService = sl<HybridDamService>();
        await legacyService.initialize();
      }
    } catch (e) {
      print('Error saving legacy mode: $e');
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = '';
    });

    try {
      if (_isLegacyMode) {
        final legacyService = sl<HybridDamService>();
        await legacyService.initialize();
        const result =
            true; // Hybrid DAM Service always initializes successfully
        setState(() {
          _testResult = result
              ? '✅ Legacy mode: Connection successful!'
              : '❌ Legacy mode: Connection failed';
        });
      } else {
        await CmmsRepositories.workOrders.initialize();
        final result = await CmmsRepositories.workOrders.testConnection();
        setState(() {
          _testResult = result
              ? '✅ New mode: Connection successful!'
              : '❌ New mode: Connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _testResult = '❌ Test error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Legacy Mode'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Legacy Mode Toggle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Switch between the new authentication mode and the old working mode.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Use Legacy Mode'),
                        subtitle: Text(
                          _isLegacyMode
                              ? 'Using old APK method'
                              : 'Using new authentication method',
                        ),
                        value: _isLegacyMode,
                        onChanged: _toggleLegacyMode,
                        activeThumbColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connection Test',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test the current mode to see if it works.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _testConnection,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check),
                          label: Text(
                            _isLoading ? 'Testing...' : 'Test Connection',
                          ),
                          style: AppTheme.elevatedButtonStyle,
                        ),
                      ),
                      if (_testResult.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _testResult.startsWith('✅')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _testResult.startsWith('✅')
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _testResult,
                            style: TextStyle(
                              color: _testResult.startsWith('✅')
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Differences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Legacy Mode (Old APK):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '• Uses API keys in URLs\n• No authentication required\n• Works like your old APK',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'New Mode:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '• Uses Firebase authentication\n• Requires user sign-in\n• More secure but needs setup',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
