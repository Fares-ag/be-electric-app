import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/support_request.dart';
import '../repositories/support_request_repository.dart';
import '../config/locator.dart';

typedef SupportUploadProgressCallback = void Function(int completed, int total);

/// Local attachment pending upload for a support request form.
class PendingSupportAttachment {
  PendingSupportAttachment({
    required this.file,
    required this.displayName,
    this.isImage = true,
  });

  final XFile file;
  final String displayName;
  final bool isImage;
}

class SupportRequestService {
  SupportRequestService({SupportRequestRepository? repository})
      : _repository = repository ?? sl<SupportRequestRepository>();

  final SupportRequestRepository _repository;

  Future<SupportRequest> submitKnowHowRequest({
    required String createdBy,
    String? companyId,
    required String topic,
    required String question,
    String? chargerModel,
    List<PendingSupportAttachment> attachments = const [],
    SupportUploadProgressCallback? onUploadProgress,
  }) async {
    final request = SupportRequest.create(
      type: SupportRequestType.knowHow,
      createdBy: createdBy,
      companyId: companyId,
      topic: topic.trim(),
      question: question.trim(),
      summary: topic.trim(),
      chargerModel: chargerModel?.trim().isEmpty ?? true
          ? null
          : chargerModel!.trim(),
    );

    return _submitWithAttachments(
      request: request,
      attachments: attachments,
      onUploadProgress: onUploadProgress,
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
    SupportUploadProgressCallback? onUploadProgress,
  }) async {
    final request = SupportRequest.create(
      type: SupportRequestType.commissioning,
      createdBy: createdBy,
      companyId: companyId,
      summary: summary.trim(),
      scheduledDate: scheduledDate,
      address: address.trim(),
      country: country.trim(),
      chargerSerialNumber: chargerSerialNumber.trim(),
      chargerModel: chargerModel.trim(),
      details: details.trim(),
    );

    return _submitWithAttachments(
      request: request,
      attachments: attachments,
      onUploadProgress: onUploadProgress,
    );
  }

  Future<SupportRequest> _submitWithAttachments({
    required SupportRequest request,
    required List<PendingSupportAttachment> attachments,
    SupportUploadProgressCallback? onUploadProgress,
  }) async {
    final uploadedUrls = <String>[];
    final total = attachments.length;

    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      final url = await _repository.uploadAttachment(
        file: attachment.file,
        fileName: _safeFileName(attachment.displayName, index),
        supportRequestId: request.id,
      );

      if (url == null || url.isEmpty) {
        throw Exception(
          'Failed to upload attachment "${attachment.displayName}". '
          'Please check your connection and try again.',
        );
      }

      uploadedUrls.add(url);
      onUploadProgress?.call(index + 1, total);
    }

    final requestWithAttachments = request.copyWith(attachments: uploadedUrls);
    final id = await _repository.createSupportRequest(requestWithAttachments);
    return requestWithAttachments.copyWith(id: id);
  }

  Future<List<SupportRequest>> getSupportRequestsForCurrentUser(
    String userId,
  ) {
    return _repository.getSupportRequestsForCurrentUser(userId);
  }

  String _safeFileName(String originalName, int index) {
    final baseName = p.basename(originalName).trim();
    if (baseName.isNotEmpty) {
      return baseName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    }
    return 'attachment_$index';
  }
}
