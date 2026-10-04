import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cmms_core/services/offline_queue_service.dart';
import 'package:cmms_core/utils/sync_queue_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migrateLegacySyncQueueIfNeeded', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync_queue');
      await prefs.remove('offline_operation_queue');
      await prefs.remove('offline_queue_migrated_from_sync_queue_v1');
    });

    test('migrates legacy work_orders update and parts_requests create', () async {
      final legacyOps = [
        {
          'id': 'update_work_order_wo-legacy-1',
          'type': 'update',
          'collection': 'work_orders',
          'data': {
            'id': 'wo-legacy-1',
            'status': 'inProgress',
            'updatedAt': '2024-06-01T10:00:00.000Z',
          },
          'timestamp': '2024-06-01T10:00:00.000Z',
          'retryCount': 0,
          'metadata': {
            'entityId': 'wo-legacy-1',
            'localPhotoPaths': ['/tmp/photo.jpg'],
          },
        },
        {
          'id': 'create_parts_request_pr-1',
          'type': 'create',
          'collection': 'parts_requests',
          'data': {
            'id': 'pr-1',
            'workOrderId': 'wo-legacy-1',
            'requestedBy': 'tech-1',
            'status': 'pending',
            'requestedAt': '2024-06-01T10:00:00.000Z',
            'createdAt': '2024-06-01T10:00:00.000Z',
            'updatedAt': '2024-06-01T10:00:00.000Z',
            'requestedParts': [
              {
                'inventoryItemId': 'inv-1',
                'name': 'Filter',
                'quantity': 2,
              },
            ],
          },
          'timestamp': '2024-06-01T10:00:00.000Z',
          'retryCount': 0,
          'metadata': {'entityId': 'pr-1'},
        },
      ];

      SharedPreferences.setMockInitialValues({
        'sync_queue': jsonEncode(legacyOps),
      });

      await migrateLegacySyncQueueIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sync_queue'), isNull);
      expect(prefs.getBool('offline_queue_migrated_from_sync_queue_v1'), isTrue);

      final migratedJson = prefs.getString('offline_operation_queue');
      expect(migratedJson, isNotNull);
      final migrated = (jsonDecode(migratedJson!) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(migrated.length, 2);

      final woOp = migrated.firstWhere(
        (op) => op['type'] == OperationType.updateWorkOrder.name,
      );
      expect(woOp['id'], 'wo-legacy-1');
      expect(woOp['data']['_legacySupabasePayload'], isTrue);
      expect(
        (woOp['data']['pendingPhotoFilePaths'] as List).single,
        '/tmp/photo.jpg',
      );

      final partsOp = migrated.firstWhere(
        (op) => op['type'] == OperationType.createPartsRequest.name,
      );
      expect(partsOp['id'], 'pr-1');
    });

    test('is idempotent when migration flag is set', () async {
      SharedPreferences.setMockInitialValues({
        'sync_queue': jsonEncode([
          {
            'id': 'update_work_order_wo-2',
            'type': 'update',
            'collection': 'work_orders',
            'data': {'id': 'wo-2', 'status': 'open'},
            'timestamp': '2024-06-01T10:00:00.000Z',
            'metadata': {'entityId': 'wo-2'},
          },
        ]),
        'offline_queue_migrated_from_sync_queue_v1': true,
      });

      await migrateLegacySyncQueueIfNeeded();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sync_queue'), isNotNull);
      expect(prefs.getString('offline_operation_queue'), isNull);
    });
  });
}
