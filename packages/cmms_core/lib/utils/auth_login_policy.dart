/// Client-side auth policy helpers for login and session restore.
///
/// Roles used for in-app authorization must come from [public.users].
/// These helpers avoid email-substring role inference and first-user bootstrap.

/// Default role when Supabase Auth metadata has no explicit role.
const String kDefaultAuthProfileRole = 'requestor';

/// Role assigned when [AppConfig.autoCreateUsersOnLogin] creates a missing row.
const String kAutoCreatedUserRole = 'requestor';

/// Resolves a display/auth profile role from Supabase metadata only.
/// Never infers privileged roles from email substrings.
String resolveAuthProfileRole({
  String? userMetadataRole,
  String? appMetadataRole,
}) {
  final role = userMetadataRole ?? appMetadataRole;
  if (role != null && role.trim().isNotEmpty) {
    return role.trim();
  }
  return kDefaultAuthProfileRole;
}

/// Whether login may create a missing [public.users] row.
bool shouldAutoCreateUserOnLogin({required bool autoCreateUsersOnLogin}) {
  return autoCreateUsersOnLogin;
}

/// Session is valid only when a database user row exists.
bool isSessionAuthorized({required bool hasDatabaseUser}) {
  return hasDatabaseUser;
}

/// Whether [SharedPreferences] session restore is allowed outside Supabase Auth.
bool shouldAllowLocalSessionRestore({required bool isReleaseMode}) {
  return !isReleaseMode;
}

/// Whether passwordless database email lookup auth is allowed (debug tooling only).
bool shouldAllowDebugDatabaseAuth({
  required bool isReleaseMode,
  required bool isDebugMode,
}) {
  return !isReleaseMode && isDebugMode;
}

/// Whether hardcoded demo-user fallback login is allowed.
bool shouldAllowDemoUserFallback({required bool isDemoMode}) {
  return isDemoMode;
}
