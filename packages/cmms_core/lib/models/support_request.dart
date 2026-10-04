import 'package:uuid/uuid.dart';

enum SupportRequestType {
  knowHow,
  commissioning,
}

enum SupportRequestStatus {
  submitted,
  open,
  inProgress,
  resolved,
  closed,
}

class SupportRequest {
  SupportRequest({
    required this.id,
    required this.type,
    required this.createdBy,
    required this.createdAt,
    this.status = SupportRequestStatus.submitted,
    this.summary,
    this.topic,
    this.question,
    this.details,
    this.chargerModel,
    this.chargerSerialNumber,
    this.address,
    this.country,
    this.scheduledDate,
    List<String>? attachments,
    this.companyId,
    this.staffReply,
  }) : attachments = List<String>.from(attachments ?? const []);

  factory SupportRequest.create({
    required SupportRequestType type,
    required String createdBy,
    String? companyId,
    String? summary,
    String? topic,
    String? question,
    String? details,
    String? chargerModel,
    String? chargerSerialNumber,
    String? address,
    String? country,
    DateTime? scheduledDate,
    List<String>? attachments,
  }) {
    return SupportRequest(
      id: const Uuid().v4(),
      type: type,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      companyId: companyId,
      summary: summary,
      topic: topic,
      question: question,
      details: details,
      chargerModel: chargerModel,
      chargerSerialNumber: chargerSerialNumber,
      address: address,
      country: country,
      scheduledDate: scheduledDate,
      attachments: attachments,
    );
  }

  factory SupportRequest.fromMap(Map<String, dynamic> data) {
    return SupportRequest(
      id: data['id'] as String? ?? '',
      type: SupportRequestType.values.firstWhere(
        (value) => value.name == data['type'],
        orElse: () => SupportRequestType.knowHow,
      ),
      status: SupportRequestStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => SupportRequestStatus.submitted,
      ),
      summary: data['summary'] as String?,
      topic: data['topic'] as String?,
      question: data['question'] as String?,
      details: data['details'] as String?,
      chargerModel: data['chargerModel'] as String?,
      chargerSerialNumber: data['chargerSerialNumber'] as String?,
      address: data['address'] as String?,
      country: data['country'] as String?,
      scheduledDate: _parseDate(data['scheduledDate']),
      attachments: (data['attachments'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      companyId: data['companyId'] as String?,
      staffReply: data['staffReply'] as String?,
    );
  }

  final String id;
  final SupportRequestType type;
  final SupportRequestStatus status;
  final String? summary;
  final String? topic;
  final String? question;
  final String? details;
  final String? chargerModel;
  final String? chargerSerialNumber;
  final String? address;
  final String? country;
  final DateTime? scheduledDate;
  final List<String> attachments;
  final String createdBy;
  final DateTime createdAt;
  final String? companyId;
  final String? staffReply;

  SupportRequest copyWith({
    String? id,
    SupportRequestType? type,
    SupportRequestStatus? status,
    String? summary,
    String? topic,
    String? question,
    String? details,
    String? chargerModel,
    String? chargerSerialNumber,
    String? address,
    String? country,
    DateTime? scheduledDate,
    List<String>? attachments,
    String? createdBy,
    DateTime? createdAt,
    String? companyId,
    String? staffReply,
  }) {
    return SupportRequest(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      topic: topic ?? this.topic,
      question: question ?? this.question,
      details: details ?? this.details,
      chargerModel: chargerModel ?? this.chargerModel,
      chargerSerialNumber: chargerSerialNumber ?? this.chargerSerialNumber,
      address: address ?? this.address,
      country: country ?? this.country,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      attachments: attachments ?? this.attachments,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      companyId: companyId ?? this.companyId,
      staffReply: staffReply ?? this.staffReply,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'summary': summary,
        'topic': topic,
        'question': question,
        'details': details,
        'chargerModel': chargerModel,
        'chargerSerialNumber': chargerSerialNumber,
        'address': address,
        'country': country,
        'scheduledDate': scheduledDate?.toIso8601String(),
        'attachments': attachments,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'companyId': companyId,
        'staffReply': staffReply,
      };
}
