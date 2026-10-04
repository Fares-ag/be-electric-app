import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_schedule.dart';
import 'package:cmms_core/repositories/pm_occurrence_repository.dart';
import 'package:image_picker/image_picker.dart';

class FakePmOccurrenceRepository implements PmOccurrenceRepository {
  FakePmOccurrenceRepository({
    this.occurrences = const [],
    this.schedules = const [],
  });

  final List<PmOccurrence> occurrences;
  final List<PmSchedule> schedules;

  int getAssignedOccurrencesCalls = 0;
  int getOccurrenceByIdCalls = 0;
  int queryOccurrencesCalls = 0;
  int querySchedulesCalls = 0;
  int getScheduleByIdCalls = 0;
  int completeOccurrenceCalls = 0;
  int confirmOccurrenceForRequestorCalls = 0;
  int uploadOccurrenceCompletionPhotoCalls = 0;
  Exception? completeError;
  Exception? confirmError;

  String? lastCompletedOccurrenceId;
  String? lastCompletedById;
  String? lastCompletionNotes;
  String? lastCompletionPhotoPath;
  String? lastConfirmedOccurrenceId;
  String? lastConfirmedRequestorId;

  int get totalCalls =>
      getAssignedOccurrencesCalls +
      getOccurrenceByIdCalls +
      queryOccurrencesCalls +
      querySchedulesCalls +
      getScheduleByIdCalls +
      completeOccurrenceCalls +
      confirmOccurrenceForRequestorCalls +
      uploadOccurrenceCompletionPhotoCalls;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> testConnection() async => true;

  @override
  Future<List<PmOccurrence>> getAssignedOccurrences(String technicianId) async {
    getAssignedOccurrencesCalls++;
    return occurrences
        .where((item) => item.assignedTechnicianIds.contains(technicianId))
        .toList();
  }

  @override
  Future<PmOccurrence?> getOccurrenceById(String occurrenceId) async {
    getOccurrenceByIdCalls++;
    for (final item in occurrences) {
      if (item.id == occurrenceId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<PmOccurrence>> queryOccurrences({
    String? assignedTechnicianId,
    String? assetId,
    String? companyId,
    String? scheduleId,
    PmOccurrenceStoredStatus? storedStatus,
    DateTime? dueStart,
    DateTime? dueEnd,
  }) async {
    queryOccurrencesCalls++;
    return occurrences;
  }

  @override
  Future<List<PmSchedule>> querySchedules({String? companyId}) async {
    querySchedulesCalls++;
    return schedules;
  }

  @override
  Future<PmSchedule?> getScheduleById(String scheduleId) async {
    getScheduleByIdCalls++;
    for (final item in schedules) {
      if (item.id == scheduleId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> completeOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    String? completionPhotoPath,
  }) async {
    completeOccurrenceCalls++;
    lastCompletedOccurrenceId = occurrenceId;
    lastCompletedById = completedById;
    lastCompletionNotes = completionNotes;
    lastCompletionPhotoPath = completionPhotoPath;
    if (completeError != null) {
      throw completeError!;
    }
  }

  @override
  Future<void> confirmOccurrenceForRequestor({
    required String occurrenceId,
    required String requestorId,
  }) async {
    confirmOccurrenceForRequestorCalls++;
    lastConfirmedOccurrenceId = occurrenceId;
    lastConfirmedRequestorId = requestorId;
    if (confirmError != null) {
      throw confirmError!;
    }
  }

  @override
  Future<String?> uploadOccurrenceCompletionPhoto({
    required XFile photoFile,
    required String occurrenceId,
  }) async {
    uploadOccurrenceCompletionPhotoCalls++;
    return null;
  }
}
