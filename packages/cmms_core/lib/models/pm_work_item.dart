import '../utils/pm_work_item_display_status.dart';
import '../utils/pm_work_item_mapper.dart';
import '../utils/pm_work_item_sort.dart';
import 'pm_occurrence.dart';
import 'pm_task.dart';

export '../utils/pm_work_item_display_status.dart';
export '../utils/pm_work_item_filter.dart';
export '../utils/pm_work_item_mapper.dart';
export '../utils/pm_work_item_sort.dart';

/// Presentation-only merge of legacy PM tasks and Option A occurrences.
///
/// Never persist this model; it exists for unified inbox sorting and
/// requestor read-only views. UI-only merge — no deduplication across sources.
///
/// **Legacy source:** frozen `PMTask` rows (read + existing completion only).
/// **Occurrence source:** Option A write path when `ENABLE_PM_OCCURRENCES` is ON.
enum PmWorkItemSource {
  legacy,
  occurrence,
}

class PmWorkItem {
  PmWorkItem._({
    required this.source,
    required this.id,
    required this.title,
    required this.dueDate,
    required this.displayStatus,
    this.legacyTask,
    this.occurrence,
  });

  factory PmWorkItem.fromLegacyTask(
    PMTask task, {
    DateTime? referenceDate,
  }) =>
      PmWorkItem._(
        source: PmWorkItemSource.legacy,
        id: task.id,
        title: task.taskName,
        dueDate: task.nextDueDate ?? task.createdAt,
        displayStatus: normalizeLegacyPmTaskDisplayStatus(
          task,
          referenceDate: referenceDate,
        ),
        legacyTask: task,
      );

  factory PmWorkItem.fromOccurrence(
    PmOccurrence occurrence, {
    DateTime? referenceDate,
  }) =>
      PmWorkItem._(
        source: PmWorkItemSource.occurrence,
        id: occurrence.id,
        title: occurrence.taskName.isNotEmpty
            ? occurrence.taskName
            : 'Preventive maintenance',
        dueDate: occurrence.dueDate,
        displayStatus: normalizeOccurrenceDisplayStatus(
          occurrence,
          referenceDate: referenceDate,
        ),
        occurrence: occurrence,
      );

  final PmWorkItemSource source;
  final String id;
  final String title;
  final DateTime dueDate;
  final PmWorkItemDisplayStatus displayStatus;
  final PMTask? legacyTask;
  final PmOccurrence? occurrence;

  bool get isLegacy => source == PmWorkItemSource.legacy;

  bool get isOccurrence => source == PmWorkItemSource.occurrence;

  bool get isOpen => isPmWorkItemDisplayStatusOpen(displayStatus);

  bool get isRequestorConfirmed =>
      isOccurrence && (occurrence?.isRequestorConfirmed ?? false);

  bool get showsRequestorConfirm =>
      isOccurrence && isOpen && !isRequestorConfirmed;

  static List<PmWorkItem> mergeAndSort({
    required List<PMTask> legacyTasks,
    required List<PmOccurrence> occurrences,
    DateTime? referenceDate,
  }) =>
      sortPmWorkItems(
        mergePmWorkItems(
          legacyTasks: legacyTasks,
          occurrences: occurrences,
          referenceDate: referenceDate,
        ),
      );
}
