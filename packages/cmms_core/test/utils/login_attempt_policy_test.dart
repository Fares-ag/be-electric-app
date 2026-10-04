import 'package:cmms_core/utils/login_attempt_policy.dart';
import 'package:cmms_core/utils/security_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(SecurityUtils.clearAllRateLimits);

  group('isLoginAttemptRateLimited', () {
    test('blocks immediate repeat attempts for same email', () {
      const email = 'user@example.com';

      expect(isLoginAttemptRateLimited(email), isFalse);
      expect(isLoginAttemptRateLimited(email), isTrue);
    });

    test('does not block different emails', () {
      expect(isLoginAttemptRateLimited('a@example.com'), isFalse);
      expect(isLoginAttemptRateLimited('b@example.com'), isFalse);
    });

    test('clearLoginRateLimit resets cooldown', () {
      const email = 'reset@example.com';

      isLoginAttemptRateLimited(email);
      expect(isLoginAttemptRateLimited(email), isTrue);

      clearLoginRateLimit(email);
      expect(isLoginAttemptRateLimited(email), isFalse);
    });
  });

  group('validateLoginEmail', () {
    test('accepts valid email', () {
      expect(validateLoginEmail('user@example.com'), isNull);
    });

    test('rejects invalid email format', () {
      expect(validateLoginEmail('not-an-email'), isNotNull);
    });

    test('rejects empty email', () {
      expect(validateLoginEmail(''), isNotNull);
    });
  });
}
