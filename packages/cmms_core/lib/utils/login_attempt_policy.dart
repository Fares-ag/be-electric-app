import 'security_utils.dart';

/// Minimum wait between sign-in attempts for the same email (client-side).
const Duration kLoginAttemptCooldown = Duration(seconds: 2);

const String kLoginRateLimitedMessage =
    'Too many sign-in attempts. Please wait a moment and try again.';

String loginRateLimitKey(String email) =>
    'login:${email.trim().toLowerCase()}';

bool isLoginAttemptRateLimited(String email) {
  return SecurityUtils.isRateLimited(
    loginRateLimitKey(email),
    kLoginAttemptCooldown,
  );
}

void clearLoginRateLimit(String email) {
  SecurityUtils.clearRateLimit(loginRateLimitKey(email));
}

/// Validates login email using shared [SecurityUtils] rules.
String? validateLoginEmail(String email) {
  return SecurityUtils.getEmailError(email.trim());
}
