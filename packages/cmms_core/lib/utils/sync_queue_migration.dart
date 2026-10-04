import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/offline_queue_service.dart';

const _legacyQueueKey = 'sync_queue';
const _migrationDoneKey = 'offline_queue_migrated_from_sync_queue_v1';

/// One-time migration from legacy [SyncQueueService] prefs to [OfflineQueueService].
Future<void> migrateLegacySyncQueueIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_migrationDoneKey) == true) return;

  final legacyJson = prefs.getString(_legacyQueueKey);
  if (legacyJson == null || legacyJson.isEmpty) {
    await prefs.setBool(_migrationDoneKey, true);
    return;
  }

  try {
    final legacyOps = jsonDecode(legacyJson) as List<dynamic>;
    final migrated = <QueuedOperation>[];

    for (final raw in legacyOps) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final collection = map['collection']?.toString() ?? '';
      final type = map['type']?.toString() ?? '';
      final data = map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : <String, dynamic>{};
      final metadata = map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : <String, dynamic>{};
      final timestamp = DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now();
      final retryCount = map['retryCount'] as int? ?? 0;
      final lastError = map['error']?.toString();

      if (collection == 'work_orders' && type == 'update') {
        final entityId =
            (data['id'] ?? metadata['entityId'] ?? map['id'])?.toString();
        if (entityId == null || entityId.isEmpty) continue;
        final localPaths = (metadata['localPhotoPaths'] as List?)
                ?.map((e) => e.toString())
                .where((p) => p.isNotEmpty)
                .toList() ??
            <String>[];
        migrated.add(
          QueuedOperation(
            id: entityId,
            type: OperationType.updateWorkOrder,
            data: {
              '_legacySupabasePayload': true,
              'payload': data,
              if (localPaths.isNotEmpty) 'pendingPhotoFilePaths': localPaths,
            },
            createdAt: timestamp,
            retryCount: retryCount,
            lastError: lastError,
          ),
        );
      } else if (collection == 'parts_requests' && type == 'create') {
        final entityId =
            (data['id'] ?? metadata['entityId'] ?? map['id'])?.toString();
        if (entityId == null || entityId.isEmpty) continue;
        migrated.add(
          QueuedOperation(
            id: entityId,
            type: OperationType.createPartsRequest,
            data: data,
            createdAt: timestamp,
            retryCount: retryCount,
            lastError: lastError,
          ),
        );
      }
    }

    if (migrated.isNotEmpty) {
      final existingJson = prefs.getString('offline_operation_queue');
      final existing = <QueuedOperation>[];
      if (existingJson != null && existingJson.isNotEmpty) {
        final list = jsonDecode(existingJson) as List<dynamic>;
        existing.addAll(
          list.map(
            (item) => QueuedOperation.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      }
      final merged = [...existing, ...migrated];
      await prefs.setString(
        'offline_operation_queue',
        jsonEncode(merged.map((op) => op.toMap()).toList()),
      );
      debugPrint(
        'OfflineQueueService: migrated ${migrated.length} legacy sync_queue ops',
      );
    }

    await prefs.remove(_legacyQueueKey);
    await prefs.setBool(_migrationDoneKey, true);
  } catch (e) {
    debugPrint('OfflineQueueService: legacy sync_queue migration failed: $e');
  }
}
