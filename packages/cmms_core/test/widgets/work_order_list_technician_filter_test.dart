import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/providers/cmms_provider_bundle.dart';
import 'package:cmms_core/screens/work_orders/work_order_list_screen.dart';
import 'package:cmms_core/utils/technician_work_order_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fixtures/test_data.dart';
import '../test_helpers.dart';

void main() {
  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  group('WorkOrderListScreen technician filtering (T-006 regression)', () {
    late CmmsProviderBundle bundle;

    setUp(() {
      bundle = CmmsProviderBundle.forTesting(autoStart: false);
    });

    tearDown(() {
      bundle.dispose();
    });

    Future<void> seedWorkOrders(List<WorkOrder> workOrders) async {
      for (final wo in workOrders) {
        bundle.workOrders.updateCachedWorkOrder(wo);
      }
    }

    testWidgets('technician list shows assigned work orders only', (
      tester,
    ) async {
      final selfCreated = WorkOrder(
        id: 'wo_self',
        ticketNumber: 'WO-2024-SELF',
        problemDescription: 'Self-created, unassigned',
        requestorId: TestUsers.technician.id,
        requestor: TestUsers.technician,
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime(2024, 2, 1),
      );

      await seedWorkOrders([
        selfCreated,
        TestWorkOrders.assignedWorkOrder,
        TestWorkOrders.openWorkOrder,
      ]);
      bundle.auth.setUser(TestUsers.technician);

      await tester.pumpWidget(
        MultiProvider(
          providers: bundle.providers,
          child: const MaterialApp(
            home: WorkOrderListScreen(isTechnicianView: true, showAppBar: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WO-2024-002'), findsOneWidget);
      expect(find.text('WO-2024-001'), findsNothing);
      expect(find.text('WO-2024-SELF'), findsNothing);
    });

    testWidgets('requestor list still filters by requestorId', (tester) async {
      await seedWorkOrders([
        TestWorkOrders.openWorkOrder,
        TestWorkOrders.assignedWorkOrder,
      ]);
      bundle.auth.setUser(TestUsers.requestor);

      await tester.pumpWidget(
        MultiProvider(
          providers: bundle.providers,
          child: const MaterialApp(
            home: WorkOrderListScreen(showAppBar: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WO-2024-001'), findsOneWidget);
      expect(find.text('WO-2024-002'), findsOneWidget);
    });

    testWidgets('admin list still shows all work orders', (tester) async {
      final otherRequestorWo = WorkOrder(
        id: 'wo_admin_view',
        ticketNumber: 'WO-2024-ADMIN',
        problemDescription: 'Unassigned admin-visible row',
        requestorId: TestUsers.requestor.id,
        createdAt: DateTime(2024, 2, 3),
        updatedAt: DateTime(2024, 2, 3),
      );

      await seedWorkOrders([
        TestWorkOrders.openWorkOrder,
        TestWorkOrders.assignedWorkOrder,
        otherRequestorWo,
      ]);
      bundle.auth.setUser(TestUsers.admin);

      await tester.pumpWidget(
        MultiProvider(
          providers: bundle.providers,
          child: const MaterialApp(
            home: WorkOrderListScreen(showAppBar: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WO-2024-001'), findsOneWidget);
      expect(find.text('WO-2024-002'), findsOneWidget);
      expect(find.text('WO-2024-ADMIN'), findsOneWidget);
    });
  });

  test('list filter matches dashboard helper for technician scope', () {
    final selfCreated = WorkOrder(
      id: 'wo_self',
      ticketNumber: 'WO-2024-SELF',
      problemDescription: 'Self-created',
      requestorId: TestUsers.technician.id,
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime(2024, 2, 1),
    );
    final all = [
      selfCreated,
      TestWorkOrders.assignedWorkOrder,
      TestWorkOrders.openWorkOrder,
    ];

    final listScope = workOrdersAssignedToTechnician(all, TestUsers.technician.id);

    expect(listScope, [TestWorkOrders.assignedWorkOrder]);
  });
}
