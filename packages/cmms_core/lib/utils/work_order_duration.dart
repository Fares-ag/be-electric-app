import '../models/pm_task.dart';
import '../models/work_order.dart';

/// Non-negative span between two timestamps (for timeline metrics).
int elapsedSecondsBetween(DateTime start, DateTime end) {
  final seconds = end.difference(start).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

double elapsedDaysBetween(DateTime start, DateTime end) =>
    elapsedSecondsBetween(start, end) / 86400.0;

int pausedSecondsFromHistory({
  required List<Map<String, dynamic>>? pauseHistory,
  required DateTime endTime,
  bool isPaused = false,
  DateTime? pausedAt,
}) {
  var total = 0;

  if (pauseHistory != null) {
    for (final entry in pauseHistory) {
      final pauseStart = _parsePauseTimestamp(entry['pausedAt']);
      final pauseEnd = _parsePauseTimestamp(entry['resumedAt']);
      if (pauseStart != null && pauseEnd != null) {
        total += elapsedSecondsBetween(pauseStart, pauseEnd);
      }
    }
  }

  if (isPaused && pausedAt != null) {
    total += elapsedSecondsBetween(pausedAt, endTime);
  }

  return total;
}

int calculateActiveDurationSeconds({
  required DateTime start,
  required DateTime end,
  List<Map<String, dynamic>>? pauseHistory,
  bool isPaused = false,
  DateTime? pausedAt,
  int? storedDurationSeconds,
}) {
  if (storedDurationSeconds != null && storedDurationSeconds >= 0) {
    return storedDurationSeconds;
  }

  final totalSeconds = elapsedSecondsBetween(start, end) -
      pausedSecondsFromHistory(
        pauseHistory: pauseHistory,
        endTime: end,
        isPaused: isPaused,
        pausedAt: pausedAt,
      );
  return totalSeconds < 0 ? 0 : totalSeconds;
}

/// Active work duration in seconds, excluding paused time.
/// Prefers [WorkOrder.workDurationSeconds] when set at completion.
int? calculateWorkDurationSeconds(
  WorkOrder workOrder, {
  DateTime? endTime,
}) {
  if (endTime == null &&
      workOrder.workDurationSeconds != null &&
      workOrder.workDurationSeconds! >= 0) {
    return workOrder.workDurationSeconds;
  }

  final start = workOrder.startedAt;
  final end = endTime ?? workOrder.completedAt;
  if (start == null || end == null) {
    return workOrder.workDurationSeconds;
  }

  return calculateActiveDurationSeconds(
    start: start,
    end: end,
    pauseHistory: workOrder.pauseHistory,
    isPaused: workOrder.isPaused,
    pausedAt: workOrder.pausedAt,
    storedDurationSeconds: endTime == null
        ? workOrder.workDurationSeconds
        : null,
  );
}

/// Pause-aware PM task duration. Prefers stored [durationSeconds] when provided.
int? calculatePmTaskDurationSeconds(
  PMTask pmTask, {
  DateTime? endTime,
  int? storedDurationSeconds,
}) {
  if (storedDurationSeconds != null && storedDurationSeconds >= 0) {
    return storedDurationSeconds;
  }

  final start = pmTask.startedAt;
  final end = endTime ?? pmTask.completedAt ?? pmTask.lastCompletedAt;
  if (start == null || end == null) {
    return storedDurationSeconds;
  }

  return calculateActiveDurationSeconds(
    start: start,
    end: end,
    pauseHistory: pmTask.pauseHistory,
    isPaused: pmTask.isPaused,
    pausedAt: pmTask.pausedAt,
  );
}

DateTime? _parsePauseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String formatWorkDurationSeconds(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final seconds = safeSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

String formatWorkDuration(Duration duration) =>
    formatWorkDurationSeconds(duration.inSeconds);
