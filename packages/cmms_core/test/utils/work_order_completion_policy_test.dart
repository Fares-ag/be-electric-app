import 'package:cmms_core/utils/work_order_completion_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkOrderCompletionPolicy (T-004 Option A)', () {
    test('allows submit with technician signature only', () {
      expect(
        WorkOrderCompletionPolicy.canSubmitTechnicianCompletion(
          technicianSignature: 'data:image/png;base64,abc',
        ),
        isTrue,
      );
    });

    test('blocks submit without technician signature', () {
      expect(
        WorkOrderCompletionPolicy.canSubmitTechnicianCompletion(
          technicianSignature: null,
        ),
        isFalse,
      );
      expect(
        WorkOrderCompletionPolicy.blockingMessage(
          technicianSignature: null,
        ),
        'Technician signature is required',
      );
    });

    test('does not require requestor signature on technician complete', () {
      expect(
        WorkOrderCompletionPolicy.requireRequestorSignatureOnTechnicianComplete,
        isFalse,
      );
      expect(
        WorkOrderCompletionPolicy.canSubmitTechnicianCompletion(
          technicianSignature: 'signed',
          requestorSignature: null,
        ),
        isTrue,
      );
    });
  });
}
