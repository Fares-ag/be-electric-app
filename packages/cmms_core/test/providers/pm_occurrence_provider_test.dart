import 'package:cmms_core/config/app_config.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pm_occurrence_service.dart';

PmOccurrence _sampleOccurrence() => PmOccurrence.fromMap({
      'id': 'occ-1',
      'scheduleId': 'sched-1',
      'assetId': 'asset-1',
      'dueDate': DateTime.utc(2026, 6, 20),
    });

void main() {
  group('PmOccurrenceProvider initial state', () {
    test('starts empty and not loading', () {
      final provider = PmOccurrenceProvider(
        service: FakePmOccurrenceService(),
      );

      expect(provider.isLoading, isFalse);
      expect(provider.hasLoaded, isFalse);
      expect(provider.hasError, isFalse);
      expect(provider.occurrences, isEmpty);
      expect(provider.isEnabled, isFalse);
    });
  });

  group('PmOccurrenceProvider feature flag OFF', () {
    test('does not call service and returns empty list', () async {
      final service = FakePmOccurrenceService(
        assignedOccurrences: [_sampleOccurrence()],
      );
      final provider = PmOccurrenceProvider(service: service);

      expect(AppConfig.enablePmOccurrences, isFalse);
      expect(provider.isEnabled, isFalse);

      await provider.loadAssignedOccurrences('tech-1');

      expect(service.getAssignedOccurrencesCalls, 0);
      expect(provider.occurrences, isEmpty);
      expect(provider.hasLoaded, isTrue);
      expect(provider.hasError, isFalse);
      expect(provider.isLoading, isFalse);
    });
  });

  group('PmOccurrenceProvider feature flag ON', () {
    late FakePmOccurrenceService service;
    late PmOccurrenceProvider provider;

    setUp(() {
      service = FakePmOccurrenceService(enabled: true);
      provider = PmOccurrenceProvider(service: service);
    });

    test('loads occurrences through service', () async {
      service.assignedOccurrences = [_sampleOccurrence()];

      expect(provider.isLoading, isFalse);
      final loadFuture = provider.loadAssignedOccurrences('tech-1');
      expect(provider.isLoading, isTrue);
      await loadFuture;

      expect(service.getAssignedOccurrencesCalls, 1);
      expect(provider.isLoading, isFalse);
      expect(provider.hasLoaded, isTrue);
      expect(provider.hasError, isFalse);
      expect(provider.occurrences, hasLength(1));
      expect(provider.occurrences.first.id, 'occ-1');
      expect(provider.isEnabled, isTrue);
    });

    test('refresh reloads occurrences', () async {
      service.assignedOccurrences = [_sampleOccurrence()];

      await provider.loadAssignedOccurrences('tech-1');
      await provider.refreshAssignedOccurrences('tech-1');

      expect(service.getAssignedOccurrencesCalls, 2);
      expect(provider.occurrences, hasLength(1));
    });

    test('loads company occurrences for requestor visibility', () async {
      service.queryResults = [_sampleOccurrence()];

      await provider.loadCompanyOccurrences('company-1');

      expect(service.queryOccurrencesCalls, 1);
      expect(provider.occurrences, hasLength(1));
      expect(provider.hasLoaded, isTrue);
    });

    test('confirmOccurrenceForRequestor updates local occurrence', () async {
      service.queryResults = [_sampleOccurrence()];
      await provider.loadCompanyOccurrences('company-1');

      await provider.confirmOccurrenceForRequestor(
        occurrenceId: 'occ-1',
        requestorId: 'requestor-1',
      );

      expect(service.confirmOccurrenceForRequestorCalls, 1);
      expect(provider.occurrences.first.isRequestorConfirmed, isTrue);
      expect(provider.occurrences.first.requestorConfirmedById, 'requestor-1');
    });
  });

  group('PmOccurrenceProvider loading failure', () {
    test('captures error and clears occurrences', () async {
      final service = FakePmOccurrenceService(
        enabled: true,
        assignedError: Exception('Failed to load occurrences'),
      );
      final provider = PmOccurrenceProvider(service: service);

      await provider.loadAssignedOccurrences('tech-1');

      expect(service.getAssignedOccurrencesCalls, 1);
      expect(provider.isLoading, isFalse);
      expect(provider.hasLoaded, isTrue);
      expect(provider.hasError, isTrue);
      expect(provider.errorMessage, contains('Failed to load occurrences'));
      expect(provider.occurrences, isEmpty);
    });
  });

  group('PmOccurrenceProvider clear', () {
    test('reset clears loaded state and collection', () async {
      final service = FakePmOccurrenceService(
        enabled: true,
        assignedOccurrences: [_sampleOccurrence()],
      );
      final provider = PmOccurrenceProvider(service: service);

      await provider.loadAssignedOccurrences('tech-1');
      expect(provider.hasOccurrences, isTrue);

      provider.clear();

      expect(provider.occurrences, isEmpty);
      expect(provider.hasLoaded, isFalse);
      expect(provider.hasError, isFalse);
      expect(provider.isLoading, isFalse);
    });
  });
}
