import 'package:flutter/material.dart';

import '../services/error_handling_service.dart';
import 'app_theme.dart';

/// Default message when no operation-specific copy is supplied.
const String kGenericUserErrorMessage =
    'Something went wrong. Please try again or contact support if the problem continues.';

/// Logs [error] for developers and returns a safe string for UI surfaces.
String userFacingErrorMessage(
  Object error, {
  String? genericMessage,
  StackTrace? stackTrace,
  String? contextLabel,
}) {
  final logMessage = contextLabel != null
      ? '$contextLabel: $error'
      : error.toString();
  ErrorHandlingService.logError(logMessage, stackTrace);
  return genericMessage ?? kGenericUserErrorMessage;
}

/// Shows a SnackBar with a user-safe message; logs the underlying [error].
void showUserErrorSnackBar(
  BuildContext context,
  Object error, {
  String? genericMessage,
  StackTrace? stackTrace,
  String? contextLabel,
  Color? backgroundColor,
  Duration? duration,
}) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        userFacingErrorMessage(
          error,
          genericMessage: genericMessage,
          stackTrace: stackTrace,
          contextLabel: contextLabel,
        ),
      ),
      backgroundColor: backgroundColor ?? AppTheme.accentRed,
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}
