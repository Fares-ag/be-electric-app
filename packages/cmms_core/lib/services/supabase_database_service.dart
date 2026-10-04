// Supabase Database Service
// Handles cloud database operations with Supabase Postgres

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/asset.dart';
import '../models/company.dart';
import '../models/inventory_item.dart';
import '../models/parts_request.dart';
import '../models/pm_occurrence.dart';
import '../models/pm_schedule.dart';
import '../models/pm_task.dart';
import '../models/purchase_order.dart';
import '../models/support_request.dart';
import '../models/user.dart' as app_user;
import '../models/work_order.dart';
import '../models/workflow_models.dart';
import '../utils/deterministic_id_generator.dart';
import '../utils/parts_request_supabase_payload.dart';
import '../utils/supabase_write_result.dart';
import '../utils/validators.dart';
import 'audit_logging_service.dart';
import 'enhanced_inventory_service.dart';
import 'enhanced_notification_service.dart';
import 'escalation_service.dart';

class SupabaseDatabaseService {

  /// Initialize Supabase Database Service
  Future<void> initialize() async {
    try {
      debugPrint('Supabase Database: Initializing...');
      debugPrint('Supabase Database: Initialized successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase Database: Initialization error: $e');
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Get current user ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get _isAuthenticated => _currentUserId != null;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static bool _isValidUuid(String s) => _uuidRegex.hasMatch(s);

  /// Convert data map to Supabase format (handle DateTime conversion)
  Map<String, dynamic> convertToSupabaseMap(Map<String, dynamic> dataMap) {
    final supabaseMap = <String, dynamic>{};

    for (final entry in dataMap.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        supabaseMap[key] = null;
      } else if (value is DateTime) {
        supabaseMap[key] = value.toIso8601String();
      } else if (value.toString().contains('Timestamp')) {
        // Handle legacy Timestamp format (for backward compatibility)
        try {
          final timestampStr = value.toString();
          final match = RegExp(r'Timestamp\(seconds=(\d+), nanoseconds=(\d+)\)')
              .firstMatch(timestampStr);
          if (match != null) {
            final seconds = int.parse(match.group(1)!);
            final nanoseconds = int.parse(match.group(2)!);
            final dateTime = DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round(),
            );
            supabaseMap[key] = dateTime.toIso8601String();
          } else {
            supabaseMap[key] = value;
          }
        } catch (e, st) {
          supabaseMap[key] = value;
        }
      } else if (value is Map) {
        supabaseMap[key] =
            convertToSupabaseMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        supabaseMap[key] = value.map((item) {
          if (item is Map) {
            return convertToSupabaseMap(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        supabaseMap[key] = value;
      }
    }

    return supabaseMap;
  }

  /// Extract reopen fields from metadata and merge into data map
  void _extractReopenFieldsFromMetadata(Map<String, dynamic> data) {
    final metadata = data['metadata'] as Map<String, dynamic>?;
    if (metadata != null) {
      // Extract reopen fields from metadata if they exist and aren't already in data
      if (metadata.containsKey('reopenedAt') &&
          !data.containsKey('reopenedAt')) {
        data['reopenedAt'] = metadata['reopenedAt'];
      }
      if (metadata.containsKey('reopenedBy') &&
          !data.containsKey('reopenedBy')) {
        data['reopenedBy'] = metadata['reopenedBy'];
      }
      if (metadata.containsKey('reopenReason') &&
          !data.containsKey('reopenReason')) {
        data['reopenReason'] = metadata['reopenReason'];
      }
      if (metadata.containsKey('reopenCount') &&
          !data.containsKey('reopenCount')) {
        data['reopenCount'] = metadata['reopenCount'];
      }
      if (metadata.containsKey('previousCompletionDate') &&
          !data.containsKey('previousCompletionDate')) {
        data['previousCompletionDate'] = metadata['previousCompletionDate'];
      }
      if (metadata.containsKey('previousStatus') &&
          !data.containsKey('previousStatus')) {
        data['previousStatus'] = metadata['previousStatus'];
      }
      if (metadata.containsKey('workDurationSeconds') &&
          !data.containsKey('workDurationSeconds')) {
        data['workDurationSeconds'] = metadata['workDurationSeconds'];
      }
      // Extract problem photo URLs (requestor images) from metadata for display.
      // Use value check (not just containsKey) so a null/empty Supabase column
      // does not block restoration from the metadata JSONB blob.
      if (metadata.containsKey('photoPaths')) {
        final existing = data['photoPaths'];
        final hasExisting =
            existing is List && (existing).isNotEmpty;
        if (!hasExisting) {
          final paths = metadata['photoPaths'];
          data['photoPaths'] =
              paths is List ? List<String>.from(paths) : paths;
        }
      }
      // Extract completion photo URLs (multiple) from metadata for display.
      if (metadata.containsKey('completionPhotoPaths')) {
        final existing = data['completionPhotoPaths'];
        final hasExisting =
            existing is List && (existing).isNotEmpty;
        if (!hasExisting) {
          final paths = metadata['completionPhotoPaths'];
          data['completionPhotoPaths'] =
              paths is List ? List<String>.from(paths) : paths;
        }
      }
    }
  }

  /// Convert Supabase map to data map (handle DateTime conversion)
  Map<String, dynamic> convertFromSupabaseMap(
      Map<String, dynamic> supabaseMap) {
    final dataMap = <String, dynamic>{};

    for (final entry in supabaseMap.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) {
        dataMap[key] = null;
      } else if (value is String && _isIso8601Date(value)) {
        // Convert ISO8601 string to DateTime (models will handle conversion)
        dataMap[key] = DateTime.tryParse(value) ?? value;
      } else if (value is Map) {
        dataMap[key] = convertFromSupabaseMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        dataMap[key] = value.map((item) {
          if (item is Map) {
            return convertFromSupabaseMap(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        dataMap[key] = value;
      }
    }

    // Extract reopen fields from metadata after conversion
    _extractReopenFieldsFromMetadata(dataMap);

    return dataMap;
  }

  /// Persists full problem + completion photo URL lists in [metadata] so reads
  /// (and clients that only set the legacy single columns) always round-trip.
  void _mergeWorkOrderPhotoMetadataIntoRow(Map<String, dynamic> data) {
    final existingMeta =
        (data['metadata'] as Map<String, dynamic>?) != null
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : <String, dynamic>{};

    final problemList = data['photoPaths'] as List<dynamic>?;
    final problemSingle = data['photoPath'] as String?;
    final effectiveProblem = <String>[];
    if (problemList != null && problemList.isNotEmpty) {
      effectiveProblem.addAll(problemList.map((e) => e.toString()));
    } else if (problemSingle != null && problemSingle.isNotEmpty) {
      effectiveProblem.add(problemSingle);
    }
    if (effectiveProblem.isNotEmpty) {
      existingMeta['photoPaths'] = effectiveProblem;
    }

    final completionList = data['completionPhotoPaths'] as List<dynamic>?;
    final completionSingle = data['completionPhotoPath'] as String?;
    final effectiveCompletion = <String>[];
    if (completionList != null && completionList.isNotEmpty) {
      effectiveCompletion.addAll(completionList.map((e) => e.toString()));
    } else if (completionSingle != null && completionSingle.isNotEmpty) {
      effectiveCompletion.add(completionSingle);
    }
    if (effectiveCompletion.isNotEmpty) {
      existingMeta['completionPhotoPaths'] = effectiveCompletion;
    }

    if (existingMeta.isNotEmpty) {
      data['metadata'] = existingMeta;
    }
    data.remove('photoPaths');
    data.remove('completionPhotoPaths');
  }

  bool _isIso8601Date(String value) {
    try {
      DateTime.parse(value);
      return value.contains('T') || value.contains('-');
    } catch (e, st) {
      return false;
    }
  }

  DateTime? _latestWorkOrderReferenceBeforeStart(WorkOrder workOrder) {
    final createdAt = workOrder.createdAt;
    final assignedAt = workOrder.assignedAt;

    if (assignedAt != null && createdAt != null) {
      return assignedAt.isAfter(createdAt) ? assignedAt : createdAt;
    }
    return assignedAt ?? createdAt;
  }

  /// Keeps timestamp ordering valid without collapsing work duration when clocks differ.
  WorkOrder _adjustWorkOrderTimestamps(WorkOrder workOrder) {
    var adjusted = workOrder;

    if (workOrder.startedAt != null && workOrder.completedAt != null) {
      final originalStarted = workOrder.startedAt!;
      final originalCompleted = workOrder.completedAt!;
      final elapsed = originalCompleted.difference(originalStarted);
      final preservedDuration = workOrder.workDurationSeconds != null
          ? Duration(seconds: workOrder.workDurationSeconds!)
          : (elapsed.isNegative ? Duration.zero : elapsed);

      var newStarted = originalStarted;
      final latestReference = _latestWorkOrderReferenceBeforeStart(workOrder);
      if (latestReference != null) {
        final minimumStarted = latestReference.add(const Duration(seconds: 1));
        if (newStarted.isBefore(minimumStarted) ||
            newStarted.isAtSameMomentAs(latestReference)) {
          debugPrint(
            '⚠️ Supabase: Adjusting startedAt from ${originalStarted.toIso8601String()} '
            'to preserve ${preservedDuration.inSeconds}s duration after '
            '${latestReference.toIso8601String()}',
          );
          newStarted = minimumStarted;
        }
      }

      final newCompleted = preservedDuration.inSeconds > 0
          ? newStarted.add(preservedDuration)
          : newStarted.add(const Duration(seconds: 1));

      adjusted = adjusted.copyWith(
        startedAt: newStarted,
        completedAt: newCompleted,
      );
    } else {
      if (workOrder.startedAt != null) {
        final startedAt = workOrder.startedAt!;
        final latestReference = _latestWorkOrderReferenceBeforeStart(workOrder);

        if (latestReference != null) {
          final adjustedStartedAt =
              latestReference.add(const Duration(seconds: 1));
          if (startedAt.isBefore(adjustedStartedAt) ||
              startedAt.isAtSameMomentAs(latestReference)) {
            debugPrint(
                '⚠️ Supabase: Adjusting startedAt from ${startedAt.toIso8601String()} to be after ${latestReference.toIso8601String()}');
            adjusted = adjusted.copyWith(startedAt: adjustedStartedAt);
          }
        }
      }

      if (adjusted.completedAt != null) {
        final completedAt = adjusted.completedAt!;
        final startedAt = adjusted.startedAt;
        final assignedAt = adjusted.assignedAt;
        final createdAt = adjusted.createdAt;

        DateTime? latestReference;
        if (startedAt != null) {
          latestReference = startedAt;
        } else if (assignedAt != null && createdAt != null) {
          latestReference =
              assignedAt.isAfter(createdAt) ? assignedAt : createdAt;
        } else if (assignedAt != null) {
          latestReference = assignedAt;
        } else if (createdAt != null) {
          latestReference = createdAt;
        }

        if (latestReference != null) {
          final adjustedCompletedAt =
              latestReference.add(const Duration(seconds: 1));
          if (completedAt.isBefore(adjustedCompletedAt) ||
              completedAt.isAtSameMomentAs(latestReference)) {
            debugPrint(
                '⚠️ Supabase: Adjusting completedAt from ${completedAt.toIso8601String()} to be after ${latestReference.toIso8601String()}');
            adjusted = adjusted.copyWith(completedAt: adjustedCompletedAt);
          }
        }
      }
    }

    if (adjusted.closedAt != null) {
      final closedAt = adjusted.closedAt!;
      final completedAt = adjusted.completedAt;
      final startedAt = adjusted.startedAt;
      final createdAt = adjusted.createdAt;

      DateTime? latestReference;
      if (completedAt != null) {
        latestReference = completedAt;
      } else if (startedAt != null) {
        latestReference = startedAt;
      } else if (createdAt != null) {
        latestReference = createdAt;
      }

      if (latestReference != null) {
        final adjustedClosedAt = latestReference.add(const Duration(seconds: 1));
        if (closedAt.isBefore(adjustedClosedAt) ||
            closedAt.isAtSameMomentAs(latestReference)) {
          debugPrint(
              '⚠️ Supabase: Adjusting closedAt from ${closedAt.toIso8601String()} to be after ${latestReference.toIso8601String()}');
          adjusted = adjusted.copyWith(closedAt: adjustedClosedAt);
        }
      }
    }

    if (adjusted.assignedAt != null && adjusted.createdAt != null) {
      final assignedAt = adjusted.assignedAt!;
      final createdAt = adjusted.createdAt!;

      if (assignedAt.isBefore(createdAt) ||
          assignedAt.isAtSameMomentAs(createdAt)) {
        final adjustedAssignedAt = createdAt.add(const Duration(seconds: 1));
        debugPrint(
            '⚠️ Supabase: Adjusting assignedAt from ${assignedAt.toIso8601String()} to be after ${createdAt.toIso8601String()}');
        adjusted = adjusted.copyWith(assignedAt: adjustedAssignedAt);
      }
    }

    return adjusted;
  }

  // ============================================================================
  // WORK ORDERS
  // ============================================================================

  /// Create work order in Supabase (deterministic ID, idempotent)
  Future<String> createWorkOrder(WorkOrder workOrder) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validateWorkOrder(workOrder);

      final id = (workOrder.id.isNotEmpty)
          ? DeterministicIdGenerator.normalizeWorkOrderId(workOrder.id)
          : DeterministicIdGenerator.generateWorkOrderId(
              idempotencyKey: workOrder.idempotencyKey,
              ticketNumber: workOrder.ticketNumber,
              requestorId: workOrder.requestorId,
              createdAt: workOrder.createdAt,
            );

      debugPrint('Supabase: Upserting work order $id');

      final data = convertToSupabaseMap(workOrder.toMap());
      data['id'] = id;

      // Extract reopen fields to store in metadata (since they may not be in schema yet)
      final reopenMetadata = <String, dynamic>{};
      if (data.containsKey('reopenedAt')) {
        reopenMetadata['reopenedAt'] = data.remove('reopenedAt');
      }
      if (data.containsKey('reopenedBy')) {
        reopenMetadata['reopenedBy'] = data.remove('reopenedBy');
      }
      if (data.containsKey('reopenReason')) {
        reopenMetadata['reopenReason'] = data.remove('reopenReason');
      }
      if (data.containsKey('reopenCount')) {
        reopenMetadata['reopenCount'] = data.remove('reopenCount');
      }
      if (data.containsKey('previousCompletionDate')) {
        reopenMetadata['previousCompletionDate'] =
            data.remove('previousCompletionDate');
      }
      if (data.containsKey('previousStatus')) {
        reopenMetadata['previousStatus'] = data.remove('previousStatus');
      }
      if (data.containsKey('workDurationSeconds')) {
        reopenMetadata['workDurationSeconds'] =
            data.remove('workDurationSeconds');
      }

      // Merge reopen metadata into existing metadata
      if (reopenMetadata.isNotEmpty) {
        final existingMetadata =
            data['metadata'] as Map<String, dynamic>? ?? {};
        data['metadata'] = {
          ...existingMetadata,
          ...reopenMetadata,
        };
      }

      // Remove fields that don't exist in Supabase schema
      data.remove('actualDuration');
      data.remove('estimatedDuration');
      data.remove('firstResponseTime');
      data.remove('actualStartTime');
      data.remove('actualEndTime');
      data.remove('rootCause');
      data.remove('failureMode');
      data.remove('severityLevel');
      data.remove('isRepeatFailure');
      data.remove('workCategory');
      _mergeWorkOrderPhotoMetadataIntoRow(data);

      // Log what photo data we're sending so we can diagnose storage issues.
      final metaForLog = data['metadata'] as Map<String, dynamic>?;
      final photosInMeta = metaForLog?['photoPaths'];
      debugPrint(
        '📸 createWorkOrder: photoPath=${data['photoPath']}, '
        'photoPaths in metadata=$photosInMeta',
      );

      // Use SECURITY DEFINER RPC so work order insert succeeds without
      // authenticated needing SELECT on public.users (FK checks run as definer).
      final result = await _client.rpc('upsert_work_order', params: {'p_row': data});
      final returnedId = result != null ? result.toString() : id;

      debugPrint('Supabase: Work order upserted with ID: $returnedId');

      // Belt-and-suspenders: if there are photos in metadata, persist them via
      // a direct UPDATE so they are saved even if the RPC ignores the metadata
      // field.  This UPDATE runs with the authenticated user's session.
      if (photosInMeta is List && photosInMeta.isNotEmpty) {
        try {
          final savedId = returnedId.isNotEmpty ? returnedId : id;
          await _client.from('work_orders').update({
            'metadata': metaForLog,
          }).eq('id', savedId);
          debugPrint(
            '📸 Photo metadata patched directly on row $savedId: $photosInMeta',
          );
        } catch (e, st) {
          // Non-fatal: the RPC may have already saved metadata correctly.
          debugPrint('⚠️ Could not patch photo metadata (non-fatal): $e');
        }
      }

      return returnedId;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating work order: $e');
      throw Exception('Failed to create work order: $e');
    }
  }

  /// Column-safe UPDATE row for `work_orders` (also used by SyncQueue).
  Map<String, dynamic> buildWorkOrderUpdatePayload(WorkOrder workOrder) {
    final adjustedWorkOrder = _adjustWorkOrderTimestamps(workOrder);
    validateWorkOrder(adjustedWorkOrder);

    final data = convertToSupabaseMap(adjustedWorkOrder.toMap());

    final reopenMetadata = <String, dynamic>{};
    if (data.containsKey('reopenedAt')) {
      reopenMetadata['reopenedAt'] = data.remove('reopenedAt');
    }
    if (data.containsKey('reopenedBy')) {
      reopenMetadata['reopenedBy'] = data.remove('reopenedBy');
    }
    if (data.containsKey('reopenReason')) {
      reopenMetadata['reopenReason'] = data.remove('reopenReason');
    }
    if (data.containsKey('reopenCount')) {
      reopenMetadata['reopenCount'] = data.remove('reopenCount');
    }
    if (data.containsKey('previousCompletionDate')) {
      reopenMetadata['previousCompletionDate'] =
          data.remove('previousCompletionDate');
    }
    if (data.containsKey('previousStatus')) {
      reopenMetadata['previousStatus'] = data.remove('previousStatus');
    }
    if (data.containsKey('workDurationSeconds')) {
      reopenMetadata['workDurationSeconds'] =
          data.remove('workDurationSeconds');
    }

    if (reopenMetadata.isNotEmpty) {
      final existingMetadata =
          data['metadata'] as Map<String, dynamic>? ?? {};
      data['metadata'] = {
        ...existingMetadata,
        ...reopenMetadata,
      };
    }

    data.remove('actualDuration');
    data.remove('estimatedDuration');
    data.remove('firstResponseTime');
    data.remove('actualStartTime');
    data.remove('actualEndTime');
    data.remove('rootCause');
    data.remove('failureMode');
    data.remove('severityLevel');
    data.remove('isRepeatFailure');
    data.remove('workCategory');
    data.remove('isOffline');
    data.remove('lastSyncedAt');
    _mergeWorkOrderPhotoMetadataIntoRow(data);
    _stripLocalPhotoPathsFromWorkOrderRow(data);
    return data;
  }

  /// Drop local filesystem paths from photo metadata before cloud write.
  void _stripLocalPhotoPathsFromWorkOrderRow(Map<String, dynamic> data) {
    bool isRemote(String p) {
      final lower = p.toLowerCase();
      return lower.startsWith('http://') || lower.startsWith('https://');
    }

    final meta = data['metadata'];
    if (meta is! Map) return;
    final m = Map<String, dynamic>.from(meta);

    void filterList(String key) {
      final list = m[key];
      if (list is! List) return;
      final kept = list
          .map((e) => e.toString())
          .where(isRemote)
          .toList();
      if (kept.isEmpty) {
        m.remove(key);
      } else {
        m[key] = kept;
      }
    }

    filterList('photoPaths');
    filterList('completionPhotoPaths');
    data['metadata'] = m;
  }

  /// Update work order in Supabase
  Future<void> updateWorkOrder(String workOrderId, WorkOrder workOrder) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Updating work order $workOrderId');

      final data = buildWorkOrderUpdatePayload(workOrder);

      final response = await _client
          .from('work_orders')
          .update(data)
          .eq('id', workOrderId)
          .select('id');
      ensureRowsUpdated(response, entityLabel: 'Work order');

      debugPrint('Supabase: Work order updated successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating work order: $e');
      throw Exception('Failed to update work order: $e');
    }
  }

  /// Delete work order from Supabase
  Future<void> deleteWorkOrder(String workOrderId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Deleting work order $workOrderId');

      await _client.from('work_orders').delete().eq('id', workOrderId);

      debugPrint('Supabase: Work order deleted successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting work order: $e');
      throw Exception('Failed to delete work order: $e');
    }
  }

  /// Get work order by ID
  Future<WorkOrder?> getWorkOrder(String workOrderId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting work order $workOrderId');

      final response = await _client
          .from('work_orders')
          .select()
          .eq('id', workOrderId)
          .single();

      if (response != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(response));
        final normalizedId =
            DeterministicIdGenerator.normalizeWorkOrderId(workOrderId);
        data['id'] = normalizedId;

        final workOrder = WorkOrder.fromMap(data);
        if (normalizedId != workOrderId) {
          return workOrder.copyWith(
            id: normalizedId,
            ticketNumber: normalizedId,
          );
        }
        return workOrder;
      }

      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting work order: $e');
      return null;
    }
  }

