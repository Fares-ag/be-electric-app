import '../models/pm_occurrence.dart';
import '../models/pm_task.dart';
import '../models/pm_work_item.dart';

/// Maps a legacy [PMTask] into a presentation-only [PmWorkItem].
PmWorkItem mapLegacyPmTaskToWorkItem(
  PMTask task, {
  DateTime? referenceDate,
}) =>
    PmWorkItem.fromLegacyTask(task, referenceDate: referenceDate);

/// Maps an Option A [PmOccurrence] into a presentation-only [PmWorkItem].
PmWorkItem mapOccurrenceToWorkItem(
  PmOccurrence occurrence, {
  DateTime? referenceDate,
}) =>
    PmWorkItem.fromOccurrence(
      occurrence,
      referenceDate: referenceDate,
    );

/// Merges legacy tasks and occurrences without deduplicating cross-source IDs.
///
/// Intentionally preserves both rows when IDs collide across tables during
/// migration. [validatePmInbox] surfaces those collisions as warnings.
List<PmWorkItem> mergePmWorkItems({
  required List<PMTask> legacyTasks,
  required List<PmOccurrence> occurrences,
  DateTime? referenceDate,
}) =>
    [
      ...legacyTasks.map(
        (task) => mapLegacyPmTaskToWorkItem(task, referenceDate: referenceDate),
      ),
      ...occurrences.map(
        (occurrence) =>
            mapOccurrenceToWorkItem(occurrence, referenceDate: referenceDate),
      ),
    ];
