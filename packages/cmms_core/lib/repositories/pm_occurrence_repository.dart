import 'package:image_picker/image_picker.dart';

import '../models/pm_occurrence.dart';
import '../models/pm_schedule.dart';

/// Persistence for Option A PM schedules and occurrences.
///
/// Legacy PM tasks remain in `WorkOrderRepository` (legacy `pm_tasks` aggregate).
abstract class PmOccurrenceRepository {
  Future<void> initialize();
  Future<bool> testConnection();

  Future<List<PmOccurrence>> getAssignedOccurrences(String technicianId);

  Future<PmOccurrence?> getOccurrenceById(String occurrenceId);

  Future<List<PmOccurrence>> queryOccurrences({
    String? assignedTechnicianId,
    String? assetId,
    String? companyId,
    String? scheduleId,
    PmOccurrenceStoredStatus? storedStatus,
    DateTime? dueStart,
    DateTime? dueEnd,
  });

  Future<List<PmSchedule>> querySchedules({
    String? companyId,
  });

  Future<PmSchedule?> getScheduleById(String scheduleId);

  Future<void> completeOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    String? completionPhotoPath,
  });

  Future<void> confirmOccurrenceForRequestor({
    required String occurrenceId,
    required String requestorId,
  });

  Future<String?> uploadOccurrenceCompletionPhoto({
    required XFile photoFile,
    required String occurrenceId,
  });
}
