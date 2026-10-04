import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/services/offline_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineQueueService coalesce + queue retention', () {
    late OfflineQueueService queue;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      queue = OfflineQueueService();
      await queue.clearQueue();
      await queue.initialize();
    });

    test('coalesces duplicate updateWorkOrder by id', () async {
      await queue.enqueue(
        QueuedOperation(
          id: 'wo-1',
          type: OperationType.updateWorkOrder,
          data: TestWorkOrders.openWorkOrder.copyWith(id: 'wo-1').toMap(),
          createdAt: DateTime.utc(2026, 7, 20, 10),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: 'wo-1',
          type: OperationType.updateWorkOrder,
          data: TestWorkOrders.openWorkOrder
              .copyWith(
                id: 'wo-1',
                status: WorkOrderStatus.inProgress,
              )
              .toMap(),
          createdAt: DateTime.utc(2026, 7, 20, 11),
        ),
      );

      final status = await queue.getQueueStatus();
      expect(status['pending'], 1);
      final ops = status['operations'] as List<dynamic>;
      expect(ops.single['type'], OperationType.updateWorkOrder.name);
    });

    test('completeWorkOrder supersedes legacy photo + update ops', () async {
      const workOrderId = 'wo-offline-1';
      await queue.enqueue(
        QueuedOperation(
          id: 'photo_$workOrderId',
          type: OperationType.uploadPhoto,
          data: {
            'filePath': '/tmp/completion.jpg',
            'fileName': 'completion.jpg',
            'folder': 'work_orders/completion_photos',
            'workOrderId': workOrderId,
            'photoType': 'completion',
          },
          createdAt: DateTime.utc(2024),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: workOrderId,
          type: OperationType.updateWorkOrder,
          data: TestWorkOrders.openWorkOrder.copyWith(id: workOrderId).toMap(),
          createdAt: DateTime.utc(2024),
        ),
      );
      await queue.enqueue(
        QueuedOperation(
          id: 'complete_$workOrderId',
          type: OperationType.completeWorkOrder,
          data: {
            'workOrder': TestWorkOrders.openWorkOrder
                .copyWith(
                  id: workOrderId,
                  status: WorkOrderStatus.completed,
                )
                .toMap(),
            'pendingPhotoFilePath': '/tmp/completion.jpg',
            'pendingPhotoFileName': 'completion.jpg',
          },
          createdAt: DateTime.utc(2024, 1, 2),
        ),
      );

      final status = await queue.getQueueStatus();
      expect(status['pending'], 1);
      final ops = status['operations'] as List<dynamic>;
      expect(ops.single['type'], OperationType.completeWorkOrder.name);
    });

    test('clearQueue removes all pending operations', () async {
      await queue.enqueue(
        QueuedOperation(
          id: 'wo-clear',
          type: OperationType.updateWorkOrder,
          data: TestWorkOrders.openWorkOrder.copyWith(id: 'wo-clear').toMap(),
          createdAt: DateTime.utc(2024),
        ),
      );
      expect(await queue.pendingOperationCount(), 1);
      await queue.clearQueue();
      expect(await queue.pendingOperationCount(), 0);
    });
  });
}
