import '../models/pm_work_item.dart';
import 'pm_occurrence_display_status.dart';

bool isPmWorkItemOpen(PmWorkItem item) =>
    isPmWorkItemDisplayStatusOpen(item.displayStatus);

bool isPmWorkItemCompleted(PmWorkItem item) =>
    item.displayStatus == PmWorkItemDisplayStatus.completed;

bool isPmWorkItemCancelled(PmWorkItem item) =>
    item.displayStatus == PmWorkItemDisplayStatus.cancelled;

bool isPmWorkItemOverdue(PmWorkItem item) =>
    item.displayStatus == PmWorkItemDisplayStatus.overdue;

bool isPmWorkItemUpcoming(PmWorkItem item) =>
    item.displayStatus == PmWorkItemDisplayStatus.upcoming;

bool isPmWorkItemDueToday(
  PmWorkItem item, {
  DateTime? referenceDate,
}) {
  final today = normalizePmCalendarDate(referenceDate ?? DateTime.now());
  return normalizePmCalendarDate(item.dueDate) == today;
}

List<PmWorkItem> filterPmWorkItemsOpen(List<PmWorkItem> items) =>
    items.where(isPmWorkItemOpen).toList(growable: false);

List<PmWorkItem> filterPmWorkItemsCompleted(List<PmWorkItem> items) =>
    items.where(isPmWorkItemCompleted).toList(growable: false);

List<PmWorkItem> filterPmWorkItemsCancelled(List<PmWorkItem> items) =>
    items.where(isPmWorkItemCancelled).toList(growable: false);

List<PmWorkItem> filterPmWorkItemsOverdue(List<PmWorkItem> items) =>
    items.where(isPmWorkItemOverdue).toList(growable: false);

List<PmWorkItem> filterPmWorkItemsUpcoming(List<PmWorkItem> items) =>
    items.where(isPmWorkItemUpcoming).toList(growable: false);

List<PmWorkItem> filterPmWorkItemsDueToday(
  List<PmWorkItem> items, {
  DateTime? referenceDate,
}) =>
    items
        .where((item) => isPmWorkItemDueToday(item, referenceDate: referenceDate))
        .toList(growable: false);
