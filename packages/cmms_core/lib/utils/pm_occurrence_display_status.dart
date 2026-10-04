/// Client-side display status for PM task occurrences (Option A v1).
///
/// Stored `status` is often `pending` even when past due; derive buckets
/// using the same rules as React admin (`pm-schedule.ts`).
enum PmOccurrenceDisplayStatus {
  upcoming,
  overdue,
  completed,
  cancelled,
}

DateTime normalizePmCalendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Derives UI status from stored occurrence status and due date.
PmOccurrenceDisplayStatus deriveOccurrenceDisplayStatus({
  required String storedStatus,
  required DateTime dueDate,
  DateTime? referenceDate,
}) {
  final normalizedStored = storedStatus.trim().toLowerCase();
  if (normalizedStored == 'completed') {
    return PmOccurrenceDisplayStatus.completed;
  }
  if (normalizedStored == 'cancelled') {
    return PmOccurrenceDisplayStatus.cancelled;
  }

  final due = normalizePmCalendarDate(dueDate);
  final today = normalizePmCalendarDate(referenceDate ?? DateTime.now());
  if (due.isBefore(today)) {
    return PmOccurrenceDisplayStatus.overdue;
  }
  return PmOccurrenceDisplayStatus.upcoming;
}

bool isPmOccurrenceDisplayStatusOpen(PmOccurrenceDisplayStatus status) =>
    status != PmOccurrenceDisplayStatus.completed &&
    status != PmOccurrenceDisplayStatus.cancelled;
