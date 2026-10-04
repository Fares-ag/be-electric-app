import 'package:cmms_core/utils/offline_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local photo path strip helpers', () {
    test('collectLocalPhotoPaths keeps only filesystem paths', () {
      final paths = collectLocalPhotoPaths(
        completionPhotoPaths: [
          '/tmp/local.jpg',
          'https://cdn.example/remote.jpg',
        ],
        completionPhotoPath: '/tmp/other.jpg',
      );
      expect(paths, ['/tmp/local.jpg', '/tmp/other.jpg']);
    });

    test('isLocalFilePath rejects remote urls', () {
      expect(isLocalFilePath('https://x/a.jpg'), isFalse);
      expect(isLocalFilePath('/data/user/0/a.jpg'), isTrue);
    });
  });
}
