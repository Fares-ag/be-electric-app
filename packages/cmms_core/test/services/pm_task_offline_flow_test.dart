import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/services/offline_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PMTask _fixturePMTask({
  required String id,
  PMTaskStatus status = PMTaskStatus.inProgress,
}) =>
    PMTask(
      id: id,
      taskName: 'Monthly inspection',
      assetId: 'asset-1',
      description: 'Inspect equipment',
      checklist: '[]',
      frequency: PMTaskFrequency.monthly,
      intervalDays: 30,
      nextDueDate: DateTime.utc(2024, 7),
      createdAt: DateTime.utc(2024, 6),
      updatedAt: DateTime.utc(2024, 6),
      status: status,
    );

void main() {
  group('Offline queue — PM atomic completion', () {
    late OfflineQueueService queueService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      queueService = OfflineQueueService();
      await queueService.clearQueue();
    });

    test('enqueue completePMTask supersedes legacy photo + update ops',
        () async {
      const pmTaskId = 'pm-offline-1';
      final legacyPhoto = QueuedOperation(
        id: 'photo_$pmTaskId',
        type: OperationType.uploadPhoto,
        data: {
          'filePath': '/tmp/pm_completion.jpg',
          'fileName': 'pm_completion.jpg',
          'folder': 'pm_tasks/completion_photos',
          'pmTaskId': pmTaskId,
        },
        createdAt: DateTime.utc(2024, 6, 1),
      );
      final legacyUpdate = QueuedOperation(
        id: pmTaskId,
        type: OperationType.updatePMTask,
        data: _fixturePMTask(id: pmTaskId).toMap(),
        createdAt: DateTime.utc(2024, 6, 1),
      );

      await queueService.enqueue(legacyPhoto);
      await queueService.enqueue(legacyUpdate);

      final resetTask = _fixturePMTask(id: pmTaskId).copyWith(
        status: PMTaskStatus.pending,
        startedAt: null,
        completionHistory: [
          {
            'completedAt': DateTime.utc(2024, 6, 1, 10).toIso8601String(),
            'startedAt': DateTime.utc(2024, 6, 1, 9).toIso8601String(),
          },
        ],
      );

      await queueService.enqueue(
        QueuedOperation(
          id: 'complete_$pmTaskId',
          type: OperationType.completePMTask,
          data: {
            'pmTask': resetTask.toMap(),
            'pendingPhotoFilePath': '/tmp/pm_completion.jpg',
            'pendingPhotoFileName': 'pm_completion.jpg',
          },
          createdAt: DateTime.utc(2024, 6, 1, 11),
        ),
      );

      final status = await queueService.getQueueStatus();
      expect(status['pending'], 1);
      final ops = status['operations'] as List<dynamic>;
      expect(ops.single['type'], OperationType.completePMTask.name);
      expect(ops.single['id'], 'complete_$pmTaskId');
    });

    test('enqueue createPMTask deduplicates by id', () async {
      const pmTaskId = 'pm-create-offline';
      final taskMap = _fixturePMTask(id: pmTaskId, status: PMTaskStatus.pending)
          .copyWith(isOffline: true)
          .toMap();

      await queueService.enqueue(
        QueuedOperation(
          id: pmTaskId,
          type: OperationType.createPMTask,
          data: taskMap,
          createdAt: DateTime.utc(2024, 6, 1),
        ),
      );
      await queueService.enqueue(
        QueuedOperation(
          id: pmTaskId,
          type: OperationType.createPMTask,
          data: taskMap,
          createdAt: DateTime.utc(2024, 6, 2),
        ),
      );

      final status = await queueService.getQueueStatus();
      expect(status['pending'], 1);
      final ops = status['operations'] as List<dynamic>;
      expect(ops.single['type'], OperationType.createPMTask.name);
    });
  });
}
