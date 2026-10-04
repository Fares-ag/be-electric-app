// Offline Queue Service
// Manages queued operations for offline scenarios with retry logic

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parts_request.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../config/app_config.dart';
import '../config/locator.dart';
import '../utils/offline_network.dart';
import '../utils/offline_sync_utils.dart';
import '../utils/parts_request_supabase_payload.dart';
import '../utils/sync_queue_migration.dart';
import 'supabase_database_service.dart';
import 'supabase_storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum OperationType {
  createWorkOrder,
  updateWorkOrder,
  createPMTask,
  updatePMTask,
  createPartsRequest,
  uploadPhoto,
  assignTechnician,
  completeWorkOrder,
  completePMTask,
}

class QueuedOperation {
  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory QueuedOperation.fromMap(Map<String, dynamic> map) =>
      QueuedOperation(
        id: map['id'],
        type: OperationType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => OperationType.createWorkOrder,
        ),
        data: Map<String, dynamic>.from(map['data']),
        createdAt: DateTime.parse(map['createdAt']),
        retryCount: map['retryCount'] ?? 0,
        lastError: map['lastError'],
      );

  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;
  String? lastError;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
      };
}

class OfflineQueueService extends ChangeNotifier {
  OfflineQueueService();

  static OfflineQueueService? _instance;
  static OfflineQueueService get instance => _instance ??= OfflineQueueService();

  static const String _queueKey = 'offline_operation_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  bool _isProcessingQueue = false;
  Future<void>? _processQueueInFlight;
  List<QueuedOperation> _memoryQueue = [];

  /// Increments whenever the queue mutates so UI can refresh pending-sync badges.
  final ValueNotifier<int> queueRevision = ValueNotifier<int>(0);

  void _notifyQueueChanged() {
    queueRevision.value++;
    notifyListeners();
  }

  String? _lastConflictMessage;
  String? get lastConflictMessage => _lastConflictMessage;

  void clearLastConflictMessage() {
    _lastConflictMessage = null;
    notifyListeners();
  }

