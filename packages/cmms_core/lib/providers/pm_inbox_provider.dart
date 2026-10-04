import 'package:flutter/foundation.dart';

import '../models/pm_occurrence.dart';
import '../models/pm_work_item.dart';
import '../utils/pm_inbox_validation.dart';
import 'pm_occurrence_provider.dart';
import 'work_order_provider.dart';

/// Read-only unified PM inbox merging legacy tasks and Option A occurrences.
///
/// **Migration policy:** This provider only merges presentation models via
/// [PmWorkItem.mergeAndSort]. Do not add write paths, repository calls, or
/// cross-source deduplication here — that belongs in backend migration tooling.
///
/// Legacy `pm_tasks` remain sourced from [WorkOrderProvider]; Option A rows
/// come from [PmOccurrenceProvider] when `ENABLE_PM_OCCURRENCES` is ON.
class PmInboxProvider extends ChangeNotifier {
  PmInboxProvider({
    required WorkOrderProvider workOrders,
    required PmOccurrenceProvider pmOccurrences,
    DateTime Function()? referenceDate,
  })  : _workOrders = workOrders,
        _pmOccurrences = pmOccurrences,
        _referenceDate = referenceDate ?? DateTime.now {
    _workOrders.addListener(_recomputeInbox);
    _pmOccurrences.addListener(_recomputeInbox);
    _recomputeInbox();
  }

  final WorkOrderProvider _workOrders;
  final PmOccurrenceProvider _pmOccurrences;
  final DateTime Function() _referenceDate;

  List<PmWorkItem> _inbox = const [];
  PmInboxValidationReport? _validationReport;

  List<PmWorkItem> get inbox => List.unmodifiable(_inbox);

  bool get isEmpty => _inbox.isEmpty;

  bool get includesOccurrences => _pmOccurrences.isEnabled;

  /// Latest validation report (debug builds only).
  PmInboxValidationReport? get validationReport => _validationReport;

  @override
  void dispose() {
    _workOrders.removeListener(_recomputeInbox);
    _pmOccurrences.removeListener(_recomputeInbox);
    super.dispose();
  }

  void _recomputeInbox() {
    final occurrences = _pmOccurrences.isEnabled
        ? _pmOccurrences.occurrences
        : const <PmOccurrence>[];

    final nextInbox = PmWorkItem.mergeAndSort(
      legacyTasks: _workOrders.pmTasks,
      occurrences: occurrences,
      referenceDate: _referenceDate(),
    );

    if (kDebugMode) {
      _validationReport = validatePmInbox(
        legacyTasks: _workOrders.pmTasks,
        occurrences: occurrences,
        inbox: nextInbox,
        referenceDate: _referenceDate(),
      );
      _validationReport!.logIfIssues();
    }

    if (_hasSameInboxPresentation(_inbox, nextInbox)) {
      return;
    }

    _inbox = nextInbox;
    notifyListeners();
  }

  bool _hasSameInboxPresentation(
    List<PmWorkItem> current,
    List<PmWorkItem> next,
  ) {
    if (identical(current, next)) {
      return true;
    }
    if (current.length != next.length) {
      return false;
    }
    for (var index = 0; index < current.length; index++) {
      final existing = current[index];
      final updated = next[index];
      if (existing.source != updated.source || existing.id != updated.id) {
        return false;
      }
      if (existing.displayStatus != updated.displayStatus) {
        return false;
      }
      if (existing.isRequestorConfirmed != updated.isRequestorConfirmed) {
        return false;
      }
    }
    return true;
  }
}
