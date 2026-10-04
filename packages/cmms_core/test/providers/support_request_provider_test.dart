import 'package:flutter_test/flutter_test.dart';

import 'package:cmms_core/models/support_request.dart';
import 'package:cmms_core/providers/support_request_provider.dart';
import 'package:cmms_core/services/support_request_service.dart';

import '../support/fake_support_request_repository.dart';

void main() {
  group('SupportRequestProvider.loadSupportRequests', () {
    late FakeSupportRequestRepository repository;
    late SupportRequestProvider provider;

    setUp(() {
      repository = FakeSupportRequestRepository();
      provider = SupportRequestProvider(
        service: SupportRequestService(repository: repository),
      );
    });

    test('loads requests and clears loading state', () async {
      repository.requests = [
        SupportRequest.create(
          type: SupportRequestType.knowHow,
          createdBy: 'user-1',
          topic: 'Firmware',
          question: 'How do I update?',
        ),
      ];

      expect(provider.isLoadingRequests, isFalse);
      expect(provider.hasLoadedRequests, isFalse);

      final loadFuture = provider.loadSupportRequests('user-1');
      expect(provider.isLoadingRequests, isTrue);
      await loadFuture;

      expect(provider.isLoadingRequests, isFalse);
      expect(provider.hasLoadedRequests, isTrue);
      expect(provider.hasRequests, isTrue);
      expect(provider.requests, hasLength(1));
      expect(provider.requests.first.topic, 'Firmware');
    });

    test('supports empty list', () async {
      await provider.loadSupportRequests('user-1');

      expect(provider.hasLoadedRequests, isTrue);
      expect(provider.hasRequests, isFalse);
      expect(provider.requests, isEmpty);
    });

    test('propagates repository errors', () async {
      repository.loadError = Exception('Failed to load support requests');

      await expectLater(
        provider.loadSupportRequests('user-1'),
        throwsA(isA<Exception>()),
      );
      expect(provider.isLoadingRequests, isFalse);
    });
  });
}
