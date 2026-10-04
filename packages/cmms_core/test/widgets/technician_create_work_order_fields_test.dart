import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/utils/requestor_category_mapper.dart';
import 'package:cmms_core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/test_data.dart';

void main() {
  group('Technician create payload contract', () {
    test('validateWorkOrder accepts technician field-created WO', () {
      final now = DateTime(2026, 10, 4, 12);
      final wo = WorkOrder(
        id: 'wo-tech-create',
        ticketNumber: 'WO-2026-00001',
        assetId: TestAssets.pump01.id,
        asset: TestAssets.pump01,
        companyId: 'company-1',
        problemDescription: 'Charger fault',
        requestorId: TestUsers.technician.id,
        requestor: TestUsers.technician,
        requestorName: 'On-site contact',
        primaryTechnicianId: TestUsers.technician.id,
        assignedTechnicianIds: [TestUsers.technician.id],
        assignedAt: now,
        status: WorkOrderStatus.assigned,
        priority: mapRequestorCategoryIssue('Electrical').priority,
        category: mapRequestorCategoryIssue('Electrical').category,
        createdAt: now,
        updatedAt: now,
      );

      expect(() => validateWorkOrder(wo), returnsNormally);
      expect(wo.requestorId, TestUsers.technician.id);
      expect(wo.assignedTechnicianIds, [TestUsers.technician.id]);
      expect(wo.status, WorkOrderStatus.assigned);
      expect(wo.companyId, 'company-1');
    });

    test('validateWorkOrder accepts general facility WO with location and no asset',
        () {
      final now = DateTime(2026, 10, 4, 12);
      final wo = WorkOrder(
        id: 'wo-general',
        ticketNumber: 'WO-2026-00002',
        location: 'Lobby',
        problemDescription: '[Civil] Wall paint peeling',
        requestorId: TestUsers.technician.id,
        assignedTechnicianIds: [TestUsers.technician.id],
        assignedAt: now,
        status: WorkOrderStatus.assigned,
        createdAt: now,
        updatedAt: now,
      );

      expect(() => validateWorkOrder(wo), returnsNormally);
      expect(wo.assetId, isNull);
      expect(wo.location, 'Lobby');
      expect(wo.problemDescription, startsWith('[Civil]'));
    });

    test('validateWorkOrder rejects empty problem description', () {
      expect(
        () => validateWorkOrder(
          WorkOrder(
            id: 'wo-bad',
            ticketNumber: 'WO-2026-00003',
            problemDescription: '   ',
            requestorId: TestUsers.technician.id,
            createdAt: DateTime(2026, 10, 4),
            updatedAt: DateTime(2026, 10, 4),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
