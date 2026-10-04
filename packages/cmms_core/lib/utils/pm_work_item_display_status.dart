import '../models/pm_occurrence.dart';
import '../models/pm_task.dart';
import 'pm_occurrence_display_status.dart';

/// Unified inbox display status for legacy PM tasks and Option A occurrences.
enum PmWorkItemDisplayStatus {
  upcoming,
  overdue,
  completed,
  cancelled,
}

bool isPmWorkItemDisplayStatusOpen(PmWorkItemDisplayStatus status) =>
    status != PmWorkItemDisplayStatus.completed &&
    status != PmWorkItemDisplayStatus.cancelled;

PmWorkItemDisplayStatus pmWorkItemDisplayStatusFromOccurrenceStatus(
  PmOccurrenceDisplayStatus status,
) {
  switch (status) {
    case PmOccurrenceDisplayStatus.upcoming:
      return PmWorkItemDisplayStatus.upcoming;
    case PmOccurrenceDisplayStatus.overdue:
      return PmWorkItemDisplayStatus.overdue;
    case PmOccurrenceDisplayStatus.completed:
      return PmWorkItemDisplayStatus.completed;
    case PmOccurrenceDisplayStatus.cancelled:
      return PmWorkItemDisplayStatus.cancelled;
  }
}

/// Normalizes [PMTask.status] and due date without mutating the source model.
PmWorkItemDisplayStatus normalizeLegacyPmTaskDisplayStatus(
  PMTask task, {
  DateTime? referenceDate,
}) {
  switch (task.status) {
    case PMTaskStatus.completed:
      return PmWorkItemDisplayStatus.completed;
    case PMTaskStatus.cancelled:
      return PmWorkItemDisplayStatus.cancelled;
    case PMTaskStatus.overdue:
      return PmWorkItemDisplayStatus.overdue;
    case PMTaskStatus.pending:
    case PMTaskStatus.inProgress:
      final due = task.nextDueDate;
      if (due == null) {
        return PmWorkItemDisplayStatus.upcoming;
      }
      return pmWorkItemDisplayStatusFromOccurrenceStatus(
        deriveOccurrenceDisplayStatus(
          storedStatus: 'pending',
          dueDate: due,
          referenceDate: referenceDate,
        ),
      );
  }
}

/// Normalizes occurrence stored status and due date without mutating the source model.
PmWorkItemDisplayStatus normalizeOccurrenceDisplayStatus(
  PmOccurrence occurrence, {
  DateTime? referenceDate,
}) =>
    pmWorkItemDisplayStatusFromOccurrenceStatus(
      occurrence.displayStatus(referenceDate: referenceDate),
    );
