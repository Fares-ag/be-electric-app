import 'package:cmms_core/utils/offline_service_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldEnqueueOfflineMutation', () {
    test('OFFLINE_MODE false never enqueues', () {
      expect(
        shouldEnqueueOfflineMutation(
          offlineModeEnabled: false,
          isOnline: false,
        ),
        isFalse,
      );
      expect(
        shouldEnqueueOfflineMutation(
          offlineModeEnabled: false,
          isOnline: true,
          caughtError: Exception('SocketException'),
        ),
        isFalse,
      );
    });

    test('offline device enqueues when mode enabled', () {
      expect(
        shouldEnqueueOfflineMutation(
          offlineModeEnabled: true,
          isOnline: false,
        ),
        isTrue,
      );
    });

    test('online enqueues only on network errors', () {
      expect(
        shouldEnqueueOfflineMutation(
          offlineModeEnabled: true,
          isOnline: true,
          caughtError: Exception('SocketException: failed'),
        ),
        isTrue,
      );
      expect(
        shouldEnqueueOfflineMutation(
          offlineModeEnabled: true,
          isOnline: true,
          caughtError: Exception('RLS policy'),
        ),
        isFalse,
      );
      expect(
        shouldEnqueueOfflineMutation(
          offlineModeEnabled: true,
          isOnline: true,
        ),
        isFalse,
      );
    });
  });
}
