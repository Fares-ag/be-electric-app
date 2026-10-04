import 'package:image_picker/image_picker.dart';

import 'package:cmms_core/models/support_request.dart';
import 'package:cmms_core/repositories/support_request_repository.dart';

class FakeSupportRequestRepository implements SupportRequestRepository {
  List<SupportRequest> requests = const [];
  Object? loadError;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> testConnection() async => true;

  @override
  Future<String> createSupportRequest(SupportRequest request) async =>
      request.id;

  @override
  Future<List<SupportRequest>> getSupportRequestsForCurrentUser(
    String userId,
  ) async {
    if (loadError != null) throw loadError!;
    return requests;
  }

  @override
  Future<String?> uploadAttachment({
    required XFile file,
    required String fileName,
    required String supportRequestId,
  }) async =>
      'https://example.com/$fileName';
}
