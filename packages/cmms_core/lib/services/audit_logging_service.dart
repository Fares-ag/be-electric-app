// Audit Logging Service - Comprehensive activity tracking and compliance reporting

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_database_service.dart';
import '../config/locator.dart';

enum AuditEventType {
  userLogin,
  userLogout,
  userCreated,
  userUpdated,
  userDeleted,
  workOrderCreated,
  workOrderUpdated,
  workOrderCompleted,
  workOrderDeleted,
  pmTaskCreated,
  pmTaskUpdated,
  pmTaskCompleted,
  pmTaskDeleted,
  assetCreated,
  assetUpdated,
  assetDeleted,
  inventoryRequestCreated,
  inventoryRequestApproved,
  inventoryRequestRejected,
  inventoryUpdated,
  systemConfigurationChanged,
  dataExported,
  dataImported,
  escalationTriggered,
  notificationSent,
  reportGenerated,
  securityEvent,
  errorOccurred,
  systemMaintenance,
}

enum AuditEventSeverity {
  low,
  medium,
  high,
  critical,
}

class AuditEvent {
  AuditEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.userId,
    required this.timestamp,
    required this.description,
    this.userName,
    this.ipAddress,
    this.userAgent,
    this.resourceId,
    this.resourceType,
    this.oldValues,
    this.newValues,
    this.metadata = const {},
    this.sessionId,
    this.requestId,
  });

  factory AuditEvent.fromMap(Map<String, dynamic> map) => AuditEvent(
        id: map['id'],
        type: AuditEventType.values.firstWhere(
          (e) => e.toString() == 'AuditEventType.${map['type']}',
          orElse: () => AuditEventType.systemMaintenance,
        ),
        severity: AuditEventSeverity.values.firstWhere(
          (e) => e.toString() == 'AuditEventSeverity.${map['severity']}',
          orElse: () => AuditEventSeverity.medium,
        ),
        userId: map['userId'],
        timestamp: DateTime.parse(map['timestamp']),
        description: map['description'],
        userName: map['userName'],
        ipAddress: map['ipAddress'],
        userAgent: map['userAgent'],
        resourceId: map['resourceId'],
        resourceType: map['resourceType'],
        oldValues: map['oldValues'] != null
            ? Map<String, dynamic>.from(map['oldValues'])
            : null,
        newValues: map['newValues'] != null
            ? Map<String, dynamic>.from(map['newValues'])
            : null,
        metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
        sessionId: map['sessionId'],
        requestId: map['requestId'],
      );

  final String id;
  final AuditEventType type;
  final AuditEventSeverity severity;
  final String userId;
  final DateTime timestamp;
  final String description;
  final String? userName;
  final String? ipAddress;
  final String? userAgent;
  final String? resourceId;
  final String? resourceType;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final Map<String, dynamic> metadata;
  final String? sessionId;
  final String? requestId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.toString().split('.').last,
        'severity': severity.toString().split('.').last,
        'userId': userId,
        'timestamp': timestamp.toIso8601String(),
        'description': description,
        'userName': userName,
        'ipAddress': ipAddress,
        'userAgent': userAgent,
        'resourceId': resourceId,
        'resourceType': resourceType,
        'oldValues': oldValues,
        'newValues': newValues,
        'metadata': metadata,
        'sessionId': sessionId,
        'requestId': requestId,
      };
}

class AuditLoggingService {

  final List<AuditEvent> _events = [];
  final StreamController<AuditEvent> _eventController =
      StreamController<AuditEvent>.broadcast();
  Timer? _cleanupTimer;
  bool _isInitialized = false;
  final SupabaseDatabaseService _databaseService =
      sl<SupabaseDatabaseService>();

  List<AuditEvent> get events => List.unmodifiable(_events);
  Stream<AuditEvent> get eventStream => _eventController.stream;

  /// Initialize audit logging service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadAuditEvents();
    _startCleanupTimer();
    _isInitialized = true;

