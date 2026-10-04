// Activity Log Service - Manages activity history for work orders and PM tasks

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_log.dart';

class ActivityLogService {

  static const String _storageKey = 'activity_logs';
  final List<ActivityLog> _activityLogs = [];
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadActivityLogs();
      _isInitialized = true;
      debugPrint('âœ… ActivityLogService: Initialized successfully');
    } catch (e, st) {
      debugPrint('âŒ ActivityLogService: Error initializing: $e');
    }
  }

  /// Load activity logs from storage
  Future<void> _loadActivityLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_storageKey);

      if (logsJson != null) {
        final List<dynamic> logsList = jsonDecode(logsJson);
        _activityLogs.clear();
        _activityLogs.addAll(
          logsList
              .map((log) => ActivityLog.fromMap(log as Map<String, dynamic>)),
        );
        debugPrint(
          'ðŸ“– ActivityLogService: Loaded ${_activityLogs.length} activity logs',
        );
      }
    } catch (e, st) {
      debugPrint('âŒ ActivityLogService: Error loading activity logs: $e');
    }
  }

  /// Save activity logs to storage
  Future<void> _saveActivityLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = jsonEncode(
        _activityLogs.map((log) => log.toMap()).toList(),
      );
      await prefs.setString(_storageKey, logsJson);
    } catch (e, st) {
      debugPrint('âŒ ActivityLogService: Error saving activity logs: $e');
    }
  }

  /// Log an activity
  Future<void> logActivity({
    required String entityId,
    required String entityType,
    required ActivityType activityType,
    required String userId,
    String? userName,
    String? description,
    String? oldValue,
    String? newValue,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final log = ActivityLog(
        id: const Uuid().v4(),
        entityId: entityId,
        entityType: entityType,
        activityType: activityType,
        timestamp: DateTime.now(),
        userId: userId,
        userName: userName,
        description: description,
        oldValue: oldValue,
        newValue: newValue,
        additionalData: additionalData,
      );

      _activityLogs.add(log);
      await _saveActivityLogs();

      debugPrint(
        'ðŸ“ ActivityLogService: Logged activity - ${log.activityType.name} for $entityType $entityId',
      );
    } catch (e, st) {
      debugPrint('âŒ ActivityLogService: Error logging activity: $e');
    }
  }

  /// Get all activity logs for a specific entity
  List<ActivityLog> getActivityLogs(String entityId) {
    return _activityLogs.where((log) => log.entityId == entityId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
  }

  /// Get activity logs for a specific entity type
  List<ActivityLog> getActivityLogsByType(String entityType) =>
      _activityLogs.where((log) => log.entityType == entityType).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  /// Get all activity logs
  List<ActivityLog> getAllActivityLogs() => List.from(_activityLogs)
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  /// Clear all activity logs
  Future<void> clearAllLogs() async {
    _activityLogs.clear();
    await _saveActivityLogs();
    debugPrint('ðŸ—‘ï¸ ActivityLogService: Cleared all activity logs');
  }

  /// Clear activity logs for a specific entity
  Future<void> clearEntityLogs(String entityId) async {
    _activityLogs.removeWhere((log) => log.entityId == entityId);
    await _saveActivityLogs();
    debugPrint(
      'ðŸ—‘ï¸ ActivityLogService: Cleared activity logs for entity $entityId',
    );
  }
}
