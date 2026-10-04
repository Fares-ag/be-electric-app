import 'dart:convert';


import '../utils/deterministic_id_generator.dart';
import 'asset.dart';
import 'user.dart';

enum PMTaskStatus { pending, inProgress, completed, overdue, cancelled }

enum PMTaskFrequency {
  daily,
  weekly,
  monthly,
  quarterly,
  semiAnnually,
  annually,
  asNeeded,
}

/// Legacy preventive maintenance task (`pm_tasks` table).
///
/// **Freeze policy (Option A migration):** maintenance-only — bug fixes and
/// RLS/security patches allowed. Do not add new fields, provider methods,
/// screens, or write paths here. New PM work uses `pm_schedules` +
/// `pm_task_occurrences` surfaced via [PmWorkItem].
class PMTask {
  PMTask({
    required this.id,
    required this.taskName,
    this.assetId = '',
    required this.description,
    required this.frequency,
    required this.intervalDays,
    required this.createdAt,
    this.idempotencyKey,
    this.asset,
    this.assetName,
    this.assetLocation,
    this.photoPath,
    this.checklist,
    this.lastCompletedAt,
    this.nextDueDate,
    this.primaryTechnicianId,
    List<String>? assignedTechnicianIds,
    this.assignedTechnicians,
    Map<String, int>? technicianEffortMinutes,
    this.status = PMTaskStatus.pending,
    this.startedAt,
    this.completedAt,
    this.completionNotes,
    this.technicianSignature,
    this.isOffline = false,
    this.lastSyncedAt,
    this.laborCost,
    this.partsCost,
    this.totalCost,
    this.updatedAt,
    // Pause/Resume fields
    this.isPaused = false,
    this.pausedAt,
    this.pauseReason,
    this.resumedAt,
    this.pauseHistory,
    // Completion History - stores multiple completion records for recurring PM tasks
    this.completionHistory,
    // Creator tracking
    this.createdById,
    this.createdBy,
  })  : assignedTechnicianIds = assignedTechnicianIds ?? <String>[],
        technicianEffortMinutes = technicianEffortMinutes != null
            ? Map<String, int>.from(technicianEffortMinutes)
            : null;