  /// Get all work orders (kept for backward-compatibility; prefer [getWorkOrdersPage]).
  Future<List<WorkOrder>> getAllWorkOrders() => getWorkOrdersPage(page: 0, pageSize: 1000);

  /// Get a single page of work orders ordered by newest first.
  /// [page] is zero-based; returns at most [pageSize] items.
  Future<List<WorkOrder>> getWorkOrdersPage({
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final from = page * pageSize;
      final to = from + pageSize - 1;

      debugPrint('Supabase: Getting work orders page $page (rows $from–$to)');

      final response = await _client
          .from('work_orders')
          .select()
          .order('createdAt', ascending: false)
          .range(from, to);

      final workOrders = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        final normalizedId =
            DeterministicIdGenerator.normalizeWorkOrderId(doc['id'] ?? '');
        data['id'] = normalizedId;
        final workOrder = WorkOrder.fromMap(data);
        if (normalizedId != doc['id']) {
          return workOrder.copyWith(
            id: normalizedId,
            ticketNumber: normalizedId,
          );
        }
        return workOrder;
      }).toList();

      debugPrint('Supabase: Retrieved ${workOrders.length} work orders '
          '(page $page, pageSize $pageSize)');
      return workOrders;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting work orders page $page: $e');
      return [];
    }
  }

  /// Get work orders by technician
  Future<List<WorkOrder>> getWorkOrdersByTechnician(String technicianId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting work orders for technician $technicianId');

      final response = await _client
          .from('work_orders')
          .select()
          .contains('assignedTechnicianIds', [technicianId]).order('createdAt',
              ascending: false);

      final workOrders = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        final normalizedId =
            DeterministicIdGenerator.normalizeWorkOrderId(doc['id'] ?? '');
        data['id'] = normalizedId;
        final workOrder = WorkOrder.fromMap(data);
        if (normalizedId != doc['id']) {
          return workOrder.copyWith(
            id: normalizedId,
            ticketNumber: normalizedId,
          );
        }
        return workOrder;
      }).toList();

      debugPrint(
          'Supabase: Retrieved ${workOrders.length} work orders for technician');
      return workOrders;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting work orders by technician: $e');
      return [];
    }
  }

  /// Get work orders by requestor
  Future<List<WorkOrder>> getWorkOrdersByRequestor(String requestorId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting work orders for requestor $requestorId');

      final response = await _client
          .from('work_orders')
          .select()
          .eq('requestorId', requestorId)
          .order('createdAt', ascending: false);

      final workOrders = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        final normalizedId =
            DeterministicIdGenerator.normalizeWorkOrderId(doc['id'] ?? '');
        data['id'] = normalizedId;
        final workOrder = WorkOrder.fromMap(data);
        if (normalizedId != doc['id']) {
          return workOrder.copyWith(
            id: normalizedId,
            ticketNumber: normalizedId,
          );
        }
        return workOrder;
      }).toList();

      debugPrint(
          'Supabase: Retrieved ${workOrders.length} work orders for requestor');
      return workOrders;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting work orders by requestor: $e');
      return [];
    }
  }

  /// Get work orders by asset
  Future<List<WorkOrder>> getWorkOrdersByAsset(String assetId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting work orders for asset $assetId');

      final response = await _client
          .from('work_orders')
          .select()
          .eq('assetId', assetId)
          .order('createdAt', ascending: false);

      final workOrders = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        final normalizedId =
            DeterministicIdGenerator.normalizeWorkOrderId(doc['id'] ?? '');
        data['id'] = normalizedId;
        final workOrder = WorkOrder.fromMap(data);
        if (normalizedId != doc['id']) {
          return workOrder.copyWith(
            id: normalizedId,
            ticketNumber: normalizedId,
          );
        }
        return workOrder;
      }).toList();

      debugPrint(
          'Supabase: Retrieved ${workOrders.length} work orders for asset');
      return workOrders;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting work orders by asset: $e');
      return [];
    }
  }

  // ============================================================================
  // ASSETS
  // ============================================================================

  /// Convert Asset to Supabase format (only include fields that exist in the database)
  Map<String, dynamic> _convertAssetToSupabaseMap(Asset asset) {
    final supabaseMap = <String, dynamic>{};

    // Only include fields that exist in the assets table schema
    // Based on supabase_migration.sql, the assets table has these columns:
    // id, name, "assetType", location, "qrCode", manufacturer, model, "serialNumber",
    // "installationDate", "lastMaintenanceDate", "nextMaintenanceDate", status,
    // "companyId", "createdAt", "updatedAt", metadata

    if (asset.id.isNotEmpty) supabaseMap['id'] = asset.id;
    if (asset.name.isNotEmpty) supabaseMap['name'] = asset.name;
    if (asset.location.isNotEmpty) supabaseMap['location'] = asset.location;
    if (asset.manufacturer != null)
      supabaseMap['manufacturer'] = asset.manufacturer;
    if (asset.model != null) supabaseMap['model'] = asset.model;
    if (asset.serialNumber != null)
      supabaseMap['serialNumber'] = asset.serialNumber;
    if (asset.status.isNotEmpty) supabaseMap['status'] = asset.status;
    if (asset.companyId != null) supabaseMap['companyId'] = asset.companyId;

    // Handle assetType - map from itemType or category
    if (asset.itemType != null) {
      supabaseMap['assetType'] = asset.itemType;
    } else if (asset.category != null) {
      supabaseMap['assetType'] = asset.category;
    }

    // Handle qrCode - use qrCodeId if qrCode is empty
    if (asset.qrCode != null && asset.qrCode!.isNotEmpty) {
      supabaseMap['qrCode'] = asset.qrCode;
    } else if (asset.qrCodeId != null && asset.qrCodeId!.isNotEmpty) {
      supabaseMap['qrCode'] = asset.qrCodeId;
    }

    // Handle dates
    if (asset.installationDate != null) {
      supabaseMap['installationDate'] =
          asset.installationDate!.toIso8601String();
    }
    if (asset.lastMaintenanceDate != null) {
      supabaseMap['lastMaintenanceDate'] =
          asset.lastMaintenanceDate!.toIso8601String();
    }
    if (asset.nextMaintenanceDate != null) {
      supabaseMap['nextMaintenanceDate'] =
          asset.nextMaintenanceDate!.toIso8601String();
    }

    // Handle timestamps
    supabaseMap['createdAt'] = asset.createdAt.toIso8601String();
    supabaseMap['updatedAt'] = asset.updatedAt.toIso8601String();

    // Store additional fields in metadata JSONB if needed
    final metadata = <String, dynamic>{};
    if (asset.description != null) metadata['description'] = asset.description;
    if (asset.category != null && asset.itemType == null)
      metadata['category'] = asset.category;
    if (asset.notes != null) metadata['notes'] = asset.notes;
    if (metadata.isNotEmpty) {
      supabaseMap['metadata'] = metadata;
    }

    return supabaseMap;
  }

  /// Create asset in Supabase (deterministic ID, idempotent)
  Future<String> createAsset(Asset asset) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validateAsset(asset);

      final id = asset.id.isNotEmpty
          ? asset.id
          : DeterministicIdGenerator.generateAssetId(
              name: asset.name,
              location: asset.location,
            );

      debugPrint('Supabase: Upserting asset $id');

      final data = _convertAssetToSupabaseMap(asset);
      data['id'] = id;

      await _client.from('assets').upsert(data);

      return id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating asset: $e');
      throw Exception('Failed to create asset: $e');
    }
  }

  /// Update asset in Supabase
  Future<void> updateAsset(String assetId, Asset asset) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validateAsset(asset);

      debugPrint('Supabase: Updating asset $assetId');

      final data = _convertAssetToSupabaseMap(asset);

      await _client.from('assets').update(data).eq('id', assetId);

      debugPrint('Supabase: Asset updated successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating asset: $e');
      throw Exception('Failed to update asset: $e');
    }
  }

  /// Delete asset from Supabase
  Future<void> deleteAsset(String assetId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Deleting asset $assetId');

      await _client.from('assets').delete().eq('id', assetId);

      debugPrint('Supabase: Asset deleted successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting asset: $e');
      throw Exception('Failed to delete asset: $e');
    }
  }

  /// Get asset by ID
  Future<Asset?> getAsset(String assetId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting asset $assetId');

      final response =
          await _client.from('assets').select().eq('id', assetId).single();

      if (response != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(response));
        data['id'] = assetId;
        return Asset.fromMap(data);
      }

      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting asset: $e');
      return null;
    }
  }

  /// Get all assets
  Future<List<Asset>> getAllAssets() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all assets');

      final response =
          await _client.from('assets').select().order('name', ascending: true);

      final assets = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return Asset.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${assets.length} assets');
      return assets;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting assets: $e');
      return [];
    }
  }

  /// Assets for a company — tries common FK column names, then [getAllAssets].
  Future<List<Asset>> getAssetsByCompanyId(String companyId) async {
    if (!_isAuthenticated) {
      throw Exception('User not authenticated');
    }
    final id = companyId.trim();
    if (id.isEmpty) {
      return [];
    }

    List<Asset> mapRows(List<dynamic> response) {
      return response.map((doc) {
        final m = Map<String, dynamic>.from(doc as Map);
        final data = convertFromSupabaseMap(m);
        data['id'] = m['id'];
        return Asset.fromMap(data);
      }).toList();
    }

    // This project uses "companyId" (see Postgrest hint). Try that first to avoid
    // 42703 noise on every call; fall back to snake_case for other deployments.
    for (final column in <String>['companyId', 'company_id']) {
      try {
        final response = await _client
            .from('assets')
            .select()
            .eq(column, id)
            .order('name', ascending: true);
        final assets = mapRows(List<dynamic>.from(response as List));
        debugPrint(
          'Supabase: getAssetsByCompanyId($column) -> ${assets.length} assets',
        );
        return assets;
      } on Exception catch (e, st) {
        debugPrint('Supabase: getAssetsByCompanyId $column: $e');
      }
    }

    final fallback = await getAllAssets();
    debugPrint(
      'Supabase: getAssetsByCompanyId — using full list fallback (${fallback.length} rows)',
    );
    return fallback;
  }

  /// Get asset by QR code
  Future<Asset?> getAssetByQRCode(String qrCode) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting asset by QR code: $qrCode');

      final response = await _client
          .from('assets')
          .select()
          .eq('qrCode', qrCode)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(response));
        data['id'] = response['id'];
        final asset = Asset.fromMap(data);
        debugPrint('Supabase: Found asset: ${asset.name}');
        return asset;
      }

      debugPrint('Supabase: No asset found with QR code: $qrCode');
      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting asset by QR code: $e');
      return null;
    }
  }

  // ============================================================================
  // PM TASKS
  // ============================================================================

  /// Convert PMTask to Supabase map (filter out fields not in schema)
  Map<String, dynamic> _convertPMTaskToSupabaseMap(PMTask pmTask) {
    final dataMap = pmTask.toMap();
    final supabaseMap = convertToSupabaseMap(dataMap);

    // Only include fields that exist in the pm_tasks table schema
    final filteredMap = <String, dynamic>{
      'id': supabaseMap['id'],
      'taskName': supabaseMap['taskName'],
      'assetId': supabaseMap['assetId'],
      'description': supabaseMap['description'],
      'assignedTechnicianIds': supabaseMap['assignedTechnicianIds'],
      'frequency': supabaseMap['frequency'],
      'frequencyValue':
          supabaseMap['intervalDays'], // Map intervalDays to frequencyValue
      'nextDueDate': supabaseMap['nextDueDate'],
      'lastCompletedDate': supabaseMap[
          'lastCompletedAt'], // Map lastCompletedAt to lastCompletedDate
      'status': supabaseMap['status'],
      'estimatedDuration': supabaseMap['estimatedDuration'],
      'createdAt': supabaseMap['createdAt'],
      'updatedAt': supabaseMap['updatedAt'],
      'idempotencyKey': supabaseMap['idempotencyKey'],
      'completionPhotoPath':
          supabaseMap['photoPath'], // Map photoPath to completionPhotoPath
    };

    // Store additional fields in metadata JSONB
    final metadata = <String, dynamic>{};
    if (supabaseMap['assetName'] != null)
      metadata['assetName'] = supabaseMap['assetName'];
    if (supabaseMap['assetLocation'] != null)
      metadata['assetLocation'] = supabaseMap['assetLocation'];
    if (supabaseMap['checklist'] != null)
      metadata['checklist'] = supabaseMap['checklist'];
    if (supabaseMap['primaryTechnicianId'] != null)
      metadata['primaryTechnicianId'] = supabaseMap['primaryTechnicianId'];
    if (supabaseMap['startedAt'] != null)
      metadata['startedAt'] = supabaseMap['startedAt'];
    if (supabaseMap['completedAt'] != null)
      metadata['completedAt'] = supabaseMap['completedAt'];
    if (supabaseMap['completionNotes'] != null)
      metadata['completionNotes'] = supabaseMap['completionNotes'];
    if (supabaseMap['technicianSignature'] != null)
      metadata['technicianSignature'] = supabaseMap['technicianSignature'];
    if (supabaseMap['technicianEffortMinutes'] != null)
      metadata['technicianEffortMinutes'] =
          supabaseMap['technicianEffortMinutes'];
    if (supabaseMap['isOffline'] != null)
      metadata['isOffline'] = supabaseMap['isOffline'];
    if (supabaseMap['lastSyncedAt'] != null)
      metadata['lastSyncedAt'] = supabaseMap['lastSyncedAt'];
    if (supabaseMap['laborCost'] != null)
      metadata['laborCost'] = supabaseMap['laborCost'];
    if (supabaseMap['partsCost'] != null)
      metadata['partsCost'] = supabaseMap['partsCost'];
    if (supabaseMap['totalCost'] != null)
      metadata['totalCost'] = supabaseMap['totalCost'];
    if (supabaseMap['isPaused'] != null)
      metadata['isPaused'] = supabaseMap['isPaused'];
    if (supabaseMap['pausedAt'] != null)
      metadata['pausedAt'] = supabaseMap['pausedAt'];
    if (supabaseMap['pauseReason'] != null)
      metadata['pauseReason'] = supabaseMap['pauseReason'];
    if (supabaseMap['resumedAt'] != null)
      metadata['resumedAt'] = supabaseMap['resumedAt'];
    if (supabaseMap['pauseHistory'] != null)
      metadata['pauseHistory'] = supabaseMap['pauseHistory'];
    if (supabaseMap['completionHistory'] != null)
      metadata['completionHistory'] = supabaseMap['completionHistory'];
    if (supabaseMap['createdById'] != null)
      metadata['createdById'] = supabaseMap['createdById'];

    if (metadata.isNotEmpty) {
      filteredMap['metadata'] = metadata;
    }

    return filteredMap;
  }

  /// Create PM task in Supabase (deterministic ID, idempotent)
  Future<String> createPMTask(PMTask pmTask) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validatePMTask(pmTask);

      final id = pmTask.id.isNotEmpty
          ? pmTask.id
          : DeterministicIdGenerator.generatePMTaskId(
              idempotencyKey: pmTask.idempotencyKey,
              title: pmTask.taskName,
              assetId: pmTask.assetId,
            );

      debugPrint('Supabase: Upserting PM task $id');

      final data = _convertPMTaskToSupabaseMap(pmTask);
      data['id'] = id;

      await _client.from('pm_tasks').upsert(data);

      return id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating PM task: $e');
      throw Exception('Failed to create PM task: $e');
    }
  }

  /// Update PM task in Supabase
  Future<void> updatePMTask(String pmTaskId, PMTask pmTask) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validatePMTask(pmTask);

      debugPrint('Supabase: Updating PM task $pmTaskId');

      final data = _convertPMTaskToSupabaseMap(pmTask);

      await _client.from('pm_tasks').update(data).eq('id', pmTaskId);

      debugPrint('Supabase: PM task updated successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating PM task: $e');
      throw Exception('Failed to update PM task: $e');
    }
  }

  /// Delete PM task from Supabase
  Future<void> deletePMTask(String pmTaskId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Deleting PM task $pmTaskId');

      await _client.from('pm_tasks').delete().eq('id', pmTaskId);

      debugPrint('Supabase: PM task deleted successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting PM task: $e');
      throw Exception('Failed to delete PM task: $e');
    }
  }

  /// Get single PM task by id (for offline queue photo guards).
  Future<PMTask?> getPMTaskById(String pmTaskId) async {
    try {
      if (pmTaskId.isEmpty) return null;

      final response = await _client
          .from('pm_tasks')
          .select()
          .eq('id', pmTaskId)
          .maybeSingle();

      if (response == null) return null;

      final data = convertFromSupabaseMap(Map<String, dynamic>.from(response));
      data['id'] = response['id'];
      return PMTask.fromMap(data);
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting PM task by id: $e');
      return null;
    }
  }

  /// Build PM task update payload (mirrors [buildWorkOrderUpdatePayload]).
  Map<String, dynamic> buildPMTaskUpdatePayload(PMTask pmTask) =>
      _convertPMTaskToSupabaseMap(pmTask);

  /// Build PM task create payload.
  Map<String, dynamic> buildPMTaskCreatePayload(PMTask pmTask) {
    final data = _convertPMTaskToSupabaseMap(pmTask);
    if (pmTask.id.isNotEmpty) {
      data['id'] = pmTask.id;
    }
    return data;
  }

  /// Get all PM tasks
  Future<List<PMTask>> getAllPMTasks() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all PM tasks');

      final response = await _client
          .from('pm_tasks')
          .select()
          .order('createdAt', ascending: false);

      final pmTasks = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return PMTask.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${pmTasks.length} PM tasks');
      return pmTasks;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting PM tasks: $e');
      return [];
    }
  }

  // ============================================================================
  // USERS
  // ============================================================================

  /// Create user in Supabase (via SECURITY DEFINER RPC — bypasses GRANT/RLS).
  /// Uses Auth UUID when provided so public.users.id matches auth.users.id.
  Future<String> createUser(app_user.User user) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validateUser(user);

      final isUuid = user.id.isNotEmpty && _isValidUuid(user.id);
      final id = isUuid
          ? user.id
          : DeterministicIdGenerator.generateUserId(user.email);

      final userWithId = user.id == id ? user : user.copyWith(id: id);

      debugPrint('Supabase: Creating user $id');

      final data = convertToSupabaseMap(userWithId.toMap());
      data['id'] = id;

      final outId = await _client.rpc('insert_user', params: {'p_row': data});
      final resultId = outId is String ? outId : id;

      debugPrint('Supabase: User created/upserted: $resultId');
      return resultId;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  /// Update user in Supabase (via SECURITY DEFINER RPC — bypasses GRANT/RLS)
  Future<void> updateUser(String userId, app_user.User user) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      validateUser(user);
      final targetUser = user.id.isNotEmpty ? user : user.copyWith(id: userId);

      debugPrint('Supabase: Updating user $userId');

      final data = convertToSupabaseMap(targetUser.toMap());

      await _client.rpc('update_user', params: {'p_id': userId, 'p_row': data});

      debugPrint('Supabase: User updated: $userId');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  /// Delete user (via SECURITY DEFINER RPC — bypasses GRANT/RLS)
  Future<void> deleteUser(String userId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Deleting user $userId');

      await _client.rpc('delete_user_by_id', params: {'p_id': userId});

      debugPrint('Supabase: User deleted successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Get user by email (via SECURITY DEFINER RPC — bypasses GRANT/RLS)
  Future<app_user.User?> getUserByEmail(String email) async {
    try {
      if (_currentUserId == null) {
        debugPrint(
            'Supabase: getUserByEmail - User not authenticated in Supabase Auth');
        throw Exception('User not authenticated');
      }

      debugPrint(
          'Supabase: Getting user by email: $email (Auth UID: $_currentUserId)');

      final response = await _client.rpc(
        'get_user_by_email',
        params: {'p_email': email.trim()},
      );

      final list = response as List<dynamic>?;
      if (list != null && list.isNotEmpty && list.first != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(list.first as Map));
        data['id'] = (list.first as Map)['id'];
        final user = app_user.User.fromMap(data);
        debugPrint('Supabase: Retrieved user: ${user.name}');
        return user;
      }

      debugPrint('Supabase: User not found with email: $email');
      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting user by email: $e');
      return null;
    }
  }

  /// Get all users (via SECURITY DEFINER RPC — bypasses GRANT/RLS)
  Future<List<app_user.User>> getAllUsers() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all users');

      final response = await _client.rpc('get_users_list');

      final list = response as List<dynamic>? ?? [];
      final users = list.map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc as Map));
        data['id'] = doc['id'];
        return app_user.User.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${users.length} users');
      return users;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting users: $e');
      return [];
    }
  }

  /// Get single user by ID (via SECURITY DEFINER RPC — bypasses GRANT/RLS)
  Future<app_user.User?> getUserById(String userId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting user $userId');

      final response = await _client.rpc(
        'get_user_by_id',
        params: {'p_id': userId},
      );

      final list = response as List<dynamic>?;
      if (list != null && list.isNotEmpty && list.first != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(list.first as Map));
        data['id'] = userId;
        return app_user.User.fromMap(data);
      }

      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting user $userId: $e');
      return null;
    }
  }

  // ============================================================================
  // INVENTORY
  // ============================================================================

  /// Create inventory item in Supabase (deterministic ID = SKU hash)
  Future<String> createInventoryItem(InventoryItem item) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final id = item.id.isNotEmpty && item.id != ''
          ? item.id
          : (item.sku != null && item.sku!.isNotEmpty
              ? DeterministicIdGenerator.generateInventoryId(item.sku!)
              : DateTime.now().millisecondsSinceEpoch.toString());

      debugPrint('Supabase: Upserting inventory item $id');

      final data = convertToSupabaseMap(item.toMap());
      data['id'] = id;

      await _client.from('inventory_items').upsert(data);

      return id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating inventory item: $e');
      throw Exception('Failed to create inventory item: $e');
    }
  }

  /// Get all inventory items
  Future<List<InventoryItem>> getAllInventoryItems() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all inventory items');

      final response = await _client
          .from('inventory_items')
          .select()
          .order('name', ascending: true);

      final items = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return InventoryItem.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${items.length} inventory items');
      return items;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting inventory items: $e');
      return [];
    }
  }

  /// Update inventory item
  Future<void> updateInventoryItem(String itemId, InventoryItem item) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final data = convertToSupabaseMap(item.toMap());

      await _client.from('inventory_items').update(data).eq('id', itemId);
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating inventory item: $e');
      throw Exception('Failed to update inventory item: $e');
    }
  }

  /// Get inventory item by ID
  Future<InventoryItem?> getInventoryItem(String itemId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('inventory_items')
          .select()
          .eq('id', itemId)
          .maybeSingle();

      if (response != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(response));
        data['id'] = itemId;
        return InventoryItem.fromMap(data);
      }
      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting inventory item: $e');
      return null;
    }
  }

  /// Backwards-compatible alias
  Future<InventoryItem?> getInventoryItemById(String itemId) =>
      getInventoryItem(itemId);

  /// Delete inventory item
  Future<void> deleteInventoryItem(String itemId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Deleting inventory item $itemId');

      await _client.from('inventory_items').delete().eq('id', itemId);

      debugPrint('Supabase: Successfully deleted inventory item $itemId');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting inventory item $itemId: $e');
      throw Exception('Failed to delete inventory item: $e');
    }
  }

  // ============================================================================
  // PARTS REQUESTS
  // ============================================================================

  /// Create parts request in Supabase
  Future<String> createPartsRequest(PartsRequest request) async {
    try {
      final requestedBy = _currentUserId;
      if (requestedBy == null) throw Exception('User not authenticated');

      debugPrint('Supabase: Creating parts request ${request.id}');

      final data = convertToSupabaseMap(
        buildPartsRequestInsertPayload(
          request: request,
          requestedBy: requestedBy,
          inventoryItemName: request.inventoryItem?.name,
        ),
      );

      final response =
          await _client.from('parts_requests').insert(data).select('id');

      if (response is! List || response.isEmpty) {
        throw Exception('Failed to create parts request: no row returned');
      }

      final id = response[0]['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString();

      debugPrint('Supabase: Parts request created with ID: $id');
      return id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating parts request: $e');
      throw Exception('Failed to create parts request: $e');
    }
  }

  /// Get all parts requests
  Future<List<PartsRequest>> getAllPartsRequests() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all parts requests');

      final response = await _client
          .from('parts_requests')
          .select()
          .order('createdAt', ascending: false);

      final requests = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return PartsRequest.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${requests.length} parts requests');
      return requests;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting parts requests: $e');
      // Do not return [] — callers must distinguish empty vs failure.
      throw Exception('Failed to get parts requests: $e');
    }
  }

  /// Update parts request (live schema only — see [buildPartsRequestUpdatePayload]).
  Future<void> updatePartsRequest(
    String requestId,
    PartsRequest request,
  ) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final data = convertToSupabaseMap(
        buildPartsRequestUpdatePayload(
          request: request,
          inventoryItemName: request.inventoryItem?.name,
        ),
      );

      final response = await _client
          .from('parts_requests')
          .update(data)
          .eq('id', requestId)
          .select('id');

      if (response is! List || response.isEmpty) {
        throw Exception(
          'Failed to update parts request: no row updated (check RLS/id)',
        );
      }
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating parts request: $e');
      throw Exception('Failed to update parts request: $e');
    }
  }

  // ============================================================================
  // SUPPORT REQUESTS
  // ============================================================================

  /// Create a Be Electric support request in Supabase.
  ///
  /// Expected table: `support_requests` (see docs/SUPPORT_REQUESTS_BACKEND.md).
  Future<String> createSupportRequest(SupportRequest request) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Creating support request ${request.id}');

      final data = convertToSupabaseMap(request.toMap());
      if (request.id.isNotEmpty) {
        data['id'] = request.id;
      }

      final response =
          await _client.from('support_requests').insert(data).select();

      final id = response != null && response.isNotEmpty
          ? response[0]['id'] as String
          : request.id;

      debugPrint('Supabase: Support request created with ID: $id');
      return id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating support request: $e');
      throw Exception('Failed to create support request: $e');
    }
  }

  /// List support requests for the signed-in requestor (RLS also applies).
  Future<List<SupportRequest>> getSupportRequestsForUser(String userId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting support requests for user $userId');

      final response = await _client
          .from('support_requests')
          .select()
          .eq('createdBy', userId)
          .order('createdAt', ascending: false);

      final requests = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return SupportRequest.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${requests.length} support requests');
      return requests;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting support requests: $e');
      throw Exception('Failed to load support requests: $e');
    }
  }

  // ============================================================================
  // PURCHASE ORDERS
  // ============================================================================

  /// Create purchase order in Supabase
  Future<String> createPurchaseOrder(PurchaseOrder order) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Creating purchase order ${order.id}');

      final data = convertToSupabaseMap(order.toMap());
      if (order.id.isNotEmpty) {
        data['id'] = order.id;
      }

      final response =
          await _client.from('purchase_orders').insert(data).select();

      final id = response != null && response.isNotEmpty
          ? response[0]['id'] as String
          : DateTime.now().millisecondsSinceEpoch.toString();

      debugPrint('Supabase: Purchase order created with ID: $id');
      return id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating purchase order: $e');
      throw Exception('Failed to create purchase order: $e');
    }
  }

  /// Get all purchase orders
  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all purchase orders');

      final response = await _client
          .from('purchase_orders')
          .select()
          .order('createdAt', ascending: false);

      final orders = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return PurchaseOrder.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${orders.length} purchase orders');
      return orders;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting purchase orders: $e');
      return [];
    }
  }

  /// Update purchase order
  Future<void> updatePurchaseOrder(String orderId, PurchaseOrder order) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final data = convertToSupabaseMap(order.toMap());

      await _client.from('purchase_orders').update(data).eq('id', orderId);
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating purchase order: $e');
      throw Exception('Failed to update purchase order: $e');
    }
  }

  // ============================================================================
  // REAL-TIME LISTENERS
  // ============================================================================

  /// Listen to work orders changes
  Stream<List<WorkOrder>> listenToWorkOrders() {
    return _client
        .from('work_orders')
        .stream(primaryKey: ['id'])
        .order('createdAt', ascending: false)
        .map((snapshot) {
          return snapshot.map((doc) {
            final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
            final normalizedId =
                DeterministicIdGenerator.normalizeWorkOrderId(doc['id'] ?? '');
            data['id'] = normalizedId;
            final workOrder = WorkOrder.fromMap(data);
            if (normalizedId != doc['id']) {
              return workOrder.copyWith(
                id: normalizedId,
                ticketNumber: normalizedId,
              );
            }
            return workOrder;
          }).toList();
        });
  }

  /// Listen to assets changes
  Stream<List<Asset>> listenToAssets() {
    return _client
        .from('assets')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((snapshot) {
          return snapshot.map((doc) {
            final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
            data['id'] = doc['id'];
            return Asset.fromMap(data);
          }).toList();
        });
  }

  /// Listen to PM tasks changes
  Stream<List<PMTask>> listenToPMTasks() {
    return _client
        .from('pm_tasks')
        .stream(primaryKey: ['id'])
        .order('createdAt', ascending: false)
        .map((snapshot) {
          return snapshot.map((doc) {
            final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
            data['id'] = doc['id'];
            return PMTask.fromMap(data);
          }).toList();
        });
  }

  // ============================================================================
  // QUERY METHODS
  // ============================================================================

  Future<List<WorkOrder>> queryWorkOrders({
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? assignedTechnicianId,
    String? assetId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      var queryBuilder = _client.from('work_orders').select();

      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status.name);
      }
      if (priority != null) {
        queryBuilder = queryBuilder.eq('priority', priority.name);
      }
      if (assignedTechnicianId != null) {
        queryBuilder = queryBuilder
            .contains('assignedTechnicianIds', [assignedTechnicianId]);
      }
      if (assetId != null) {
        queryBuilder = queryBuilder.eq('assetId', assetId);
      }
      if (startDate != null) {
        queryBuilder =
            queryBuilder.gte('createdAt', startDate.toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('createdAt', endDate.toIso8601String());
      }

      final response = await queryBuilder.order('createdAt', ascending: false);

      return (response as List).map((d) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(d));
        final normalizedId =
            DeterministicIdGenerator.normalizeWorkOrderId(d['id'] ?? '');
        data['id'] = normalizedId;
        final workOrder = WorkOrder.fromMap(data);
        if (normalizedId != d['id']) {
          return workOrder.copyWith(
            id: normalizedId,
            ticketNumber: normalizedId,
          );
        }
        return workOrder;
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: queryWorkOrders error: $e');
      return [];
    }
  }

  Future<List<PMTask>> queryPMTasks({
    PMTaskStatus? status,
    String? assignedTechnicianId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDueStart,
    DateTime? nextDueEnd,
  }) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      var queryBuilder = _client.from('pm_tasks').select();

      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status.name);
      }
      if (assignedTechnicianId != null) {
        queryBuilder = queryBuilder
            .contains('assignedTechnicianIds', [assignedTechnicianId]);
      }
      if (startDate != null) {
        queryBuilder =
            queryBuilder.gte('createdAt', startDate.toIso8601String());
      }
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('createdAt', endDate.toIso8601String());
      }
      if (nextDueStart != null) {
        queryBuilder =
            queryBuilder.gte('nextDueDate', nextDueStart.toIso8601String());
      }
      if (nextDueEnd != null) {
        queryBuilder =
            queryBuilder.lte('nextDueDate', nextDueEnd.toIso8601String());
      }

      final response = await queryBuilder.order('createdAt', ascending: false);

      return (response as List).map((d) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(d));
        data['id'] = d['id'];
        return PMTask.fromMap(data);
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: queryPMTasks error: $e');
      return [];
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check Supabase connection (uses users RPC to avoid direct table access)
  Future<bool> checkConnection() async {
    try {
      await _client.rpc('get_users_list');
      return true;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Connection check failed: $e');
      return false;
    }
  }

  /// Test connection (alias for checkConnection)
  Future<bool> testConnection() async => checkConnection();

  /// Load configuration (placeholder)
  Future<void> loadConfiguration() async {
    debugPrint('Supabase: Loading configuration...');
  }

  /// Get configuration status
  Map<String, dynamic> getConfigurationStatus() => {
        'connected': true,
        'initialized': true,
      };

  /// Configure Supabase (placeholder)
  Future<void> configureSupabase({
    required String projectId,
    required String databaseId,
    required String apiKey,
    String? serviceAccountKey,
  }) async {
    debugPrint('Supabase: Configuring Supabase...');
    debugPrint('Project ID: $projectId');
    debugPrint('Database ID: $databaseId');
    debugPrint('API Key: $apiKey');
  }

  /// Clear configuration (placeholder)
  Future<void> clearConfiguration() async {
    debugPrint('Supabase: Clearing configuration...');
  }

  /// Search assets
  Future<List<Asset>> searchAssets(String query) async {
    try {
      final response =
          await _client.from('assets').select().ilike('name', '%$query%');

      return (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return Asset.fromMap(data);
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error searching assets: $e');
      return [];
    }
  }

  /// Clear all data (for testing)
  Future<void> clearAllData() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Clearing all data');

      final collections = [
        'work_orders',
        'assets',
        'pm_tasks',
        'users',
        'inventory_items',
        'parts_requests',
        'purchase_orders',
      ];

      for (final collection in collections) {
        await _client.from(collection).delete().neq('id', '');
      }

      debugPrint('Supabase: All data cleared');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error clearing data: $e');
      throw Exception('Failed to clear data: $e');
    }
  }

  // ============================================================================
  // AUDIT LOGGING
  // ============================================================================

  /// Save audit event to Supabase
  Future<void> saveAuditEvent(AuditEvent event) async {
    try {
      final data = convertToSupabaseMap(event.toMap());
      await _client.from('audit_events').insert(data);
      debugPrint('Supabase: Audit event saved: ${event.id}');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error saving audit event: $e');
      throw Exception('Failed to save audit event: $e');
    }
  }

  /// Get audit events from Supabase
  Future<List<AuditEvent>> getAuditEvents({int? limit}) async {
    try {
      var query = _client
          .from('audit_events')
          .select()
          .order('timestamp', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        return AuditEvent.fromMap(data);
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting audit events: $e');
      throw Exception('Failed to get audit events: $e');
    }
  }

  /// Get audit events by user
  Future<List<AuditEvent>> getAuditEventsByUser(String userId) async {
    try {
      final response = await _client
          .from('audit_events')
          .select()
          .eq('userId', userId)
          .order('timestamp', ascending: false);

      return (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        return AuditEvent.fromMap(data);
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting audit events by user: $e');
      throw Exception('Failed to get audit events by user: $e');
    }
  }

  /// Get audit events by type
  Future<List<AuditEvent>> getAuditEventsByType(String eventType) async {
    try {
      final response = await _client
          .from('audit_events')
          .select()
          .eq('type', eventType)
          .order('timestamp', ascending: false);

      return (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        return AuditEvent.fromMap(data);
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting audit events by type: $e');
      throw Exception('Failed to get audit events by type: $e');
    }
  }

  // ============================================================================
  // ESCALATION EVENTS
  // ============================================================================

  /// Save escalation event to Supabase
  Future<void> saveEscalationEvent(EscalationEvent event) async {
    try {
      final data = {
        'id': event.id,
        'ruleId': event.ruleId,
        'type': event.type.toString().split('.').last,
        'itemId': event.itemId,
        'itemType': event.itemType,
        'currentLevel': event.currentLevel.toString().split('.').last,
        'createdAt': event.createdAt.toIso8601String(),
        'resolvedAt': event.resolvedAt?.toIso8601String(),
        'resolvedBy': event.resolvedBy,
        'notes': event.notes,
        'data': event.data,
      };
      await _client.from('escalation_events').insert(data);
      debugPrint('Supabase: Escalation event saved: ${event.id}');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error saving escalation event: $e');
      throw Exception('Failed to save escalation event: $e');
    }
  }

  /// Get escalation events from Supabase
  Future<List<EscalationEvent>> getEscalationEvents({int? limit}) async {
    try {
      var query = _client
          .from('escalation_events')
          .select()
          .order('createdAt', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return (response as List).map((doc) {
        final data = Map<String, dynamic>.from(doc);
        return EscalationEvent(
          id: data['id'],
          ruleId: data['ruleId'],
          type: EscalationType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
            orElse: () => EscalationType.workOrderOverdue,
          ),
          itemId: data['itemId'],
          itemType: data['itemType'],
          currentLevel: EscalationLevel.values.firstWhere(
            (e) => e.toString().split('.').last == data['currentLevel'],
            orElse: () => EscalationLevel.none,
          ),
          createdAt: DateTime.parse(data['createdAt']),
          resolvedAt: data['resolvedAt'] != null
              ? DateTime.parse(data['resolvedAt'])
              : null,
          resolvedBy: data['resolvedBy'],
          notes: data['notes'],
          data: Map<String, dynamic>.from(data['data'] ?? {}),
        );
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting escalation events: $e');
      throw Exception('Failed to get escalation events: $e');
    }
  }

  // ============================================================================
  // NOTIFICATIONS
  // ============================================================================

  /// Save notification to Supabase
  Future<void> saveNotification(EnhancedNotification notification) async {
    try {
      final data = {
        'id': notification.id,
        'title': notification.title,
        'message': notification.message,
        'type': notification.type.toString().split('.').last,
        'priority': notification.priority.toString().split('.').last,
        'channel': notification.channel.toString().split('.').last,
        'userId': notification.userId,
        'relatedId': notification.relatedId,
        'relatedType': notification.relatedType,
        'createdAt': notification.createdAt.toIso8601String(),
        'isRead': notification.isRead,
        'readAt': notification.readAt?.toIso8601String(),
        'data': notification.data,
        'expiresAt': notification.expiresAt?.toIso8601String(),
        'actions': notification.actions,
      };
      await _client.from('notifications').insert(data);
      debugPrint('Supabase: Notification saved: ${notification.id}');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error saving notification: $e');
      throw Exception('Failed to save notification: $e');
    }
  }

  /// Get notifications from Supabase
  Future<List<EnhancedNotification>> getNotifications({
    int? limit,
    String? userId,
  }) async {
    try {
      var queryBuilder = _client.from('notifications').select();

      if (userId != null) {
        queryBuilder = queryBuilder.eq('userId', userId);
      }

      final orderedQuery = queryBuilder.order('createdAt', ascending: false);

      final response =
          limit != null ? await orderedQuery.limit(limit) : await orderedQuery;
      return (response as List).map((doc) {
        final data = Map<String, dynamic>.from(doc);
        return EnhancedNotification(
          id: data['id'],
          title: data['title'],
          message: data['message'],
          type: NotificationType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
            orElse: () => NotificationType.systemAlert,
          ),
          priority: NotificationPriority.values.firstWhere(
            (e) => e.toString().split('.').last == data['priority'],
            orElse: () => NotificationPriority.medium,
          ),
          channel: NotificationChannel.values.firstWhere(
            (e) => e.toString().split('.').last == data['channel'],
            orElse: () => NotificationChannel.inApp,
          ),
          userId: data['userId'],
          relatedId: data['relatedId'],
          relatedType: data['relatedType'],
          createdAt: DateTime.parse(data['createdAt']),
          isRead: data['isRead'] ?? false,
          readAt:
              data['readAt'] != null ? DateTime.parse(data['readAt']) : null,
          data: data['data'] != null
              ? Map<String, dynamic>.from(data['data'])
              : null,
          expiresAt: data['expiresAt'] != null
              ? DateTime.parse(data['expiresAt'])
              : null,
          actions:
              data['actions'] != null ? List<String>.from(data['actions']) : [],
        );
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  // ============================================================================
  // WORKFLOWS
  // ============================================================================

  /// Create workflow in Supabase
  Future<String> createWorkflow(Workflow workflow) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Creating workflow ${workflow.id}');

      await _client.from('workflows').insert(workflow.toJson());

      debugPrint('Supabase: Workflow created with ID: ${workflow.id}');
      return workflow.id;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating workflow: $e');
      throw Exception('Failed to create workflow: $e');
    }
  }

  /// Update workflow in Supabase
  Future<void> updateWorkflow(String workflowId, Workflow workflow) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Updating workflow $workflowId');

      await _client
          .from('workflows')
          .update(workflow.toJson())
          .eq('id', workflowId);

      debugPrint('Supabase: Workflow updated successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating workflow: $e');
      throw Exception('Failed to update workflow: $e');
    }
  }

  /// Delete workflow from Supabase
  Future<void> deleteWorkflow(String workflowId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Deleting workflow $workflowId');

      await _client.from('workflows').delete().eq('id', workflowId);

      debugPrint('Supabase: Workflow deleted successfully');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting workflow: $e');
      throw Exception('Failed to delete workflow: $e');
    }
  }

  /// Get workflow by ID from Supabase
  Future<Workflow?> getWorkflowById(String workflowId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('workflows')
          .select()
          .eq('id', workflowId)
          .maybeSingle();

      if (response != null) {
        return Workflow.fromJson(response);
      }

      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting workflow: $e');
      return null;
    }
  }

  /// Get all workflows from Supabase
  Future<List<Workflow>> getAllWorkflows() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('workflows')
          .select()
          .order('createdAt', ascending: false);

      return (response as List).map((doc) => Workflow.fromJson(doc)).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting workflows: $e');
      return [];
    }
  }

  /// Get workflows by status
  Future<List<Workflow>> getWorkflowsByStatus(WorkflowStatus status) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('workflows')
          .select()
          .eq('status', status.name)
          .order('createdAt', ascending: false);

      return (response as List).map((doc) => Workflow.fromJson(doc)).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting workflows by status: $e');
      return [];
    }
  }

  /// Get workflows for a specific user
  Future<List<Workflow>> getWorkflowsForUser(String userId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      // Get workflows created by user
      final createdByResponse = await _client
          .from('workflows')
          .select()
          .eq('createdByUserId', userId)
          .order('createdAt', ascending: false);

      // Get workflows assigned to user
      final assignedToResponse = await _client
          .from('workflows')
          .select()
          .eq('assignedToUserId', userId)
          .order('createdAt', ascending: false);

      final workflows = <Workflow>[];
      final workflowIds = <String>{};

      // Add created workflows
      for (final doc in createdByResponse as List) {
        if (!workflowIds.contains(doc['id'])) {
          workflows.add(Workflow.fromJson(doc));
          workflowIds.add(doc['id']);
        }
      }

      // Add assigned workflows
      for (final doc in assignedToResponse as List) {
        if (!workflowIds.contains(doc['id'])) {
          workflows.add(Workflow.fromJson(doc));
          workflowIds.add(doc['id']);
        }
      }

      return workflows;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting workflows for user: $e');
      return [];
    }
  }

  /// Get pending approvals for a user
  Future<List<Workflow>> getPendingApprovalsForUser(String userId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('workflows')
          .select()
          .eq('status', WorkflowStatus.pendingApproval.name)
          .contains('approvers', [userId]).order('createdAt', ascending: false);

      return (response as List).map((doc) => Workflow.fromJson(doc)).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting pending approvals: $e');
      return [];
    }
  }

  // ============================================================================
  // VENDORS
  // ============================================================================

  /// Save vendor to Supabase
  Future<void> saveVendor(Vendor vendor) async {
    try {
      final data = {
        'id': vendor.id,
        'name': vendor.name,
        'contactEmail': vendor.contactEmail,
        'contactPhone': vendor.contactPhone,
        'address': vendor.address,
        'website': vendor.website,
        'rating': vendor.rating,
        'isActive': vendor.isActive,
        'notes': vendor.notes,
      };
      await _client.from('vendors').upsert(data);
      debugPrint('Supabase: Vendor saved: ${vendor.id}');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error saving vendor: $e');
      throw Exception('Failed to save vendor: $e');
    }
  }

  /// Get vendors from Supabase
  Future<List<Vendor>> getVendors() async {
    try {
      final response = await _client.from('vendors').select();

      return (response as List).map((doc) {
        final data = Map<String, dynamic>.from(doc);
        return Vendor(
          id: data['id'],
          name: data['name'],
          contactEmail: data['contactEmail'],
          contactPhone: data['contactPhone'],
          address: data['address'],
          website: data['website'],
          rating: data['rating']?.toDouble(),
          isActive: data['isActive'] ?? true,
          notes: data['notes'],
        );
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting vendors: $e');
      throw Exception('Failed to get vendors: $e');
    }
  }

  // ============================================================================
  // COMPANIES
  // ============================================================================

  /// Get all companies
  Future<List<Company>> getAllCompanies() async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      debugPrint('Supabase: Getting all companies');

      final response = await _client
          .from('companies')
          .select()
          .order('name', ascending: true);

      final companies = (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return Company.fromMap(data);
      }).toList();

      debugPrint('Supabase: Retrieved ${companies.length} companies');
      return companies;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting companies: $e');
      return [];
    }
  }

  /// Create company in Supabase
  Future<String> createCompany(Company company) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      // Check if user is admin or manager using admin_users table (no RLS issues)
      final currentUserEmail = _client.auth.currentUser?.email;
      if (currentUserEmail != null) {
        final adminCheck = await _client
            .from('admin_users')
            .select('is_admin, is_manager')
            .eq('email', currentUserEmail.toLowerCase().trim())
            .maybeSingle();

        debugPrint(
            'Supabase: Admin check result: $adminCheck for email: ${currentUserEmail.toLowerCase().trim()}');

        if (adminCheck == null ||
            (!adminCheck['is_admin'] && !adminCheck['is_manager'])) {
          throw Exception('Only admins and managers can create companies');
        }
      } else {
        throw Exception('User email not found');
      }

      final readableId =
          DeterministicIdGenerator.generateCompanyId(company.name);

      final companyWithId = company.id.isEmpty ||
              !DeterministicIdGenerator.isValidCompanyId(company.id)
          ? company.copyWith(id: readableId)
          : company;

      debugPrint('Supabase: Creating company $readableId');

      final data = convertToSupabaseMap(companyWithId.toMap());
      data['id'] = readableId;

      await _client.from('companies').upsert(data);

      debugPrint('Supabase: Company created/upserted: $readableId');
      return readableId;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error creating company: $e');
      throw Exception('Failed to create company: $e');
    }
  }

  /// Update company in Supabase
  Future<void> updateCompany(String companyId, Company company) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      // Check if user is admin or manager using admin_users table (no RLS issues)
      final currentUserEmail = _client.auth.currentUser?.email;
      if (currentUserEmail != null) {
        final adminCheck = await _client
            .from('admin_users')
            .select('is_admin, is_manager')
            .eq('email', currentUserEmail.toLowerCase().trim())
            .maybeSingle();

        if (adminCheck == null ||
            (!adminCheck['is_admin'] && !adminCheck['is_manager'])) {
          throw Exception('Only admins and managers can update companies');
        }
      } else {
        throw Exception('User email not found');
      }

      debugPrint('Supabase: Updating company $companyId');

      final data = convertToSupabaseMap(company.toMap());
      data['updatedAt'] = DateTime.now().toIso8601String();

      await _client.from('companies').update(data).eq('id', companyId);

      debugPrint('Supabase: Company updated: $companyId');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error updating company: $e');
      throw Exception('Failed to update company: $e');
    }
  }

  /// Delete company in Supabase
  Future<void> deleteCompany(String companyId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      // Check if user is admin or manager using admin_users table (no RLS issues)
      final currentUserEmail = _client.auth.currentUser?.email;
      if (currentUserEmail != null) {
        final adminCheck = await _client
            .from('admin_users')
            .select('is_admin, is_manager')
            .eq('email', currentUserEmail.toLowerCase().trim())
            .maybeSingle();

        if (adminCheck == null ||
            (!adminCheck['is_admin'] && !adminCheck['is_manager'])) {
          throw Exception('Only admins and managers can delete companies');
        }
      } else {
        throw Exception('User email not found');
      }

      debugPrint('Supabase: Deleting company $companyId');

      await _client.from('companies').delete().eq('id', companyId);

      debugPrint('Supabase: Company deleted: $companyId');
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error deleting company: $e');
      throw Exception('Failed to delete company: $e');
    }
  }

  /// Get company by ID
  Future<Company?> getCompanyById(String companyId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('companies')
          .select()
          .eq('id', companyId)
          .maybeSingle();

      if (response != null) {
        final data =
            convertFromSupabaseMap(Map<String, dynamic>.from(response));
        data['id'] = companyId;
        return Company.fromMap(data);
      }

      return null;
    } on Exception catch (e, st) {
      debugPrint('Supabase: Error getting company $companyId: $e');
      return null;
    }
  }

  // ============================================================================
  // PM SCHEDULES + OCCURRENCES (Option A)
  // ============================================================================

  static const String _pmOccurrenceListSelect = '''
id, scheduleId, assetId, dueDate, status, assignedTechnicianIds,
completedAt, completedById, completionPhotoPath, completionNotes,
cancelledAt, cancelledById, cancelReason,
requestorConfirmedAt, requestorConfirmedById,
metadata, createdAt, updatedAt,
schedule:pm_schedules(
  id, taskName, description, frequency, frequencyValue, scheduleStartDate,
  scheduleEndDate, companyId, assignedTechnicianIds, createdById, metadata,
  createdAt, updatedAt
),
asset:assets(id, name, location, manufacturer, model, serialNumber)
''';

  static const String _pmScheduleSelect = '''
id, taskName, description, frequency, frequencyValue, scheduleStartDate,
scheduleEndDate, companyId, assignedTechnicianIds, createdById, metadata,
createdAt, updatedAt
''';

  PmOccurrence _mapPmOccurrenceRow(Map<String, dynamic> doc) {
    final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
    data['id'] = doc['id'];
    return PmOccurrence.fromMap(data);
  }

  String _formatDateOnly(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }

  Future<List<PmOccurrence>> getAssignedPmOccurrences(
    String technicianId,
  ) async {
    return queryPmOccurrences(assignedTechnicianId: technicianId);
  }

  Future<PmOccurrence?> getPmOccurrenceById(String occurrenceId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('pm_task_occurrences')
          .select(_pmOccurrenceListSelect)
          .eq('id', occurrenceId)
          .maybeSingle();

      if (response == null) return null;
      return _mapPmOccurrenceRow(Map<String, dynamic>.from(response));
    } on Exception catch (e, st) {
      debugPrint('Supabase: getPmOccurrenceById error: $e');
      return null;
    }
  }

  Future<List<PmOccurrence>> queryPmOccurrences({
    String? assignedTechnicianId,
    String? assetId,
    String? companyId,
    String? scheduleId,
    String? storedStatus,
    DateTime? dueStart,
    DateTime? dueEnd,
  }) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      var queryBuilder = _client
          .from('pm_task_occurrences')
          .select(_pmOccurrenceListSelect);

      if (assignedTechnicianId != null && assignedTechnicianId.isNotEmpty) {
        queryBuilder = queryBuilder.contains(
          'assignedTechnicianIds',
          [assignedTechnicianId],
        );
      }
      if (assetId != null && assetId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('assetId', assetId);
      }
      if (scheduleId != null && scheduleId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('scheduleId', scheduleId);
      }
      if (storedStatus != null && storedStatus.isNotEmpty) {
        queryBuilder = queryBuilder.eq('status', storedStatus);
      }
      if (dueStart != null) {
        queryBuilder =
            queryBuilder.gte('dueDate', _formatDateOnly(dueStart));
      }
      if (dueEnd != null) {
        queryBuilder = queryBuilder.lte('dueDate', _formatDateOnly(dueEnd));
      }

      final response = await queryBuilder.order('dueDate', ascending: true);
      var rows = (response as List)
          .map(
            (doc) => _mapPmOccurrenceRow(Map<String, dynamic>.from(doc as Map)),
          )
          .toList();

      if (companyId != null && companyId.isNotEmpty) {
        rows = rows
            .where(
              (occurrence) => occurrence.schedule?.companyId == companyId,
            )
            .toList();
      }

      return rows;
    } on Exception catch (e, st) {
      debugPrint('Supabase: queryPmOccurrences error: $e');
      return [];
    }
  }

  Future<List<PmSchedule>> queryPmSchedules({String? companyId}) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      var queryBuilder = _client.from('pm_schedules').select(_pmScheduleSelect);
      if (companyId != null && companyId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('companyId', companyId);
      }

      final response =
          await queryBuilder.order('createdAt', ascending: false);

      return (response as List).map((doc) {
        final data = convertFromSupabaseMap(Map<String, dynamic>.from(doc));
        data['id'] = doc['id'];
        return PmSchedule.fromMap(data);
      }).toList();
    } on Exception catch (e, st) {
      debugPrint('Supabase: queryPmSchedules error: $e');
      return [];
    }
  }

  Future<PmSchedule?> getPmScheduleById(String scheduleId) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final response = await _client
          .from('pm_schedules')
          .select(_pmScheduleSelect)
          .eq('id', scheduleId)
          .maybeSingle();

      if (response == null) return null;

      final data = convertFromSupabaseMap(Map<String, dynamic>.from(response));
      data['id'] = scheduleId;
      return PmSchedule.fromMap(data);
    } on Exception catch (e, st) {
      debugPrint('Supabase: getPmScheduleById error: $e');
      return null;
    }
  }

  Future<void> completePmOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    String? completionPhotoPath,
  }) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final trimmedNotes = completionNotes?.trim();
      await _client.from('pm_task_occurrences').update({
        'status': 'completed',
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'completedById': completedById,
        'completionNotes':
            trimmedNotes == null || trimmedNotes.isEmpty ? null : trimmedNotes,
        'completionPhotoPath': completionPhotoPath,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', occurrenceId);
    } on Exception catch (e, st) {
      debugPrint('Supabase: completePmOccurrence error: $e');
      throw Exception('Failed to complete PM occurrence: $e');
    }
  }

  Future<void> confirmPmOccurrenceForRequestor({
    required String occurrenceId,
    required String requestorId,
  }) async {
    try {
      if (!_isAuthenticated) throw Exception('User not authenticated');

      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('pm_task_occurrences').update({
        'requestorConfirmedAt': now,
        'requestorConfirmedById': requestorId,
        'updatedAt': now,
      }).eq('id', occurrenceId);
    } on Exception catch (e, st) {
      debugPrint('Supabase: confirmPmOccurrenceForRequestor error: $e');
      throw Exception('Failed to confirm PM occurrence: $e');
    }
  }
}
