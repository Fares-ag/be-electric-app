import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing user authentication accounts
class UserAuthService {

  final SupabaseClient _client = Supabase.instance.client;

  /// Create a new authentication account for a user
  Future<Map<String, dynamic>?> createUserAccount({
    required String email,
    required String password,
    required String name,
    required String role,
    String? department,
    String? workEmail,
  }) async {
    try {
      // Create the authentication account
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          if (department != null) 'department': department,
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Note: User document creation is handled by the calling service
      // This service only handles authentication account creation

      return {
        'uid': user.id,
        'email': email,
        'name': name,
        'role': role,
        'isEmailVerified': user.emailConfirmedAt != null,
      };
    } on AuthException catch (e, st) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'Authentication error: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e, st) {
      throw Exception('Failed to create user account: $e');
    }
  }

  /// Send password reset email to user
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e, st) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = 'Password reset error: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e, st) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Update user's password
  Future<void> updateUserPassword(String uid, String newPassword) async {
    try {
      // This would typically be done by the user themselves
      // For admin password reset, you might want to use a different approach
      throw Exception(
          'Password updates should be done by the user through password reset',);
    } catch (e, st) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Deactivate user account
  Future<void> deactivateUserAccount(String uid) async {
    try {
      // This would typically disable the user's authentication account
      // For now, we'll just throw an exception as this requires admin privileges
      throw Exception('User deactivation requires admin privileges');
    } catch (e, st) {
      throw Exception('Failed to deactivate user account: $e');
    }
  }

  /// Reactivate user account
  Future<void> reactivateUserAccount(String uid) async {
    try {
      // This would typically re-enable the user's authentication account
      // For now, we'll just throw an exception as this requires admin privileges
      throw Exception('User reactivation requires admin privileges');
    } catch (e, st) {
      throw Exception('Failed to reactivate user account: $e');
    }
  }

  /// Get user authentication status
  Future<Map<String, dynamic>?> getUserAuthStatus(String uid) async {
    try {
      // This would check the user's authentication status
      // For now, return a basic status
      return {
        'uid': uid,
        'isActive': true,
        'isEmailVerified': false,
      };
    } catch (e, st) {
      throw Exception('Failed to get user auth status: $e');
    }
  }
}
