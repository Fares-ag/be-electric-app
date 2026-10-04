/// Builds a client-side work-order ticket number in WO-YYYY-NNNNN format.
///
/// Uses [workOrderId] so the suffix does not depend on in-memory list length.
String buildWorkOrderTicketNumber({
  required DateTime createdAt,
  required String workOrderId,
}) {
  final year = createdAt.year;
  final uniqueSuffix = (createdAt.microsecondsSinceEpoch ^ workOrderId.hashCode)
      .abs()
      .remainder(100000);
  final sequential = uniqueSuffix.toString().padLeft(5, '0');
  return 'WO-$year-$sequential';
}
