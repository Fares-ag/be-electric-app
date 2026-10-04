import 'package:cmms_core/utils/requestor_company_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateRequestorCompanyAssignment', () {
    test('blocks requestors without companyId', () {
      final gate = validateRequestorCompanyAssignment(
        role: 'requestor',
        companyId: null,
      );

      expect(gate.allowed, isFalse);
      expect(gate.userMessage, kRequestorMissingCompanyMessage);
    });

    test('blocks requestors with blank companyId', () {
      final gate = validateRequestorCompanyAssignment(
        role: 'requestor',
        companyId: '   ',
      );

      expect(gate.allowed, isFalse);
    });

    test('allows requestors with companyId', () {
      final gate = validateRequestorCompanyAssignment(
        role: 'requestor',
        companyId: 'company-123',
      );

      expect(gate.allowed, isTrue);
      expect(gate.userMessage, isNull);
    });

    test('does not block non-requestor roles', () {
      for (final role in ['admin', 'technician', 'manager']) {
        final gate = validateRequestorCompanyAssignment(
          role: role,
          companyId: null,
        );

        expect(gate.allowed, isTrue, reason: role);
      }
    });
  });
}
