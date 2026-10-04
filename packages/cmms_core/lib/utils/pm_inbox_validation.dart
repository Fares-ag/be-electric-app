import 'package:flutter/foundation.dart';

import '../models/pm_occurrence.dart';
import '../models/pm_task.dart';
import '../models/pm_work_item.dart';

/// Severity for inbox validation findings during PM migration.
enum PmInboxValidationSeverity {
  info,
  warning,
  error,
}

/// A single inbox consistency or duplicate-source finding.
class PmInboxValidationIssue {
  const PmInboxValidationIssue({
    required this.code,
    required this.message,
    this.severity = PmInboxValidationSeverity.warning,
  });

  final String code;
  final String message;
  final PmInboxValidationSeverity severity;
}

/// Result of validating a merged PM inbox against its upstream sources.
class PmInboxValidationReport {
  const PmInboxValidationReport({this.issues = const []});

  final List<PmInboxValidationIssue> issues;

  bool get isConsistent => !issues.any(
        (issue) => issue.severity == PmInboxValidationSeverity.error,
      );

  bool get hasWarnings => issues.any(
        (issue) => issue.severity == PmInboxValidationSeverity.warning,
      );

  int get crossSourceIdCollisionCount => issues
      .where((issue) => issue.code == 'cross_source_id_collision')
      .length;

  void logIfIssues() {
    if (issues.isEmpty) {
      return;
    }
    for (final issue in issues) {
      debugPrint(
        '[PmInboxValidation] ${issue.severity.name}: ${issue.message}',
      );
    }
  }
}

/// Validates that [inbox] matches a fresh merge of [legacyTasks] + [occurrences].
///
/// Also surfaces cross-source ID collisions (expected during migration) and
/// duplicate `(source, id)` rows (never expected).
PmInboxValidationReport validatePmInbox({
  required List<PMTask> legacyTasks,
  required List<PmOccurrence> occurrences,
  required List<PmWorkItem> inbox,
  DateTime? referenceDate,
}) {
  final issues = <PmInboxValidationIssue>[];

  final expected = PmWorkItem.mergeAndSort(
    legacyTasks: legacyTasks,
    occurrences: occurrences,
    referenceDate: referenceDate,
  );

  if (expected.length != inbox.length) {
    issues.add(
      PmInboxValidationIssue(
        code: 'inbox_length_mismatch',
        message:
            'Inbox length ${inbox.length} != expected ${expected.length}',
        severity: PmInboxValidationSeverity.error,
      ),
    );
  } else {
    for (var index = 0; index < expected.length; index++) {
      final actual = inbox[index];
      final predicted = expected[index];
      if (actual.source != predicted.source || actual.id != predicted.id) {
        issues.add(
          PmInboxValidationIssue(
            code: 'inbox_identity_mismatch',
            message:
                'Inbox item at $index (${actual.source.name}/${actual.id}) '
                '!= expected (${predicted.source.name}/${predicted.id})',
            severity: PmInboxValidationSeverity.error,
          ),
        );
        break;
      }
    }
  }

  final seenKeys = <String>{};
  for (final item in inbox) {
    final key = '${item.source.name}:${item.id}';
    if (seenKeys.contains(key)) {
      issues.add(
        PmInboxValidationIssue(
          code: 'duplicate_inbox_key',
          message: 'Duplicate inbox entry for $key',
          severity: PmInboxValidationSeverity.error,
        ),
      );
    }
    seenKeys.add(key);
  }

  final legacyIds = legacyTasks.map((task) => task.id).toSet();
  for (final occurrence in occurrences) {
    if (legacyIds.contains(occurrence.id)) {
      issues.add(
        PmInboxValidationIssue(
          code: 'cross_source_id_collision',
          message:
              'ID "${occurrence.id}" exists in both legacy pm_tasks and '
              'pm_task_occurrences',
          severity: PmInboxValidationSeverity.warning,
        ),
      );
    }
  }

  for (final item in inbox) {
    if (item.isLegacy && item.legacyTask == null) {
      issues.add(
        PmInboxValidationIssue(
          code: 'missing_legacy_payload',
          message:
              'Legacy inbox item ${item.id} is missing legacyTask payload',
          severity: PmInboxValidationSeverity.error,
        ),
      );
    }
    if (item.isOccurrence && item.occurrence == null) {
      issues.add(
        PmInboxValidationIssue(
          code: 'missing_occurrence_payload',
          message:
              'Occurrence inbox item ${item.id} is missing occurrence payload',
          severity: PmInboxValidationSeverity.error,
        ),
      );
    }
  }

  return PmInboxValidationReport(issues: issues);
}
