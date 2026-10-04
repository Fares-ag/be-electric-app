import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/pm_work_item.dart';
import 'package:flutter_test/flutter_test.dart';

PMTask _legacyTask({
  required String id,
  required String taskName,
  required DateTime dueDate,
  PMTaskStatus status = PMTaskStatus.pending,
}) =>
    PMTask(
      id: id,
      taskName: taskName,
      description: 'Legacy description',
      frequency: PMTaskFrequency.monthly,
      intervalDays: 30,
      createdAt: DateTime.utc(2026, 1, 1),
      nextDueDate: dueDate,
      status: status,
    );

PmOccurrence _occurrence({
  required String id,
  required DateTime dueDate,
  String status = 'pending',
  String taskName = 'Occurrence task',
}) =>
    PmOccurrence.fromMap({
      'id': id,
      'scheduleId': 'sched-$id',
      'assetId': 'asset-1',
      'dueDate': dueDate,
      'status': status,
      'schedule': {
        'id': 'sched-$id',
        'taskName': taskName,
        'frequency': 'monthly',
        'frequencyValue': 30,
        'scheduleStartDate': DateTime.utc(2026, 1, 1),
        'scheduleEndDate': DateTime.utc(2026, 12, 31),
      },
    });

void main() {
  final referenceDate = DateTime.utc(2026, 6, 25);

  group('PmWorkItem mapper', () {
    test('maps legacy task without mutating source model', () {
      final task = _legacyTask(
        id: 'legacy-1',
        taskName: 'Filter replacement',
        dueDate: DateTime.utc(2026, 6, 20),
        status: PMTaskStatus.overdue,
      );

      final item = mapLegacyPmTaskToWorkItem(task, referenceDate: referenceDate);

      expect(item.source, PmWorkItemSource.legacy);
      expect(item.id, 'legacy-1');
      expect(item.title, 'Filter replacement');
      expect(item.displayStatus, PmWorkItemDisplayStatus.overdue);
      expect(item.legacyTask, task);
      expect(item.occurrence, isNull);
      expect(task.status, PMTaskStatus.overdue);
    });

    test('maps occurrence without mutating source model', () {
      final occurrence = _occurrence(
        id: 'occ-1',
        dueDate: DateTime.utc(2026, 6, 20),
      );

      final item =
          mapOccurrenceToWorkItem(occurrence, referenceDate: referenceDate);

      expect(item.source, PmWorkItemSource.occurrence);
      expect(item.id, 'occ-1');
      expect(item.displayStatus, PmWorkItemDisplayStatus.overdue);
      expect(item.occurrence, occurrence);
      expect(item.legacyTask, isNull);
      expect(occurrence.status.name, 'pending');
    });

    test('mergePmWorkItems combines mixed legacy and occurrence lists', () {
      final merged = mergePmWorkItems(
        legacyTasks: [
          _legacyTask(
            id: 'legacy-1',
            taskName: 'Legacy',
            dueDate: DateTime.utc(2026, 6, 30),
          ),
        ],
        occurrences: [
          _occurrence(id: 'occ-1', dueDate: DateTime.utc(2026, 6, 20)),
        ],
        referenceDate: referenceDate,
      );

      expect(merged, hasLength(2));
      expect(merged.map((item) => item.id), ['legacy-1', 'occ-1']);
    });

    test('mergePmWorkItems keeps duplicate IDs across different sources', () {
      final merged = mergePmWorkItems(
        legacyTasks: [
          _legacyTask(
            id: 'shared-id',
            taskName: 'Legacy duplicate',
            dueDate: DateTime.utc(2026, 6, 10),
          ),
        ],
        occurrences: [
          _occurrence(
            id: 'shared-id',
            dueDate: DateTime.utc(2026, 6, 15),
            taskName: 'Occurrence duplicate',
          ),
        ],
        referenceDate: referenceDate,
      );

      expect(merged, hasLength(2));
      expect(merged.where((item) => item.isLegacy), hasLength(1));
      expect(merged.where((item) => item.isOccurrence), hasLength(1));
    });

    test('mergeAndSort returns empty list for empty collections', () {
      final merged = PmWorkItem.mergeAndSort(
        legacyTasks: const [],
        occurrences: const [],
        referenceDate: referenceDate,
      );

      expect(merged, isEmpty);
    });
  });

  group('PmWorkItem sorting', () {
    test('sorts by due date ascending', () {
      final items = sortPmWorkItems([
        mapLegacyPmTaskToWorkItem(
          _legacyTask(
            id: 'b',
            taskName: 'Later',
            dueDate: DateTime.utc(2026, 6, 30),
          ),
          referenceDate: referenceDate,
        ),
        mapOccurrenceToWorkItem(
          _occurrence(id: 'a', dueDate: DateTime.utc(2026, 6, 10)),
          referenceDate: referenceDate,
        ),
      ]);

      expect(items.map((item) => item.id), ['a', 'b']);
    });

    test('places overdue before upcoming on the same due date', () {
      final overdueLegacy = mapLegacyPmTaskToWorkItem(
        _legacyTask(
          id: 'legacy-overdue',
          taskName: 'Overdue legacy',
          dueDate: DateTime.utc(2026, 6, 25),
          status: PMTaskStatus.overdue,
        ),
        referenceDate: referenceDate,
      );
      final upcomingOccurrence = mapOccurrenceToWorkItem(
        _occurrence(
          id: 'occ-upcoming',
          dueDate: DateTime.utc(2026, 6, 25),
        ),
        referenceDate: referenceDate,
      );

      final items = sortPmWorkItems([upcomingOccurrence, overdueLegacy]);

      expect(items.first.displayStatus, PmWorkItemDisplayStatus.overdue);
      expect(items.last.displayStatus, PmWorkItemDisplayStatus.upcoming);
    });

    test('uses stable source then id ordering for ties', () {
      final legacy = mapLegacyPmTaskToWorkItem(
        _legacyTask(
          id: 'b-id',
          taskName: 'Legacy B',
          dueDate: DateTime.utc(2026, 6, 25),
          status: PMTaskStatus.overdue,
        ),
        referenceDate: referenceDate,
      );
      final occurrence = mapOccurrenceToWorkItem(
        _occurrence(
          id: 'a-id',
          dueDate: DateTime.utc(2026, 6, 25),
          status: 'overdue',
        ),
        referenceDate: referenceDate,
      );

      final items = sortPmWorkItems([occurrence, legacy]);

      expect(items.map((item) => item.source), [
        PmWorkItemSource.legacy,
        PmWorkItemSource.occurrence,
      ]);
      expect(items.map((item) => item.id), ['b-id', 'a-id']);
    });

    test('mergeAndSort applies deterministic ordering for mixed lists', () {
      final merged = PmWorkItem.mergeAndSort(
        legacyTasks: [
          _legacyTask(
            id: 'legacy-1',
            taskName: 'Legacy task',
            dueDate: DateTime.utc(2026, 6, 30),
          ),
        ],
        occurrences: [
          _occurrence(id: 'occ-1', dueDate: DateTime.utc(2026, 6, 20)),
        ],
        referenceDate: referenceDate,
      );

      expect(merged.first.isOccurrence, isTrue);
      expect(merged.last.isLegacy, isTrue);
    });
  });

  group('PmWorkItem status normalization', () {
    test('normalizes legacy completed and cancelled statuses', () {
      expect(
        normalizeLegacyPmTaskDisplayStatus(
          _legacyTask(
            id: 'done',
            taskName: 'Done',
            dueDate: DateTime.utc(2026, 6, 1),
            status: PMTaskStatus.completed,
          ),
        ),
        PmWorkItemDisplayStatus.completed,
      );
      expect(
        normalizeLegacyPmTaskDisplayStatus(
          _legacyTask(
            id: 'cancelled',
            taskName: 'Cancelled',
            dueDate: DateTime.utc(2026, 6, 1),
            status: PMTaskStatus.cancelled,
          ),
        ),
        PmWorkItemDisplayStatus.cancelled,
      );
    });

    test('derives overdue upcoming from legacy pending due dates', () {
      expect(
        normalizeLegacyPmTaskDisplayStatus(
          _legacyTask(
            id: 'overdue',
            taskName: 'Overdue',
            dueDate: DateTime.utc(2026, 6, 1),
          ),
          referenceDate: referenceDate,
        ),
        PmWorkItemDisplayStatus.overdue,
      );
      expect(
        normalizeLegacyPmTaskDisplayStatus(
          _legacyTask(
            id: 'upcoming',
            taskName: 'Upcoming',
            dueDate: DateTime.utc(2026, 7, 1),
          ),
          referenceDate: referenceDate,
        ),
        PmWorkItemDisplayStatus.upcoming,
      );
    });
  });

  group('PmWorkItem filters', () {
    late List<PmWorkItem> items;

    setUp(() {
      items = mergePmWorkItems(
        legacyTasks: [
          _legacyTask(
            id: 'legacy-open-overdue',
            taskName: 'Legacy overdue',
            dueDate: DateTime.utc(2026, 6, 1),
            status: PMTaskStatus.overdue,
          ),
          _legacyTask(
            id: 'legacy-completed',
            taskName: 'Legacy completed',
            dueDate: DateTime.utc(2026, 5, 1),
            status: PMTaskStatus.completed,
          ),
          _legacyTask(
            id: 'legacy-cancelled',
            taskName: 'Legacy cancelled',
            dueDate: DateTime.utc(2026, 5, 2),
            status: PMTaskStatus.cancelled,
          ),
          _legacyTask(
            id: 'legacy-today',
            taskName: 'Legacy today',
            dueDate: DateTime.utc(2026, 6, 25),
          ),
        ],
        occurrences: [
          _occurrence(
            id: 'occ-upcoming',
            dueDate: DateTime.utc(2026, 7, 1),
          ),
        ],
        referenceDate: referenceDate,
      );
    });

    test('filters open items', () {
      final open = filterPmWorkItemsOpen(items);

      expect(open.every(isPmWorkItemOpen), isTrue);
      expect(open.map((item) => item.id), [
        'legacy-open-overdue',
        'legacy-today',
        'occ-upcoming',
      ]);
    });

    test('filters completed items', () {
      final completed = filterPmWorkItemsCompleted(items);

      expect(completed, hasLength(1));
      expect(completed.single.id, 'legacy-completed');
    });

    test('filters cancelled items', () {
      final cancelled = filterPmWorkItemsCancelled(items);

      expect(cancelled, hasLength(1));
      expect(cancelled.single.id, 'legacy-cancelled');
    });

    test('filters overdue items', () {
      final overdue = filterPmWorkItemsOverdue(items);

      expect(overdue, hasLength(1));
      expect(overdue.single.id, 'legacy-open-overdue');
    });

    test('filters upcoming items', () {
      final upcoming = filterPmWorkItemsUpcoming(items);

      expect(upcoming, hasLength(2));
      expect(upcoming.map((item) => item.id), ['legacy-today', 'occ-upcoming']);
    });

    test('filters items due today', () {
      final today = filterPmWorkItemsDueToday(
        items,
        referenceDate: referenceDate,
      );

      expect(today, hasLength(1));
      expect(today.single.id, 'legacy-today');
    });
  });
}
