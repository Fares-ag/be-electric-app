import 'package:image_picker/image_picker.dart';

import '../../models/support_request.dart';
import '../../services/supabase_database_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../config/locator.dart';
import '../support_request_repository.dart';

class SupabaseSupportRequestRepository implements SupportRequestRepository {
  SupabaseSupportRequestRepository({
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
  Future<String> createSupportRequest(SupportRequest request) =>
      _database.createSupportRequest(request);

  @override
  Future<List<SupportRequest>> getSupportRequestsForCurrentUser(
    String userId,
  ) =>
      _database.getSupportRequestsForUser(userId);

  @override
  Future<String?> uploadAttachment({
    required XFile file,
    required String fileName,
    required String supportRequestId,
  }) {
    return _storage.uploadFile(
      file: file,
      fileName: fileName,
      folder: 'support_requests/$supportRequestId',
    );
  }
}
