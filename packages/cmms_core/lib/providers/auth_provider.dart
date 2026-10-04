import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/user.dart';
import '../repositories/cmms_repositories.dart';
import '../services/session_purge_service.dart';
import '../services/supabase_auth_service.dart';
import '../utils/auth_login_policy.dart';
import '../config/locator.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  /// True only while [checkAuthStatus] is resolving (cold start / session restore).
  /// Do not use for logout — see [isLoading] for login button state.
  bool _isRestoringSession = false;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  /// When true, [AuthWrapper] may show a full-screen progress indicator.
  bool get isRestoringSession => _isRestoringSession;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkAuthStatus() async {
    _isRestoringSession = true;
    notifyListeners();

    try {
      // Check Supabase authentication first
      final supabaseAuthService = sl<SupabaseAuthService>();
      if (supabaseAuthService.isSignedIn) {
        final supabaseUser = await supabaseAuthService.getCurrentAppUser();
        if (supabaseUser != null) {
          final dbUser = await CmmsRepositories.users
              .getUserByEmail(supabaseUser.email);
          if (isSessionAuthorized(hasDatabaseUser: dbUser != null)) {
            _currentUser = dbUser;
            _isAuthenticated = true;
            notifyListeners();
            return;
          }

          debugPrint(
            '⚠️ Supabase session active but no public.users row for '
            '${supabaseUser.email}. Clearing session.',
          );
          await supabaseAuthService.signOut();
        }
      }

      // Fallback: restore from local prefs only in debug/demo builds.
      // Release builds require a valid Supabase Auth session (RLS-safe).
      if (shouldAllowLocalSessionRestore(isReleaseMode: kReleaseMode)) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('current_user_id');

        if (userId != null) {
          final storedUser =
              await CmmsRepositories.users.getUserById(userId);
          if (storedUser != null) {
            _currentUser = storedUser;
            _isAuthenticated = true;
            debugPrint(
              '🔄 Session restored (debug) - User: ${storedUser.name}, '
              'Role: ${storedUser.role}',
            );
          } else {
            debugPrint(
              '⚠️ User ID $userId not found in Supabase, clearing session',
            );
            await prefs.remove('current_user_id');
          }
        }
      } else {
        // Clear stale prefs if Supabase session expired in release.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_user_id');
      }
    } catch (e, st) {
      debugPrint('Error checking auth status: $e');
      // Set default state if there's an error
      _isAuthenticated = false;
      _currentUser = null;
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Validate input
      if (email.isEmpty || password.isEmpty) {
        return false;
      }

      // Try Supabase authentication first
      try {
        final supabaseAuthService = sl<SupabaseAuthService>();
        final supabaseUser =
            await supabaseAuthService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (supabaseUser != null) {
          // Get user from Supabase
          var dbUser = await CmmsRepositories.users.getUserByEmail(email);

          debugPrint('🔑 Login: Supabase UID: ${supabaseUser.id}');
          debugPrint('🔑 Login: Supabase User: ${dbUser?.name} (ID: ${dbUser?.id})');

          if (dbUser == null) {
            if (!shouldAutoCreateUserOnLogin(
              autoCreateUsersOnLogin: AppConfig.autoCreateUsersOnLogin,
            )) {
              debugPrint(
                '⚠️ User authenticated in Supabase Auth but not found in users table. '
                'User must be created by an admin before they can log in.',
              );
              _isLoading = false;
              notifyListeners();
              return false;
            }

            debugPrint('⚠️ User not found in Supabase, creating requestor row...');
            final newUser = supabaseUser.copyWith(role: kAutoCreatedUserRole);
            final readableId =
                await CmmsRepositories.users.createUser(newUser);
            dbUser =
                await CmmsRepositories.users.getUserById(readableId);
            debugPrint(
              '✅ Created user in Supabase: ${dbUser?.name} (ID: ${dbUser?.id})',
            );
          }

          _currentUser = dbUser;
          if (_currentUser == null) {
            debugPrint('❌ AuthProvider: User created/found but getUserById returned null');
            _isLoading = false;
            notifyListeners();
            return false;
          }
          _isAuthenticated = true;

          debugPrint('🔑 Login: Using user ID: ${_currentUser!.id}');

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user_id', _currentUser!.id);

          _isLoading = false;
          debugPrint(
            '✅ AuthProvider: Login successful - isAuthenticated=$_isAuthenticated, '
            'isLoading=$_isLoading, user=${_currentUser!.name}',
          );
          notifyListeners();
          return true;
        }
      } catch (e, st) {
        debugPrint('Supabase authentication error: $e');
        // Continue to try demo users as fallback
      }

      // Fallback to demo users for testing (demo mode only)
      if (shouldAllowDemoUserFallback(isDemoMode: AppConfig.isDemoMode) &&
          _isDemoUser(email, password)) {
        // FIRST: Try to load user from Supabase (they might have been updated)
        final dbUser = await CmmsRepositories.users.getUserByEmail(email);

        if (dbUser != null) {
          // User exists in Supabase - use their current role!
          _currentUser = dbUser;
          debugPrint(
            '✅ Loaded demo user from Supabase with role: ${dbUser.role}',
          );
        } else {
          // User doesn't exist - create new demo user
          _currentUser = _createDemoUser(email);
          debugPrint(
            '✅ Created new demo user with role: ${_currentUser!.role}',
          );
        }

        _isAuthenticated = true;

        // Save user session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user_id', _currentUser!.id);

        // Set loading to false BEFORE notifying listeners
        _isLoading = false;
        debugPrint(
          '✅ AuthProvider: Demo user login successful - isAuthenticated=$_isAuthenticated, '
          'isLoading=$_isLoading, user=${_currentUser!.name}',
        );
        notifyListeners();
        return true;
      }

      // Debug-only passwordless DB lookup (never in release/profile builds).
      if (shouldAllowDebugDatabaseAuth(
            isReleaseMode: kReleaseMode,
            isDebugMode: kDebugMode,
          ) &&
          !kIsWeb) {
        try {
          final user = await _authenticateWithDatabase(email, password);
          if (user != null) {
            _currentUser = user;
            _isAuthenticated = true;

            // Save user session
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('current_user_id', _currentUser!.id);

            // Set loading to false BEFORE notifying listeners
            _isLoading = false;
            debugPrint(
              '✅ AuthProvider: Database auth successful - isAuthenticated=$_isAuthenticated, '
              'isLoading=$_isLoading, user=${_currentUser!.name}',
            );
            notifyListeners();
            return true;
          }
        } catch (e, st) {
          debugPrint('Database authentication error: $e');
          // Continue to return false if database auth fails
        }
      }

      return false;
    } catch (e, st) {
      debugPrint('Login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isDemoUser(String email, String password) {
    // Use AppConfig for demo user validation (only works in demo mode)
    return AppConfig.isDemoUser(email, password);
  }

  User _createDemoUser(String email) {
    // Get demo user from AppConfig
    final demoUser = AppConfig.getDemoUserByEmail(email);

    if (demoUser == null) {
      // Fallback for unknown demo user
      return User(
        id: 'demo_${email.split('@')[0]}_001',
        email: email,
        name: 'Demo User',
        role: 'technician',
        department: 'Maintenance',
        createdAt: DateTime.now(),
      );
    }

    return User(
      id: 'demo_${email.split('@')[0]}_001',
      email: email,
      name: demoUser['name'] ?? 'Demo User',
      role: demoUser['role'] ?? 'technician',
      department: demoUser['department'] ?? 'Maintenance',
      createdAt: DateTime.now(),
    );
  }

  Future<User?> _authenticateWithDatabase(String email, String password) async {
    if (!shouldAllowDebugDatabaseAuth(
      isReleaseMode: kReleaseMode,
      isDebugMode: kDebugMode,
    )) {
      debugPrint('Database-only auth disabled outside debug builds');
      return null;
    }
    try {
      final users = await CmmsRepositories.users.getAllUsers();
      final user = users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );
      return user;
    } catch (e, st) {
      debugPrint('Supabase authentication error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    // Do not set [isLoading] or [isRestoringSession] here. AuthWrapper treats those
    // as "block entire app with a spinner", which makes logout look stuck if
    // sign-out is slow or hangs.
    await SessionPurgeService.purgeOnSessionEnd();
    try {
      await sl<SupabaseAuthService>()
          .signOut()
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      debugPrint('Supabase signOut: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
    } catch (e, st) {
      debugPrint('Logout clear prefs: $e');
    }
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  bool get isManager => _currentUser?.isManager ?? false;
  bool get isTechnician => _currentUser?.isTechnician ?? false;

  /// Set user directly (for updates)
  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Get all users (for technician assignment)
  Future<List<User>> getAllUsers() async {
    try {
      return await CmmsRepositories.users.getAllUsers();
    } catch (e, st) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }
}