    debugPrint('âœ… AuditLoggingService: Initialized');
  }

  /// Load audit events from storage
  Future<void> _loadAuditEvents() async {
    try {
      // Try Firestore first, fallback to local storage
      try {
        final firestoreEvents = await _databaseService.getAuditEvents();
        _events.clear();
        _events.addAll(firestoreEvents);
        debugPrint(
          'âœ… AuditLoggingService: Loaded ${_events.length} events from Firestore',
        );
      } catch (e, st) {
        debugPrint(
          'âš ï¸ AuditLoggingService: Firestore unavailable, loading from local storage: $e',
        );
        // Fallback to local storage
        final prefs = await SharedPreferences.getInstance();
        final eventsJson = prefs.getStringList('audit_events') ?? [];

        _events.clear();
        for (final json in eventsJson) {
          try {
            final event = AuditEvent.fromMap(jsonDecode(json));
            _events.add(event);
          } catch (e, st) {
            debugPrint('Error loading audit event: $e');
          }
        }
      }

      _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e, st) {
      debugPrint('âŒ AuditLoggingService: Error loading audit events: $e');
    }
  }

  /// Save audit events to storage
  Future<void> _saveAuditEvents() async {
    try {
      // Save to Firestore first, then local storage as backup
      try {
        await _databaseService.saveAuditEvent(_events.last);
        debugPrint('âœ… AuditLoggingService: Saved event to Firestore');
      } catch (e, st) {
        debugPrint(
          'âš ï¸ AuditLoggingService: Firestore save failed, using local storage: $e',
        );
      }

      // Always save to local storage as backup
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = _events.map((e) => jsonEncode(e.toMap())).toList();
      await prefs.setStringList('audit_events', eventsJson);
    } catch (e, st) {
      debugPrint('âŒ AuditLoggingService: Error saving audit events: $e');
    }
  }

  /// Log audit event
  Future<String> logEvent({
    required AuditEventType type,
    required String userId,
    required String description,
    AuditEventSeverity severity = AuditEventSeverity.medium,
    String? userName,
    String? ipAddress,
    String? userAgent,
    String? resourceId,
    String? resourceType,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic> metadata = const {},
    String? sessionId,
    String? requestId,
  }) async {
    final event = AuditEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      severity: severity,
      userId: userId,
      timestamp: DateTime.now(),
      description: description,
      userName: userName,
      ipAddress: ipAddress,
      userAgent: userAgent,
      resourceId: resourceId,
      resourceType: resourceType,
      oldValues: oldValues,
      newValues: newValues,
      metadata: metadata,
      sessionId: sessionId,
      requestId: requestId,
    );

    _events.insert(0, event);
    await _saveAuditEvents();
    _eventController.add(event);

    debugPrint(
      'ðŸ“ AuditLoggingService: Logged event: ${event.type} - ${event.description}',
    );
    return event.id;
  }

  /// Log user login
  Future<String> logUserLogin({
    required String userId,
    String? userName,
    String? ipAddress,
    String? userAgent,
    String? sessionId,
  }) async =>
      logEvent(
        type: AuditEventType.userLogin,
        userId: userId,
        description: 'User logged in',
        severity: AuditEventSeverity.low,
        userName: userName,
        ipAddress: ipAddress,
        userAgent: userAgent,
        sessionId: sessionId,
      );

  /// Log user logout
  Future<String> logUserLogout({
    required String userId,
    String? userName,
    String? sessionId,
  }) async =>
      logEvent(
        type: AuditEventType.userLogout,
        userId: userId,
        description: 'User logged out',
        severity: AuditEventSeverity.low,
        userName: userName,
        sessionId: sessionId,
      );

  /// Log user creation
  Future<String> logUserCreated({
    required String userId,
    required String createdUserId,
    String? userName,
    Map<String, dynamic>? userData,
  }) async =>
      logEvent(
        type: AuditEventType.userCreated,
        userId: userId,
        description: 'User created: $createdUserId',
        userName: userName,
        resourceId: createdUserId,
        resourceType: 'user',
        newValues: userData,
      );

  /// Log user update
  Future<String> logUserUpdated({
    required String userId,
    required String updatedUserId,
    String? userName,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async =>
      logEvent(
        type: AuditEventType.userUpdated,
        userId: userId,
        description: 'User updated: $updatedUserId',
        userName: userName,
        resourceId: updatedUserId,
        resourceType: 'user',
        oldValues: oldValues,
        newValues: newValues,
      );

  /// Log user deletion
  Future<String> logUserDeleted({
    required String userId,
    required String deletedUserId,
    String? userName,
    Map<String, dynamic>? userData,
  }) async =>
      logEvent(
        type: AuditEventType.userDeleted,
        userId: userId,
        description: 'User deleted: $deletedUserId',
        severity: AuditEventSeverity.high,
        userName: userName,
        resourceId: deletedUserId,
        resourceType: 'user',
        oldValues: userData,
      );

  /// Log work order creation
  Future<String> logWorkOrderCreated({
    required String userId,
    required String workOrderId,
    String? userName,
    Map<String, dynamic>? workOrderData,
  }) async =>
      logEvent(
        type: AuditEventType.workOrderCreated,
        userId: userId,
        description: 'Work order created: $workOrderId',
        userName: userName,
        resourceId: workOrderId,
        resourceType: 'work_order',
        newValues: workOrderData,
      );

  /// Log work order update
  Future<String> logWorkOrderUpdated({
    required String userId,
    required String workOrderId,
    String? userName,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async =>
      logEvent(
        type: AuditEventType.workOrderUpdated,
        userId: userId,
        description: 'Work order updated: $workOrderId',
        userName: userName,
        resourceId: workOrderId,
        resourceType: 'work_order',
        oldValues: oldValues,
        newValues: newValues,
      );

  /// Log work order completion
  Future<String> logWorkOrderCompleted({
    required String userId,
    required String workOrderId,
    String? userName,
    Map<String, dynamic>? completionData,
  }) async =>
      logEvent(
        type: AuditEventType.workOrderCompleted,
        userId: userId,
        description: 'Work order completed: $workOrderId',
        userName: userName,
        resourceId: workOrderId,
        resourceType: 'work_order',
        newValues: completionData,
      );

  /// Log PM task creation
  Future<String> logPMTaskCreated({
    required String userId,
    required String pmTaskId,
    String? userName,
    Map<String, dynamic>? pmTaskData,
  }) async =>
      logEvent(
        type: AuditEventType.pmTaskCreated,
        userId: userId,
        description: 'PM task created: $pmTaskId',
        userName: userName,
        resourceId: pmTaskId,
        resourceType: 'pm_task',
        newValues: pmTaskData,
      );

  /// Log PM task completion
  Future<String> logPMTaskCompleted({
    required String userId,
    required String pmTaskId,
    String? userName,
    Map<String, dynamic>? completionData,
  }) async =>
      logEvent(
        type: AuditEventType.pmTaskCompleted,
        userId: userId,
        description: 'PM task completed: $pmTaskId',
        userName: userName,
        resourceId: pmTaskId,
        resourceType: 'pm_task',
        newValues: completionData,
      );

  /// Log inventory request creation
  Future<String> logInventoryRequestCreated({
    required String userId,
    required String requestId,
    String? userName,
    Map<String, dynamic>? requestData,
  }) async =>
      logEvent(
        type: AuditEventType.inventoryRequestCreated,
        userId: userId,
        description: 'Inventory request created: $requestId',
        userName: userName,
        resourceId: requestId,
        resourceType: 'inventory_request',
        newValues: requestData,
      );

  /// Log inventory request approval
  Future<String> logInventoryRequestApproved({
    required String userId,
    required String requestId,
    String? userName,
    Map<String, dynamic>? approvalData,
  }) async =>
      logEvent(
        type: AuditEventType.inventoryRequestApproved,
        userId: userId,
        description: 'Inventory request approved: $requestId',
        userName: userName,
        resourceId: requestId,
        resourceType: 'inventory_request',
        newValues: approvalData,
      );

  /// Log inventory request rejection
  Future<String> logInventoryRequestRejected({
    required String userId,
    required String requestId,
    String? userName,
    String? reason,
  }) async =>
      logEvent(
        type: AuditEventType.inventoryRequestRejected,
        userId: userId,
        description: 'Inventory request rejected: $requestId',
        userName: userName,
        resourceId: requestId,
        resourceType: 'inventory_request',
        metadata: {'reason': reason},
      );

  /// Log data export
  Future<String> logDataExported({
    required String userId,
    required String reportType,
    String? userName,
    Map<String, dynamic>? exportData,
  }) async =>
      logEvent(
        type: AuditEventType.dataExported,
        userId: userId,
        description: 'Data exported: $reportType',
        userName: userName,
        resourceType: 'export',
        newValues: exportData,
      );

  /// Log data import
  Future<String> logDataImported({
    required String userId,
    required String importType,
    String? userName,
    Map<String, dynamic>? importData,
  }) async =>
      logEvent(
        type: AuditEventType.dataImported,
        userId: userId,
        description: 'Data imported: $importType',
        userName: userName,
        resourceType: 'import',
        newValues: importData,
      );

  /// Log security event
  Future<String> logSecurityEvent({
    required String userId,
    required String description,
    AuditEventSeverity severity = AuditEventSeverity.high,
    String? userName,
    Map<String, dynamic>? securityData,
  }) async =>
      logEvent(
        type: AuditEventType.securityEvent,
        userId: userId,
        description: description,
        severity: severity,
        userName: userName,
        metadata: securityData ?? {},
      );

  /// Log error
  Future<String> logError({
    required String userId,
    required String error,
    String? userName,
    Map<String, dynamic>? errorData,
  }) async =>
      logEvent(
        type: AuditEventType.errorOccurred,
        userId: userId,
        description: 'Error occurred: $error',
        severity: AuditEventSeverity.high,
        userName: userName,
        metadata: errorData ?? {},
      );

  /// Log system maintenance
  Future<String> logSystemMaintenance({
    required String userId,
    required String description,
    String? userName,
    Map<String, dynamic>? maintenanceData,
  }) async =>
      logEvent(
        type: AuditEventType.systemMaintenance,
        userId: userId,
        description: description,
        userName: userName,
        metadata: maintenanceData ?? {},
      );

  /// Get events by user
  List<AuditEvent> getEventsByUser(String userId) =>
      _events.where((e) => e.userId == userId).toList();

  /// Get events by type
  List<AuditEvent> getEventsByType(AuditEventType type) =>
      _events.where((e) => e.type == type).toList();

  /// Get events by severity
  List<AuditEvent> getEventsBySeverity(AuditEventSeverity severity) =>
      _events.where((e) => e.severity == severity).toList();

  /// Get events by date range
  List<AuditEvent> getEventsByDateRange(DateTime start, DateTime end) => _events
      .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
      .toList();

  /// Get events by resource
  List<AuditEvent> getEventsByResource(
    String resourceId,
    String resourceType,
  ) =>
      _events
          .where(
            (e) => e.resourceId == resourceId && e.resourceType == resourceType,
          )
          .toList();

  /// Get audit statistics
  Map<String, dynamic> getAuditStats() {
    final totalEvents = _events.length;
    final eventsByType = <String, int>{};
    final eventsBySeverity = <String, int>{};
    final eventsByUser = <String, int>{};

    for (final event in _events) {
      final type = event.type.toString().split('.').last;
      eventsByType[type] = (eventsByType[type] ?? 0) + 1;

      final severity = event.severity.toString().split('.').last;
      eventsBySeverity[severity] = (eventsBySeverity[severity] ?? 0) + 1;

      eventsByUser[event.userId] = (eventsByUser[event.userId] ?? 0) + 1;
    }

    final now = DateTime.now();
    final last24Hours = _events
        .where(
          (e) => e.timestamp.isAfter(now.subtract(const Duration(hours: 24))),
        )
        .length;
    final last7Days = _events
        .where(
          (e) => e.timestamp.isAfter(now.subtract(const Duration(days: 7))),
        )
        .length;

    return {
      'totalEvents': totalEvents,
      'eventsLast24Hours': last24Hours,
      'eventsLast7Days': last7Days,
      'eventsByType': eventsByType,
      'eventsBySeverity': eventsBySeverity,
      'eventsByUser': eventsByUser,
      'mostActiveUser': eventsByUser.isNotEmpty
          ? eventsByUser.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
      'mostCommonEventType': eventsByType.isNotEmpty
          ? eventsByType.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
    };
  }

  /// Generate compliance report
  Map<String, dynamic> generateComplianceReport({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    AuditEventType? eventType,
  }) {
    var filteredEvents = _events;

    if (startDate != null) {
      filteredEvents =
          filteredEvents.where((e) => e.timestamp.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      filteredEvents =
          filteredEvents.where((e) => e.timestamp.isBefore(endDate)).toList();
    }
    if (userId != null) {
      filteredEvents = filteredEvents.where((e) => e.userId == userId).toList();
    }
    if (eventType != null) {
      filteredEvents =
          filteredEvents.where((e) => e.type == eventType).toList();
    }

    final report = {
      'reportGenerated': DateTime.now().toIso8601String(),
      'filters': {
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'userId': userId,
        'eventType': eventType?.toString().split('.').last,
      },
      'summary': {
        'totalEvents': filteredEvents.length,
        'dateRange': {
          'start': filteredEvents.isNotEmpty
              ? filteredEvents
                  .map((e) => e.timestamp)
                  .reduce((a, b) => a.isBefore(b) ? a : b)
                  .toIso8601String()
              : null,
          'end': filteredEvents.isNotEmpty
              ? filteredEvents
                  .map((e) => e.timestamp)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .toIso8601String()
              : null,
        },
      },
      'events': filteredEvents.map((e) => e.toMap()).toList(),
    };

    return report;
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _cleanupOldEvents();
    });
  }

  /// Cleanup old events (keep last 90 days)
  Future<void> _cleanupOldEvents() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final initialCount = _events.length;

    _events.removeWhere((e) => e.timestamp.isBefore(cutoffDate));

    if (_events.length != initialCount) {
      await _saveAuditEvents();
      debugPrint(
        'ðŸ§¹ AuditLoggingService: Cleaned up ${initialCount - _events.length} old events',
      );
    }
  }

  /// Clear all events
  Future<void> clearAllEvents() async {
    _events.clear();
    await _saveAuditEvents();
    debugPrint('ðŸ—‘ï¸ AuditLoggingService: Cleared all audit events');
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _eventController.close();
  }
}
