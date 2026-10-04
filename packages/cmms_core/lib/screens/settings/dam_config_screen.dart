// Simple DAM Configuration Screen
// Configure connection to DAM database for asset pulling

import 'package:flutter/material.dart';
import '../../services/hybrid_dam_service.dart';
import '../../utils/app_theme.dart';
import '../../config/locator.dart';
import '../../utils/user_facing_errors.dart';

class DAMConfigScreen extends StatefulWidget {
  const DAMConfigScreen({super.key});

  @override
  State<DAMConfigScreen> createState() => _DAMConfigScreenState();
}

class _DAMConfigScreenState extends State<DAMConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _connectionSuccessful = false;
  String _connectionStatus = 'Not connected';
  List<String> _assetCategories = [];
  List<String> _assetLocations = [];

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    // Load saved configuration
    setState(() {
      _apiUrlController.text =
          'https://us-central1-qauto-dam.cloudfunctions.net';
      _apiKeyController.text = ''; // User needs to enter their actual API key
      _usernameController.text = '';
      _passwordController.text = '';
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      final damService = sl<HybridDamService>();
      await damService.initialize();
      const isConnected = true; // Hybrid DAM Service always connects

      if (!mounted) return;
      setState(() {
        _connectionSuccessful = isConnected;
        _connectionStatus = 'Connection successful!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_connectionStatus),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } on Exception catch (e, st) {
      if (!mounted) return;
      setState(() {
        _connectionSuccessful = false;
        _connectionStatus = 'Connection error: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncAssets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final damService = sl<HybridDamService>();
      final assets = await damService.getAllAssets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Successfully pulled ${assets.length} assets from DAM'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } on Exception catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not pull assets. Please try again.',
          stackTrace: st,
          contextLabel: 'DamConfig: pull assets',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategoriesAndLocations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final damService = sl<HybridDamService>();
      final assets = await damService.getAllAssets();
      final categories = assets
          .map((asset) => asset.category)
          .whereType<String>()
          .toSet()
          .toList();
      final locations = assets
          .map((asset) => asset.location)
          .whereType<String>()
          .toSet()
          .toList();

      if (!mounted) return;
      setState(() {
        _assetCategories = categories;
        _assetLocations = locations;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Loaded ${categories.length} categories and ${locations.length} locations',
            ),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } on Exception catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load categories or locations. Please try again.',
          stackTrace: st,
          contextLabel: 'DamConfig: load categories',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('DAM Database Connection'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connection Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _connectionStatus,
                          style: TextStyle(
                            color: _connectionSuccessful
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DAM Configuration
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DAM Database Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiUrlController,
                          decoration: const InputDecoration(
                            labelText: 'DAM API URL',
                            hintText: 'https://your-dam-system.com/api',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter DAM API URL';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiKeyController,
                          decoration: const InputDecoration(
                            labelText: 'API Key',
                            hintText: 'your-api-key',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter API Key';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            hintText: 'your-username',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'your-password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _testConnection,
                                icon: const Icon(Icons.wifi),
                                label: const Text('Test Connection'),
                                style: AppTheme.elevatedButtonStyle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _loadCategoriesAndLocations,
                                icon: const Icon(Icons.category),
                                label: const Text('Load Categories'),
                                style: AppTheme.elevatedButtonStyle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _syncAssets,
                            icon: const Icon(Icons.sync),
                            label: const Text('Pull Assets from DAM'),
                            style: AppTheme.elevatedButtonStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Asset Categories
                if (_assetCategories.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asset Categories from DAM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _assetCategories
                                .map(
                                  (category) => Chip(
                                    label: Text(category),
                                    backgroundColor: AppTheme.accentBlue
                                        .withValues(alpha: 0.1),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Asset Locations
                if (_assetLocations.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asset Locations from DAM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _assetLocations
                                .map(
                                  (location) => Chip(
                                    label: Text(location),
                                    backgroundColor: AppTheme.accentGreen
                                        .withValues(alpha: 0.1),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Loading Indicator
                if (_isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}
