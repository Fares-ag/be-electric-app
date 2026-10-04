import '../config/app_config.dart';
import '../utils/pm_occurrence_display_status.dart';
import 'pm_schedule.dart';

/// Stored occurrence status in `pm_task_occurrences.status`.
enum PmOccurrenceStoredStatus {
  pending,
  completed,
  overdue,
  cancelled,
}

/// Executable PM unit (`pm_task_occurrences` table).
class PmOccurrence {
  PmOccurrence({
    required this.id,
    required this.scheduleId,
    required this.assetId,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    List<String>? assignedTechnicianIds,
    this.completedAt,
    this.completedById,
    this.completionNotes,
    this.completionPhotoPath,
    this.cancelledAt,
    this.cancelledById,
    this.cancelReason,
    this.requestorConfirmedAt,
    this.requestorConfirmedById,
    this.metadata,
    this.schedule,
    this.assetName,
    this.assetLocation,
    this.assetManufacturer,
    this.assetModel,
    this.assetSerialNumber,
  }) : assignedTechnicianIds =
            List<String>.from(assignedTechnicianIds ?? const []);

  factory PmOccurrence.fromMap(Map<String, dynamic> data) {
    final scheduleRaw = data['schedule'];
    final schedule = scheduleRaw is Map
        ? PmSchedule.fromMap(Map<String, dynamic>.from(scheduleRaw))
        : null;

    final assetRaw = data['asset'];
    Map<String, dynamic>? assetMap;
    if (assetRaw is Map) {
      assetMap = Map<String, dynamic>.from(assetRaw);
    }

    return PmOccurrence(
      id: data['id'] as String? ?? '',
      scheduleId: data['scheduleId'] as String? ?? '',
      assetId: data['assetId'] as String? ?? '',
      dueDate: _parseDate(data['dueDate']) ?? DateTime.now(),
      status: _parseStoredStatus(data['status']),
      assignedTechnicianIds: _parseStringList(data['assignedTechnicianIds']),
      completedAt: _parseDate(data['completedAt']),
      completedById: data['completedById'] as String?,
      completionNotes: data['completionNotes'] as String?,
      completionPhotoPath: data['completionPhotoPath'] as String?,
      cancelledAt: _parseDate(data['cancelledAt']),
      cancelledById: data['cancelledById'] as String?,
      cancelReason: data['cancelReason'] as String?,
      requestorConfirmedAt: _parseDate(data['requestorConfirmedAt']),
      requestorConfirmedById: data['requestorConfirmedById'] as String?,
      metadata: _parseMetadata(data['metadata']),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
      schedule: schedule,
      assetName: assetMap?['name'] as String? ?? data['assetName'] as String?,
      assetLocation:
          assetMap?['location'] as String? ?? data['assetLocation'] as String?,
      assetManufacturer: assetMap?['manufacturer'] as String? ??
          data['assetManufacturer'] as String?,
      assetModel: assetMap?['model'] as String? ?? data['assetModel'] as String?,
      assetSerialNumber: assetMap?['serialNumber'] as String? ??
          data['assetSerialNumber'] as String?,
    );
  }

  final String id;
  final String scheduleId;
  final String assetId;
  final DateTime dueDate;
  final PmOccurrenceStoredStatus status;
  final List<String> assignedTechnicianIds;
  final DateTime? completedAt;
  final String? completedById;
  final String? completionNotes;
  final String? completionPhotoPath;
  final DateTime? cancelledAt;
  final String? cancelledById;
  final String? cancelReason;
  final DateTime? requestorConfirmedAt;
  final String? requestorConfirmedById;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PmSchedule? schedule;
  final String? assetName;
  final String? assetLocation;
  final String? assetManufacturer;
  final String? assetModel;
  final String? assetSerialNumber;

  String get taskName => schedule?.taskName ?? '';

  String? get description => schedule?.description;

  List<String> get checklist => schedule?.checklist ?? const [];

  bool get isRequestorConfirmed => requestorConfirmedAt != null;

  PmOccurrence copyWith({
    DateTime? requestorConfirmedAt,
    String? requestorConfirmedById,
    DateTime? updatedAt,
  }) =>
      PmOccurrence(
        id: id,
        scheduleId: scheduleId,
        assetId: assetId,
        dueDate: dueDate,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        assignedTechnicianIds: assignedTechnicianIds,
        completedAt: completedAt,
        completedById: completedById,
        completionNotes: completionNotes,
        completionPhotoPath: completionPhotoPath,
        cancelledAt: cancelledAt,
        cancelledById: cancelledById,
        cancelReason: cancelReason,
        requestorConfirmedAt: requestorConfirmedAt ?? this.requestorConfirmedAt,
        requestorConfirmedById:
            requestorConfirmedById ?? this.requestorConfirmedById,
        metadata: metadata,
        schedule: schedule,
        assetName: assetName,
        assetLocation: assetLocation,
        assetManufacturer: assetManufacturer,
        assetModel: assetModel,
        assetSerialNumber: assetSerialNumber,
      );

  PmOccurrenceDisplayStatus displayStatus({DateTime? referenceDate}) {
    return deriveOccurrenceDisplayStatus(
      storedStatus: status.name,
      dueDate: dueDate,
      referenceDate: referenceDate,
    );
  }

  /// Resolves a storage path or legacy public URL for display/download.
  String? get completionPhotoReference {
    final value = completionPhotoPath?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = AppConfig.supabaseUrl.trim();
    if (base.isEmpty) return value;
    return '$base/storage/v1/object/public/files/$value';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'scheduleId': scheduleId,
        'assetId': assetId,
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
        'assignedTechnicianIds': assignedTechnicianIds,
        'completedAt': completedAt?.toIso8601String(),
        'completedById': completedById,
        'completionNotes': completionNotes,
        'completionPhotoPath': completionPhotoPath,
        'cancelledAt': cancelledAt?.toIso8601String(),
        'cancelledById': cancelledById,
        'cancelReason': cancelReason,
        'requestorConfirmedAt': requestorConfirmedAt?.toIso8601String(),
        'requestorConfirmedById': requestorConfirmedById,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (schedule != null) 'schedule': schedule!.toMap(),
        if (assetName != null) 'assetName': assetName,
        if (assetLocation != null) 'assetLocation': assetLocation,
        if (assetManufacturer != null) 'assetManufacturer': assetManufacturer,
        if (assetModel != null) 'assetModel': assetModel,
        if (assetSerialNumber != null) 'assetSerialNumber': assetSerialNumber,
      };
}

PmOccurrenceStoredStatus _parseStoredStatus(dynamic value) {
  final raw = value?.toString().trim().toLowerCase() ?? 'pending';
  return PmOccurrenceStoredStatus.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => PmOccurrenceStoredStatus.pending,
  );
}

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

Map<String, dynamic>? _parseMetadata(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
