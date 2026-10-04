import 'package:cmms_core/utils/offline_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLikelyNetworkError', () {
    test('detects common network failure strings', () {
      expect(isLikelyNetworkError(Exception('SocketException: failed')), isTrue);
      expect(isLikelyNetworkError('ClientException: Connection refused'), isTrue);
      expect(isLikelyNetworkError('failed host lookup'), isTrue);
      expect(isLikelyNetworkError('timed out'), isTrue);
    });

    test('ignores non-network errors', () {
      expect(isLikelyNetworkError(Exception('RLS policy violation')), isFalse);
      expect(isLikelyNetworkError('duplicate key value'), isFalse);
    });
  });

  group('isLocalFilePath', () {
    test('accepts filesystem paths', () {
      expect(isLocalFilePath('/var/mobile/Containers/photo.jpg'), isTrue);
      expect(isLocalFilePath('file:///tmp/a.jpg'), isTrue);
    });

    test('rejects remote urls', () {
      expect(isLocalFilePath('https://cdn.example/a.jpg'), isFalse);
      expect(isLocalFilePath('http://cdn.example/a.jpg'), isFalse);
      expect(isLocalFilePath(null), isFalse);
      expect(isLocalFilePath(''), isFalse);
    });
  });

  group('collectLocalPhotoPaths', () {
    test('collects only local paths and dedupes', () {
      final paths = collectLocalPhotoPaths(
        completionPhotoPaths: [
          '/tmp/a.jpg',
          'https://cdn.example/b.jpg',
          '/tmp/a.jpg',
        ],
        completionPhotoPath: '/tmp/c.jpg',
      );
      expect(paths, ['/tmp/a.jpg', '/tmp/c.jpg']);
    });
  });
}
