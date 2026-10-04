import 'package:flutter/foundation.dart';

import '../models/support_request.dart';
import '../services/support_request_service.dart';
import '../config/locator.dart';

class SupportRequestProvider extends ChangeNotifier {
  SupportRequestProvider({SupportRequestService? service})
      : _service = service ?? sl<SupportRequestService>();

  final SupportRequestService _service;

  bool _isSubmitting = false;
  double _uploadProgress = 0;
  bool _isLoadingRequests = false;
  bool _hasLoadedRequests = false;
  List<SupportRequest> _requests = const [];

  bool get isSubmitting => _isSubmitting;
  double get uploadProgress => _uploadProgress;
  bool get isLoadingRequests => _isLoadingRequests;
  bool get hasLoadedRequests => _hasLoadedRequests;
  List<SupportRequest> get requests => List.unmodifiable(_requests);
  bool get hasRequests => _requests.isNotEmpty;

  Future<SupportRequest> submitKnowHowRequest({
    required String createdBy,
    String? companyId,
    required String topic,
    required String question,
    String? chargerModel,
    List<PendingSupportAttachment> attachments = const [],
  }) {
    return _submit(
      () => _service.submitKnowHowRequest(
        createdBy: createdBy,
        companyId: companyId,
        topic: topic,
        question: question,
        chargerModel: chargerModel,
        attachments: attachments,
        onUploadProgress: _reportUploadProgress,
      ),
      attachmentCount: attachments.length,
    );
  }

  Future<SupportRequest> submitCommissioningRequest({
    required String createdBy,
    String? companyId,
    required String summary,
    required DateTime scheduledDate,
    required String address,
    required String country,
    required String chargerSerialNumber,
    required String chargerModel,
    required String details,
    List<PendingSupportAttachment> attachments = const [],
  }) {
    return _submit(
      () => _service.submitCommissioningRequest(
        createdBy: createdBy,
        companyId: companyId,
        summary: summary,
        scheduledDate: scheduledDate,
        address: address,
        country: country,
        chargerSerialNumber: chargerSerialNumber,
        chargerModel: chargerModel,
        details: details,
        attachments: attachments,
        onUploadProgress: _reportUploadProgress,
      ),
      attachmentCount: attachments.length,
    );
  }

  Future<void> loadSupportRequests(String userId) async {
    if (_isLoadingRequests) return;

    _isLoadingRequests = true;
    notifyListeners();

    try {
      _requests = await _service.getSupportRequestsForCurrentUser(userId);
      _hasLoadedRequests = true;
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  Future<void> refreshSupportRequests(String userId) =>
      loadSupportRequests(userId);

  Future<SupportRequest> _submit(
    Future<SupportRequest> Function() submit, {
    required int attachmentCount,
  }) async {
    if (_isSubmitting) {
      throw StateError('A support request is already being submitted.');
    }

    _isSubmitting = true;
    _uploadProgress = attachmentCount == 0 ? 1 : 0;
    notifyListeners();

    try {
      final result = await submit();
      _uploadProgress = 1;
      return result;
    } finally {
      _isSubmitting = false;
      _uploadProgress = 0;
      notifyListeners();
    }
  }

  void _reportUploadProgress(int completed, int total) {
    if (total <= 0) {
      _uploadProgress = 1;
    } else {
      _uploadProgress = completed / total;
    }
    notifyListeners();
  }
}
