import 'package:cmms_core/config/app_config.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/services/pm_occurrence_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pm_occurrence_repository.dart';
import '../helpers/fake_pm_occurrence_service.dart';

PmOccurrence _sampleOccurrence({String id = 'occ-1'}) => PmOccurrence.fromMap({
      'id': id,
      'scheduleId': 'sched-1',
      'assetId': 'asset-1',
      'dueDate': DateTime.utc(2026, 6, 20),
      'status': 'pending',
      'createdAt': DateTime.utc(2026, 1, 1),
      'updatedAt': DateTime.utc(2026, 1, 1),
    });

class _EnabledPmOccurrenceService extends PmOccurrenceService {
  _EnabledPmOccurrenceService({required super.repository});

  @override
  bool get isEnabled => true;
}

void main() {
  group('PmOccurrenceProvider.completeOccurrence', () {
    test('feature flag OFF throws without calling service', () async {
      final service = FakePmOccurrenceService(enabled: false);
      final provider = PmOccurrenceProvider(service: service);

      await expectLater(
        () => provider.completeOccurrence(
          occurrenceId: 'occ-1',
          completedById: 'tech-1',
          completionNotes: 'Done',
        ),
        throwsStateError,
      );
      expect(service.completeOccurrenceCalls, 0);
    });

    test('success removes occurrence from provider cache', () async {
      final service = FakePmOccurrenceService(
        enabled: true,
        assignedOccurrences: [_sampleOccurrence()],
      );
      final provider = PmOccurrenceProvider(service: service);
      await provider.loadAssignedOccurrences('tech-1');

      await provider.completeOccurrence(
        occurrenceId: 'occ-1',
        completedById: 'tech-1',
        completionNotes: 'Filter replaced',
      );

      expect(service.completeOccurrenceCalls, 1);
      expect(service.lastCompletedOccurrenceId, 'occ-1');
      expect(service.lastCompletedById, 'tech-1');
      expect(service.lastCompletionNotes, 'Filter replaced');
      expect(provider.occurrences, isEmpty);
      expect(provider.isCompleting, isFalse);
    });

    test('failure rethrows and keeps occurrence in cache', () async {
      final service = FakePmOccurrenceService(
        enabled: true,
        assignedOccurrences: [_sampleOccurrence()],
        completeError: Exception('Completion failed'),
      );
      final provider = PmOccurrenceProvider(service: service);
      await provider.loadAssignedOccurrences('tech-1');

      await expectLater(
        provider.completeOccurrence(
          occurrenceId: 'occ-1',
          completedById: 'tech-1',
        ),
        throwsException,
      );

      expect(service.completeOccurrenceCalls, 1);
      expect(provider.occurrences, hasLength(1));
      expect(provider.hasError, isTrue);
    });
  });

  group('PmOccurrenceService.completeOccurrence', () {
    test('does not call repository when feature flag is disabled', () async {
      final repository = FakePmOccurrenceRepository();
      final service = PmOccurrenceService(repository: repository);

      expect(AppConfig.enablePmOccurrences, isFalse);

      await expectLater(
        service.completeOccurrence(
          occurrenceId: 'occ-1',
          completedById: 'tech-1',
        ),
        throwsStateError,
      );
      expect(repository.completeOccurrenceCalls, 0);
    });

    test('calls repository completeOccurrence exactly once when enabled', () async {
      final repository = FakePmOccurrenceRepository();
      final service = _EnabledPmOccurrenceService(repository: repository);

      await service.completeOccurrence(
        occurrenceId: 'occ-1',
        completedById: 'tech-1',
        completionNotes: 'Done',
      );

      expect(repository.completeOccurrenceCalls, 1);
      expect(repository.uploadOccurrenceCompletionPhotoCalls, 0);
      expect(repository.lastCompletedOccurrenceId, 'occ-1');
      expect(repository.lastCompletedById, 'tech-1');
      expect(repository.lastCompletionNotes, 'Done');
    });
  });
}
