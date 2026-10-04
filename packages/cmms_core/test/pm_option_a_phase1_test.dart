import 'package:cmms_core/config/app_config.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_schedule.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/pm_work_item.dart';
import 'package:cmms_core/services/pm_occurrence_service.dart';
import 'package:cmms_core/utils/pm_occurrence_display_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_pm_occurrence_repository.dart';

void main() {
  group('deriveOccurrenceDisplayStatus', () {
    final reference = DateTime(2026, 6, 25);

    test('returns completed for stored completed', () {
      expect(
        deriveOccurrenceDisplayStatus(
          storedStatus: 'completed',
          dueDate: DateTime(2026, 1, 1),
          referenceDate: reference,
        ),
        PmOccurrenceDisplayStatus.completed,
      );
    });

    test('returns cancelled for stored cancelled', () {
      expect(
        deriveOccurrenceDisplayStatus(
          storedStatus: 'cancelled',
          dueDate: DateTime(2026, 1, 1),
          referenceDate: reference,
        ),
        PmOccurrenceDisplayStatus.cancelled,
      );
    });

    test('returns overdue when pending and due date is before today', () {
      expect(
        deriveOccurrenceDisplayStatus(
          storedStatus: 'pending',
          dueDate: DateTime(2026, 6, 24),
          referenceDate: reference,
        ),
        PmOccurrenceDisplayStatus.overdue,
      );
    });

    test('returns upcoming when pending and due today or later', () {
      expect(
        deriveOccurrenceDisplayStatus(
          storedStatus: 'pending',
          dueDate: DateTime(2026, 6, 25),
          referenceDate: reference,
        ),
        PmOccurrenceDisplayStatus.upcoming,
      );
      expect(
        deriveOccurrenceDisplayStatus(
          storedStatus: 'pending',
          dueDate: DateTime(2026, 7, 1),
          referenceDate: reference,
        ),
        PmOccurrenceDisplayStatus.upcoming,
      );
    });
  });

  group('PmOccurrence', () {
    test('fromMap parses nested schedule, asset, and DateTime values', () {
      final dueDate = DateTime.utc(2026, 7, 1);
      final createdAt = DateTime.utc(2026, 6, 1, 12);

      final occurrence = PmOccurrence.fromMap({
        'id': 'occ-1',
        'scheduleId': 'sched-1',
        'assetId': 'asset-1',
        'dueDate': dueDate,
        'status': 'pending',
        'assignedTechnicianIds': const ['tech-1'],
        'createdAt': createdAt,
        'updatedAt': createdAt,
        'schedule': {
          'id': 'sched-1',
          'taskName': 'Quarterly inspection',
          'description': 'Inspect charger',
          'frequency': 'quarterly',
          'frequencyValue': 90,
          'scheduleStartDate': DateTime.utc(2026, 1, 1),
          'scheduleEndDate': DateTime.utc(2026, 12, 31),
          'metadata': {
            'checklist': const ['Visual check', 'Cable test'],
          },
          'createdAt': createdAt,
          'updatedAt': createdAt,
        },
        'asset': {
          'name': 'Charger A',
          'location': 'Bay 1',
          'manufacturer': 'Siemens',
          'model': 'Sicharge D',
          'serialNumber': 'SN-001',
        },
      });

      expect(occurrence.taskName, 'Quarterly inspection');
      expect(occurrence.checklist, ['Visual check', 'Cable test']);
      expect(occurrence.assetName, 'Charger A');
      expect(occurrence.dueDate, dueDate);
      expect(
        occurrence.displayStatus(referenceDate: DateTime.utc(2026, 6, 25)),
        PmOccurrenceDisplayStatus.upcoming,
      );
    });

    test('completionPhotoReference resolves storage path to public URL', () {
      final occurrence = PmOccurrence.fromMap({
        'id': 'occ-1',
        'scheduleId': 'sched-1',
        'assetId': 'asset-1',
        'dueDate': DateTime.utc(2026, 7, 1),
        'status': 'completed',
        'createdAt': DateTime.utc(2026, 6, 1),
        'updatedAt': DateTime.utc(2026, 6, 1),
        'completionPhotoPath':
            'pm_occurrences/occ-1/completion/12345_photo.jpg',
      });

      expect(
        occurrence.completionPhotoReference,
        contains('pm_occurrences/occ-1/completion/12345_photo.jpg'),
      );
    });
  });

  group('PmSchedule', () {
    test('checklist reads metadata.checklist', () {
      final schedule = PmSchedule.fromMap({
        'id': 'sched-1',
        'taskName': 'Monthly PM',
        'frequency': 'monthly',
        'frequencyValue': 30,
        'scheduleStartDate': DateTime.utc(2026, 1, 1),
        'scheduleEndDate': DateTime.utc(2026, 12, 31),
        'metadata': {
          'checklist': const ['Step 1', 'Step 2'],
        },
        'createdAt': DateTime.utc(2026, 1, 1),
        'updatedAt': DateTime.utc(2026, 1, 1),
      });

      expect(schedule.checklist, ['Step 1', 'Step 2']);
    });
  });

  group('PmWorkItem', () {
    test('mergeAndSort combines legacy tasks and occurrences by due date', () {
      final legacy = PMTask(
        id: 'legacy-1',
        taskName: 'Legacy task',
        description: 'Legacy',
        frequency: PMTaskFrequency.monthly,
        intervalDays: 30,
        createdAt: DateTime.utc(2026, 1, 1),
        nextDueDate: DateTime.utc(2026, 6, 30),
      );
      final occurrence = PmOccurrence.fromMap({
        'id': 'occ-1',
        'scheduleId': 'sched-1',
        'assetId': 'asset-1',
        'dueDate': DateTime.utc(2026, 6, 20),
        'status': 'pending',
        'createdAt': DateTime.utc(2026, 1, 1),
        'updatedAt': DateTime.utc(2026, 1, 1),
        'schedule': {
          'id': 'sched-1',
          'taskName': 'Occurrence task',
          'frequency': 'monthly',
          'frequencyValue': 30,
          'scheduleStartDate': DateTime.utc(2026, 1, 1),
          'scheduleEndDate': DateTime.utc(2026, 12, 31),
          'createdAt': DateTime.utc(2026, 1, 1),
          'updatedAt': DateTime.utc(2026, 1, 1),
        },
      });

      final merged = PmWorkItem.mergeAndSort(
        legacyTasks: [legacy],
        occurrences: [occurrence],
        referenceDate: DateTime.utc(2026, 6, 25),
      );

      expect(merged, hasLength(2));
      expect(merged.first.isOccurrence, isTrue);
      expect(merged.last.isLegacy, isTrue);
    });
  });

  group('PmOccurrenceService', () {
    test('returns empty results when feature flag is disabled', () async {
      final repository = FakePmOccurrenceRepository(
        occurrences: [
          PmOccurrence.fromMap({
            'id': 'occ-1',
            'scheduleId': 'sched-1',
            'assetId': 'asset-1',
            'dueDate': DateTime.utc(2026, 6, 20),
            'status': 'pending',
            'createdAt': DateTime.utc(2026, 1, 1),
            'updatedAt': DateTime.utc(2026, 1, 1),
          }),
        ],
      );
      final service = PmOccurrenceService(repository: repository);

      expect(AppConfig.enablePmOccurrences, isFalse);
      final results = await service.getAssignedOccurrences('tech-1');
      expect(results, isEmpty);
    });

    test('does not call repository when feature flag is disabled', () async {
      final repository = FakePmOccurrenceRepository(
        occurrences: [
          PmOccurrence.fromMap({
            'id': 'occ-1',
            'scheduleId': 'sched-1',
            'assetId': 'asset-1',
            'dueDate': DateTime.utc(2026, 6, 20),
            'status': 'pending',
            'createdAt': DateTime.utc(2026, 1, 1),
            'updatedAt': DateTime.utc(2026, 1, 1),
          }),
        ],
        schedules: [
          PmSchedule.fromMap({
            'id': 'sched-1',
            'taskName': 'Monthly PM',
            'frequency': 'monthly',
            'frequencyValue': 30,
            'scheduleStartDate': DateTime.utc(2026, 1, 1),
            'scheduleEndDate': DateTime.utc(2026, 12, 31),
            'createdAt': DateTime.utc(2026, 1, 1),
            'updatedAt': DateTime.utc(2026, 1, 1),
          }),
        ],
      );
      final service = PmOccurrenceService(repository: repository);

      expect(AppConfig.enablePmOccurrences, isFalse);

      await service.getAssignedOccurrences('tech-1');
      await service.getOccurrenceById('occ-1');
      await service.queryOccurrences(companyId: 'company-1');
      await service.querySchedules(companyId: 'company-1');
      await service.getScheduleById('sched-1');

      expect(repository.totalCalls, 0);
    });
  });

  group('Phase 1 legacy compatibility', () {
    test('feature flag defaults off so legacy PM path remains primary', () {
      expect(AppConfig.enablePmOccurrences, isFalse);
    });

    test('PmOccurrenceService is separate from WorkOrderRepository surface', () {
      final service = PmOccurrenceService(
        repository: FakePmOccurrenceRepository(),
      );
      expect(service.isEnabled, isFalse);
    });
  });
}
