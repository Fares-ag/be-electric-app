import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/services/realtime_supabase_service.dart';
import 'package:cmms_core/utils/work_order_cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

WorkOrder _workOrder(String id) {
  final now = DateTime(2026, 1, 1);
  return WorkOrder(
    id: id,
    ticketNumber: 'WO-$id',
    problemDescription: 'Test',
    requestorId: 'requestor-1',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('applyWorkOrderChange', () {
    test('insert adds work order to cache', () {
      final result = applyWorkOrderChange(
        [],
        WorkOrderChangeEvent(
          type: WorkOrderChangeType.insert,
          workOrder: _workOrder('wo-1'),
        ),
      );

      expect(result, hasLength(1));
      expect(result.first.id, 'wo-1');
    });

    test('update replaces existing work order by id', () {
      final original = _workOrder('wo-1');
      final updated = original.copyWith(problemDescription: 'Updated');

      final result = applyWorkOrderChange(
        [original],
        WorkOrderChangeEvent(
          type: WorkOrderChangeType.update,
          workOrder: updated,
        ),
      );

      expect(result, hasLength(1));
      expect(result.first.problemDescription, 'Updated');
    });

    test('delete removes work order from cache', () {
      final result = applyWorkOrderChange(
        [_workOrder('wo-1'), _workOrder('wo-2')],
        const WorkOrderChangeEvent(
          type: WorkOrderChangeType.delete,
          deletedId: 'wo-1',
        ),
      );

      expect(result, hasLength(1));
      expect(result.first.id, 'wo-2');
    });
  });

  group('applyRealtimeWorkOrderSnapshot', () {
    test('returns a copy of the realtime snapshot', () {
      final snapshot = [_workOrder('wo-1'), _workOrder('wo-2')];
      final result = applyRealtimeWorkOrderSnapshot(snapshot);

      expect(result, snapshot);
      expect(identical(result, snapshot), isFalse);
    });

    test('empty snapshot clears service cache when assigned', () {
      final result = applyRealtimeWorkOrderSnapshot([]);

      expect(result, isEmpty);
    });
  });
}
