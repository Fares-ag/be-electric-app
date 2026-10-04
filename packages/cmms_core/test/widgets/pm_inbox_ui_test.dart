import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/providers/asset_provider.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/providers/cmms_provider_bundle.dart';
import 'package:cmms_core/providers/pm_inbox_provider.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/providers/unified_data_provider.dart';
import 'package:cmms_core/providers/user_provider.dart';
import 'package:cmms_core/screens/pm_tasks/pm_occurrence_detail_screen.dart';
import 'package:cmms_core/screens/pm_tasks/pm_task_detail_screen.dart';
import 'package:cmms_core/widgets/pm/pm_inbox_list_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../helpers/fake_pm_occurrence_service.dart';
import '../helpers/fake_work_order_provider_for_inbox.dart';
import '../test_helpers.dart';

PMTask _legacyTask({
  required String id,
  required String taskName,
  required DateTime dueDate,
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
  String taskName = 'Scheduled occurrence',
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

Future<void> _pumpInboxBody(
  WidgetTester tester, {
  required PmInboxProvider inbox,
  PmOccurrenceProvider? pmOccurrences,
  List<SingleChildWidget>? extraProviders,
}) async {
  final occurrences = pmOccurrences ?? PmOccurrenceProvider(
    service: FakePmOccurrenceService(),
  );
  final auth = AuthProvider()
    ..setUser(
      User(
        id: 'tech-1',
        email: 'tech@test.com',
        name: 'Taylor Tech',
        role: 'technician',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<PmOccurrenceProvider>.value(value: occurrences),
        ...?extraProviders,
        ChangeNotifierProvider<PmInboxProvider>.value(value: inbox),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: PmInboxListBody(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  group('PmInboxListBody', () {
    late FakeWorkOrderProviderForInbox workOrders;
    late PmOccurrenceProvider pmOccurrences;
    late PmInboxProvider inbox;

    tearDown(() {
      inbox.dispose();
      workOrders.dispose();
      if (pmOccurrences case final provider?) {
        provider.dispose();
      }
    });

    testWidgets('renders legacy-only inbox when occurrences are disabled', (
      tester,
    ) async {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
        pmTasks: [
          _legacyTask(
            id: 'legacy-1',
            taskName: 'Filter replacement',
            dueDate: DateTime.utc(2026, 6, 30),
          ),
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

      await _pumpInboxBody(tester, inbox: inbox, pmOccurrences: pmOccurrences);

      expect(find.text('Filter replacement'), findsOneWidget);
      expect(find.text('Legacy PM'), findsOneWidget);
      expect(find.text('Scheduled PM'), findsNothing);
    });

    testWidgets('renders merged inbox when occurrences are enabled', (
      tester,
    ) async {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
        pmTasks: [
          _legacyTask(
            id: 'legacy-1',
            taskName: 'Legacy task',
            dueDate: DateTime.utc(2026, 6, 30),
          ),
        ],
      );
      pmOccurrences = PmOccurrenceProvider(
        service: FakePmOccurrenceService(
          enabled: true,
          assignedOccurrences: [
            _occurrence(
              id: 'occ-1',
              dueDate: DateTime.utc(2026, 6, 20),
              taskName: 'Scheduled occurrence',
            ),
          ],
        ),
      );
      await pmOccurrences.loadAssignedOccurrences('tech-1');
      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );

      await _pumpInboxBody(tester, inbox: inbox, pmOccurrences: pmOccurrences);

      expect(find.text('Legacy task'), findsOneWidget);
      expect(find.text('Scheduled occurrence'), findsOneWidget);
      expect(find.text('Legacy PM'), findsOneWidget);
      expect(find.text('Scheduled PM'), findsOneWidget);
    });

    testWidgets('shows empty state when inbox has no items', (tester) async {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
      );
      pmOccurrences = PmOccurrenceProvider(
        service: FakePmOccurrenceService(),
      );
      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );

      await _pumpInboxBody(tester, inbox: inbox, pmOccurrences: pmOccurrences);

      expect(find.text('No PM tasks found'), findsOneWidget);
    });

    testWidgets('routes legacy items to PMTaskDetailScreen', (tester) async {
      final bundle = CmmsProviderBundle.forTesting(autoStart: false);
      addTearDown(bundle.dispose);

      workOrders = FakeWorkOrderProviderForInbox(
        users: bundle.users,
        assets: bundle.assets,
        pmTasks: [
          _legacyTask(
            id: 'legacy-1',
            taskName: 'Legacy route task',
            dueDate: DateTime.utc(2026, 6, 30),
          ),
        ],
      );
      pmOccurrences = PmOccurrenceProvider(
        service: FakePmOccurrenceService(),
      );
      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );

      await _pumpInboxBody(
        tester,
        inbox: inbox,
        pmOccurrences: pmOccurrences,
        extraProviders: [
          ChangeNotifierProvider<AuthProvider>.value(value: bundle.auth),
          ChangeNotifierProvider<UnifiedDataProvider>.value(
            value: bundle.unified,
          ),
        ],
      );
      await tester.tap(find.text('Legacy route task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PMTaskDetailScreen), findsOneWidget);
    });

    testWidgets('routes occurrence items to PmOccurrenceDetailScreen', (
      tester,
    ) async {
      workOrders = FakeWorkOrderProviderForInbox(
        users: UserProvider(),
        assets: AssetProvider(),
      );
      pmOccurrences = PmOccurrenceProvider(
        service: FakePmOccurrenceService(
          enabled: true,
          assignedOccurrences: [
            _occurrence(
              id: 'occ-1',
              dueDate: DateTime.utc(2026, 6, 20),
              taskName: 'Occurrence route task',
            ),
          ],
        ),
      );
      await pmOccurrences.loadAssignedOccurrences('tech-1');
      inbox = PmInboxProvider(
        workOrders: workOrders,
        pmOccurrences: pmOccurrences,
        referenceDate: () => DateTime.utc(2026, 6, 25),
      );

      await _pumpInboxBody(tester, inbox: inbox, pmOccurrences: pmOccurrences);
      await tester.tap(find.text('Occurrence route task'));
      await tester.pumpAndSettle();

      expect(find.byType(PmOccurrenceDetailScreen), findsOneWidget);
      expect(find.text('Scheduled PM'), findsWidgets);
    });
  });
}
