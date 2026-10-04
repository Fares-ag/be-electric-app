import 'package:cmms_core/config/cmms_app_mode.dart';
import 'package:cmms_core/utils/app_role_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isRoleAllowedForAppMode', () {
    test('requestor app allows requestor role only', () {
      expect(
        isRoleAllowedForAppMode(
          role: 'requestor',
          appMode: CmmsAppMode.requestor,
        ),
        isTrue,
      );
      expect(
        isRoleAllowedForAppMode(
          role: 'technician',
          appMode: CmmsAppMode.requestor,
        ),
        isFalse,
      );
    });

    test('technician app blocks requestor role only', () {
      expect(
        isRoleAllowedForAppMode(
          role: 'requestor',
          appMode: CmmsAppMode.technician,
        ),
        isFalse,
      );
      for (final role in ['technician', 'manager', 'admin', 'supervisor']) {
        expect(
          isRoleAllowedForAppMode(
            role: role,
            appMode: CmmsAppMode.technician,
          ),
          isTrue,
          reason: role,
        );
      }
    });
  });

  group('wrongAppRoleMessage', () {
    test('requestor app message mentions technician app', () {
      final message = wrongAppRoleMessage(
        role: 'technician',
        appMode: CmmsAppMode.requestor,
      );

      expect(message, contains('requestor app'));
      expect(message, contains('technician'));
    });

    test('technician app message for requestor account', () {
      final message = wrongAppRoleMessage(
        role: 'requestor',
        appMode: CmmsAppMode.technician,
      );

      expect(message, contains('requestor app'));
    });
  });
}
