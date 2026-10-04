import 'package:cmms_core/utils/auth_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userFacingAuthErrorMessage', () {
    test('returns generic login message without exception text', () {
      expect(
        userFacingAuthErrorMessage(
          StateError('Invalid login credentials from supabase'),
          genericMessage: kGenericLoginErrorMessage,
        ),
        kGenericLoginErrorMessage,
      );
    });

    test('returns generic password reset message without exception text', () {
      expect(
        userFacingAuthErrorMessage(
          Exception('SMTP timeout'),
          genericMessage: kGenericPasswordResetErrorMessage,
        ),
        kGenericPasswordResetErrorMessage,
      );
    });
  });
}
