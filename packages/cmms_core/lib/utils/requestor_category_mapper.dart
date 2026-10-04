import '../models/work_order.dart';

/// Priority and repair category derived from the requestor create-form selection.
class RequestorSubmissionFields {
  const RequestorSubmissionFields({
    required this.priority,
    required this.category,
  });

  final WorkOrderPriority priority;
  final RepairCategory category;
}

/// Form options shown on requestor create/edit screens.
const List<String> kRequestorCategoryIssueOptions = [
  'Electrical',
  'Mechanical',
  'Software',
  'Hardware',
  'Other',
];

/// Maps requestor "Category Issue" dropdown values to work-order fields.
///
/// Form options: Electrical, Mechanical, Software, Hardware, Other
RequestorSubmissionFields mapRequestorCategoryIssue(String categoryIssue) {
  switch (categoryIssue.trim().toLowerCase()) {
    case 'electrical':
      return const RequestorSubmissionFields(
        priority: WorkOrderPriority.high,
        category: RepairCategory.electrical,
      );
    case 'mechanical':
      return const RequestorSubmissionFields(
        priority: WorkOrderPriority.medium,
        category: RepairCategory.mechanicalHvac,
      );
    case 'software':
      return const RequestorSubmissionFields(
        priority: WorkOrderPriority.medium,
        category: RepairCategory.itLowVoltage,
      );
    case 'hardware':
      return const RequestorSubmissionFields(
        priority: WorkOrderPriority.medium,
        category: RepairCategory.specializedEquipment,
      );
    case 'other':
      return const RequestorSubmissionFields(
        priority: WorkOrderPriority.medium,
        category: RepairCategory.reactive,
      );
    default:
      return const RequestorSubmissionFields(
        priority: WorkOrderPriority.medium,
        category: RepairCategory.reactive,
      );
  }
}

/// Notes block written on requestor and technician create so admin sees one shape.
String buildMaintenanceRequestNotes({
  required String chargerType,
  required String chargerId,
  required String categoryIssue,
  String department = '',
}) {
  final chargerIdLabel =
      chargerId.trim().isEmpty ? 'N/A' : chargerId.trim().toUpperCase();
  return '''
Department: ${department.trim().isEmpty ? 'N/A' : department.trim()}
Charger: ${chargerType.trim().isEmpty ? 'N/A' : chargerType.trim()}
Charger ID: $chargerIdLabel
Category Issue: ${categoryIssue.trim().isEmpty ? 'N/A' : categoryIssue.trim()}
'''.trim();
}

/// Reverse-maps stored work-order category to the requestor form label.
String resolveRequestorCategoryIssueLabel(RepairCategory? category) {
  switch (category) {
    case RepairCategory.electrical:
      return 'Electrical';
    case RepairCategory.mechanicalHvac:
      return 'Mechanical';
    case RepairCategory.itLowVoltage:
      return 'Software';
    case RepairCategory.specializedEquipment:
      return 'Hardware';
    case RepairCategory.reactive:
    case RepairCategory.preventive:
    case RepairCategory.emergency:
    case RepairCategory.safetyCompliance:
    case RepairCategory.structural:
    case RepairCategory.plumbing:
    case RepairCategory.interior:
    case RepairCategory.exterior:
    case null:
      return 'Other';
  }
}
