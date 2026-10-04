import 'dart:io';

/// Environment helpers for optional live Supabase integration tests.
class IntegrationEnv {
  static String get supabaseUrl => Platform.environment['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey =>
      Platform.environment['SUPABASE_ANON_KEY'] ?? '';

  static String get requestorEmail =>
      Platform.environment['INTEGRATION_REQUESTOR_EMAIL'] ?? '';

  static String get requestorPassword =>
      Platform.environment['INTEGRATION_REQUESTOR_PASSWORD'] ?? '';

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasRequestorCredentials =>
      requestorEmail.isNotEmpty && requestorPassword.isNotEmpty;

  static bool get canRunLiveAuthTests =>
      hasSupabaseConfig && hasRequestorCredentials;

  static String get supabaseRestUrl =>
      hasSupabaseConfig ? '$supabaseUrl/rest/v1' : '';

  static String get supabaseAuthUrl =>
      hasSupabaseConfig ? '$supabaseUrl/auth/v1' : '';
}
