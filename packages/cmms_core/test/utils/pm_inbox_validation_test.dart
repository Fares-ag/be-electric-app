import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/pm_work_item.dart';
import 'package:cmms_core/utils/pm_inbox_validation.dart';
import 'package:flutter_test/flutter_test.dart';

PMTask _legacyTask({
  required String id,
  DateTime? dueDate,
}) =>
    PMTask(
      id: id,
      taskName: 'Legacy $id',
      description: 'Legacy description',
      frequency: PMTaskFrequency.monthly,
      intervalDays: 30,
      createdAt: DateTime.utc(2026, 1, 1),
      nextDueDate: dueDate ?? DateTime.utc(2026, 6, 30),
    );

PmOccurrence _occurrence({
  required String id,
  DateTime? dueDate,
}) =>
    PmOccurrence.fromMap({
      'id': id,
      'scheduleId': 'sched-$id',
      'assetId': 'asset-1',
      'dueDate': dueDate ?? DateTime.utc(2026, 6, 20),
      'status': 'pending',
      'schedule': {
        'id': 'sched-$id',
        'taskName': 'Occurrence $id',
        'frequency': 'monthly',
        'frequencyValue': 30,
        'scheduleStartDate': DateTime.utc(2026, 1, 1),
        'scheduleEndDate': DateTime.utc(2026, 12, 31),
      },
    });

void main() {
  final referenceDate = DateTime.utc(2026, 6, 25);

  group('validatePmInbox', () {
    test('reports consistent inbox as valid', () {
      final legacy = [_legacyTask(id: 'legacy-1')];
      final occurrences = [_occurrence(id: 'occ-1')];
      final inbox = PmWorkItem.mergeAndSort(
        legacyTasks: legacy,
        occurrences: occurrences,
        referenceDate: referenceDate,
      );

      final report = validatePmInbox(
        legacyTasks: legacy,
        occurrences: occurrences,
        inbox: inbox,
        referenceDate: referenceDate,
      );

      expect(report.isConsistent, isTrue);
      expect(report.issues, isEmpty);
    });

    test('warns on cross-source ID collision without failing consistency', () {
      final legacy = [_legacyTask(id: 'shared-id')];
      final occurrences = [_occurrence(id: 'shared-id')];
      final inbox = PmWorkItem.mergeAndSort(
        legacyTasks: legacy,
        occurrences: occurrences,
        referenceDate: referenceDate,
      );

      final report = validatePmInbox(
        legacyTasks: legacy,
        occurrences: occurrences,
        inbox: inbox,
        referenceDate: referenceDate,
      );

      expect(report.isConsistent, isTrue);
      expect(report.crossSourceIdCollisionCount, 1);
      expect(
        report.issues.single.code,
        'cross_source_id_collision',
      );
    });

    test('errors when inbox length diverges from merge', () {
      final legacy = [_legacyTask(id: 'legacy-1')];
      final occurrences = [_occurrence(id: 'occ-1')];
      final inbox = PmWorkItem.mergeAndSort(
        legacyTasks: legacy,
        occurrences: const [],
        referenceDate: referenceDate,
      );

      final report = validatePmInbox(
        legacyTasks: legacy,
        occurrences: occurrences,
        inbox: inbox,
        referenceDate: referenceDate,
      );

      expect(report.isConsistent, isFalse);
      expect(
        report.issues.any((issue) => issue.code == 'inbox_length_mismatch'),
        isTrue,
      );
    });

    test('errors on duplicate source/id keys in inbox', () {
      final item = PmWorkItem.fromLegacyTask(_legacyTask(id: 'dup-1'));
      final inbox = [item, item];

      final report = validatePmInbox(
        legacyTasks: [_legacyTask(id: 'dup-1')],
        occurrences: const [],
        inbox: inbox,
        referenceDate: referenceDate,
      );

      expect(report.isConsistent, isFalse);
      expect(
        report.issues.any((issue) => issue.code == 'duplicate_inbox_key'),
        isTrue,
      );
    });
  });
}
