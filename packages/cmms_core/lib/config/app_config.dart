// Application Configuration
//
// Centralized configuration for environment-specific settings.
// Uses environment variables for production, with fallbacks for development.
//
// Usage:
// ```dart
// if (AppConfig.isDemoMode) {
//   // Show demo banner
// }
//
// final apiKey = AppConfig.apiKey;
// ```

import 'package:flutter/foundation.dart';

/// Application configuration with environment-based settings
class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  /// Check if running in debug mode
  static bool get isDebugMode => kDebugMode;

  /// Check if demo mode is enabled (only in debug mode)
  /// Set via: flutter run --dart-define=DEMO_MODE=true
  static bool get isDemoMode {
    const demoMode = bool.fromEnvironment('DEMO_MODE');
    return demoMode && isDebugMode; // Only allow in debug mode
  }

  /// Enable verbose logging
  /// Set via: flutter run --dart-define=VERBOSE_LOGGING=true
  static bool get isVerboseLogging =>
      const bool.fromEnvironment('VERBOSE_LOGGING');

  /// API Base URL
  /// Set via: flutter run --dart-define=API_URL=https://your-api.com
  static String get apiUrl => const String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://api-qauto.firebaseapp.com',
      );

  /// API Key (if needed)
  /// Set via: flutter run --dart-define=API_KEY=your_key_here
  static String? get apiKey {
    const key = String.fromEnvironment('API_KEY');
    return key.isEmpty ? null : key;
  }

  /// Supabase project URL
  /// Set via: flutter run --dart-define=SUPABASE_URL=your_url
  /// Release builds must pass SUPABASE_URL via --dart-define (no baked-in default).
  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (isDebugMode) {
      return 'https://sdhqjyjeczrbnvukrmny.supabase.co';
    }
    return '';
  }

  /// Supabase anon (publishable) key for client-side auth
  /// Set via: flutter run --dart-define=SUPABASE_ANON_KEY=your_key
  /// Release builds must pass SUPABASE_ANON_KEY via --dart-define.
  static String get supabaseAnonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (isDebugMode) {
      return 'sb_publishable_jymzllhRW_CVJH6pY3qleA_7GRd1ETA';
    }
    return '';
  }

  /// True when required Supabase credentials are present.
  static bool get hasValidSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Public privacy policy URL (required for App Store).
  /// --dart-define=PRIVACY_POLICY_URL=https://your-domain.com/privacy
  static String get privacyPolicyUrl {
    const fromEnv = String.fromEnvironment('PRIVACY_POLICY_URL');
    return fromEnv.trim();
  }

  /// Terms of service URL (optional in-app link).
  /// --dart-define=TERMS_OF_SERVICE_URL=https://your-domain.com/terms
  static String get termsOfServiceUrl {
    const fromEnv = String.fromEnvironment('TERMS_OF_SERVICE_URL');
    return fromEnv.trim();
  }

  /// Public support / help page URL for App Store Connect.
  /// --dart-define=SUPPORT_URL=https://your-domain.com/support
  static String get supportUrl {
    const fromEnv = String.fromEnvironment('SUPPORT_URL');
    return fromEnv.trim();
  }

  /// Support email for account help and deletion requests.
  /// --dart-define=SUPPORT_EMAIL=support@your-domain.com
  static String get supportEmail {
    const fromEnv = String.fromEnvironment('SUPPORT_EMAIL');
    return fromEnv.trim();
  }

  /// True when legal/support URLs needed for store compliance are set.
  static bool get hasValidLegalConfig =>
      privacyPolicyUrl.isNotEmpty &&
      supportEmail.isNotEmpty &&
      supportUrl.isNotEmpty;

  /// Maximum file upload size (in MB)
  static int get maxFileUploadSizeMB =>
      const int.fromEnvironment('MAX_UPLOAD_SIZE_MB', defaultValue: 10);

  /// Session timeout (in minutes)
  static int get sessionTimeoutMinutes =>
      const int.fromEnvironment('SESSION_TIMEOUT', defaultValue: 30);

  /// Enable offline mode
  static bool get isOfflineModeEnabled =>
      const bool.fromEnvironment('OFFLINE_MODE', defaultValue: true);

  /// Sync interval (in seconds)
  static int get syncIntervalSeconds {
    return const int.fromEnvironment(
      'SYNC_INTERVAL',
      defaultValue: 300,
    ); // 5 minutes
  }

  /// Maximum retry attempts for failed operations
  static int get maxRetryAttempts =>
      const int.fromEnvironment('MAX_RETRIES', defaultValue: 3);

  /// Enable analytics tracking
  static bool get isAnalyticsEnabled =>
      const bool.fromEnvironment('ANALYTICS_ENABLED', defaultValue: true);

  /// Enable crash reporting
  static bool get isCrashReportingEnabled {
    return const bool.fromEnvironment('CRASH_REPORTING', defaultValue: true) &&
        !isDebugMode; // Disable in debug mode
  }

  /// Enable automatic user population from Supabase
  /// When disabled, users are only created explicitly, not automatically synced
  /// Set via: flutter run --dart-define=AUTO_POPULATE_USERS=false
  static bool get autoPopulateUsers =>
      const bool.fromEnvironment('AUTO_POPULATE_USERS', defaultValue: false);

  /// Enable automatic user creation on login
  /// When disabled, users must exist in database before they can log in
  /// Set via: flutter run --dart-define=AUTO_CREATE_USERS_ON_LOGIN=false
  static bool get autoCreateUsersOnLogin =>
      const bool.fromEnvironment('AUTO_CREATE_USERS_ON_LOGIN', defaultValue: false);

  /// Option A PM schedules + occurrences (technician inbox + requestor read-only).
  ///
  /// **Default: OFF** — legacy `pm_tasks` only; requestor PM module hidden.
  /// **ON:** unified [PmInboxProvider] merges legacy + occurrences; requestor
  /// PM dashboard enabled; occurrence completion is the new write path.
  ///
  /// Production: set in `scripts/defines.production.json` before store release.
  /// Set via: flutter run --dart-define=ENABLE_PM_OCCURRENCES=true
  static bool get enablePmOccurrences =>
      const bool.fromEnvironment('ENABLE_PM_OCCURRENCES');

  /// Demo user credentials (only available in demo mode)
  static Map<String, Map<String, String>> get demoUsers {
    if (!isDemoMode) return {}; // Return empty map in production

    return {
      'admin': {
        'email': 'admin@qauto.com',
        'password': 'demo123', // Changed from hardcoded 'password123'
        'role': 'admin',
        'name': 'Demo Admin',
        'department': 'Administration',
      },
      'manager': {
        'email': 'manager@qauto.com',
        'password': 'demo123',
        'role': 'manager',
        'name': 'Demo Manager',
        'department': 'Management',
      },
      'technician': {
        'email': 'technician@qauto.com',
        'password': 'demo123',
        'role': 'technician',
        'name': 'Demo Technician',
        'department': 'Maintenance',
      },
      'requestor': {
        'email': 'requestor@qauto.com',
        'password': 'demo123',
        'role': 'requestor',
        'name': 'Demo Requestor',
        'department': 'Operations',
      },
    };
  }

  /// Check if a user exists in demo users
  static bool isDemoUser(String email, String password) {
    if (!isDemoMode) return false;

    return demoUsers.values.any(
      (user) => user['email'] == email && user['password'] == password,
    );
  }

  /// Get demo user by email
  static Map<String, String>? getDemoUserByEmail(String email) {
    if (!isDemoMode) return null;

    try {
      return demoUsers.values.firstWhere(
        (user) => user['email'] == email,
      );
    } catch (e) {
      return null;
    }
  }

  /// Print configuration summary (debug only)
  static void printConfig() {
    if (!isDebugMode) return;

    print('═══════════════════════════════════════');
    print('📋 Application Configuration');
    print('═══════════════════════════════════════');
    print('Debug Mode: $isDebugMode');
    print('Demo Mode: $isDemoMode');
    print('Verbose Logging: $isVerboseLogging');
    print('API URL: $apiUrl');
    print('Supabase URL: $supabaseUrl');
    print('Offline Mode: $isOfflineModeEnabled');
    print('Analytics: $isAnalyticsEnabled');
    print('Crash Reporting: $isCrashReportingEnabled');
    print('Auto Populate Users: $autoPopulateUsers');
    print('Auto Create Users on Login: $autoCreateUsersOnLogin');
    print('Session Timeout: $sessionTimeoutMinutes min');
    print('Sync Interval: $syncIntervalSeconds sec');
    print('Max Upload Size: $maxFileUploadSizeMB MB');
    if (isDemoMode) {
      print('Demo Users Available: ${demoUsers.length}');
    }
    print('═══════════════════════════════════════');
  }
}
