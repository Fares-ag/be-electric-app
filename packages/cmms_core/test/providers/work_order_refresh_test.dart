import 'package:cmms_core/config/locator.dart';
import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/providers/cmms_provider_bundle.dart';
import 'package:cmms_core/repositories/cmms_repositories.dart';
import 'package:cmms_core/repositories/work_order_repository.dart';
import 'package:cmms_core/services/unified_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

class _FakeWorkOrderRepository implements WorkOrderRepository {
  _FakeWorkOrderRepository({required this.remote});

  WorkOrder? remote;
  int getWorkOrderCalls = 0;

  @override
  Future<WorkOrder?> getWorkOrder(String workOrderId) async {
    getWorkOrderCalls++;
    await Future<void>.delayed(Duration.zero);
    if (remote?.id != workOrderId) return null;
    return remote;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkOrder _workOrder({
  required String id,
  required WorkOrderStatus status,
}) {
  final now = DateTime(2024, 6, 1);
  return WorkOrder(
    id: id,
    ticketNumber: 'WO-TEST',
    problemDescription: 'Test problem',
    requestorId: 'requestor-1',
    createdAt: now,
    updatedAt: now,
    status: status,
  );
}

void main() {
  late _FakeWorkOrderRepository fakeRepo;
  late CmmsProviderBundle bundle;

  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  setUp(() {
    fakeRepo = _FakeWorkOrderRepository(
      remote: _workOrder(id: 'wo-1', status: WorkOrderStatus.inProgress),
    );
    registerMock<WorkOrderRepository>(fakeRepo);
    CmmsRepositories.configure(workOrders: fakeRepo);

    sl<UnifiedDataService>().upsertWorkOrderInCache(
      _workOrder(id: 'wo-1', status: WorkOrderStatus.open),
    );

    bundle = CmmsProviderBundle.forTesting(autoStart: false);
  });

  tearDown(() {
    bundle.dispose();
  });

  group('WorkOrderProvider.refreshWorkOrder', () {
    test('loads from repository and updates canonical cache', () async {
      await bundle.workOrders.refreshWorkOrder('wo-1');

      expect(fakeRepo.getWorkOrderCalls, 1);
      expect(
        bundle.workOrders.getWorkOrderById('wo-1')?.status,
        WorkOrderStatus.inProgress,
      );
      expect(
        sl<UnifiedDataService>().workOrders
            .firstWhere((wo) => wo.id == 'wo-1')
            .status,
        WorkOrderStatus.inProgress,
      );
    });

    test('deduplicates concurrent refresh requests for the same id', () async {
      await Future.wait([
        bundle.workOrders.refreshWorkOrder('wo-1'),
        bundle.workOrders.refreshWorkOrder('wo-1'),
      ]);

      expect(fakeRepo.getWorkOrderCalls, 1);
    });
  });

  group('UnifiedDataProvider.refreshWorkOrder', () {
    test('delegates to WorkOrderProvider', () async {
      await bundle.unified.refreshWorkOrder('wo-1');

      expect(fakeRepo.getWorkOrderCalls, 1);
      expect(
        bundle.unified.workOrders.firstWhere((wo) => wo.id == 'wo-1').status,
        WorkOrderStatus.inProgress,
      );
    });
  });
}