  /// Create PMTask from data map
  factory PMTask.fromMap(Map<String, dynamic> data) => PMTask(
        id: data['id'] ??
            DeterministicIdGenerator.generatePMTaskId(
              idempotencyKey: data['idempotencyKey'],
              title: data['taskName'],
              assetId: data['assetId'],
            ),
        taskName: data['taskName'] ?? '',
        assetId: data['assetId'] ?? '',
        assetName: data['assetName'],
        assetLocation: data['assetLocation'],
        description: data['description'] ?? '',
        photoPath: data['photoPath'],
        checklist: data['checklist'],
        frequency: PMTaskFrequency.values.firstWhere(
          (e) => e.name == data['frequency'],
          orElse: () => PMTaskFrequency.monthly,
        ),
        intervalDays: data['intervalDays'] ?? 30,
        lastCompletedAt: _parseFirestoreDate(data['lastCompletedAt']),
        nextDueDate: _parseFirestoreDate(data['nextDueDate']),
        primaryTechnicianId: data['primaryTechnicianId'] as String? ??
            data['assignedTechnicianId'] as String?,
        assignedTechnicianIds: _parseTechnicianIdList(data),
        technicianEffortMinutes: _parseTechnicianEffortMap(
          data['technicianEffortMinutes'],
          fallbackTechnicianId: data['assignedTechnicianId'] as String?,
        ),
        status: PMTaskStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => PMTaskStatus.pending,
        ),
        createdAt: _parseFirestoreDate(data['createdAt']) ?? DateTime.now(),
        idempotencyKey: data['idempotencyKey'],
        startedAt: _parseFirestoreDate(data['startedAt']),
        completedAt: _parseFirestoreDate(data['completedAt']),
        completionNotes: data['completionNotes'],
        technicianSignature: data['technicianSignature'],
        isOffline: _parseBoolFromDynamic(data['isOffline']) ?? false,
        lastSyncedAt: _parseFirestoreDate(data['lastSyncedAt']),
        laborCost: data['laborCost']?.toDouble(),
        partsCost: data['partsCost']?.toDouble(),
        totalCost: data['totalCost']?.toDouble(),
        updatedAt: _parseFirestoreDate(data['updatedAt']) ?? DateTime.now(),
        // Pause/Resume fields
        isPaused: _parseBoolFromDynamic(data['isPaused']) ?? false,
        pausedAt: _parseFirestoreDate(data['pausedAt']),
        pauseReason: data['pauseReason'],
        resumedAt: _parseFirestoreDate(data['resumedAt']),
        pauseHistory: _parsePauseHistory(data['pauseHistory']),
        completionHistory: _parseCompletionHistory(data['completionHistory']),
        createdById: data['createdById'] as String?,
      );

  /// Create a new PM task with idempotency key
  factory PMTask.create({
    required String taskName,
    String assetId = '',
    required String description,
    required PMTaskFrequency frequency,
    required int intervalDays,
    List<String>? assignedTechnicianIds,
    String? assignedTechnicianId, // deprecated single-assignment support
    String? sourceId,
  }) {
    final now = DateTime.now();
    final idempotencyKey = sourceId != null
        ? DeterministicIdGenerator.generateIdempotencyKey(
            type: 'pm',
            sourceId: sourceId,
            timestamp: now,
          )
        : null;
    final ids = <String>[];
    if (assignedTechnicianIds != null) {
      ids.addAll(assignedTechnicianIds.where((id) => id.isNotEmpty));
    }
    if (assignedTechnicianId != null && assignedTechnicianId.isNotEmpty) {
      ids.add(assignedTechnicianId);
    }
    final primaryId = ids.isNotEmpty ? ids.first : null;
    return PMTask(
      id: DeterministicIdGenerator.generatePMTaskId(
        idempotencyKey: idempotencyKey,
        title: taskName,
        assetId: assetId,
      ),
      taskName: taskName,
      assetId: assetId,
      description: description,
      frequency: frequency,
      intervalDays: intervalDays,
      createdAt: now,
      idempotencyKey: idempotencyKey,
      primaryTechnicianId: primaryId,
      assignedTechnicianIds: ids,
    );
  }

  /// Helper method to parse DateTime from Supabase (ISO8601 string) or DateTime
  static DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Safely parse boolean from dynamic value
  /// Handles: bool, int (0/1), null
  static bool? _parseBoolFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1; // 0 â†’ false, 1 â†’ true
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  /// Safely parse completion history from dynamic value
  /// Handles: List<Map>, String "[]", null
  static List<Map<String, dynamic>>? _parseCompletionHistory(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      try {
        return List<Map<String, dynamic>>.from(
          value.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } catch (e) {
        return null;
      }
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return List<Map<String, dynamic>>.from(
            decoded.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Safely parse pause history from dynamic value
  /// Handles: List<Map>, String "[]", null
  static List<Map<String, dynamic>>? _parsePauseHistory(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      try {
        return List<Map<String, dynamic>>.from(
          value.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      } catch (e) {
        return null;
      }
    }
    if (value is String) {
      // Handle string "[]" stored in Firestore
      if (value == '[]' || value.isEmpty) return null;
    }
    return null;
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      try {
        return List<String>.from(value);
      } catch (_) {
        return null;
      }
    }
    if (value is String && value.isNotEmpty) {
      return <String>[value];
    }
    return null;
  }

  static List<String> _parseTechnicianIdList(Map<String, dynamic> data) {
    final raw = _parseStringList(data['assignedTechnicianIds']);
    if (raw != null && raw.isNotEmpty) return raw;
    final single = data['assignedTechnicianId'] as String?;
    return single != null ? <String>[single] : <String>[];
  }

  static Map<String, int>? _parseTechnicianEffortMap(
    dynamic value, {
    String? fallbackTechnicianId,
  }) {
    if (value == null) {
      return fallbackTechnicianId != null
          ? <String, int>{fallbackTechnicianId: 0}
          : null;
    }
    if (value is Map) {
      try {
        return value.map(
          (key, val) => MapEntry(
            key.toString(),
            val is num ? val.toInt() : int.tryParse(val.toString()) ?? 0,
          ),
        );
      } catch (_) {
        return fallbackTechnicianId != null
            ? <String, int>{fallbackTechnicianId: 0}
            : null;
      }
    }
    return fallbackTechnicianId != null
        ? <String, int>{fallbackTechnicianId: 0}
        : null;
  }

  final String id;
  final String taskName;
  final String assetId;
  final String? idempotencyKey;
  final Asset? asset;
  final String? assetName; // For quick display without needing asset object
  final String? assetLocation; // For quick display without needing asset object
  final String description;
  final String? photoPath; // Creation photo (optional)
  final String? checklist;
  final PMTaskFrequency frequency;
  final int intervalDays;
  final DateTime? lastCompletedAt;
  final DateTime? nextDueDate;
  final String? primaryTechnicianId;
  final List<String> assignedTechnicianIds;
  final List<User>? assignedTechnicians;
  final Map<String, int>? technicianEffortMinutes;
  final PMTaskStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionNotes;
  final String? technicianSignature;
  final bool isOffline;
  final DateTime? lastSyncedAt;
  final double? laborCost;
  final double? partsCost;
  final double? totalCost;
  final DateTime? updatedAt;
  // Pause/Resume fields
  final bool isPaused;
  final DateTime? pausedAt;
  final String? pauseReason;
  final DateTime? resumedAt;
  final List<Map<String, dynamic>>? pauseHistory;
  // Completion History - stores multiple completion records for recurring PM tasks
  final List<Map<String, dynamic>>? completionHistory;
  // Creator tracking
  final String? createdById;
  final User? createdBy;

  String? get assignedTechnicianId =>
      primaryTechnicianId ??
      (assignedTechnicianIds.isNotEmpty ? assignedTechnicianIds.first : null);

  User? get assignedTechnician =>
      assignedTechnicians != null && assignedTechnicians!.isNotEmpty
          ? assignedTechnicians!.first
          : null;

  int technicianMinutesFor(String technicianId) =>
      technicianEffortMinutes?[technicianId] ?? 0;

  bool hasTechnician(String technicianId) =>
      assignedTechnicianIds.contains(technicianId);

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskName': taskName,
        'assetId': assetId,
        'assetName': assetName,
        'assetLocation': assetLocation,
        'description': description,
        'photoPath': photoPath,
        'checklist': checklist,
        'frequency': frequency.name,
        'intervalDays': intervalDays,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
        'nextDueDate': nextDueDate?.toIso8601String(),
        'primaryTechnicianId': primaryTechnicianId ??
            (assignedTechnicianIds.isNotEmpty
                ? assignedTechnicianIds.first
                : null),
        'assignedTechnicianId': primaryTechnicianId ??
            (assignedTechnicianIds.isNotEmpty
                ? assignedTechnicianIds.first
                : null),
        'assignedTechnicianIds': assignedTechnicianIds,
        'technicianEffortMinutes': technicianEffortMinutes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'completionNotes': completionNotes,
        'technicianSignature': technicianSignature,
        'isOffline': isOffline ? 1 : 0,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'laborCost': laborCost,
        'partsCost': partsCost,
        'totalCost': totalCost,
        'updatedAt': updatedAt?.toIso8601String(),
        // Pause/Resume fields
        'isPaused': isPaused ? 1 : 0,
        'pausedAt': pausedAt?.toIso8601String(),
        'pauseReason': pauseReason,
        'resumedAt': resumedAt?.toIso8601String(),
        'pauseHistory': pauseHistory,
        'completionHistory': completionHistory,
        'createdById': createdById,
      };

  PMTask copyWith({
    String? id,
    String? taskName,
    String? assetId,
    Asset? asset,
    String? assetName,
    String? assetLocation,
    String? description,
    String? photoPath,
    String? checklist,
    PMTaskFrequency? frequency,
    int? intervalDays,
    DateTime? lastCompletedAt,
    DateTime? nextDueDate,
    String? primaryTechnicianId,
    List<String>? assignedTechnicianIds,
    List<User>? assignedTechnicians,
    Map<String, int>? technicianEffortMinutes,
    String? assignedTechnicianId,
    User? assignedTechnician,
    PMTaskStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completionNotes,
    String? technicianSignature,
    bool? isOffline,
    DateTime? lastSyncedAt,
    double? laborCost,
    double? partsCost,
    double? totalCost,
    DateTime? updatedAt,
    bool? isPaused,
    DateTime? pausedAt,
    String? pauseReason,
    DateTime? resumedAt,
    List<Map<String, dynamic>>? pauseHistory,
    List<Map<String, dynamic>>? completionHistory,
    String? createdById,
    User? createdBy,
  }) =>
      PMTask(
        id: id ?? this.id,
        taskName: taskName ?? this.taskName,
        assetId: assetId ?? this.assetId,
        asset: asset ?? this.asset,
        assetName: assetName ?? this.assetName,
        assetLocation: assetLocation ?? this.assetLocation,
        description: description ?? this.description,
        photoPath: photoPath ?? this.photoPath,
        checklist: checklist ?? this.checklist,
        frequency: frequency ?? this.frequency,
        intervalDays: intervalDays ?? this.intervalDays,
        lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        primaryTechnicianId: primaryTechnicianId ??
            assignedTechnicianId ??
            this.primaryTechnicianId ??
            ((assignedTechnicianIds ?? this.assignedTechnicianIds).isNotEmpty
                ? (assignedTechnicianIds ?? this.assignedTechnicianIds).first
                : null),
        assignedTechnicianIds: assignedTechnicianIds ??
            (assignedTechnicianId != null
                ? <String>[assignedTechnicianId]
                : this.assignedTechnicianIds),
        assignedTechnicians: assignedTechnicians ??
            (assignedTechnician != null
                ? <User>[assignedTechnician]
                : this.assignedTechnicians),
        technicianEffortMinutes:
            technicianEffortMinutes ?? this.technicianEffortMinutes,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        completionNotes: completionNotes ?? this.completionNotes,
        technicianSignature: technicianSignature ?? this.technicianSignature,
        isOffline: isOffline ?? this.isOffline,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        laborCost: laborCost ?? this.laborCost,
        partsCost: partsCost ?? this.partsCost,
        totalCost: totalCost ?? this.totalCost,
        updatedAt: updatedAt ?? this.updatedAt,
        isPaused: isPaused ?? this.isPaused,
        pausedAt: pausedAt ?? this.pausedAt,
        pauseReason: pauseReason ?? this.pauseReason,
        resumedAt: resumedAt ?? this.resumedAt,
        pauseHistory: pauseHistory ?? this.pauseHistory,
        completionHistory: completionHistory ?? this.completionHistory,
        createdById: createdById ?? this.createdById,
        createdBy: createdBy ?? this.createdBy,
      );

  String get statusDisplayName {
    switch (status) {
      case PMTaskStatus.pending:
        return 'Pending';
      case PMTaskStatus.inProgress:
        return 'In Progress';
      case PMTaskStatus.completed:
        return 'Completed';
      case PMTaskStatus.overdue:
        return 'Overdue';
      case PMTaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get frequencyDisplayName {
    switch (frequency) {
      case PMTaskFrequency.daily:
        return 'Daily';
      case PMTaskFrequency.weekly:
        return 'Weekly';
      case PMTaskFrequency.monthly:
        return 'Monthly';
      case PMTaskFrequency.quarterly:
        return 'Quarterly';
      case PMTaskFrequency.semiAnnually:
        return 'Semi-Annually';
      case PMTaskFrequency.annually:
        return 'Annually';
      case PMTaskFrequency.asNeeded:
        return 'As Needed';
    }
  }

  bool get isPending => status == PMTaskStatus.pending;
  bool get isInProgress => status == PMTaskStatus.inProgress;
  bool get isCompleted => status == PMTaskStatus.completed;
  bool get isOverdue =>
      status == PMTaskStatus.overdue ||
      (nextDueDate != null &&
          DateTime.now().isAfter(nextDueDate!) &&
          status != PMTaskStatus.completed);
  bool get isCancelled => status == PMTaskStatus.cancelled;

  bool get isDueToday =>
      nextDueDate != null &&
      DateTime.now().difference(nextDueDate!).inDays == 0;

  bool get isDueSoon =>
      nextDueDate != null &&
      DateTime.now().difference(nextDueDate!).inDays <= 3 &&
      DateTime.now().difference(nextDueDate!).inDays >= 0;

  // Convenience getters for technician information
  String? get assignedTechnicianName => assignedTechnician?.name;

  // Additional getters for compatibility
  DateTime? get nextDue => nextDueDate;
  String? get notes => completionNotes;

  /// Convert PMTask to Firestore map
  Map<String, dynamic> toFirestoreMap() => {
        'id': id,
        'idempotencyKey': idempotencyKey,
        'taskName': taskName,
        'assetId': assetId,
        'description': description,
        'photoPath': photoPath,
        'checklist': checklist,
        'frequency': frequency.name,
        'intervalDays': intervalDays,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
        'nextDueDate': nextDueDate?.toIso8601String(),
        'primaryTechnicianId': primaryTechnicianId ??
            (assignedTechnicianIds.isNotEmpty
                ? assignedTechnicianIds.first
                : null),
        'assignedTechnicianId': primaryTechnicianId ??
            (assignedTechnicianIds.isNotEmpty
                ? assignedTechnicianIds.first
                : null),
        'assignedTechnicianIds': assignedTechnicianIds,
        'technicianEffortMinutes': technicianEffortMinutes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'completionNotes': completionNotes,
        'technicianSignature': technicianSignature,
        'isOffline': isOffline,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'laborCost': laborCost,
        'partsCost': partsCost,
        'totalCost': totalCost,
        'updatedAt': updatedAt?.toIso8601String(),
        'isPaused': isPaused,
        'pausedAt': pausedAt?.toIso8601String(),
        'pauseReason': pauseReason,
        'resumedAt': resumedAt?.toIso8601String(),
        'pauseHistory': pauseHistory,
        'completionHistory': completionHistory,
        'createdById': createdById,
      };
}
