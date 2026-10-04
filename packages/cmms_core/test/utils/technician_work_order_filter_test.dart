import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/utils/technician_work_order_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/test_data.dart';

void main() {
  late List<WorkOrder> allWorkOrders;
  late WorkOrder selfCreatedByTechnician;

  setUp(() {
    selfCreatedByTechnician = WorkOrder(
      id: 'wo_self',
      ticketNumber: 'WO-2024-SELF',
      problemDescription: 'Technician-created request, not yet assigned',
      requestorId: TestUsers.technician.id,
      requestor: TestUsers.technician,
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime(2024, 2, 1),
    );

    allWorkOrders = [
      TestWorkOrders.openWorkOrder,
      TestWorkOrders.assignedWorkOrder,
      selfCreatedByTechnician,
      WorkOrder(
        id: 'wo_other',
        ticketNumber: 'WO-2024-OTHER',
        problemDescription: 'Assigned to someone else',
        requestorId: TestUsers.requestor.id,
        assignedTechnicianIds: ['other-tech-id'],
        createdAt: DateTime(2024, 2, 2),
        updatedAt: DateTime(2024, 2, 2),
      ),
    ];
  });

  List<String> ids(Iterable<WorkOrder> workOrders) =>
      workOrders.map((wo) => wo.id).toList();

  group('workOrdersAssignedToTechnician (T-006)', () {
    test('includes work orders assigned to the technician', () {
      final results = workOrdersAssignedToTechnician(
        allWorkOrders,
        TestUsers.technician.id,
      );

      expect(ids(results), contains(TestWorkOrders.assignedWorkOrder.id));
      expect(ids(results), isNot(contains(selfCreatedByTechnician.id)));
    });

    test('returns empty list for blank technician id', () {
      expect(
        workOrdersAssignedToTechnician(allWorkOrders, ''),
        isEmpty,
      );
    });
  });

  group('workOrdersForRoleListView (T-006 regression)', () {
    test('technician view uses assignment-only scope', () {
      final results = workOrdersForRoleListView(
        workOrders: allWorkOrders,
        userId: TestUsers.technician.id,
        userRole: 'technician',
        isTechnicianView: true,
      );

      expect(ids(results), [TestWorkOrders.assignedWorkOrder.id]);
    });

    test('technician role without explicit view flag uses assignment-only scope', () {
      final results = workOrdersForRoleListView(
        workOrders: allWorkOrders,
        userId: TestUsers.technician.id,
        userRole: 'technician',
        isTechnicianView: false,
      );

      expect(ids(results), [TestWorkOrders.assignedWorkOrder.id]);
    });

    test('requestor view still filters by requestorId', () {
      final results = workOrdersForRoleListView(
        workOrders: allWorkOrders,
        userId: TestUsers.requestor.id,
        userRole: 'requestor',
        isTechnicianView: false,
      );

      expect(
        ids(results),
        containsAll([
          TestWorkOrders.openWorkOrder.id,
          TestWorkOrders.assignedWorkOrder.id,
          'wo_other',
        ]),
      );
      expect(ids(results), isNot(contains(selfCreatedByTechnician.id)));
    });

    test('admin view still returns all work orders', () {
      final results = workOrdersForRoleListView(
        workOrders: allWorkOrders,
        userId: TestUsers.admin.id,
        userRole: 'admin',
        isTechnicianView: false,
      );

      expect(ids(results), ids(allWorkOrders));
    });

    test('manager view still returns all work orders', () {
      final results = workOrdersForRoleListView(
        workOrders: allWorkOrders,
        userId: TestUsers.manager.id,
        userRole: 'manager',
        isTechnicianView: false,
      );

      expect(ids(results), ids(allWorkOrders));
    });
  });
}
