import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../repositories/cmms_repositories.dart';
import '../services/unified_data_service.dart';
import '../utils/performance_optimizer.dart';
import '../utils/stream_subscription_cancel.dart';
import 'domain/cmms_domain_provider.dart';
import 'domain/domain_deduplication.dart';
import '../config/locator.dart';

class UserProvider with ChangeNotifier implements CmmsDomainProvider {
  UserProvider({UnifiedDataService? dataService})
      : _dataService = dataService ?? sl<UnifiedDataService>();

  final UnifiedDataService _dataService;
  bool _isDisposed = false;
  StreamSubscription<List<User>>? _usersSubscription;
  List<User> _realtimeUsers = [];

  List<User> get users =>
      _realtimeUsers.isNotEmpty ? _realtimeUsers : _dataService.users;

  bool get isUsersLoading => _dataService.isUsersLoading;

  Stream<List<User>> get usersStream => _dataService.usersStream;

  int get totalUsers => users.length;
  int get technicians =>
      users.where((user) => user.role == 'technician').length;
  int get managers => users.where((user) => user.role == 'manager').length;
  int get admins => users.where((user) => user.role == 'admin').length;
  int get requestors => users.where((user) => user.role == 'requestor').length;

  List<User> getTechnicians() =>
      users.where((user) => user.role.toLowerCase() == 'technician').toList();

  List<User> getManagers() =>
      users.where((user) => user.role.toLowerCase() == 'manager').toList();

  List<User> getAdmins() =>
      users.where((user) => user.role.toLowerCase() == 'admin').toList();

  User? getUserById(String id) {
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (_) {
      return null;
    }
  }

  User? getUserByEmail(String email) {
    try {
      return users.firstWhere((user) => user.email == email);
    } catch (_) {
      return null;
    }
  }

  Future<String> createUser(User user) async {
    try {
      final id = await _dataService.createUser(user);
      final createdUser = user.copyWith(id: id);
      final index = _realtimeUsers.indexWhere((u) => u.id == id);
      if (index != -1) {
        _realtimeUsers[index] = createdUser;
      } else {
        _realtimeUsers.add(createdUser);
      }
      notifyListeners();
      return id;
    } catch (e, st) {
      debugPrint('UserProvider: Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _dataService.updateUser(user);
      final index = _realtimeUsers.indexWhere((u) => u.id == user.id);
      if (index != -1) {
        _realtimeUsers[index] = user;
      } else {
        _realtimeUsers.add(user);
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('UserProvider: Error updating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(
    String userId, {
    String? currentUserRole,
    String? currentUserId,
  }) async {
    try {
      if (currentUserId != null && currentUserId == userId) {
        throw Exception('You cannot delete your own account');
      }

      User user;
      try {
        user = users.firstWhere((u) => u.id == userId);
      } catch (e, st) {
        final fetchedUser = await CmmsRepositories.users.getUserById(userId);
        if (fetchedUser == null) {
          throw Exception('User not found');
        }
        user = fetchedUser;
      }

      if ((user.role == 'admin' || user.role == 'manager') &&
          currentUserRole != 'admin') {
        throw Exception(
          'Only administrators can delete ${user.role}s',
        );
      }

      await _dataService.deleteUser(userId);
      _realtimeUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e, st) {
      debugPrint('UserProvider: Error deleting user: $e');
      rethrow;
    }
  }

  @override
  void clearCache() {
    _realtimeUsers = [];
  }

  @override
  Future<void> cancelRealtimeListeners() async {
    await cancelStreamSubscriptions([_usersSubscription]);
    _usersSubscription = null;
  }

  @override
  Future<void> startRealtimeListeners() async {
    if (_isDisposed) return;
    await cancelRealtimeListeners();
    if (_isDisposed) return;

    _usersSubscription = _dataService.usersStream.listen(
      (users) {
        _realtimeUsers = dedupeUsers(users);
        if (!_isDisposed) {
          ChangeNotifierBatcher.batchNotify(
            () => notifyListeners(),
            batchKey: this,
          );
        }
      },
      onError: (error) {
        debugPrint('❌ Users stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    ChangeNotifierBatcher.cancel(this);
    unawaited(cancelRealtimeListeners());
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
