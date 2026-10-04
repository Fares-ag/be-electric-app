import 'package:flutter/foundation.dart';

/// Compile-time gates for dev-only and destructive admin tooling.
///
/// Release builds hide dev menus by default. Opt in for internal QA/staging only:
/// `--dart-define=ENABLE_DEV_TOOLS=true`
/// `--dart-define=ENABLE_DESTRUCTIVE_ADMIN_TOOLS=true`
class ReleaseSafety {
  ReleaseSafety._();

  /// Diagnostics, seeding, and non-destructive maintenance tools.
  static bool get showDevTools =>
      kDebugMode || const bool.fromEnvironment('ENABLE_DEV_TOOLS');

  /// Database wipe, bulk delete, and sample-data removal.
  static bool get allowDestructiveAdminTools =>
      kDebugMode ||
      const bool.fromEnvironment('ENABLE_DESTRUCTIVE_ADMIN_TOOLS');

  /// Data seeding screens and actions.
  static bool get allowDataSeeding => showDevTools;

  static const Set<String> devToolMenuActions = {
    'seed_assets',
    'cleanup_users',
    'data_diagnostic',
    'assignment_diagnostic',
    'user_id_diagnostic',
    'performance_diagnostic',
    'orphan_cleanup_dry',
    'fix_admin',
    'duplicate_monitor',
  };

  static const Set<String> destructiveMenuActions = {
    'clear_database',
    'nuclear_option',
    'remove_sample_data',
    'cleanup_duplicates',
    'orphan_cleanup_delete',
  };

  static bool isDevToolMenuAction(String value) =>
      devToolMenuActions.contains(value);

  static bool isDestructiveMenuAction(String value) =>
      destructiveMenuActions.contains(value);
}
