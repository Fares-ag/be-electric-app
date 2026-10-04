import 'pm_task.dart';

/// Admin-created PM schedule template (`pm_schedules` table).
class PmSchedule {
  PmSchedule({
    required this.id,
    required this.taskName,
    required this.frequency,
    required this.frequencyValue,
    required this.scheduleStartDate,
    required this.scheduleEndDate,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.companyId,
    List<String>? assignedTechnicianIds,
    this.createdById,
    this.metadata,
  }) : assignedTechnicianIds = List<String>.from(assignedTechnicianIds ?? const []);

  factory PmSchedule.fromMap(Map<String, dynamic> data) {
    return PmSchedule(
      id: data['id'] as String? ?? '',
      taskName: data['taskName'] as String? ?? '',
      description: data['description'] as String?,
      frequency: PMTaskFrequency.values.firstWhere(
        (value) => value.name == data['frequency'],
        orElse: () => PMTaskFrequency.monthly,
      ),
      frequencyValue: (data['frequencyValue'] as num?)?.toInt() ?? 30,
      scheduleStartDate:
          _parseDate(data['scheduleStartDate']) ?? DateTime.now(),
      scheduleEndDate: _parseDate(data['scheduleEndDate']) ?? DateTime.now(),
      companyId: data['companyId'] as String?,
      assignedTechnicianIds: _parseStringList(data['assignedTechnicianIds']),
      createdById: data['createdById'] as String?,
      metadata: _parseMetadata(data['metadata']),
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String taskName;
  final String? description;
  final PMTaskFrequency frequency;
  final int frequencyValue;
  final DateTime scheduleStartDate;
  final DateTime scheduleEndDate;
  final String? companyId;
  final List<String> assignedTechnicianIds;
  final String? createdById;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get checklist {
    final raw = metadata?['checklist'];
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskName': taskName,
        'description': description,
        'frequency': frequency.name,
        'frequencyValue': frequencyValue,
        'scheduleStartDate': scheduleStartDate.toIso8601String(),
        'scheduleEndDate': scheduleEndDate.toIso8601String(),
        'companyId': companyId,
        'assignedTechnicianIds': assignedTechnicianIds,
        'createdById': createdById,
        'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
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
