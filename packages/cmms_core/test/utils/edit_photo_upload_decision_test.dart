import 'package:cmms_core/utils/edit_photo_upload_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluateEditPhotoUpload', () {
    test('no new photos — save changes', () {
      final decision = evaluateEditPhotoUpload(
        newPhotoCount: 0,
        uploadedCount: 0,
        failCount: 0,
      );

      expect(decision.shouldSaveChanges, isTrue);
      expect(decision.partialSuccessMessage, isNull);
      expect(decision.allNewPhotosFailedMessage, isNull);
    });

    test('all new uploads fail — still save with warning', () {
      final decision = evaluateEditPhotoUpload(
        newPhotoCount: 2,
        uploadedCount: 0,
        failCount: 2,
      );

      expect(decision.shouldSaveChanges, isTrue);
      expect(decision.allNewPhotosFailedMessage, isNotNull);
      expect(decision.partialSuccessMessage, isNull);
    });

    test('partial success — save with count message', () {
      final decision = evaluateEditPhotoUpload(
        newPhotoCount: 4,
        uploadedCount: 2,
        failCount: 2,
      );

      expect(decision.shouldSaveChanges, isTrue);
      expect(
        decision.partialSuccessMessage,
        'Request updated successfully. 2 of 4 new photos were attached.',
      );
    });

    test('full success — save without extra message', () {
      final decision = evaluateEditPhotoUpload(
        newPhotoCount: 1,
        uploadedCount: 1,
        failCount: 0,
      );

      expect(decision.shouldSaveChanges, isTrue);
      expect(decision.partialSuccessMessage, isNull);
      expect(decision.allNewPhotosFailedMessage, isNull);
    });
  });
}
