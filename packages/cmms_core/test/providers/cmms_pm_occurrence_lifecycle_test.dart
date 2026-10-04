import 'package:cmms_core/config/app_config.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/providers/asset_provider.dart';
import 'package:cmms_core/providers/cmms_data_coordinator.dart';
import 'package:cmms_core/providers/inventory_provider.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/providers/user_provider.dart';
import 'package:cmms_core/providers/work_order_provider.dart';
import 'package:cmms_core/providers/workflow_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pm_occurrence_service.dart';
import '../test_helpers.dart';

PmOccurrence _sampleOccurrence() => PmOccurrence.fromMap({
      'id': 'occ-1',
      'scheduleId': 'sched-1',
      'assetId': 'asset-1',
      'dueDate': DateTime.utc(2026, 6, 20),
    });

void main() {
  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  group('CmmsDataCoordinator PM occurrence lifecycle', () {
    late AssetProvider assets;
    late UserProvider users;
    late WorkOrderProvider workOrders;
    late InventoryProvider inventory;
    late WorkflowProvider workflows;
    late FakePmOccurrenceService pmService;
    late PmOccurrenceProvider pmOccurrences;
    late CmmsDataCoordinator coordinator;

    setUp(() {
      assets = AssetProvider();
      users = UserProvider();
      workOrders = WorkOrderProvider(users: users, assets: assets);
      inventory = InventoryProvider();
      workflows = WorkflowProvider();
      pmService = FakePmOccurrenceService(enabled: true);
      pmOccurrences = PmOccurrenceProvider(service: pmService);
      coordinator = CmmsDataCoordinator(
        workOrders: workOrders,
        assets: assets,
        users: users,
        inventory: inventory,
        workflows: workflows,
        pmOccurrences: pmOccurrences,
        resolveSignedInUserId: () async => 'tech-1',
      );
    });

    tearDown(() {
      coordinator.dispose();
      workOrders.dispose();
      assets.dispose();
      users.dispose();
      inventory.dispose();
      workflows.dispose();
      pmOccurrences.dispose();
    });

    test('loads provider when feature flag is ON', () async {
      pmService.assignedOccurrences = [_sampleOccurrence()];

      await coordinator.initializePmOccurrencesForTesting();

      expect(pmService.getAssignedOccurrencesCalls, 1);
      expect(pmOccurrences.hasLoaded, isTrue);
      expect(pmOccurrences.hasOccurrences, isTrue);
      expect(pmOccurrences.isEnabled, isTrue);
    });

    test('does not load provider when feature flag is OFF', () async {
      final disabledService = FakePmOccurrenceService(
        assignedOccurrences: [_sampleOccurrence()],
      );
      final disabledProvider = PmOccurrenceProvider(service: disabledService);
      final disabledCoordinator = CmmsDataCoordinator(
        workOrders: workOrders,
        assets: assets,
        users: users,
        inventory: inventory,
        workflows: workflows,
        pmOccurrences: disabledProvider,
        resolveSignedInUserId: () async => 'tech-1',
      );
      addTearDown(disabledCoordinator.dispose);
      addTearDown(disabledProvider.dispose);

      expect(AppConfig.enablePmOccurrences, isFalse);
      expect(disabledProvider.isEnabled, isFalse);

      await disabledCoordinator.initializePmOccurrencesForTesting();

      expect(disabledService.getAssignedOccurrencesCalls, 0);
      expect(disabledProvider.hasLoaded, isFalse);
      expect(disabledProvider.occurrences, isEmpty);
    });

    test('calls provider exactly once for concurrent initialize', () async {
      pmService.assignedOccurrences = [_sampleOccurrence()];

      await Future.wait([
        coordinator.initializePmOccurrencesForTesting(),
        coordinator.initializePmOccurrencesForTesting(),
      ]);

      expect(pmService.getAssignedOccurrencesCalls, 1);
    });

    test('reset clears provider state on sign-out lifecycle', () async {
      pmService.assignedOccurrences = [_sampleOccurrence()];

      await coordinator.initializePmOccurrencesForTesting();
      expect(pmOccurrences.hasOccurrences, isTrue);

      await coordinator.resetSessionStateForTesting();

      expect(pmOccurrences.occurrences, isEmpty);
      expect(pmOccurrences.hasLoaded, isFalse);
      expect(pmOccurrences.hasError, isFalse);
    });

    test('provider load failure does not break coordinator initialize', () async {
      pmService.assignedError = Exception('PM occurrence load failed');

      await expectLater(
        coordinator.initializePmOccurrencesForTesting(),
        completes,
      );

      expect(pmService.getAssignedOccurrencesCalls, 1);
      expect(pmOccurrences.hasError, isTrue);
      expect(pmOccurrences.occurrences, isEmpty);
    });
  });
}
