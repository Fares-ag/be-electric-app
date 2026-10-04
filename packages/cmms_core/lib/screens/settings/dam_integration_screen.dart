// DAM Integration Configuration Screen
// Configure connection to Digital Asset Management system

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

// Minimal inline stubs to satisfy lints; replace with real implementations if added later
class DAMIntegrationService {
  Future<bool> testDAMConnection() async => Future.value(false);
  Future<List<Map<String, dynamic>>> fetchAllAssetsFromDAM() async => [];
}

class DAMIntegrationScreen extends StatefulWidget {
  const DAMIntegrationScreen({super.key});

  @override
  State<DAMIntegrationScreen> createState() => _DAMIntegrationScreenState();
}

class _DAMIntegrationScreenState extends State<DAMIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _integrationType = 'api';
  bool _isLoading = false;
  bool _connectionSuccessful = false;
  String _connectionStatus = 'Not connected';

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
      _apiUrlController.text = 'https://your-dam-system.com/api';
      _apiKeyController.text = 'your-api-key';
      _usernameController.text = 'your-username';
      _passwordController.text = 'your-password';
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      final damService = DAMIntegrationService();
      final isConnected = await damService.testDAMConnection();

      setState(() {
        _connectionSuccessful = isConnected;
        _connectionStatus = isConnected
            ? 'Connection successful!'
            : 'Connection failed. Check your configuration.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_connectionStatus),
            backgroundColor: isConnected ? AppTheme.accentGreen : Colors.red,
          ),
        );
      }
    } catch (e, st) {
      setState(() {
        _connectionSuccessful = false;
        _connectionStatus = 'Connection error: $e';
      });
    } finally {
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
      final damService = DAMIntegrationService();
      final assets = await damService.fetchAllAssetsFromDAM();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Successfully synced ${assets.length} assets from DAM'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not sync assets. Please try again.',
          stackTrace: st,
          contextLabel: 'DamIntegration: sync assets',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('DAM Integration'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Integration Type Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Integration Type',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        RadioListTile<String>(
                          title: const Text('API Integration'),
                          subtitle:
                              const Text('REST API connection to DAM system'),
                          value: 'api',
                          groupValue: _integrationType,
                          onChanged: (value) {
                            setState(() {
                              _integrationType = value!;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('Database Connection'),
                          subtitle: const Text(
                            'Direct database access to DAM system',
                          ),
                          value: 'database',
                          groupValue: _integrationType,
                          onChanged: (value) {
                            setState(() {
                              _integrationType = value!;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: const Text('File Import'),
                          subtitle: const Text(
                            'CSV/JSON file import from DAM system',
                          ),
                          value: 'file',
                          groupValue: _integrationType,
                          onChanged: (value) {
                            setState(() {
                              _integrationType = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Configuration Form
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connection Configuration',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (_integrationType == 'api') ...[
                          TextFormField(
                            controller: _apiUrlController,
                            decoration: const InputDecoration(
                              labelText: 'API URL',
                              hintText: 'https://your-dam-system.com/api',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter API URL';
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
                            obscureText: true,
                          ),
                        ] else if (_integrationType == 'database') ...[
                          TextFormField(
                            controller: _apiUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Database Host',
                              hintText: 'your-dam-database.com',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Database Username',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Database Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                        ] else if (_integrationType == 'file') ...[
                          const Text(
                            'File Import Configuration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload CSV or JSON files from your DAM system to import assets.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Connection Status
                Card(
                  color:
                      _connectionSuccessful ? Colors.green[50] : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _connectionSuccessful
                              ? Icons.check_circle
                              : Icons.error,
                          color:
                              _connectionSuccessful ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _connectionStatus,
                            style: TextStyle(
                              color: _connectionSuccessful
                                  ? Colors.green[800]
                                  : Colors.red[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testConnection,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi),
                        label:
                            Text(_isLoading ? 'Testing...' : 'Test Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || !_connectionSuccessful
                            ? null
                            : _syncAssets,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync Assets'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Help Text
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text(
                              'DAM Integration Help',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• API Integration: Connect to DAM system via REST API\n'
                          '• Database Connection: Direct access to DAM database\n'
                          '• File Import: Import assets from CSV/JSON files\n'
                          '• Test connection before syncing assets\n'
                          '• Assets will be imported to your CMMS system',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
