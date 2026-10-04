import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';

/// Service for direct database access to Asset Management System
class AssetDatabaseService {

  // Database configuration
  String? _host;
  int? _port;
  String? _database;
  String? _username;
  String? _password;
  String? _connectionString;
  bool _isConfigured = false;

  /// Configure database connection
  Future<void> configureDatabase({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
    String? connectionString,
  }) async {
    _host = host;
    _port = port;
    _database = database;
    _username = username;
    _password = password;
    _connectionString = connectionString;
    _isConfigured = true;

    // Save configuration
    await _saveConfiguration();
    print('ðŸ—„ï¸ Database configured: $host:$port/$database');
  }

  /// Load configuration from storage
  Future<void> loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _host = prefs.getString('db_host');
      _port = prefs.getInt('db_port');
      _database = prefs.getString('db_database');
      _username = prefs.getString('db_username');
      _password = prefs.getString('db_password');
      _connectionString = prefs.getString('db_connection_string');

      _isConfigured = _host != null && _port != null && _database != null;
      print('ðŸ—„ï¸ Database config loaded: $_isConfigured');
    } catch (e, st) {
      print('âŒ Error loading database config: $e');
      _isConfigured = false;
    }
  }

  /// Save configuration to storage
  Future<void> _saveConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_host != null) await prefs.setString('db_host', _host!);
      if (_port != null) await prefs.setInt('db_port', _port!);
      if (_database != null) await prefs.setString('db_database', _database!);
      if (_username != null) await prefs.setString('db_username', _username!);
      if (_password != null) await prefs.setString('db_password', _password!);
      if (_connectionString != null) {
        await prefs.setString('db_connection_string', _connectionString!);
      }
    } catch (e, st) {
      print('âŒ Error saving database config: $e');
    }
  }

  /// Test database connection
  Future<bool> testConnection() async {
    if (!_isConfigured) {
      print('âŒ Database not configured');
      return false;
    }

    try {
      // For now, we'll simulate a connection test
      // In a real implementation, you would use a database driver like:
      // - PostgreSQL: postgres package
      // - MySQL: mysql1 package
      // - SQLite: sqflite package
      // - MongoDB: mongo_dart package

      print('ðŸ” Testing database connection...');
      print('Host: $_host');
      print('Port: $_port');
      print('Database: $_database');
      print('Username: $_username');

      // Simulate connection test
      await Future.delayed(const Duration(seconds: 1));

      print('âœ… Database connection successful');
      return true;
    } catch (e, st) {
      print('âŒ Database connection failed: $e');
      return false;
    }
  }

  /// Get asset by QR code from database
  Future<Asset?> getAssetByQRCode(String qrCode) async {
    if (!_isConfigured) {
      print('âŒ Database not configured');
      return null;
    }

    try {
      print('ðŸ” Database lookup for QR code: $qrCode');

      // Simulate database query
      // In a real implementation, you would execute SQL like:
      // SELECT * FROM assets WHERE qr_code = ? OR qr_code_id = ? OR id = ?

      await Future.delayed(
          const Duration(milliseconds: 500),); // Simulate query time

      // For demo purposes, return a mock asset if QR code contains "ASSET"
      if (qrCode.toUpperCase().contains('ASSET')) {
        return Asset(
          id: 'db_${qrCode}_001',
          name: 'Database Asset: $qrCode',
          description: 'Asset retrieved from database',
          category: 'Equipment',
          location: 'Warehouse A',
          qrCodeId: qrCode,
          itemType: 'Equipment',
          supplier: 'Database Supplier',
          company: 'Q-AUTO',
          department: 'Maintenance',
          assignedStaff: 'Technician',
          condition: 'Good',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      print('âŒ Asset not found in database');
      return null;
    } catch (e, st) {
      print('âŒ Database query error: $e');
      return null;
    }
  }

  /// Search assets in database
  Future<List<Asset>> searchAssets(String query) async {
    if (!_isConfigured) {
      print('âŒ Database not configured');
      return [];
    }

    try {
      print('ðŸ” Database search for: $query');

      // Simulate database search
      await Future.delayed(const Duration(milliseconds: 300));

      // Return mock results for demo
      if (query.isNotEmpty) {
        return [
          Asset(
            id: 'db_search_001',
            name: 'Search Result 1: $query',
            description: 'Found in database search',
            category: 'Equipment',
            location: 'Warehouse A',
            qrCodeId: 'QR_${query.toUpperCase()}_001',
            itemType: 'Equipment',
            supplier: 'Database Supplier',
            company: 'Q-AUTO',
            department: 'Maintenance',
            assignedStaff: 'Technician',
            condition: 'Good',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
      }

      return [];
    } catch (e, st) {
      print('âŒ Database search error: $e');
      return [];
    }
  }

  /// Get all assets from database
  Future<List<Asset>> getAllAssets({int? limit}) async {
    if (!_isConfigured) {
      print('âŒ Database not configured');
      return [];
    }

    try {
      print('ðŸ” Database get all assets (limit: ${limit ?? 'none'})');

      // Simulate database query
      await Future.delayed(const Duration(milliseconds: 800));

      // Return mock results for demo
      final assets = <Asset>[];
      final count = limit ?? 10;

      for (var i = 1; i <= count; i++) {
        assets.add(
          Asset(
            id: 'db_asset_$i',
            name: 'Database Asset $i',
            description: 'Asset $i from database',
            category: 'Equipment',
            location:
                'Warehouse ${String.fromCharCode(64 + (i % 3) + 1)}', // A, B, C
            qrCodeId: 'DB_QR_$i',
            itemType: 'Equipment',
            supplier: 'Database Supplier',
            company: 'Q-AUTO',
            department: 'Maintenance',
            assignedStaff: 'Technician $i',
            condition: 'Good',
            createdAt: DateTime.now().subtract(Duration(days: i)),
            updatedAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );
      }

      print('âœ… Retrieved ${assets.length} assets from database');
      return assets;
    } catch (e, st) {
      print('âŒ Database get all assets error: $e');
      return [];
    }
  }

  /// Get database configuration status
  Map<String, dynamic> getConfigurationStatus() => {
        'isConfigured': _isConfigured,
        'host': _host,
        'port': _port,
        'database': _database,
        'username': _username,
        'hasPassword': _password != null,
        'hasConnectionString': _connectionString != null,
      };

  /// Clear database configuration
  Future<void> clearConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('db_host');
      await prefs.remove('db_port');
      await prefs.remove('db_database');
      await prefs.remove('db_username');
      await prefs.remove('db_password');
      await prefs.remove('db_connection_string');

      _host = null;
      _port = null;
      _database = null;
      _username = null;
      _password = null;
      _connectionString = null;
      _isConfigured = false;

      print('ðŸ—‘ï¸ Database configuration cleared');
    } catch (e, st) {
      print('âŒ Error clearing database config: $e');
    }
  }
}
