import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_schedule.dart';
import 'package:cmms_core/repositories/pm_occurrence_repository.dart';
import 'package:cmms_core/services/pm_occurrence_service.dart';
import 'package:image_picker/image_picker.dart';

import 'fake_pm_occurrence_repository.dart';

/// Test double for [PmOccurrenceService] with controllable enablement and responses.
class FakePmOccurrenceService extends PmOccurrenceService {
  FakePmOccurrenceService({
    this.enabled = false,
    PmOccurrenceRepository? repository,
    this.assignedOccurrences = const [],
    this.queryResults = const [],
    this.assignedError,
    this.queryError,
    this.completeError,
  }) : super(repository: repository ?? FakePmOccurrenceRepository());

  final bool enabled;
  List<PmOccurrence> assignedOccurrences;
  List<PmOccurrence> queryResults;
  Exception? assignedError;
  Exception? queryError;
  Exception? completeError;
  Exception? confirmError;

  int getAssignedOccurrencesCalls = 0;
  int queryOccurrencesCalls = 0;
  int completeOccurrenceCalls = 0;
  int confirmOccurrenceForRequestorCalls = 0;
  int loadCompanyOccurrencesCalls = 0;

  String? lastCompletedOccurrenceId;
  String? lastCompletedById;
  String? lastCompletionNotes;
  XFile? lastCompletionPhoto;
  String? lastConfirmedOccurrenceId;
  String? lastConfirmedRequestorId;

  @override
  bool get isEnabled => enabled;

  @override
  Future<List<PmOccurrence>> getAssignedOccurrences(String technicianId) async {
    getAssignedOccurrencesCalls++;
    if (assignedError != null) {
      throw assignedError!;
    }
    return assignedOccurrences;
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
    loadCompanyOccurrencesCalls++;
    if (queryError != null) {
      throw queryError!;
    }
    return queryResults;
  }

  @override
  Future<void> completeOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    XFile? completionPhoto,
  }) async {
    completeOccurrenceCalls++;
    lastCompletedOccurrenceId = occurrenceId;
    lastCompletedById = completedById;
    lastCompletionNotes = completionNotes;
    lastCompletionPhoto = completionPhoto;
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
  Future<PmOccurrence?> getOccurrenceById(String occurrenceId) async {
    throw UnsupportedError('Not used in PmOccurrenceProvider tests');
  }

  @override
  Future<List<PmSchedule>> querySchedules({String? companyId}) async {
    throw UnsupportedError('Not used in PmOccurrenceProvider tests');
  }

  @override
  Future<PmSchedule?> getScheduleById(String scheduleId) async {
    throw UnsupportedError('Not used in PmOccurrenceProvider tests');
  }
}
