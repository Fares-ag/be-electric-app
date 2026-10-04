import 'package:image_picker/image_picker.dart';

import '../models/support_request.dart';

/// Persistence and file uploads for Be Electric support requests.
abstract class SupportRequestRepository {
  Future<void> initialize();
  Future<bool> testConnection();

  Future<String> createSupportRequest(SupportRequest request);

  Future<List<SupportRequest>> getSupportRequestsForCurrentUser(String userId);

  Future<String?> uploadAttachment({
    required XFile file,
    required String fileName,
    required String supportRequestId,
  });
}
