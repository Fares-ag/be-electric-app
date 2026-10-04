import 'package:cmms_core/utils/cmms_bootstrap_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRethrowSupabaseBootstrapFailure', () {
    test('rethrows in release mode', () {
      expect(
        shouldRethrowSupabaseBootstrapFailure(isReleaseMode: true),
        isTrue,
      );
    });

    test('allows debug builds to continue without credentials', () {
      expect(
        shouldRethrowSupabaseBootstrapFailure(isReleaseMode: false),
        isFalse,
      );
    });
  });

  group('shouldRethrowMissingLegalConfig', () {
    test('rethrows in release when legal config missing', () {
      expect(
        shouldRethrowMissingLegalConfig(
          isReleaseMode: true,
          hasValidLegalConfig: false,
        ),
        isTrue,
      );
    });

    test('allows debug builds without legal config', () {
      expect(
        shouldRethrowMissingLegalConfig(
          isReleaseMode: false,
          hasValidLegalConfig: false,
        ),
        isFalse,
      );
    });

    test('allows release when legal config present', () {
      expect(
        shouldRethrowMissingLegalConfig(
          isReleaseMode: true,
          hasValidLegalConfig: true,
        ),
        isFalse,
      );
    });
  });

  group('bootstrapFailureUserMessage', () {
    test('maps missing legal config errors to user message', () {
      expect(
        bootstrapFailureUserMessage(
          StateError(kMissingLegalConfigBootstrapError),
        ),
        kMissingLegalConfigUserMessage,
      );
    });

    test('maps other errors to connection failure message', () {
      expect(
        bootstrapFailureUserMessage(
          StateError('Missing SUPABASE_URL or SUPABASE_ANON_KEY'),
        ),
        kBootstrapConnectionFailureUserMessage,
      );
    });
  });
}
