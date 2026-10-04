import 'package:cmms_core/utils/auth_error_messages.dart';
import 'package:cmms_core/utils/user_facing_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('returns generic message without exposing exception text', () {
      final message = userFacingErrorMessage(
        StateError('RLS policy violation on users table'),
        genericMessage: 'Could not load data. Please try again.',
        contextLabel: 'Test.load',
      );

      expect(message, 'Could not load data. Please try again.');
      expect(message, isNot(contains('RLS')));
    });

    test('uses default generic message when none supplied', () {
      final message = userFacingErrorMessage(Exception('internal detail'));

      expect(message, kGenericUserErrorMessage);
      expect(message, isNot(contains('internal detail')));
    });
  });

  group('userFacingAuthErrorMessage', () {
    test('delegates to auth-specific generic copy', () {
      final message = userFacingAuthErrorMessage(
        Exception('Invalid login credentials'),
        genericMessage: kGenericLoginErrorMessage,
      );

      expect(message, kGenericLoginErrorMessage);
    });
  });
}
