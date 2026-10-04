/// Client-side bootstrap policy for CMMS app startup.

/// Whether a failed Supabase bootstrap should abort app launch.
///
/// Release builds must not run with a broken backend client; debug builds may
/// continue so local tooling can still inspect UI without credentials.
bool shouldRethrowSupabaseBootstrapFailure({required bool isReleaseMode}) {
  return isReleaseMode;
}

/// Whether release builds must abort when legal/support dart-defines are missing.
bool shouldRethrowMissingLegalConfig({
  required bool isReleaseMode,
  required bool hasValidLegalConfig,
}) {
  return isReleaseMode && !hasValidLegalConfig;
}

const String kMissingLegalConfigBootstrapError =
    'Missing PRIVACY_POLICY_URL, SUPPORT_URL, or SUPPORT_EMAIL. '
    'Pass all via --dart-define for release builds.';

const String kMissingLegalConfigUserMessage =
    'This app build is missing required privacy and support information. '
    'Please reinstall from the official store or contact support.';

/// Maps bootstrap exceptions to user-safe startup screen copy.
String bootstrapFailureUserMessage(Object error) {
  final text = error.toString();
  if (text.contains('PRIVACY_POLICY_URL') ||
      text.contains('SUPPORT_URL') ||
      text.contains('SUPPORT_EMAIL')) {
    return kMissingLegalConfigUserMessage;
  }
  return kBootstrapConnectionFailureUserMessage;
}

const String kBootstrapConnectionFailureUserMessage =
    'Unable to connect to Be Electric services. '
    'Please check your network connection and try again, '
    'or contact support if the problem continues.';
