import '../models/pm_work_item.dart';
import 'pm_occurrence_display_status.dart';

/// Deterministic comparator for unified PM inbox ordering.
///
/// 1. Due date ascending (calendar day)
/// 2. Overdue before non-overdue on the same due date
/// 3. Source order (`legacy` before `occurrence`)
/// 4. ID lexicographic ascending
int comparePmWorkItems(PmWorkItem a, PmWorkItem b) {
  final dueCompare = normalizePmCalendarDate(a.dueDate)
      .compareTo(normalizePmCalendarDate(b.dueDate));
  if (dueCompare != 0) {
    return dueCompare;
  }

  final overdueCompare =
      _overdueSortRank(a.displayStatus).compareTo(_overdueSortRank(b.displayStatus));
  if (overdueCompare != 0) {
    return overdueCompare;
  }

  final sourceCompare = a.source.index.compareTo(b.source.index);
  if (sourceCompare != 0) {
    return sourceCompare;
  }

  return a.id.compareTo(b.id);
}

/// Returns a new list sorted with [comparePmWorkItems].
List<PmWorkItem> sortPmWorkItems(List<PmWorkItem> items) {
  final sorted = List<PmWorkItem>.from(items)..sort(comparePmWorkItems);
  return sorted;
}

int _overdueSortRank(PmWorkItemDisplayStatus status) =>
    status == PmWorkItemDisplayStatus.overdue ? 0 : 1;
