import 'package:cmms_core/utils/requestor_submit_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration/support/requestor_fixtures.dart';

void main() {
  group('evaluateRequestorSubmitReadiness', () {
    test('pre-upload rejects unauthenticated submitter', () {
      final readiness = evaluateRequestorSubmitPreUpload(user: null);

      expect(readiness.canProceed, isFalse);
      expect(readiness.dialogTitle, 'Sign in required');
    });

    test('post-upload accepts no-photo submit with registered asset', () {
      final readiness = evaluateRequestorSubmitPostUpload(
        asset: RequestorIntegrationFixtures.registeredCharger(),
        selectedPhotoCount: 0,
        uploadedCount: 0,
        failCount: 0,
      );

      expect(readiness.canProceed, isTrue);
      expect(readiness.partialPhotoMessage, isNull);
    });

    test('app access rejects technician in requestor binary', () {
      final readiness = evaluateRequestorAppAccess(
        user: RequestorIntegrationFixtures.technicianAccount(),
      );

      expect(readiness.canProceed, isFalse);
    });
  });
}
