import 'package:image_picker/image_picker.dart';

import '../../config/locator.dart';
import '../../models/pm_occurrence.dart';
import '../../models/pm_schedule.dart';
import '../../services/supabase_database_service.dart';
import '../../services/supabase_storage_service.dart';
import '../pm_occurrence_repository.dart';

class SupabasePmOccurrenceRepository implements PmOccurrenceRepository {
  SupabasePmOccurrenceRepository({
    SupabaseDatabaseService? database,
    SupabaseStorageService? storage,
  })  : _database = database ?? sl<SupabaseDatabaseService>(),
        _storage = storage ?? sl<SupabaseStorageService>();

  final SupabaseDatabaseService _database;
  final SupabaseStorageService _storage;

  @override
  Future<void> initialize() => _database.initialize();

  @override
  Future<bool> testConnection() => _database.testConnection();

  @override
  Future<List<PmOccurrence>> getAssignedOccurrences(String technicianId) =>
      _database.getAssignedPmOccurrences(technicianId);

  @override
  Future<PmOccurrence?> getOccurrenceById(String occurrenceId) =>
      _database.getPmOccurrenceById(occurrenceId);

  @override
  Future<List<PmOccurrence>> queryOccurrences({
    String? assignedTechnicianId,
    String? assetId,
    String? companyId,
    String? scheduleId,
    PmOccurrenceStoredStatus? storedStatus,
    DateTime? dueStart,
    DateTime? dueEnd,
  }) =>
      _database.queryPmOccurrences(
        assignedTechnicianId: assignedTechnicianId,
        assetId: assetId,
        companyId: companyId,
        scheduleId: scheduleId,
        storedStatus: storedStatus?.name,
        dueStart: dueStart,
        dueEnd: dueEnd,
      );

  @override
  Future<List<PmSchedule>> querySchedules({String? companyId}) =>
      _database.queryPmSchedules(companyId: companyId);

  @override
  Future<PmSchedule?> getScheduleById(String scheduleId) =>
      _database.getPmScheduleById(scheduleId);

  @override
  Future<void> completeOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    String? completionPhotoPath,
  }) =>
      _database.completePmOccurrence(
        occurrenceId: occurrenceId,
        completedById: completedById,
        completionNotes: completionNotes,
        completionPhotoPath: completionPhotoPath,
      );

  @override
  Future<void> confirmOccurrenceForRequestor({
    required String occurrenceId,
    required String requestorId,
  }) =>
      _database.confirmPmOccurrenceForRequestor(
        occurrenceId: occurrenceId,
        requestorId: requestorId,
      );

  @override
  Future<String?> uploadOccurrenceCompletionPhoto({
    required XFile photoFile,
    required String occurrenceId,
  }) {
    final extension = _fileExtension(photoFile.name);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.$extension';
    return _storage.uploadFileReturningStoragePath(
      file: photoFile,
      fileName: fileName,
      folder: 'pm_occurrences/$occurrenceId/completion',
    );
  }
}

String _fileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex >= fileName.length - 1) {
    return 'jpg';
  }
  return fileName.substring(dotIndex + 1).toLowerCase();
}

String _randomSuffix() => DateTime.now().microsecondsSinceEpoch
    .toRadixString(36)
    .padLeft(8, '0')
    .substring(0, 8);
