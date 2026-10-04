import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../config/locator.dart';
import '../models/pm_occurrence.dart';
import '../models/pm_schedule.dart';
import '../repositories/pm_occurrence_repository.dart';

/// Service layer for Option A PM schedules and occurrences.
class PmOccurrenceService {
  PmOccurrenceService({PmOccurrenceRepository? repository})
      : _repository = repository ?? sl<PmOccurrenceRepository>();

  final PmOccurrenceRepository _repository;

  bool get isEnabled => AppConfig.enablePmOccurrences;

  Future<List<PmOccurrence>> getAssignedOccurrences(String technicianId) {
    if (!isEnabled) return Future.value(const []);
    return _repository.getAssignedOccurrences(technicianId);
  }

  Future<PmOccurrence?> getOccurrenceById(String occurrenceId) {
    if (!isEnabled) return Future.value();
    return _repository.getOccurrenceById(occurrenceId);
  }

  Future<List<PmOccurrence>> queryOccurrences({
    String? assignedTechnicianId,
    String? assetId,
    String? companyId,
    String? scheduleId,
    PmOccurrenceStoredStatus? storedStatus,
    DateTime? dueStart,
    DateTime? dueEnd,
  }) {
    if (!isEnabled) return Future.value(const []);
    return _repository.queryOccurrences(
      assignedTechnicianId: assignedTechnicianId,
      assetId: assetId,
      companyId: companyId,
      scheduleId: scheduleId,
      storedStatus: storedStatus,
      dueStart: dueStart,
      dueEnd: dueEnd,
    );
  }

  Future<List<PmSchedule>> querySchedules({String? companyId}) {
    if (!isEnabled) return Future.value(const []);
    return _repository.querySchedules(companyId: companyId);
  }

  Future<PmSchedule?> getScheduleById(String scheduleId) {
    if (!isEnabled) return Future.value();
    return _repository.getScheduleById(scheduleId);
  }

  /// Marks an occurrence completed (Option A write path).
  Future<void> completeOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    XFile? completionPhoto,
  }) async {
    if (!isEnabled) {
      throw StateError('PM occurrences are not enabled');
    }

    String? completionPhotoPath;
    if (completionPhoto != null) {
      completionPhotoPath = await _repository.uploadOccurrenceCompletionPhoto(
        photoFile: completionPhoto,
        occurrenceId: occurrenceId,
      );
    }

    await _repository.completeOccurrence(
      occurrenceId: occurrenceId,
      completedById: completedById,
      completionNotes: completionNotes,
      completionPhotoPath: completionPhotoPath,
    );
  }

  /// Records requestor acknowledgment before scheduled PM execution.
  Future<void> confirmOccurrenceForRequestor({
    required String occurrenceId,
    required String requestorId,
  }) async {
    if (!isEnabled) {
      throw StateError('PM occurrences are not enabled');
    }
    return _repository.confirmOccurrenceForRequestor(
      occurrenceId: occurrenceId,
      requestorId: requestorId,
    );
  }
}
