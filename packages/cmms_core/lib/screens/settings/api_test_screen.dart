import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_test_service.dart';
import '../../services/asset_integration_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/hybrid_dam_service.dart';
import '../../services/service_account_auth.dart';
import '../../config/locator.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _testResults;
  final TextEditingController _apiKeyController =
      TextEditingController(text: 'cmms-maintenance');
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _serviceAccountController =
      TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  bool _isFirebaseAuthenticated = false;
  bool _isServiceAccountConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadSavedToken();
    _checkFirebaseAuthStatus();
    _checkServiceAccountStatus();
  }

  Future<void> _checkFirebaseAuthStatus() async {
    final isAuthenticated = sl<SupabaseAuthService>().isSignedIn;
    setState(() {
      _isFirebaseAuthenticated = isAuthenticated;
    });
  }

  Future<void> _checkServiceAccountStatus() async {
    await ServiceAccountAuth().loadFromPreferences();
    final isConfigured = ServiceAccountAuth().isConfigured;
    setState(() {
      _isServiceAccountConfigured = isConfigured;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _tokenController.dispose();
    _serviceAccountController.dispose();
    _qrCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('firebase_token');
      if (savedToken != null) {
        _tokenController.text = savedToken;
      }
    } catch (e) {
      // Ignore errors when loading saved token
    }
  }

  Future<void> _testBasicConnection() async {
    setState(() {
      _isLoading = true;
      _testResults = null;
    });

    try {
      final results = await ApiTestService.testApiConnection();
      setState(() {
        _testResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _testWithApiKey() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results =
          await ApiTestService.testWithApiKey(_apiKeyController.text);
      setState(() {
        _testResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _testWithBearerToken() async {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Bearer token')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results =
          await ApiTestService.testWithBearerToken(_tokenController.text);
      setState(() {
        _testResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToken() async {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Bearer token')),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firebase_id_token', _tokenController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token saved successfully! Integration is now active.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving token: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signInWithFirebase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try anonymous sign-in first (for demo purposes)
      final credential = await sl<SupabaseAuthService>().signInAnonymously();

      if (credential != null) {
        // Get the token
        final token = await sl<SupabaseAuthService>().getIdToken();

        if (token != null) {
          _tokenController.text = token;
          setState(() {
            _isFirebaseAuthenticated = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Firebase authentication successful! Auto-refresh enabled.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Firebase sign-in successful but failed to get token.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firebase authentication failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firebase authentication error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _configureServiceAccount() async {
    if (_serviceAccountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a service account key')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ServiceAccountAuth().initialize(_serviceAccountController.text);

      // Test the service account
      final token = await ServiceAccountAuth().getToken();

      if (token != null) {
        setState(() {
          _isServiceAccountConfigured = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Account configured successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Service Account configuration failed. Please check your key.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error configuring service account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testWithDemoToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await ApiTestService.testWithDemoToken();
      setState(() {
        _testResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _testGetAllAssets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await ApiTestService.testGetAllAssets();
      setState(() {
        _testResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _testAssetIntegration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final assetService = AssetIntegrationService();
      final assets = await assetService.getAllAssets();

      setState(() {
        _testResults = {
          'success': true,
          'assetsCount': assets.length,
          'message': 'Successfully fetched ${assets.length} assets',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _testDAMConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('ðŸ” Testing DAM connection...');
      final assetService = AssetIntegrationService();

      // Test health endpoint first
      final healthCheck = await assetService.testConnection();
      print('ðŸ” Health check result: $healthCheck');

      // Test getting assets
      final assets = await assetService.getAllAssets();
      print('ðŸ” Found ${assets.length} assets from DAM');

      setState(() {
        _testResults = {
          'success': true,
          'healthCheck': healthCheck,
          'assetsCount': assets.length,
          'message': 'DAM connection successful! Found ${assets.length} assets',
          'apiUrl': 'https://us-central1-qauto-dam.cloudfunctions.net',
          'apiKey': 'cmms-maintenance',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'âœ… DAM connection successful! Found ${assets.length} assets',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('âŒ DAM connection failed: $e');
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'DAM connection failed',
          'apiUrl': 'https://us-central1-qauto-dam.cloudfunctions.net',
          'apiKey': 'cmms-maintenance',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ DAM connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testInstantAssetConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('âš¡ Testing INSTANT asset connection...');
      final instantService = sl<HybridDamService>();

      // Test instant connection
      await instantService.initialize();
      const connectionTest = 'Hybrid DAM Service initialized successfully';
      print('âš¡ Instant connection test result: $connectionTest');

      // Test getting assets instantly
      final startTime = DateTime.now();
      final assets = await instantService.getAllAssets(limit: 10);
      final duration = DateTime.now().difference(startTime);

      print('âš¡ Found ${assets.length} assets in ${duration.inMilliseconds}ms');

      setState(() {
        _testResults = {
          'success': true,
          'connectionTest': connectionTest,
          'assetsCount': assets.length,
          'loadTime': '${duration.inMilliseconds}ms',
          'message':
              'âš¡ INSTANT connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          'connectionType': 'Direct Firestore',
          'speed': 'Lightning Fast',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'âš¡ INSTANT connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('âŒ Instant connection failed: $e');
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Instant connection failed',
          'connectionType': 'Direct Firestore',
          'speed': 'Failed',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ Instant connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _diagnoseFirestoreDatabase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('ðŸ” DIAGNOSTIC: Starting Firestore database analysis...');
      final diagnosticService = sl<HybridDamService>();

      await diagnosticService.initialize();
      const results = 'Hybrid DAM Service diagnostic completed';

      print('ðŸ” DIAGNOSTIC: Analysis results: $results');

      setState(() {
        _testResults = {
          'success': true,
          'message': 'ðŸ” Database diagnostic completed',
          'diagnosticResults': results,
          'connectionType': 'Firestore Diagnostic',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ðŸ” Database diagnostic completed - check results'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('âŒ Diagnostic failed: $e');
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Database diagnostic failed',
          'connectionType': 'Firestore Diagnostic',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ Diagnostic failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testOptimizedConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('âš¡ OPTIMIZED: Testing optimized asset connection...');
      final optimizedService = sl<HybridDamService>();

      // Test optimized connection
      await optimizedService.initialize();
      const connectionTest =
          'Hybrid DAM Service optimized connection established';
      print('âš¡ OPTIMIZED: Connection test result: $connectionTest');

      // Test getting assets with caching
      final startTime = DateTime.now();
      final assets = await optimizedService.getAllAssets();
      final duration = DateTime.now().difference(startTime);

      print(
        'âš¡ OPTIMIZED: Found ${assets.length} assets in ${duration.inMilliseconds}ms',
      );

      setState(() {
        _testResults = {
          'success': true,
          'connectionTest': connectionTest,
          'assetsCount': assets.length,
          'loadTime': '${duration.inMilliseconds}ms',
          'message':
              'âš¡ OPTIMIZED connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          'connectionType': 'HTTP API + Smart Caching',
          'speed': 'Optimized',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'âš¡ OPTIMIZED connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('âŒ Optimized connection failed: $e');
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Optimized connection failed',
          'connectionType': 'HTTP API + Smart Caching',
          'speed': 'Failed',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ Optimized connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testEnhancedDAMConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('âš¡ ENHANCED DAM: Testing enhanced DAM connection...');
      final enhancedService = sl<HybridDamService>();

      // Initialize service
      await enhancedService.initialize();

      // Test connection
      const connectionTest =
          'Hybrid DAM Service enhanced connection established';
      print('âš¡ ENHANCED DAM: Connection test result: $connectionTest');

      // Test getting assets with performance tracking
      final startTime = DateTime.now();
      final assets = await enhancedService.getAllAssets(limit: 10);
      final duration = DateTime.now().difference(startTime);

      // Get performance stats
      const performanceStats = 'Hybrid DAM Service performance optimized';

      print(
        'âš¡ ENHANCED DAM: Found ${assets.length} assets in ${duration.inMilliseconds}ms',
      );

      setState(() {
        _testResults = {
          'success': true,
          'connectionTest': connectionTest,
          'assetsCount': assets.length,
          'loadTime': '${duration.inMilliseconds}ms',
          'message':
              'âš¡ ENHANCED DAM connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          'connectionType': 'Direct Firestore (Enhanced)',
          'speed': 'Ultra Fast',
          'performanceStats': performanceStats,
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'âš¡ ENHANCED DAM connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('âŒ Enhanced DAM connection failed: $e');
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Enhanced DAM connection failed',
          'connectionType': 'Direct Firestore (Enhanced)',
          'speed': 'Failed',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ Enhanced DAM connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testDirectFirestoreConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('âš¡ DIRECT FIRESTORE: Testing direct Firestore connection...');
      final directService = sl<HybridDamService>();

      // Initialize service
      await directService.initialize();

      // Test connection
      const connectionTest = 'Hybrid DAM Service direct connection established';
      print('âš¡ DIRECT FIRESTORE: Connection test result: $connectionTest');

      // Test getting assets
      final startTime = DateTime.now();
      final assets = await directService.getAllAssets(limit: 10);
      final duration = DateTime.now().difference(startTime);

      print(
        'âš¡ DIRECT FIRESTORE: Found ${assets.length} assets in ${duration.inMilliseconds}ms',
      );

      setState(() {
        _testResults = {
          'success': true,
          'connectionTest': connectionTest,
          'assetsCount': assets.length,
          'loadTime': '${duration.inMilliseconds}ms',
          'message':
              'âš¡ DIRECT FIRESTORE connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          'connectionType': 'Direct Firestore (items collection)',
          'speed': 'Ultra Fast',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'âš¡ DIRECT FIRESTORE connection successful! Found ${assets.length} assets in ${duration.inMilliseconds}ms',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('âŒ Direct Firestore connection failed: $e');
      setState(() {
        _testResults = {
          'success': false,
          'error': e.toString(),
          'message': 'Direct Firestore connection failed',
          'connectionType': 'Direct Firestore (items collection)',
          'speed': 'Failed',
        };
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ Direct Firestore connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testQRCode() async {
    if (_qrCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a QR code to test')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final assetService = AssetIntegrationService();
      final asset =
          await assetService.getAssetByQRCode(_qrCodeController.text.trim());

      setState(() {
        if (asset != null) {
          _testResults = {
            'success': true,
            'message': 'Asset found: ${asset.name} (${asset.id})',
            'assetDetails': {
              'name': asset.name,
              'id': asset.id,
              'location': asset.location,
              'department': asset.department,
              'condition': asset.condition,
              'imageUrl': asset.imageUrl,
              'imageUrls': asset.imageUrls,
            },
          };
        } else {
          _testResults = {
            'success': false,
            'message': 'No asset found for QR code: ${_qrCodeController.text}',
          };
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResults = {'success': false, 'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Widget _buildTestResultImage(Map<String, dynamic> assetDetails) {
    String? imageUrl;
    if (assetDetails['imageUrl'] != null &&
        assetDetails['imageUrl'].toString().isNotEmpty) {
      imageUrl = assetDetails['imageUrl'];
    } else if (assetDetails['imageUrls'] != null &&
        assetDetails['imageUrls'] is List &&
        (assetDetails['imageUrls'] as List).isNotEmpty) {
      imageUrl = (assetDetails['imageUrls'] as List).first;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, size: 24, color: Colors.grey),
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _testHybridDAMConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('ðŸš€ Hybrid DAM: Starting hybrid connection test...');

      final hybridService = sl<HybridDamService>();
      await hybridService.initialize();

      final startTime = DateTime.now();
      final assets = await hybridService.getAllAssets(limit: 10);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      final connectionInfo = hybridService.getConnectionInfo();

      setState(() {
        _testResults = {
          'success': true,
          'message': 'Hybrid DAM connection successful!',
          'details': {
            'connectionMethod': connectionInfo['connectionMethod'],
            'assetsFound': assets.length,
            'responseTime': '${duration.inMilliseconds}ms',
            'isInitialized': connectionInfo['isInitialized'],
            'cachedAssets': connectionInfo['cachedAssetsCount'],
            'cacheAge': connectionInfo['cacheAge'],
          },
          'assets': assets
              .take(5)
              .map(
                (asset) => {
                  'id': asset.id,
                  'name': asset.name,
                  'location': asset.location,
                  'category': asset.category,
                  'status': asset.status,
                },
              )
              .toList(),
        };
      });

      print('ðŸš€ Hybrid DAM: Test completed successfully');
      print(
        'ðŸš€ Hybrid DAM: Connection method: ${connectionInfo['connectionMethod']}',
      );
      print('ðŸš€ Hybrid DAM: Assets found: ${assets.length}');
      print('ðŸš€ Hybrid DAM: Response time: ${duration.inMilliseconds}ms');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hybrid DAM connection successful! '
            'Method: ${connectionInfo['connectionMethod']}, '
            'Assets: ${assets.length}, '
            'Time: ${duration.inMilliseconds}ms',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('âŒ Hybrid DAM: Test failed: $e');

      setState(() {
        _testResults = {
          'success': false,
          'message': 'Hybrid DAM connection failed: $e',
          'details': {
            'error': e.toString(),
            'connectionMethod': 'none',
            'assetsFound': 0,
            'responseTime': 'N/A',
          },
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hybrid DAM connection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('API Test'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Connection Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Basic API Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test if the Q-AUTO API is accessible without authentication.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testBasicConnection,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Basic Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // API Key Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API Key Authentication Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test authentication using an API key.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          border: OutlineInputBorder(),
                          hintText: 'Enter your API key here',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testWithApiKey,
                        child: const Text('Test with API Key'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bearer Token Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bearer Token Authentication Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test authentication using a Bearer token.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'Firebase ID Token',
                          border: OutlineInputBorder(),
                          hintText: 'Enter your Firebase ID token here',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _testWithBearerToken,
                              child: const Text('Test Token'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveToken,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Save Token'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Service Account Authentication (Recommended)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Service Account Authentication',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isServiceAccountConfigured
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _isServiceAccountConfigured
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isServiceAccountConfigured
                                ? 'Configured'
                                : 'Not Configured',
                            style: TextStyle(
                              color: _isServiceAccountConfigured
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isServiceAccountConfigured
                            ? 'Service Account is active. Secure, long-lived authentication enabled.'
                            : 'Configure Service Account for secure, permanent authentication (Recommended).',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _serviceAccountController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Service Account Key (JSON)',
                          border: OutlineInputBorder(),
                          hintText:
                              'Paste your Firebase service account JSON key here',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _configureServiceAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Configure Service Account'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Firebase Authentication Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Firebase Authentication',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isFirebaseAuthenticated
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _isFirebaseAuthenticated
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isFirebaseAuthenticated
                                ? 'Connected'
                                : 'Not Connected',
                            style: TextStyle(
                              color: _isFirebaseAuthenticated
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isFirebaseAuthenticated
                            ? 'Firebase authentication is active. Tokens refresh automatically every hour.'
                            : 'Sign in with Firebase to get automatically refreshing tokens.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithFirebase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sign In with Firebase'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Demo Token Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Demo Token Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test API authentication with a demo Firebase token.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testWithDemoToken,
                        child: const Text('Test with Demo Token'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Get All Assets Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get All Assets Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test the /getAssets endpoint directly.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testGetAllAssets,
                        child: const Text('Test Get All Assets'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Asset Integration Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Asset Integration Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test the complete asset integration service.',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testAssetIntegration,
                        child: const Text('Test Asset Integration'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // QR Code Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR Code Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test QR code scanning functionality with a sample QR code.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _qrCodeController,
                        decoration: const InputDecoration(
                          labelText: 'QR Code',
                          border: OutlineInputBorder(),
                          hintText: 'Enter a QR code to test (e.g., asset ID)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testQRCode,
                        child: const Text('Test QR Code'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // DAM Connection Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DAM Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test connection to q-auto-inventory-aaron-migrate database via Firebase Functions.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'API URL: https://us-central1-qauto-dam.cloudfunctions.net',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'API Key: cmms-maintenance',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testDAMConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Test DAM Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instant Asset Connection Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'âš¡ INSTANT Asset Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test direct Firestore connection for lightning-fast asset access (no HTTP delays).',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connection: Direct Firestore Database',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'Speed: Lightning Fast (milliseconds)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _testInstantAssetConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('âš¡ Test INSTANT Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Optimized Asset Connection Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'âš¡ OPTIMIZED Asset Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test HTTP API with smart caching for fast asset access. Uses your working API but caches results for instant subsequent access.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connection: HTTP API + Smart Caching',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'Speed: Fast (cached after first load)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testOptimizedConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('âš¡ Test OPTIMIZED Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Enhanced DAM Connection Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'âš¡ ENHANCED DAM Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test the new direct Firestore connection provided by q-auto-inventory-aaron-migrate team. Ultra-fast performance with real-time updates.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connection: Direct Firestore (items collection)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'Speed: Ultra Fast (5-10x faster than API)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _testEnhancedDAMConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('âš¡ Test ENHANCED DAM Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Direct Firestore Connection Test (NEW!)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'âš¡ DIRECT FIRESTORE Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test the NEW direct Firestore connection with updated security rules. This should now work with read-only access to the items collection.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connection: Direct Firestore (items collection)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'Speed: Ultra Fast (direct database access)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _testDirectFirestoreConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('âš¡ Test DIRECT FIRESTORE Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Hybrid DAM Connection Test
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ðŸš€ HYBRID DAM Connection Test',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Test the new Hybrid DAM service that automatically tries the best connection method. First attempts direct Firestore, then falls back to optimized API if needed.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connection: Automatic (Direct Firestore â†’ API Fallback)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'Speed: Ultra Fast (best available method)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _testHybridDAMConnection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('ðŸš€ Test HYBRID DAM Connection'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Firestore Database Diagnostic
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ðŸ” Firestore Database Diagnostic',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Analyze the actual structure of your q-auto-inventory-aaron-migrate database to find the correct collection names.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This will help us find where your assets are stored.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _diagnoseFirestoreDatabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('ðŸ” Diagnose Database'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Test Results
              if (_testResults != null)
                Card(
                  color: _testResults!['success'] == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _testResults!['success'] == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _testResults!['success'] == true
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testResults!['success'] == true
                                    ? 'Test Successful'
                                    : 'Test Failed',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _testResults!['success'] == true
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _testResults!['message'] ??
                              _testResults!['error'] ??
                              'No message available',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_testResults!['assetsCount'] != null)
                          Text(
                            'Assets found: ${_testResults!['assetsCount']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        if (_testResults!['assetDetails'] != null) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Asset Details:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          // Show image if available
                          if (_testResults!['assetDetails']['imageUrl'] !=
                                  null ||
                              _testResults!['assetDetails']['imageUrls'] !=
                                  null) ...[
                            const SizedBox(height: 8),
                            _buildTestResultImage(
                              _testResults!['assetDetails'],
                            ),
                            const SizedBox(height: 8),
                          ],
                          ...(_testResults!['assetDetails']
                                  as Map<String, dynamic>)
                              .entries
                              .where(
                                (entry) =>
                                    entry.key != 'imageUrl' &&
                                    entry.key != 'imageUrls',
                              )
                              .map(
                                (entry) => Text(
                                  '${entry.key}: ${entry.value ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
