import 'package:cmms_core/providers/cmms_provider_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  group('Cmms realtime lifecycle', () {
    test('cancelAllRealtimeListeners completes without error', () async {
      final bundle = CmmsProviderBundle.forTesting(autoStart: false);
      addTearDown(bundle.dispose);

      await bundle.coordinator.cancelAllRealtimeListeners();
    });

    test('provider bundle dispose tears down coordinator and providers', () {
      final bundle = CmmsProviderBundle.forTesting(autoStart: false);

      expect(() => bundle.dispose(), returnsNormally);
    });
  });
}
