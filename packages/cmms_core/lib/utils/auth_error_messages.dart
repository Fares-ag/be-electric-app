// User-facing auth error strings. Log exception details via [userFacingErrorMessage].

import 'user_facing_errors.dart';

const String kGenericLoginErrorMessage =
    'Sign-in failed. Check your email and password, or contact your administrator.';

const String kGenericPasswordResetErrorMessage =
    'Could not send a reset link. Please try again later.';

/// Returns a safe message for auth UI surfaces and logs the underlying error.
String userFacingAuthErrorMessage(
  Object error, {
  required String genericMessage,
  StackTrace? stackTrace,
  String? contextLabel,
}) =>
    userFacingErrorMessage(
      error,
      genericMessage: genericMessage,
      stackTrace: stackTrace,
      contextLabel: contextLabel ?? 'Auth',
    );
