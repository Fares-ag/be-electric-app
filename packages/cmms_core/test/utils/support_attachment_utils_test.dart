import 'package:flutter_test/flutter_test.dart';

import 'package:cmms_core/utils/support_attachment_utils.dart';

void main() {
  group('supportAttachmentKindForUrl', () {
    test('detects common image extensions', () {
      expect(
        supportAttachmentKindForUrl(
          'https://example.com/storage/photo.JPG',
        ),
        SupportAttachmentKind.image,
      );
      expect(
        supportAttachmentKindForUrl(
          'https://example.com/storage/scan.png?token=abc',
        ),
        SupportAttachmentKind.image,
      );
    });

    test('detects pdf', () {
      expect(
        supportAttachmentKindForUrl(
          'https://example.com/files/manual.pdf',
        ),
        SupportAttachmentKind.pdf,
      );
    });

    test('treats office documents as other', () {
      expect(
        supportAttachmentKindForUrl(
          'https://example.com/files/spec.docx',
        ),
        SupportAttachmentKind.other,
      );
    });
  });

  test('supportAttachmentFileName decodes path segment', () {
    expect(
      supportAttachmentFileName(
        'https://example.com/files/my%20file.pdf',
        fallbackIndex: 0,
      ),
      'my file.pdf',
    );
  });
}
