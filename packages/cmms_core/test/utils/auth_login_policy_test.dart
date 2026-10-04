import 'package:flutter_test/flutter_test.dart';
import 'package:cmms_core/utils/auth_login_policy.dart';

void main() {
  group('resolveAuthProfileRole', () {
    test('returns userMetadata role when present', () {
      expect(
        resolveAuthProfileRole(
          userMetadataRole: 'technician',
          appMetadataRole: 'admin',
        ),
        'technician',
      );
    });

    test('falls back to appMetadata role', () {
      expect(
        resolveAuthProfileRole(
          userMetadataRole: null,
          appMetadataRole: 'requestor',
        ),
        'requestor',
      );
    });

    test('defaults to requestor when metadata missing', () {
      expect(
        resolveAuthProfileRole(
          userMetadataRole: null,
          appMetadataRole: null,
        ),
        kDefaultAuthProfileRole,
      );
    });

    test('does not infer admin from email-like metadata values', () {
      // Regression for C3: email substrings must not be used upstream.
      expect(
        resolveAuthProfileRole(
          userMetadataRole: null,
          appMetadataRole: null,
        ),
        isNot('admin'),
      );
    });

    test('trims whitespace from metadata role', () {
      expect(
        resolveAuthProfileRole(
          userMetadataRole: '  requestor  ',
          appMetadataRole: null,
        ),
        'requestor',
      );
    });
  });

  group('shouldAutoCreateUserOnLogin', () {
    test('allows create only when flag enabled', () {
      expect(
        shouldAutoCreateUserOnLogin(autoCreateUsersOnLogin: true),
        isTrue,
      );
      expect(
        shouldAutoCreateUserOnLogin(autoCreateUsersOnLogin: false),
        isFalse,
      );
    });
  });

  group('isSessionAuthorized', () {
    test('requires database user row', () {
      expect(isSessionAuthorized(hasDatabaseUser: true), isTrue);
      expect(isSessionAuthorized(hasDatabaseUser: false), isFalse);
    });
  });

  group('kAutoCreatedUserRole', () {
    test('never assigns admin on auto-create', () {
      expect(kAutoCreatedUserRole, 'requestor');
      expect(kAutoCreatedUserRole, isNot('admin'));
    });
  });

  group('debug auth fallbacks', () {
    test('local session restore blocked in release', () {
      expect(shouldAllowLocalSessionRestore(isReleaseMode: true), isFalse);
      expect(shouldAllowLocalSessionRestore(isReleaseMode: false), isTrue);
    });

    test('passwordless database auth requires debug non-release', () {
      expect(
        shouldAllowDebugDatabaseAuth(
          isReleaseMode: false,
          isDebugMode: true,
        ),
        isTrue,
      );
      expect(
        shouldAllowDebugDatabaseAuth(
          isReleaseMode: true,
          isDebugMode: false,
        ),
        isFalse,
      );
      expect(
        shouldAllowDebugDatabaseAuth(
          isReleaseMode: false,
          isDebugMode: false,
        ),
        isFalse,
      );
    });

    test('demo user fallback requires demo mode flag', () {
      expect(shouldAllowDemoUserFallback(isDemoMode: true), isTrue);
      expect(shouldAllowDemoUserFallback(isDemoMode: false), isFalse);
    });
  });
}
