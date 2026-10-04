import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/services/offline_queue_service.dart';
import 'package:cmms_core/utils/offline_sync_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildOfflineSyncSnapshot', () {
    test('collects work-order ids from update and complete ops', () {
      final snapshot = buildOfflineSyncSnapshot([
        QueuedOperation(
          id: 'wo-1',
          type: OperationType.updateWorkOrder,
          data: {},
          createdAt: DateTime.utc(2025, 1, 1),
        ),
        QueuedOperation(
          id: 'complete_wo-2',
          type: OperationType.completeWorkOrder,
          data: {
            'workOrder': {
              'id': 'wo-2',
              'ticketNumber': 'WO-2',
              'problemDescription': 'Test',
              'requestorId': 'r1',
              'createdAt': DateTime.utc(2025, 1, 1).toIso8601String(),
              'updatedAt': DateTime.utc(2025, 1, 1).toIso8601String(),
              'status': WorkOrderStatus.completed.index,
            },
          },
          createdAt: DateTime.utc(2025, 1, 1),
        ),
      ]);

      expect(snapshot.pendingWorkOrderIds, {'wo-1', 'wo-2'});
      expect(snapshot.totalPendingOperations, 2);
    });
  });

  group('isWorkOrderPendingSync', () {
    test('true when id is in queue snapshot', () {
      final wo = WorkOrder(
        id: 'wo-1',
        ticketNumber: 'WO-1',
        problemDescription: 'Leak',
        requestorId: 'r1',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
      );
      final snapshot = OfflineSyncSnapshot(
        pendingWorkOrderIds: {'wo-1'},
        pendingPMTaskIds: {},
        totalPendingOperations: 1,
      );

      expect(isWorkOrderPendingSync(wo, snapshot), isTrue);
    });

    test('true when work order flagged isOffline locally', () {
      final wo = WorkOrder(
        id: 'wo-9',
        ticketNumber: 'WO-9',
        problemDescription: 'Leak',
        requestorId: 'r1',
        createdAt: DateTime.utc(2025, 1, 1),
        updatedAt: DateTime.utc(2025, 1, 1),
        isOffline: true,
      );

      expect(isWorkOrderPendingSync(wo, OfflineSyncSnapshot.empty()), isTrue);
    });
  });
}
