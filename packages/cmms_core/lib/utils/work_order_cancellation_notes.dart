/// Preserves existing work-order notes when a requestor cancels.
String appendWorkOrderCancellationNote({
  required String? existingNotes,
  required String cancellationReason,
}) {
  final trimmedReason = cancellationReason.trim();
  final cancellationLine =
      'Cancelled by requestor. Reason: $trimmedReason';

  final existing = existingNotes?.trim();
  if (existing == null || existing.isEmpty) {
    return cancellationLine;
  }

  return '$existing\n\n$cancellationLine';
}
