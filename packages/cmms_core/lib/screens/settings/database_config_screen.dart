import 'package:flutter/material.dart';
import '../../services/asset_database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class DatabaseConfigScreen extends StatefulWidget {
  const DatabaseConfigScreen({super.key});

  @override
  State<DatabaseConfigScreen> createState() => _DatabaseConfigScreenState();
}

class _DatabaseConfigScreenState extends State<DatabaseConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _databaseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _connectionStringController = TextEditingController();

  bool _isLoading = false;
  bool _isTesting = false;
  bool _connectionSuccessful = false;
  bool _useConnectionString = false;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _connectionStringController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AssetDatabaseService().loadConfiguration();
      final status = AssetDatabaseService().getConfigurationStatus();

      setState(() {
        _hostController.text = status['host'] ?? '';
        _portController.text = status['port']?.toString() ?? '5432';
        _databaseController.text = status['database'] ?? '';
        _usernameController.text = status['username'] ?? '';
        _passwordController.text =
            status['hasPassword'] == true ? '••••••••' : '';
        _connectionStringController.text =
            status['hasConnectionString'] == true ? '••••••••' : '';
        _connectionSuccessful = status['isConfigured'] == true;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_useConnectionString) {
        await AssetDatabaseService().configureDatabase(
          host: 'localhost', // Dummy values for connection string mode
          port: 5432,
          database: 'assets',
          username: 'user',
          password: 'pass',
          connectionString: _connectionStringController.text.trim(),
        );
      } else {
        await AssetDatabaseService().configureDatabase(
          host: _hostController.text.trim(),
          port: int.parse(_portController.text.trim()),
          database: _databaseController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database configuration saved successfully!'),
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
          contextLabel: 'database_config_screen: Could not save configuration. ',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionSuccessful = false;
    });

    try {
      final success = await AssetDatabaseService().testConnection();
      setState(() {
        _connectionSuccessful = success;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Database connection successful!'
                  : 'Database connection failed!',
            ),
            backgroundColor:
                success ? AppTheme.accentGreen : AppTheme.accentRed,
          ),
        );
      }
    } catch (e, st) {
      setState(() {
        _connectionSuccessful = false;
      });
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Connection test failed. Please try again.',
          stackTrace: st,
          contextLabel: 'DatabaseConfig: connection test',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _clearConfiguration() async {
    try {
      await AssetDatabaseService().clearConfiguration();
      _loadConfiguration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database configuration cleared!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not clear configuration. Please try again.',
          stackTrace: st,
          contextLabel: 'DatabaseConfig: clear',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Database Configuration'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.primaryColor,
          elevation: AppTheme.elevationS,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Form(
                  key: _formKey,
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
                                    Icons.storage,
                                    color: AppTheme.accentBlue,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'Asset Management Database',
                                    style: AppTheme.heading2.copyWith(
                                      color: AppTheme.accentBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              const Text(
                                'Configure direct database access to your Asset Management System for faster performance and offline capability.',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Connection Type
                      Card(
                        color: AppTheme.surfaceColor,
                        elevation: AppTheme.elevationS,
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connection Type',
                                style: AppTheme.heading2,
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              SwitchListTile(
                                title: const Text('Use Connection String'),
                                subtitle: const Text(
                                  'Use a single connection string instead of individual parameters',
                                ),
                                value: _useConnectionString,
                                onChanged: (value) {
                                  setState(() {
                                    _useConnectionString = value;
                                  });
                                },
                                activeThumbColor: AppTheme.accentBlue,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingM),

                      // Connection String Mode
                      if (_useConnectionString) ...[
                        Card(
                          color: AppTheme.surfaceColor,
                          elevation: AppTheme.elevationS,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connection String',
                                  style: AppTheme.heading2,
                                ),
                                const SizedBox(height: AppTheme.spacingS),
                                TextFormField(
                                  controller: _connectionStringController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Database Connection String',
                                    hintText:
                                        'postgresql://username:password@host:port/database',
                                  ),
                                  maxLines: 3,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a connection string';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Individual Parameters Mode
                        Card(
                          color: AppTheme.surfaceColor,
                          elevation: AppTheme.elevationS,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Database Parameters',
                                  style: AppTheme.heading2,
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Host
                                TextFormField(
                                  controller: _hostController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Host',
                                    hintText: 'localhost',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a host';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Port
                                TextFormField(
                                  controller: _portController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Port',
                                    hintText: '5432',
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a port';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Please enter a valid port number';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Database
                                TextFormField(
                                  controller: _databaseController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Database Name',
                                    hintText: 'asset_management',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a database name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Username
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Username',
                                    hintText: 'admin',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a username';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingM),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: AppTheme.inputDecoration.copyWith(
                                    labelText: 'Password',
                                    hintText: '••••••••',
                                  ),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

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
                              onPressed: _isTesting ? null : _testConnection,
                              icon: _isTesting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _connectionSuccessful
                                          ? Icons.check
                                          : Icons.wifi,
                                    ),
                              label: Text(
                                _isTesting ? 'Testing...' : 'Test Connection',
                              ),
                              style: AppTheme.outlinedButtonStyle.copyWith(
                                foregroundColor: WidgetStateProperty.all(
                                  _connectionSuccessful
                                      ? AppTheme.accentGreen
                                      : AppTheme.accentBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTheme.spacingM),

                      // Clear Configuration
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _clearConfiguration,
                          icon: const Icon(
                            Icons.clear_all,
                            color: AppTheme.accentRed,
                          ),
                          label: const Text('Clear Configuration'),
                          style: AppTheme.outlinedButtonStyle.copyWith(
                            foregroundColor:
                                WidgetStateProperty.all(AppTheme.accentRed),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Status
                      Card(
                        color: _connectionSuccessful
                            ? AppTheme.accentGreen.withOpacity(0.1)
                            : AppTheme.accentRed.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _connectionSuccessful
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _connectionSuccessful
                                        ? AppTheme.accentGreen
                                        : AppTheme.accentRed,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'Connection Status',
                                    style: AppTheme.heading2.copyWith(
                                      color: _connectionSuccessful
                                          ? AppTheme.accentGreen
                                          : AppTheme.accentRed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              Text(
                                _connectionSuccessful
                                    ? 'Database connection is configured and working'
                                    : 'Database connection is not configured or failed',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingL),

                      // Help
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
                                    Icons.help,
                                    color: AppTheme.accentBlue,
                                  ),
                                  const SizedBox(width: AppTheme.spacingS),
                                  Text(
                                    'Database Setup Help',
                                    style: AppTheme.heading2.copyWith(
                                      color: AppTheme.accentBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.spacingS),
                              const Text(
                                'Supported databases:\n'
                                '• PostgreSQL (recommended)\n'
                                '• MySQL\n'
                                '• SQLite\n'
                                '• MongoDB\n\n'
                                'Contact your system administrator for database connection details.',
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
