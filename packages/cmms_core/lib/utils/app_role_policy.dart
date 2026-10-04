import '../config/cmms_app_mode.dart';

/// Whether a database role may use the given store binary.
bool isRoleAllowedForAppMode({
  required String role,
  required CmmsAppMode appMode,
}) {
  final normalized = role.trim().toLowerCase();
  switch (appMode) {
    case CmmsAppMode.requestor:
      return normalized == 'requestor';
    case CmmsAppMode.technician:
      // Requestor accounts must use the requestor binary; other roles may
      // route to technician/admin/dashboard screens downstream.
      return normalized != 'requestor';
  }
}

/// User-facing copy when [isRoleAllowedForAppMode] is false.
String wrongAppRoleMessage({
  required String role,
  required CmmsAppMode appMode,
}) {
  final normalized = role.trim().toLowerCase();

  switch (appMode) {
    case CmmsAppMode.requestor:
      return 'This account ($role) is not for the requestor app. '
          'Install the technician app, or use a requestor account.';
    case CmmsAppMode.technician:
      if (normalized == 'requestor') {
        return 'This is a requestor account. Open the requestor app to create maintenance requests.';
      }
      return 'This account ($role) is not supported in the technician app.';
  }
}
