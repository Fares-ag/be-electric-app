import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/locator.dart';
import '../models/pm_occurrence.dart';
import '../services/pm_occurrence_service.dart';
import '../services/realtime_supabase_service.dart';
import '../utils/stream_subscription_cancel.dart';

/// State management for Option A PM task occurrences (technician / future requestor).
class PmOccurrenceProvider extends ChangeNotifier {
  PmOccurrenceProvider({PmOccurrenceService? service})
      : _service = service ?? sl<PmOccurrenceService>();

  final PmOccurrenceService _service;

  bool _isLoading = false;
  bool _isCompleting = false;
  bool _isConfirming = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  List<PmOccurrence> _occurrences = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _occurrencesSubscription;
  String? _realtimeTechnicianId;
  String? _realtimeCompanyId;
  bool _realtimeForRequestor = false;

  bool get isLoading => _isLoading;
  bool get isCompleting => _isCompleting;
  bool get isConfirming => _isConfirming;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  List<PmOccurrence> get occurrences => List.unmodifiable(_occurrences);
  bool get hasOccurrences => _occurrences.isNotEmpty;
  bool get isEnabled => _service.isEnabled;

  Future<void> loadAssignedOccurrences(String technicianId) async {
    if (!_service.isEnabled) {
      _setDisabledState();
      return;
    }

    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _occurrences = await _service.getAssignedOccurrences(technicianId);
      _hasLoaded = true;
    } on Exception catch (error) {
      _errorMessage = error.toString();
      _occurrences = const [];
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAssignedOccurrences(String technicianId) =>
      loadAssignedOccurrences(technicianId);

  Future<void> loadCompanyOccurrences(String? companyId) async {
    if (!_service.isEnabled) {
      _setDisabledState();
      return;
    }

    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _occurrences = await _service.queryOccurrences(companyId: companyId);
      _hasLoaded = true;
    } on Exception catch (error) {
      _errorMessage = error.toString();
      _occurrences = const [];
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCompanyOccurrences(String? companyId) =>
      loadCompanyOccurrences(companyId);

  Future<void> completeOccurrence({
    required String occurrenceId,
    required String completedById,
    String? completionNotes,
    XFile? completionPhoto,
  }) async {
    if (!_service.isEnabled) {
      throw StateError('PM occurrences are not enabled');
    }
    if (_isCompleting) {
      return;
    }

    _isCompleting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.completeOccurrence(
        occurrenceId: occurrenceId,
        completedById: completedById,
        completionNotes: completionNotes,
        completionPhoto: completionPhoto,
      );
      _occurrences = _occurrences
          .where((item) => item.id != occurrenceId)
          .toList(growable: false);
    } on Exception catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isCompleting = false;
      notifyListeners();
    }
  }

  Future<void> confirmOccurrenceForRequestor({
    required String occurrenceId,
    required String requestorId,
  }) async {
    if (!_service.isEnabled) {
      throw StateError('PM occurrences are not enabled');
    }
    if (_isConfirming) {
      return;
    }

    _isConfirming = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.confirmOccurrenceForRequestor(
        occurrenceId: occurrenceId,
        requestorId: requestorId,
      );
      final confirmedAt = DateTime.now().toUtc();
      _occurrences = _occurrences
          .map(
            (item) => item.id == occurrenceId
                ? item.copyWith(
                    requestorConfirmedAt: confirmedAt,
                    requestorConfirmedById: requestorId,
                    updatedAt: confirmedAt,
                  )
                : item,
          )
          .toList(growable: false);
    } on Exception catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isConfirming = false;
      notifyListeners();
    }
  }

  void clear() {
    unawaited(stopRealtimeListener());
    _occurrences = const [];
    _errorMessage = null;
    _hasLoaded = false;
    _isLoading = false;
    _isCompleting = false;
    _isConfirming = false;
    notifyListeners();
  }

  /// Clears loaded state during sign-out / app reset (coordinator lifecycle).
  void clearCache() => clear();

  /// Live stream of `pm_task_occurrences`; reloads assigned/company scope on change.
  Future<void> startRealtimeListener({
    required String userId,
    String? companyId,
    required bool isRequestor,
  }) async {
    if (!_service.isEnabled || userId.isEmpty) return;
    await stopRealtimeListener();

    _realtimeTechnicianId = userId;
    _realtimeCompanyId = companyId;
    _realtimeForRequestor = isRequestor;

    _occurrencesSubscription =
        sl<RealtimeSupabaseService>().getPmOccurrencesStream().listen(
      (_) {
        if (_realtimeForRequestor) {
          unawaited(refreshCompanyOccurrences(_realtimeCompanyId));
        } else {
          unawaited(refreshAssignedOccurrences(_realtimeTechnicianId!));
        }
      },
      onError: (Object error) {
        debugPrint('PmOccurrenceProvider: realtime error: $error');
      },
    );
  }

  Future<void> stopRealtimeListener() async {
    await cancelStreamSubscriptions([_occurrencesSubscription]);
    _occurrencesSubscription = null;
    _realtimeTechnicianId = null;
    _realtimeCompanyId = null;
    _realtimeForRequestor = false;
  }

  void _setDisabledState() {
    _occurrences = const [];
    _errorMessage = null;
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }
}
