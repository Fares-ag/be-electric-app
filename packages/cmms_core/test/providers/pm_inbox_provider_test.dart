import 'package:cmms_core/config/app_config.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/pm_work_item.dart';
import 'package:cmms_core/providers/asset_provider.dart';
import 'package:cmms_core/providers/pm_inbox_provider.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pm_occurrence_service.dart';
import '../helpers/fake_work_order_provider_for_inbox.dart';
import '../test_helpers.dart';

PMTask _legacyTask({
  required String id,
  required DateTime dueDate,
  String taskName = 'Legacy task',
}) =>
    PMTask(
      id: id,
      taskName: taskName,
      description: 'Legacy description',
      frequency: PMTaskFrequency.monthly,
      intervalDays: 30,
      createdAt: DateTime.utc(2026, 1, 1),
      nextDueDate: dueDate,
    );

PmOccurrence _occurrence({
  required String id,
  required DateTime dueDate,
  String taskName = 'Occurrence task',
}) =>
    PmOccurrence.fromMap({
      'id': id,
      'scheduleId': 'sched-$id',
      'assetId': 'asset-1',
      'dueDate': dueDate,
      'status': 'pending',
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
  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  group('PmInboxProvider legacy-only inbox', () {
    late FakeWorkOrderProviderForInbox workOrders;
    late PmOccurrenceProvider pmOccurrences;
    late PmInboxProvider inbox;

    setUp(() {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
        pmTasks: [
          _legacyTask(id: 'legacy-1', dueDate: DateTime.utc(2026, 6, 30)),
        ],
      );
      pmOccurrences = PmOccurrenceProvider(
        service: FakePmOccurrenceService(
          assignedOccurrences: [
            _occurrence(id: 'occ-1', dueDate: DateTime.utc(2026, 6, 10)),
          ],
        ),
      );
      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );
    });

    tearDown(() {
      inbox.dispose();
      workOrders.dispose();
      pmOccurrences.dispose();
    });

    test('flag OFF exposes legacy PM tasks only', () {
      expect(AppConfig.enablePmOccurrences, isFalse);
      expect(pmOccurrences.isEnabled, isFalse);
      expect(inbox.includesOccurrences, isFalse);
      expect(inbox.inbox, hasLength(1));
      expect(inbox.inbox.single.source, PmWorkItemSource.legacy);
      expect(inbox.inbox.single.id, 'legacy-1');
    });
  });

  group('PmInboxProvider mixed inbox', () {
    late FakeWorkOrderProviderForInbox workOrders;
    late FakePmOccurrenceService pmService;
    late PmOccurrenceProvider pmOccurrences;
    late PmInboxProvider inbox;

    setUp(() async {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
        pmTasks: [
          _legacyTask(id: 'legacy-1', dueDate: DateTime.utc(2026, 6, 30)),
        ],
      );
      pmService = FakePmOccurrenceService(
        enabled: true,
        assignedOccurrences: [
          _occurrence(id: 'occ-1', dueDate: DateTime.utc(2026, 6, 20)),
        ],
      );
      pmOccurrences = PmOccurrenceProvider(service: pmService);
      await pmOccurrences.loadAssignedOccurrences('tech-1');

      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );
    });

    tearDown(() {
      inbox.dispose();
      workOrders.dispose();
      pmOccurrences.dispose();
    });

    test('flag ON merges legacy tasks and occurrences', () {
      expect(inbox.includesOccurrences, isTrue);
      expect(inbox.inbox, hasLength(2));
      expect(inbox.inbox.first.source, PmWorkItemSource.occurrence);
      expect(inbox.inbox.last.source, PmWorkItemSource.legacy);
    });

    test('sorts merged inbox by due date ascending', () {
      expect(inbox.inbox.map((item) => item.id), ['occ-1', 'legacy-1']);
    });

    test('keeps duplicate IDs across different sources', () async {
      pmService.assignedOccurrences = [
        _occurrence(
          id: 'shared-id',
          dueDate: DateTime.utc(2026, 6, 15),
          taskName: 'Occurrence duplicate',
        ),
      ];
      await pmOccurrences.loadAssignedOccurrences('tech-1');
      workOrders.setPmTasks([
        _legacyTask(
          id: 'shared-id',
          dueDate: DateTime.utc(2026, 6, 10),
          taskName: 'Legacy duplicate',
        ),
      ]);

      expect(inbox.inbox, hasLength(2));
      expect(inbox.inbox.where((item) => item.isLegacy), hasLength(1));
      expect(inbox.inbox.where((item) => item.isOccurrence), hasLength(1));
    });
  });

  group('PmInboxProvider updates', () {
    late FakeWorkOrderProviderForInbox workOrders;
    late PmOccurrenceProvider pmOccurrences;
    late FakePmOccurrenceService pmService;
    late PmInboxProvider inbox;
    var notifyCount = 0;

    setUp(() async {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
      );
      pmService = FakePmOccurrenceService(enabled: true);
      pmOccurrences = PmOccurrenceProvider(service: pmService);
      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );
      inbox.addListener(() {
        notifyCount++;
      });
      notifyCount = 0;
    });

    tearDown(() {
      inbox.dispose();
      workOrders.dispose();
      pmOccurrences.dispose();
    });

    test('starts empty when both sources are empty', () {
      expect(inbox.isEmpty, isTrue);
      expect(inbox.inbox, isEmpty);
    });

    test('recomputes when WorkOrderProvider changes', () {
      workOrders.setPmTasks([
        _legacyTask(id: 'legacy-1', dueDate: DateTime.utc(2026, 6, 30)),
      ]);

      expect(inbox.inbox, hasLength(1));
      expect(inbox.inbox.single.id, 'legacy-1');
      expect(notifyCount, 1);
    });

    test('recomputes when PmOccurrenceProvider changes', () async {
      pmService.assignedOccurrences = [
        _occurrence(id: 'occ-1', dueDate: DateTime.utc(2026, 6, 20)),
      ];
      await pmOccurrences.loadAssignedOccurrences('tech-1');

      expect(inbox.inbox, hasLength(1));
      expect(inbox.inbox.single.id, 'occ-1');
      expect(notifyCount, greaterThan(0));
    });

    test('skips notify when inbox identity is unchanged', () {
      workOrders.setPmTasks([
        _legacyTask(id: 'legacy-1', dueDate: DateTime.utc(2026, 6, 30)),
      ]);
      final countAfterFirstUpdate = notifyCount;

      workOrders.setPmTasks([
        _legacyTask(id: 'legacy-1', dueDate: DateTime.utc(2026, 6, 30)),
      ]);

      expect(notifyCount, countAfterFirstUpdate);
    });

    test('exposes consistent validation report in debug builds', () {
      workOrders.setPmTasks([
        _legacyTask(id: 'legacy-1', dueDate: DateTime.utc(2026, 6, 30)),
      ]);

      final report = inbox.validationReport;
      expect(report, isNotNull);
      expect(report!.isConsistent, isTrue);
    });

    test('validation warns on cross-source ID collision metric', () async {
      pmService.assignedOccurrences = [
        _occurrence(id: 'shared-id', dueDate: DateTime.utc(2026, 6, 15)),
      ];
      await pmOccurrences.loadAssignedOccurrences('tech-1');
      workOrders.setPmTasks([
        _legacyTask(
          id: 'shared-id',
          dueDate: DateTime.utc(2026, 6, 10),
        ),
      ]);

      final report = inbox.validationReport;
      expect(report, isNotNull);
      expect(report!.crossSourceIdCollisionCount, 1);
      expect(report.isConsistent, isTrue);
    });
  });
}
