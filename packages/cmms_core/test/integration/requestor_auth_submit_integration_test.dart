import 'package:cmms_core/utils/login_attempt_policy.dart';
import 'package:cmms_core/utils/requestor_category_mapper.dart';
import 'package:cmms_core/utils/requestor_submit_readiness.dart';
import 'package:cmms_core/utils/security_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/requestor_fixtures.dart';

void main() {
  tearDown(SecurityUtils.clearAllRateLimits);

  group('Requestor auth integration', () {
    test('linked requestor passes app access gate', () {
      final readiness = evaluateRequestorAppAccess(
        user: RequestorIntegrationFixtures.linkedRequestor(),
      );

      expect(readiness.canProceed, isTrue);
    });

    test('technician account is blocked from requestor app shell', () {
      final readiness = evaluateRequestorAppAccess(
        user: RequestorIntegrationFixtures.technicianAccount(),
      );

      expect(readiness.canProceed, isFalse);
      expect(readiness.dialogMessage, contains('requestor app'));
    });

    test('login email validation rejects malformed addresses', () {
      expect(validateLoginEmail('not-an-email'), isNotNull);
      expect(validateLoginEmail('user@example.com'), isNull);
    });

    test('login rate limit blocks rapid repeat attempts', () {
      const email = 'rate.limit@test.com';
      expect(isLoginAttemptRateLimited(email), isFalse);
      expect(isLoginAttemptRateLimited(email), isTrue);
    });
  });

  group('Requestor submit pre-upload integration', () {
    test('blocks submit when requestor has no company', () {
      final readiness = evaluateRequestorSubmitPreUpload(
        user: RequestorIntegrationFixtures.requestorWithoutCompany(),
      );

      expect(readiness.canProceed, isFalse);
      expect(readiness.dialogTitle, 'Company required');
      expect(readiness.dialogMessage, isNotNull);
    });

    test('allows submit when requestor is linked to a company', () {
      final readiness = evaluateRequestorSubmitPreUpload(
        user: RequestorIntegrationFixtures.linkedRequestor(),
      );

      expect(readiness.canProceed, isTrue);
    });
  });

  group('Requestor submit post-upload integration', () {
    test('blocks submit when all photos fail', () {
      final readiness = evaluateRequestorSubmitPostUpload(
        asset: RequestorIntegrationFixtures.registeredCharger(),
        selectedPhotoCount: 2,
        uploadedCount: 0,
        failCount: 2,
      );

      expect(readiness.canProceed, isFalse);
      expect(readiness.dialogTitle, 'Photos not uploaded');
    });

    test('blocks submit when asset is a placeholder charger', () {
      final readiness = evaluateRequestorSubmitPostUpload(
        asset: RequestorIntegrationFixtures.placeholderCharger(),
        selectedPhotoCount: 0,
        uploadedCount: 0,
        failCount: 0,
      );

      expect(readiness.canProceed, isFalse);
      expect(readiness.dialogTitle, 'Charger required');
    });

    test('allows submit with registered asset and partial photo success', () {
      final readiness = evaluateRequestorSubmitPostUpload(
        asset: RequestorIntegrationFixtures.registeredCharger(),
        selectedPhotoCount: 3,
        uploadedCount: 2,
        failCount: 1,
      );

      expect(readiness.canProceed, isTrue);
      expect(readiness.partialPhotoMessage, contains('2 of 3'));
    });

    test('maps category issue to work-order fields for submit payload', () {
      final fields = mapRequestorCategoryIssue('Electrical');

      expect(fields.category.name, 'electrical');
      expect(fields.priority.name, 'high');
    });
  });

  group('Requestor end-to-end submit readiness', () {
    test('happy path: company + asset + photos', () {
      final user = RequestorIntegrationFixtures.linkedRequestor();
      final asset = RequestorIntegrationFixtures.registeredCharger();

      final pre = evaluateRequestorSubmitPreUpload(user: user);
      expect(pre.canProceed, isTrue);

      final post = evaluateRequestorSubmitPostUpload(
        asset: asset,
        selectedPhotoCount: 1,
        uploadedCount: 1,
        failCount: 0,
      );
      expect(post.canProceed, isTrue);

      final appAccess = evaluateRequestorAppAccess(user: user);
      expect(appAccess.canProceed, isTrue);
    });

    test('failure path: missing company stops before upload phase', () {
      final user = RequestorIntegrationFixtures.requestorWithoutCompany();

      final pre = evaluateRequestorSubmitPreUpload(user: user);
      expect(pre.canProceed, isFalse);

      // Post-upload should not be reached in the UI, but asset-only check still
      // passes — company gate is the early blocker for this scenario.
      final post = evaluateRequestorSubmitPostUpload(
        asset: RequestorIntegrationFixtures.registeredCharger(),
        selectedPhotoCount: 0,
        uploadedCount: 0,
        failCount: 0,
      );
      expect(post.canProceed, isTrue);
    });
  });
}