  /// Snapshot of pending work-order / PM-task IDs for UI indicators.
  Future<OfflineSyncSnapshot> getSyncSnapshot() async {
    final queue = _initialized ? _memoryQueue : await _loadQueue();
    return buildOfflineSyncSnapshot(queue);
  }


  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await migrateLegacySyncQueueIfNeeded();
    _memoryQueue = await _loadQueue();
    _initialized = true;
    _notifyQueueChanged();
    debugPrint(
      'OfflineQueueService: initialized (${_memoryQueue.length} pending)',
    );
  }

  /// Add operation to queue (with duplicate prevention)
  Future<void> enqueue(QueuedOperation operation) async {
    final queue = await _loadQueue();
    
    // Check for duplicate operations to prevent duplicates
    // For create/update operations, check if same ID already exists
    if (operation.type == OperationType.createWorkOrder ||
        operation.type == OperationType.updateWorkOrder ||
        operation.type == OperationType.completeWorkOrder ||
        operation.type == OperationType.completePMTask ||
        operation.type == OperationType.createPMTask ||
        operation.type == OperationType.updatePMTask ||
        operation.type == OperationType.createPartsRequest) {
      final existingOp = queue.firstWhere(
        (op) => op.id == operation.id && op.type == operation.type,
        orElse: () => QueuedOperation(
          id: '',
          type: OperationType.createWorkOrder,
          data: {},
          createdAt: DateTime.now(),
        ),
      );
      
      // If duplicate found, replace it with the newer operation
      if (existingOp.id.isNotEmpty) {
        debugPrint(
          '⚠️ Offline Queue: Duplicate operation detected for ${operation.type.name} '
          '(${operation.id}) - replacing with newer operation',
        );
        queue.removeWhere((op) => op.id == operation.id && op.type == operation.type);
      }
    }
    
    // For photo uploads, check if same file is already queued
    if (operation.type == OperationType.uploadPhoto) {
      final filePath = operation.data['filePath'] as String?;
      if (filePath != null) {
        final existingPhotoOp = queue.firstWhere(
          (op) => op.type == OperationType.uploadPhoto &&
              op.data['filePath'] == filePath,
          orElse: () => QueuedOperation(
            id: '',
            type: OperationType.createWorkOrder,
            data: {},
            createdAt: DateTime.now(),
          ),
        );
        
        if (existingPhotoOp.id.isNotEmpty) {
          debugPrint(
            '⚠️ Offline Queue: Duplicate photo upload detected for $filePath - replacing',
          );
          queue.removeWhere(
            (op) => op.type == OperationType.uploadPhoto &&
                op.data['filePath'] == filePath,
          );
        }
      }
    }

    // Atomic work-order completion supersedes legacy photo + update pairs.
    if (operation.type == OperationType.completeWorkOrder) {
      final workOrderMap = operation.data['workOrder'];
      final workOrderId = workOrderMap is Map
          ? workOrderMap['id'] as String?
          : null;
      if (workOrderId != null) {
        final removed = queue.length;
        queue.removeWhere(
          (op) =>
              (op.type == OperationType.uploadPhoto &&
                  op.data['workOrderId'] == workOrderId) ||
              (op.type == OperationType.updateWorkOrder && op.id == workOrderId) ||
              (op.type == OperationType.completeWorkOrder &&
                  op.data['workOrder'] is Map &&
                  (op.data['workOrder'] as Map)['id'] == workOrderId),
        );
        if (queue.length < removed) {
          debugPrint(
            '♻️ Offline Queue: Replaced legacy completion ops for $workOrderId '
            'with atomic completeWorkOrder',
          );
        }
      }
    }

    // Atomic PM completion supersedes legacy photo + update pairs.
    if (operation.type == OperationType.completePMTask) {
      final pmTaskMap = operation.data['pmTask'];
      final pmTaskId = pmTaskMap is Map ? pmTaskMap['id'] as String? : null;
      if (pmTaskId != null) {
        final removed = queue.length;
        queue.removeWhere(
          (op) =>
              (op.type == OperationType.uploadPhoto &&
                  op.data['pmTaskId'] == pmTaskId) ||
              (op.type == OperationType.updatePMTask && op.id == pmTaskId) ||
              (op.type == OperationType.completePMTask &&
                  op.data['pmTask'] is Map &&
                  (op.data['pmTask'] as Map)['id'] == pmTaskId),
        );
        if (queue.length < removed) {
          debugPrint(
            '♻️ Offline Queue: Replaced legacy completion ops for $pmTaskId '
            'with atomic completePMTask',
          );
        }
      }
    }
    
    queue.add(operation);
    await _saveQueue(queue);
    _memoryQueue = queue;
    _notifyQueueChanged();
    debugPrint(
      '📦 Offline Queue: Enqueued ${operation.type.name} (${queue.length} pending)',
    );
  }

  /// Remove operation from queue (after successful execution)
  Future<void> dequeue(String operationId) async {
    final queue = await _loadQueue();
    queue.removeWhere((op) => op.id == operationId);
    await _saveQueue(queue);
    _memoryQueue = queue;
    _notifyQueueChanged();
    debugPrint('✅ Offline Queue: Removed operation $operationId');
  }

  /// Returns how many operations are waiting to sync (cheap prefs read).
  Future<int> pendingOperationCount() async {
    final queue = await _loadQueue();
    return queue.length;
  }

  /// Process all queued operations. Concurrent callers await the same in-flight run.
  Future<void> processQueue() async {
    final inFlight = _processQueueInFlight;
    if (inFlight != null) {
      debugPrint(
        '📦 Offline Queue: Awaiting in-flight processing from concurrent caller',
      );
      return inFlight;
    }

    final run = _runProcessQueue();
    _processQueueInFlight = run;
    try {
      await run;
    } finally {
      if (_processQueueInFlight == run) {
        _processQueueInFlight = null;
      }
    }
  }

  Future<void> _runProcessQueue() async {
    if (!AppConfig.isOfflineModeEnabled) return;
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    try {
      await _processQueueInternal();
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _processQueueInternal() async {
    final queue = await _loadQueue();
    if (queue.isEmpty) {
      debugPrint('📦 Offline Queue: No operations to process');
      return;
    }

    debugPrint('🔄 Offline Queue: Processing ${queue.length} operations...');

    final processed = <String>[];
    final failed = <QueuedOperation>[];

    for (final operation in queue) {
      try {
        final success = await _executeOperation(operation);
        if (success) {
          processed.add(operation.id);
        } else {
          if (operation.retryCount < _maxRetries) {
            operation.retryCount++;
            failed.add(operation);
            debugPrint(
              '⚠️ Offline Queue: Operation ${operation.id} failed, '
              'will retry (attempt ${operation.retryCount}/$_maxRetries)',
            );
          } else {
            debugPrint(
              '❌ Offline Queue: Operation ${operation.id} failed after '
              '$_maxRetries retries. Last error: ${operation.lastError}',
            );
            // Could send to dead letter queue or notify admin
          }
        }
      } catch (e) {
        operation.lastError = e.toString();
        if (operation.retryCount < _maxRetries) {
          operation.retryCount++;
          failed.add(operation);
        } else {
          debugPrint(
            '❌ Offline Queue: Operation ${operation.id} exception after '
            '$_maxRetries retries: $e',
          );
        }
      }

      // Add delay between retries
      if (operation.retryCount > 0) {
        await Future.delayed(_retryDelay);
      }
    }

    // Remove processed operations
    queue.removeWhere((op) => processed.contains(op.id));
    
    // Update failed operations
    for (final operation in failed) {
      final index = queue.indexWhere((op) => op.id == operation.id);
      if (index != -1) {
        queue[index] = operation;
      }
    }

    await _saveQueue(queue);
    _memoryQueue = queue;
    
    debugPrint(
      '✅ Offline Queue: Processed ${processed.length}, '
      'Failed ${failed.length}, Remaining ${queue.length}',
    );
    _notifyQueueChanged();
  }

  /// Execute a single operation
  Future<bool> _executeOperation(QueuedOperation operation) async {
    try {
      debugPrint(
        '🔄 Offline Queue: Executing ${operation.type.name} (${operation.id})',
      );
      
      switch (operation.type) {
        case OperationType.createWorkOrder:
          return await _executeCreateWorkOrder(operation);
        
        case OperationType.updateWorkOrder:
          return await _executeUpdateWorkOrder(operation);
        
        case OperationType.createPMTask:
          return await _executeCreatePMTask(operation);
        
        case OperationType.updatePMTask:
          return await _executeUpdatePMTask(operation);
        
        case OperationType.createPartsRequest:
          return await _executeCreatePartsRequest(operation);
        
        case OperationType.uploadPhoto:
          return await _executeUploadPhoto(operation);
        
        case OperationType.assignTechnician:
          return await _executeAssignTechnician(operation);
        
        case OperationType.completeWorkOrder:
          return await _executeCompleteWorkOrder(operation);

        case OperationType.completePMTask:
          return await _executeCompletePMTask(operation);
      }
    } catch (e) {
      debugPrint('❌ Offline Queue: Error executing ${operation.type.name}: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Normalize pending photo paths from queue payload (multi + legacy single).
  static List<String> normalizePendingPhotoPaths(Map<String, dynamic> data) {
    final multi = data['pendingPhotoFilePaths'];
    if (multi is List) {
      return multi.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    final single = data['pendingPhotoFilePath'] as String?;
    if (single != null && single.isNotEmpty) return [single];
    return [];
  }

  /// Extract work-order map from create/update/complete queue payloads.
  static Map<String, dynamic> workOrderMapFromQueueData(
    Map<String, dynamic> data,
  ) {
    final nested = data['workOrder'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return Map<String, dynamic>.from(data);
  }

  /// Execute create work order operation
  Future<bool> _executeCreateWorkOrder(QueuedOperation operation) async {
    try {
      var workOrder =
          WorkOrder.fromMap(workOrderMapFromQueueData(operation.data));
      final pendingPaths = normalizePendingPhotoPaths(operation.data);

      if (pendingPaths.isNotEmpty) {
        final storageService = sl<SupabaseStorageService>();
        await storageService.loadConfiguration();
        final uploadedUrls = <String>[];
        for (final path in pendingPaths) {
          final file = await _getFileFromPath(path);
          if (file == null) {
            operation.lastError = 'Create photo file not found: $path';
            debugPrint('❌ Offline Queue: ${operation.lastError}');
            return false;
          }
          final url = await storageService.uploadWorkOrderPhoto(
            photoFile: file,
            workOrderId: workOrder.id,
          );
          if (url == null) {
            operation.lastError = 'Create photo upload returned null URL';
            debugPrint('❌ Offline Queue: ${operation.lastError}');
            return false;
          }
          uploadedUrls.add(url);
        }
        workOrder = workOrder.copyWith(
          photoPaths: uploadedUrls,
          photoPath: uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
          isOffline: false,
        );
      }
      
      // Idempotency check: Verify work order doesn't already exist
      try {
        final existing = await sl<SupabaseDatabaseService>().getWorkOrder(workOrder.id);
        if (existing != null) {
          debugPrint(
            '⚠️ Offline Queue: Work order ${workOrder.ticketNumber} already exists - skipping duplicate',
          );
          return true; // Consider it successful since it already exists
        }
      } catch (e) {
        // If getWorkOrder fails, continue with creation
        debugPrint('⚠️ Offline Queue: Could not check for existing work order: $e');
      }
      
      // Create in Supabase
      await sl<SupabaseDatabaseService>().createWorkOrder(workOrder);
      
      debugPrint('✅ Offline Queue: Created work order ${workOrder.ticketNumber}');
      return true;
    } catch (e) {
      // Check if error is due to duplicate (unique constraint violation)
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('unique') ||
          errorString.contains('duplicate') ||
          errorString.contains('already exists') ||
          errorString.contains('23505')) { // PostgreSQL unique violation code
        debugPrint(
          '⚠️ Offline Queue: Work order already exists (duplicate detected) - skipping',
        );
        return true; // Consider it successful since it already exists
      }
      
      debugPrint('❌ Offline Queue: Failed to create work order: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Returns true when [value] is a remote Supabase/storage URL, not a device path.
  static bool isRemoteStorageUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Execute update work order operation
  Future<bool> _executeUpdateWorkOrder(QueuedOperation operation) async {
    try {
      if (operation.data['_legacySupabasePayload'] == true) {
        return _executeLegacyWorkOrderUpdate(operation);
      }

      // Reconstruct WorkOrder from stored data
      var workOrder = WorkOrder.fromMap(operation.data);

      // Legacy queues may still carry a local filesystem path after a photo
      // upload already wrote a remote URL — never regress the remote value.
      if (!isRemoteStorageUrl(workOrder.completionPhotoPath) &&
          workOrder.status == WorkOrderStatus.completed) {
        try {
          final existing =
              await sl<SupabaseDatabaseService>().getWorkOrder(workOrder.id);
          if (isRemoteStorageUrl(existing?.completionPhotoPath)) {
            workOrder = workOrder.copyWith(
              completionPhotoPath: existing!.completionPhotoPath,
            );
            debugPrint(
              '♻️ Offline Queue: Preserved remote completion photo URL for '
              '${workOrder.ticketNumber}',
            );
          }
        } catch (e) {
          debugPrint(
            '⚠️ Offline Queue: Could not guard completion photo URL: $e',
          );
        }
      }
      
      // Update in Supabase
      await sl<SupabaseDatabaseService>().updateWorkOrder(
        workOrder.id,
        workOrder,
      );
      
      debugPrint('✅ Offline Queue: Updated work order ${workOrder.ticketNumber}');
      return true;
    } catch (e) {
      debugPrint('❌ Offline Queue: Failed to update work order: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute create PM task operation
  Future<bool> _executeCreatePMTask(QueuedOperation operation) async {
    try {
      final pmTask = PMTask.fromMap(operation.data);

      try {
        final existing =
            await sl<SupabaseDatabaseService>().getPMTaskById(pmTask.id);
        if (existing != null) {
          debugPrint(
            '⚠️ Offline Queue: PM task ${pmTask.taskName} already exists - skipping duplicate',
          );
          return true;
        }
      } catch (e) {
        debugPrint('⚠️ Offline Queue: Could not check for existing PM task: $e');
      }

      await sl<SupabaseDatabaseService>().createPMTask(pmTask);

      debugPrint('✅ Offline Queue: Created PM task ${pmTask.taskName}');
      return true;
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('unique') ||
          errorString.contains('duplicate') ||
          errorString.contains('already exists') ||
          errorString.contains('23505')) {
        debugPrint(
          '⚠️ Offline Queue: PM task already exists (duplicate detected) - skipping',
        );
        return true;
      }

      debugPrint('❌ Offline Queue: Failed to create PM task: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute update PM task operation
  Future<bool> _executeUpdatePMTask(QueuedOperation operation) async {
    try {
      var pmTask = PMTask.fromMap(operation.data);

      // Legacy queues may carry a local photo path in the latest completion
      // history entry after upload already wrote a remote URL.
      final history = pmTask.completionHistory;
      if (history != null && history.isNotEmpty) {
        final last = Map<String, dynamic>.from(history.last);
        final photoPath = last['completionPhotoPath'] as String?;
        if (!isRemoteStorageUrl(photoPath)) {
          try {
            final existing =
                await sl<SupabaseDatabaseService>().getPMTaskById(pmTask.id);
            final existingHistory = existing?.completionHistory;
            if (existingHistory != null && existingHistory.isNotEmpty) {
              final remotePhoto =
                  existingHistory.last['completionPhotoPath'] as String?;
              if (isRemoteStorageUrl(remotePhoto)) {
                last['completionPhotoPath'] = remotePhoto;
                final patched = List<Map<String, dynamic>>.from(history);
                patched[patched.length - 1] = last;
                pmTask = pmTask.copyWith(completionHistory: patched);
                debugPrint(
                  '♻️ Offline Queue: Preserved remote PM completion photo URL',
                );
              }
            }
          } catch (e) {
            debugPrint('⚠️ Offline Queue: Could not load PM task for photo guard: $e');
          }
        }
      }

      await sl<SupabaseDatabaseService>().updatePMTask(
        pmTask.id,
        pmTask,
      );

      debugPrint('✅ Offline Queue: Updated PM task ${pmTask.taskName}');
      return true;
    } catch (e) {
      debugPrint('❌ Offline Queue: Failed to update PM task: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute create parts request operation
  Future<bool> _executeCreatePartsRequest(QueuedOperation operation) async {
    try {
      final request = PartsRequest.fromMap(operation.data);

      await sl<SupabaseDatabaseService>().createPartsRequest(request);

      debugPrint('✅ Offline Queue: Created parts request ${request.id}');
      return true;
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('unique') ||
          errorString.contains('duplicate') ||
          errorString.contains('23505')) {
        debugPrint(
          '⚠️ Offline Queue: Parts request already exists - skipping',
        );
        return true;
      }

      debugPrint('❌ Offline Queue: Failed to create parts request: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute photo upload operation
  Future<bool> _executeUploadPhoto(QueuedOperation operation) async {
    try {
      final filePath = operation.data['filePath'] as String?;
      final fileName = operation.data['fileName'] as String?;
      final folder = operation.data['folder'] as String?;
      final workOrderId = operation.data['workOrderId'] as String?;
      final photoType = operation.data['photoType'] as String?;
      
      if (filePath == null || fileName == null) {
        debugPrint('❌ Offline Queue: Missing photo upload data');
        return false;
      }
      
      // Check if file still exists
      final file = await _getFileFromPath(filePath);
      if (file == null) {
        debugPrint('❌ Offline Queue: Photo file not found: $filePath');
        return false;
      }
      
      // Upload to Supabase Storage
      final storageService = sl<SupabaseStorageService>();
      await storageService.loadConfiguration();
      
      String? url;
      
      // Handle completion photos specially
      if (photoType == 'completion' && workOrderId != null) {
        url = await storageService.uploadCompletionPhoto(
          photoFile: file,
          workOrderId: workOrderId,
          photoType: 'completion',
        );
      } else {
        // Generic file upload
        if (folder == null) {
          debugPrint('❌ Offline Queue: Missing folder for generic photo upload');
          return false;
        }
        url = await storageService.uploadFile(
          file: file,
          fileName: fileName,
          folder: folder,
        );
      }
      
      if (url != null) {
        debugPrint('✅ Offline Queue: Uploaded photo: $url');
        
        // If this is a completion photo, update the work order with the URL
        if (photoType == 'completion' && workOrderId != null) {
          try {
            final workOrder = await sl<SupabaseDatabaseService>().getWorkOrder(workOrderId);
            if (workOrder != null) {
              final updatedWorkOrder = workOrder.copyWith(
                completionPhotoPath: url,
              );
              await sl<SupabaseDatabaseService>().updateWorkOrder(
                workOrderId,
                updatedWorkOrder,
              );
              debugPrint('✅ Offline Queue: Updated work order with completion photo URL');
            }
          } catch (e) {
            debugPrint('⚠️ Offline Queue: Could not update work order with photo URL: $e');
            // Don't fail the operation - photo is uploaded successfully
          }
        }
        
        return true;
      } else {
        debugPrint('❌ Offline Queue: Photo upload returned null URL');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Offline Queue: Failed to upload photo: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute assign technician operation
  Future<bool> _executeAssignTechnician(QueuedOperation operation) async {
    try {
      final workOrderId = operation.data['workOrderId'] as String?;
      final technicianId = operation.data['technicianId'] as String?;
      
      if (workOrderId == null || technicianId == null) {
        debugPrint('❌ Offline Queue: Missing assignment data');
        return false;
      }
      
      // Get work order and update
      final workOrder = await sl<SupabaseDatabaseService>().getWorkOrder(workOrderId);
      if (workOrder == null) {
        debugPrint('❌ Offline Queue: Work order not found: $workOrderId');
        return false;
      }
      
      // Add technician to assigned list
      final assignedIds = List<String>.from(workOrder.assignedTechnicianIds);
      if (!assignedIds.contains(technicianId)) {
        assignedIds.add(technicianId);
      }
      
      final updatedWorkOrder = workOrder.copyWith(
        assignedTechnicianIds: assignedIds,
        primaryTechnicianId: assignedIds.isNotEmpty ? assignedIds.first : workOrder.primaryTechnicianId,
        assignedAt: workOrder.assignedAt ?? DateTime.now().toUtc(),
        status: workOrder.status == WorkOrderStatus.open
            ? WorkOrderStatus.assigned
            : workOrder.status,
      );
      
      await sl<SupabaseDatabaseService>().updateWorkOrder(
        workOrderId,
        updatedWorkOrder,
      );
      
      debugPrint('✅ Offline Queue: Assigned technician $technicianId to work order $workOrderId');
      return true;
    } catch (e) {
      debugPrint('❌ Offline Queue: Failed to assign technician: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute complete work order operation (atomic: optional photo upload + update).
  Future<bool> _executeCompleteWorkOrder(QueuedOperation operation) async {
    try {
      final workOrderRaw = operation.data['workOrder'];
      if (workOrderRaw is! Map) {
        debugPrint('❌ Offline Queue: completeWorkOrder missing workOrder payload');
        return false;
      }

      var workOrder = WorkOrder.fromMap(workOrderMapFromQueueData(operation.data));
      final pendingPaths = normalizePendingPhotoPaths(operation.data);

      if (pendingPaths.isNotEmpty) {
        final storageService = sl<SupabaseStorageService>();
        await storageService.loadConfiguration();
        final uploadedUrls = <String>[];
        for (final path in pendingPaths) {
          final file = await _getFileFromPath(path);
          if (file == null) {
            operation.lastError = 'Completion photo file not found: $path';
            debugPrint('❌ Offline Queue: ${operation.lastError}');
            return false;
          }
          final url = await storageService.uploadCompletionPhoto(
            photoFile: file,
            workOrderId: workOrder.id,
            photoType: 'completion',
          );
          if (url == null) {
            operation.lastError = 'Completion photo upload returned null URL';
            debugPrint('❌ Offline Queue: ${operation.lastError}');
            return false;
          }
          uploadedUrls.add(url);
        }

        workOrder = workOrder.copyWith(
          completionPhotoPaths: uploadedUrls,
          completionPhotoPath: uploadedUrls.isNotEmpty ? uploadedUrls.first : null,
        );
        debugPrint(
          '✅ Offline Queue: Uploaded ${uploadedUrls.length} completion photo(s) '
          'for ${workOrder.ticketNumber}',
        );
      } else if (!isRemoteStorageUrl(workOrder.completionPhotoPath)) {
        // No pending file and no remote URL — clear stale local path before write.
        workOrder = workOrder.copyWith(completionPhotoPath: null);
      }

      await sl<SupabaseDatabaseService>().updateWorkOrder(
        workOrder.id,
        workOrder,
      );

      debugPrint(
        '✅ Offline Queue: Atomically completed work order ${workOrder.ticketNumber}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Offline Queue: Failed to complete work order: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Execute complete PM task operation (atomic: optional photo upload + update).
  Future<bool> _executeCompletePMTask(QueuedOperation operation) async {
    try {
      final pmTaskRaw = operation.data['pmTask'];
      if (pmTaskRaw is! Map) {
        debugPrint('❌ Offline Queue: completePMTask missing pmTask payload');
        return false;
      }

      var pmTask = PMTask.fromMap(Map<String, dynamic>.from(pmTaskRaw));
      final pendingPhotoPath = operation.data['pendingPhotoFilePath'] as String?;

      if (pendingPhotoPath != null) {
        final file = await _getFileFromPath(pendingPhotoPath);
        if (file == null) {
          operation.lastError =
              'PM completion photo file not found: $pendingPhotoPath';
          debugPrint('❌ Offline Queue: ${operation.lastError}');
          return false;
        }

        final storageService = sl<SupabaseStorageService>();
        await storageService.loadConfiguration();
        final uploadedUrl = await storageService.uploadPMTaskCompletionPhoto(
          photoFile: file,
          pmTaskId: pmTask.id,
        );

        if (uploadedUrl == null) {
          operation.lastError = 'PM completion photo upload returned null URL';
          debugPrint('❌ Offline Queue: ${operation.lastError}');
          return false;
        }

        final history = List<Map<String, dynamic>>.from(
          pmTask.completionHistory ?? const [],
        );
        if (history.isNotEmpty) {
          final last = Map<String, dynamic>.from(history.last);
          last['completionPhotoPath'] = uploadedUrl;
          history[history.length - 1] = last;
          pmTask = pmTask.copyWith(completionHistory: history);
        }

        debugPrint(
          '✅ Offline Queue: Uploaded PM completion photo for ${pmTask.taskName}: '
          '$uploadedUrl',
        );
      } else {
        final history = pmTask.completionHistory;
        if (history != null && history.isNotEmpty) {
          final last = Map<String, dynamic>.from(history.last);
          final photoPath = last['completionPhotoPath'] as String?;
          if (!isRemoteStorageUrl(photoPath)) {
            try {
              final existing =
                  await sl<SupabaseDatabaseService>().getPMTaskById(pmTask.id);
              final existingHistory = existing?.completionHistory;
              if (existingHistory != null && existingHistory.isNotEmpty) {
                final remotePhoto =
                    existingHistory.last['completionPhotoPath'] as String?;
                if (isRemoteStorageUrl(remotePhoto)) {
                  last['completionPhotoPath'] = remotePhoto;
                  final patched = List<Map<String, dynamic>>.from(history);
                  patched[patched.length - 1] = last;
                  pmTask = pmTask.copyWith(completionHistory: patched);
                }
              }
            } catch (e) {
              debugPrint(
                '⚠️ Offline Queue: Could not load PM task for photo guard: $e',
              );
            }
          }
        }
      }

      await sl<SupabaseDatabaseService>().updatePMTask(pmTask.id, pmTask);

      debugPrint(
        '✅ Offline Queue: Atomically completed PM task ${pmTask.taskName}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ Offline Queue: Failed to complete PM task: $e');
      operation.lastError = e.toString();
      return false;
    }
  }

  /// Get file from path (handles both local and network paths)
  Future<XFile?> _getFileFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return XFile(filePath);
      } else {
        debugPrint('⚠️ Offline Queue: File not found: $filePath');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Offline Queue: Error getting file from path: $e');
      return null;
    }
  }

  /// Load queue from storage
  Future<List<QueuedOperation>> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      if (queueJson == null) return [];

      final List<dynamic> queueList = jsonDecode(queueJson);
      return queueList
          .map((item) => QueuedOperation.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Offline Queue: Error loading queue: $e');
      return [];
    }
  }

  /// Save queue to storage
  Future<void> _saveQueue(List<QueuedOperation> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(queue.map((op) => op.toMap()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      debugPrint('❌ Offline Queue: Error saving queue: $e');
    }
  }

  /// Work-order snapshots embedded in pending queue ops (for cold-start cache rehydrate).
  Future<List<WorkOrder>> workOrderSnapshotsFromQueue() async {
    final queue = await _loadQueue();
    final snapshots = <String, WorkOrder>{};
    for (final op in queue) {
      if (op.type == OperationType.updateWorkOrder) {
        final wo = WorkOrder.fromMap(workOrderMapFromQueueData(op.data));
        snapshots[wo.id] = wo;
      } else if (op.type == OperationType.createWorkOrder) {
        final wo = WorkOrder.fromMap(workOrderMapFromQueueData(op.data));
        snapshots[wo.id] = wo;
      } else if (op.type == OperationType.completeWorkOrder) {
        final woRaw = op.data['workOrder'];
        if (woRaw is Map) {
          final wo = WorkOrder.fromMap(Map<String, dynamic>.from(woRaw));
          snapshots[wo.id] = wo;
        }
      }
    }
    return snapshots.values.toList();
  }

  /// PM-task snapshots embedded in pending queue ops (for cold-start cache rehydrate).
  Future<List<PMTask>> pmTaskSnapshotsFromQueue() async {
    final queue = await _loadQueue();
    final snapshots = <String, PMTask>{};
    for (final op in queue) {
      if (op.type == OperationType.updatePMTask) {
        final pm = PMTask.fromMap(Map<String, dynamic>.from(op.data));
        snapshots[pm.id] = pm;
      } else if (op.type == OperationType.completePMTask) {
        final pmRaw = op.data['pmTask'];
        if (pmRaw is Map) {
          final pm = PMTask.fromMap(Map<String, dynamic>.from(pmRaw));
          snapshots[pm.id] = pm;
        }
      } else if (op.type == OperationType.createPMTask) {
        final pm = PMTask.fromMap(Map<String, dynamic>.from(op.data));
        snapshots[pm.id] = pm;
      }
    }
    return snapshots.values.toList();
  }

  /// True when [pmTaskId] has a pending offline mutation (update or complete).
  Future<bool> hasPendingMutationForPMTask(String pmTaskId) async {
    final queue = await _loadQueue();
    for (final op in queue) {
      if (op.type == OperationType.updatePMTask && op.id == pmTaskId) {
        return true;
      }
      if (op.type == OperationType.createPMTask && op.id == pmTaskId) {
        return true;
      }
      if (op.type == OperationType.completePMTask) {
        final pm = op.data['pmTask'];
        if (pm is Map && pm['id'] == pmTaskId) return true;
        if (op.id == 'complete_$pmTaskId') return true;
      }
    }
    return false;
  }

  /// True when [workOrderId] has a pending offline mutation (update or complete).
  Future<bool> hasPendingMutationForWorkOrder(String workOrderId) async {
    final queue = await _loadQueue();
    for (final op in queue) {
      if (op.type == OperationType.updateWorkOrder && op.id == workOrderId) {
        return true;
      }
      if (op.type == OperationType.createWorkOrder && op.id == workOrderId) {
        return true;
      }
      if (op.type == OperationType.completeWorkOrder) {
        final wo = op.data['workOrder'];
        if (wo is Map && wo['id'] == workOrderId) return true;
        if (op.id == 'complete_$workOrderId') return true;
      }
    }
    return false;
  }

  /// Get queue status
  Future<Map<String, dynamic>> getQueueStatus() async {
    final queue = await _loadQueue();
    return {
      'pending': queue.length,
      'operations': queue.map((op) => op.toMap()).toList(),
      'byType': _groupByType(queue),
    };
  }

  /// Group operations by type
  Map<String, int> _groupByType(List<QueuedOperation> queue) {
    final grouped = <String, int>{};
    for (final op in queue) {
      grouped[op.type.name] = (grouped[op.type.name] ?? 0) + 1;
    }
    return grouped;
  }

  /// Clear all queued operations (use with caution)
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    _memoryQueue = [];
    _notifyQueueChanged();
    debugPrint('🗑️ Offline Queue: Cleared all operations');
  }

  Future<bool> _executeLegacyWorkOrderUpdate(QueuedOperation operation) async {
    try {
      var data = Map<String, dynamic>.from(
        Map<String, dynamic>.from(operation.data['payload'] as Map),
      );
      final entityId = data['id']?.toString() ?? operation.id;
      final pendingPaths = normalizePendingPhotoPaths(operation.data);

      if (pendingPaths.isNotEmpty) {
        final storage = sl<SupabaseStorageService>();
        final urls = <String>[];
        for (final path in pendingPaths) {
          if (!isLocalFilePath(path)) {
            if (path.isNotEmpty) urls.add(path);
            continue;
          }
          final url = await storage.uploadCompletionPhoto(
            photoFile: XFile(path),
            workOrderId: entityId,
            photoType: 'completion',
          );
          if (url == null || url.isEmpty) {
            operation.lastError = 'Photo upload returned empty URL for $path';
            return false;
          }
          urls.add(url);
        }
        final meta = data['metadata'] is Map
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : <String, dynamic>{};
        final existing = (meta['completionPhotoPaths'] as List?)
                ?.map((e) => e.toString())
                .where((p) => !isLocalFilePath(p))
                .toList() ??
            <String>[];
        meta['completionPhotoPaths'] = <String>{...existing, ...urls}.toList();
        data['metadata'] = meta;
      }

      final updateBody = Map<String, dynamic>.from(data)..remove('id');
      await Supabase.instance.client
          .from('work_orders')
          .update(updateBody)
          .eq('id', entityId);
      return true;
    } catch (e) {
      operation.lastError = e.toString();
      debugPrint('❌ Offline Queue: Legacy WO update failed: $e');
      return false;
    }
  }

  Future<void> enqueueWorkOrderUpdate(
    WorkOrder workOrder, {
    List<String>? localPhotoPaths,
  }) async {
    final data = workOrder.toMap();
    if (localPhotoPaths != null && localPhotoPaths.isNotEmpty) {
      data['pendingPhotoFilePaths'] = localPhotoPaths;
    }
    await enqueue(
      QueuedOperation(
        id: workOrder.id,
        type: OperationType.updateWorkOrder,
        data: data,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> enqueuePartsRequestCreate(
    PartsRequest request, {
    required String requestedBy,
  }) async {
    final data = buildPartsRequestInsertPayload(
      request: request,
      requestedBy: requestedBy,
      inventoryItemName: request.inventoryItem?.name,
    );
    await enqueue(
      QueuedOperation(
        id: request.id,
        type: OperationType.createPartsRequest,
        data: data,
        createdAt: DateTime.now(),
      ),
    );
  }

  List<QueuedOperation> getPendingOperations() =>
      List<QueuedOperation>.unmodifiable(_memoryQueue);

  Future<List<QueuedOperation>> loadPendingOperations() async {
    _memoryQueue = await _loadQueue();
    return getPendingOperations();
  }

  int get pendingCount => _memoryQueue.length;

  Future<int> getPendingCount() async => pendingCount;

  int get failedCount => _memoryQueue
      .where((op) => op.retryCount >= _maxRetries && op.lastError != null)
      .length;

  Future<List<QueuedOperation>> getFailedOperations() async {
    final queue = await _loadQueue();
    return queue
        .where((op) => op.retryCount >= _maxRetries && op.lastError != null)
        .toList();
  }

  Future<void> retryFailedOperation(String operationId) async {
    final queue = await _loadQueue();
    final index = queue.indexWhere((op) => op.id == operationId);
    if (index < 0) return;
    queue[index].retryCount = 0;
    queue[index].lastError = null;
    await _saveQueue(queue);
    _memoryQueue = queue;
    _notifyQueueChanged();
    await processQueue();
  }

  Future<void> discardOperation(String operationId) async {
    await dequeue(operationId);
  }

  /// Adapter for legacy sync queue status screen rows.
  List<SyncQueueDisplayOperation> getDisplayOperations() =>
      _memoryQueue
          .map(
            (op) => SyncQueueDisplayOperation(
              id: op.id,
              typeName: op.type.name,
              collection: _collectionForType(op.type),
              retryCount: op.retryCount,
              error: op.lastError,
              failed: op.retryCount >= _maxRetries && op.lastError != null,
              localPhotoPaths: OfflineQueueService.normalizePendingPhotoPaths(
                op.data,
              ),
            ),
          )
          .toList();

  static String _collectionForType(OperationType type) {
    switch (type) {
      case OperationType.createWorkOrder:
      case OperationType.updateWorkOrder:
      case OperationType.completeWorkOrder:
        return 'work_orders';
      case OperationType.createPMTask:
      case OperationType.updatePMTask:
      case OperationType.completePMTask:
        return 'pm_tasks';
      case OperationType.createPartsRequest:
        return 'parts_requests';
      default:
        return type.name;
    }
  }
}

class SyncQueueDisplayOperation {
  SyncQueueDisplayOperation({
    required this.id,
    required this.typeName,
    required this.collection,
    required this.retryCount,
    this.error,
    this.failed = false,
    this.localPhotoPaths = const [],
  });

  final String id;
  final String typeName;
  final String collection;
  final int retryCount;
  final String? error;
  final bool failed;
  final List<String> localPhotoPaths;
}

