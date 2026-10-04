// Enhanced Notification Service - Centralizes notification handling

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'realtime_supabase_service.dart';
import 'supabase_database_service.dart';
import '../config/locator.dart';

enum NotificationType {
  workOrderCreated,
  workOrderAssigned,
  workOrderStarted,
  workOrderCompleted,
  workOrderOverdue,
  pmTaskAssigned,
  pmTaskDue,
  pmTaskOverdue,
  pmTaskCompleted,
  escalation,
  systemAlert,
  inventoryLowStock,
  budgetExceeded,
  qualityInspection,
  workflowApproval,
  workflowRejected,
  userActivity,
  systemHealth,
  inventoryRequest,
}

enum NotificationPriority {
  low,
  medium,
  high,
  critical,
}

enum NotificationChannel {
  inApp,
  push,
  email,
  sms,
}

class EnhancedNotification {
  EnhancedNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.channel,
    required this.createdAt,
    this.userId,
    this.relatedId,
    this.relatedType,
    this.isRead = false,
    this.readAt,
    this.data,
    this.expiresAt,
    this.actions = const [],
  });

  factory EnhancedNotification.fromMap(Map<String, dynamic> map) =>
      EnhancedNotification(
        id: map['id'],
        title: map['title'],
        message: map['message'],
        type: NotificationType.values.firstWhere(
          (e) => e.toString() == 'NotificationType.${map['type']}',
          orElse: () => NotificationType.systemAlert,
        ),
        priority: NotificationPriority.values.firstWhere(
          (e) => e.toString() == 'NotificationPriority.${map['priority']}',
          orElse: () => NotificationPriority.medium,
        ),
        channel: NotificationChannel.values.firstWhere(
          (e) => e.toString() == 'NotificationChannel.${map['channel']}',
          orElse: () => NotificationChannel.inApp,
        ),
        userId: map['userId'],
        relatedId: map['relatedId'],
        relatedType: map['relatedType'],
        createdAt: DateTime.parse(map['createdAt']),
        isRead: map['isRead'] ?? false,
        readAt: map['readAt'] != null ? DateTime.parse(map['readAt']) : null,
        data:
            map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
        expiresAt:
            map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
        actions: List<String>.from(map['actions'] ?? []),
      );

  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final String? userId;
  final String? relatedId;
  final String? relatedType;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final Map<String, dynamic>? data;
  final DateTime? expiresAt;
  final List<String> actions;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.toString().split('.').last,
        'priority': priority.toString().split('.').last,
        'channel': channel.toString().split('.').last,
        'userId': userId,
        'relatedId': relatedId,
        'relatedType': relatedType,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'readAt': readAt?.toIso8601String(),
        'data': data,
        'expiresAt': expiresAt?.toIso8601String(),
        'actions': actions,
      };

  EnhancedNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    NotificationChannel? channel,
    String? userId,
    String? relatedId,
    String? relatedType,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    Map<String, dynamic>? data,
    DateTime? expiresAt,
    List<String>? actions,
  }) =>
      EnhancedNotification(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        type: type ?? this.type,
        priority: priority ?? this.priority,
        channel: channel ?? this.channel,
        userId: userId ?? this.userId,
        relatedId: relatedId ?? this.relatedId,
        relatedType: relatedType ?? this.relatedType,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        data: data ?? this.data,
        expiresAt: expiresAt ?? this.expiresAt,
        actions: actions ?? this.actions,
      );
}

class EnhancedNotificationService {

  final List<EnhancedNotification> _notifications = [];
  final StreamController<List<EnhancedNotification>> _notificationController =
      StreamController<List<EnhancedNotification>>.broadcast();
  final StreamController<EnhancedNotification> _newNotificationController =
      StreamController<EnhancedNotification>.broadcast();
  final SupabaseDatabaseService _firestoreService =
      sl<SupabaseDatabaseService>();

  bool _isInitialized = false;
  Timer? _cleanupTimer;
  String? _realtimeUserId;
  bool _realtimeListening = false;

  List<EnhancedNotification> get notifications =>
      List.unmodifiable(_notifications);
  Stream<List<EnhancedNotification>> get notificationStream =>
      _notificationController.stream;
  Stream<EnhancedNotification> get newNotificationStream =>
      _newNotificationController.stream;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get totalCount => _notifications.length;

  /// Loads persisted notifications once. Safe to call multiple times.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadNotifications();
    _startPeriodicCleanup();
    _isInitialized = true;
  }

  /// Load notifications from storage
  Future<void> _loadNotifications() async {
    try {
      // Try Supabase first, fallback to local storage
      try {
        final firestoreNotifications =
            await _firestoreService.getNotifications();
        _notifications.clear();
        _notifications.addAll(firestoreNotifications);
        debugPrint(
            'NotificationService: Loaded ${_notifications.length} notifications from Supabase',);
      } catch (e, st) {
        debugPrint(
            'NotificationService: Supabase unavailable, loading from local storage: $e',);
        // Fallback to local storage
        final prefs = await SharedPreferences.getInstance();
        final notificationsJson =
            prefs.getStringList('enhanced_notifications') ?? [];

        _notifications.clear();
        for (final json in notificationsJson) {
          try {
            final notification = EnhancedNotification.fromMap(jsonDecode(json));
            _notifications.add(notification);
          } catch (e, st) {
            debugPrint('Error loading notification: $e');
          }
        }
      }

      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _notificationController.add(_notifications);
    } catch (e, st) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Save notifications to storage
  Future<void> _saveNotifications() async {
    try {
      // Save to Supabase first, then local storage as backup
      if (_notifications.isNotEmpty) {
        try {
          await _firestoreService.saveNotification(_notifications.last);
          debugPrint('NotificationService: Saved notification to Supabase');
        } catch (e, st) {
          debugPrint(
              'NotificationService: Supabase save failed, using local storage: $e',);
        }
      }

      // Always save to local storage as backup
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          _notifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList('enhanced_notifications', notificationsJson);
    } catch (e, st) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Create and send notification
  Future<String> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    NotificationPriority priority = NotificationPriority.medium,
    NotificationChannel channel = NotificationChannel.inApp,
    String? userId,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? data,
    Duration? expiresIn,
    List<String> actions = const [],
  }) async {
    final notification = EnhancedNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      priority: priority,
      channel: channel,
      userId: userId,
      relatedId: relatedId,
      relatedType: relatedType,
      createdAt: DateTime.now(),
      data: data,
      expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null,
      actions: actions,
    );

    _notifications.insert(0, notification);
    await _saveNotifications();

    _notificationController.add(_notifications);
    _newNotificationController.add(notification);

    // Send to external channels if configured
    await _sendToExternalChannels(notification);

    return notification.id;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
      await _saveNotifications();
      _notificationController.add(_notifications);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
      }
    }
    await _saveNotifications();
    _notificationController.add(_notifications);
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    _notificationController.add(_notifications);
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    _notificationController.add(_notifications);
  }

  /// Get notifications for user
  List<EnhancedNotification> getNotificationsForUser(String userId) =>
      _notifications
          .where((n) => n.userId == userId || n.userId == null)
          .toList();

  /// Get notifications by type
  List<EnhancedNotification> getNotificationsByType(NotificationType type) =>
      _notifications.where((n) => n.type == type).toList();

  /// Get unread notifications
  List<EnhancedNotification> getUnreadNotifications() =>
      _notifications.where((n) => !n.isRead).toList();

  /// Send to external channels
  Future<void> _sendToExternalChannels(
    EnhancedNotification notification,
  ) async {
    // TODO: Implement push notifications, email, SMS
    // This would integrate with Firebase Cloud Messaging, email services, etc.
    debugPrint(
      'Sending notification to external channels: ${notification.title}',
    );
  }

  /// Start periodic cleanup of expired notifications
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(_cleanupExpiredNotifications());
    });
  }

  /// Clean up expired notifications
  Future<void> _cleanupExpiredNotifications() async {
    final now = DateTime.now();
    final expiredNotifications = _notifications
        .where((n) => n.expiresAt != null && n.expiresAt!.isBefore(now))
        .toList();

    if (expiredNotifications.isNotEmpty) {
      for (final notification in expiredNotifications) {
        _notifications.remove(notification);
      }
      await _saveNotifications();
      _notificationController.add(_notifications);
    }
  }

  /// Work Order Notifications
  Future<String> notifyWorkOrderCreated({
    required String workOrderId,
    required String requestorId,
    required String assetName,
  }) async =>
      createNotification(
        title: 'New Work Order Created',
        message:
            'Work order for $assetName has been created and is pending assignment',
        type: NotificationType.workOrderCreated,
        userId: requestorId,
        relatedId: workOrderId,
        relatedType: 'work_order',
        data: {'assetName': assetName},
      );

  Future<String> notifyWorkOrderAssigned({
    required String workOrderId,
    required String technicianId,
    required String assetName,
  }) async =>
      createNotification(
        title: 'Work Order Assigned',
        message: 'You have been assigned to work order for $assetName',
        type: NotificationType.workOrderAssigned,
        priority: NotificationPriority.high,
        userId: technicianId,
        relatedId: workOrderId,
        relatedType: 'work_order',
        data: {'assetName': assetName},
      );

  Future<String> notifyWorkOrderCompleted({
    required String workOrderId,
    required String requestorId,
    required String assetName,
  }) async =>
      createNotification(
        title: 'Work Order Completed',
        message: 'Work order for $assetName has been completed',
        type: NotificationType.workOrderCompleted,
        userId: requestorId,
        relatedId: workOrderId,
        relatedType: 'work_order',
        data: {'assetName': assetName},
      );

  Future<String> notifyWorkOrderOverdue({
    required String workOrderId,
    required String managerId,
    required String assetName,
  }) async =>
      createNotification(
        title: 'Work Order Overdue',
        message: 'Work order for $assetName is overdue and requires attention',
        type: NotificationType.workOrderOverdue,
        priority: NotificationPriority.critical,
        userId: managerId,
        relatedId: workOrderId,
        relatedType: 'work_order',
        data: {'assetName': assetName},
      );

  /// PM Task Notifications
  Future<String> notifyPMTaskAssigned({
    required String pmTaskId,
    required String technicianId,
    required String taskName,
  }) async =>
      createNotification(
        title: 'PM Task Assigned',
        message: 'You have been assigned PM task: $taskName',
        type: NotificationType.pmTaskAssigned,
        userId: technicianId,
        relatedId: pmTaskId,
        relatedType: 'pm_task',
        data: {'taskName': taskName},
      );

  Future<String> notifyPMTaskDue({
    required String pmTaskId,
    required String technicianId,
    required String taskName,
  }) async =>
      createNotification(
        title: 'PM Task Due',
        message: 'PM task "$taskName" is due soon',
        type: NotificationType.pmTaskDue,
        priority: NotificationPriority.high,
        userId: technicianId,
        relatedId: pmTaskId,
        relatedType: 'pm_task',
        data: {'taskName': taskName},
      );

  Future<String> notifyPMTaskOverdue({
    required String pmTaskId,
    required String managerId,
    required String taskName,
  }) async =>
      createNotification(
        title: 'PM Task Overdue',
        message: 'PM task "$taskName" is overdue',
        type: NotificationType.pmTaskOverdue,
        priority: NotificationPriority.critical,
        userId: managerId,
        relatedId: pmTaskId,
        relatedType: 'pm_task',
        data: {'taskName': taskName},
      );

  /// Escalation Notifications
  Future<String> notifyEscalation({
    required String itemId,
    required String itemType,
    required String managerId,
    required String reason,
  }) async =>
      createNotification(
        title: 'Escalation Required',
        message: '$itemType $itemId requires escalation: $reason',
        type: NotificationType.escalation,
        priority: NotificationPriority.critical,
        userId: managerId,
        relatedId: itemId,
        relatedType: itemType,
        data: {'reason': reason},
      );

  /// System Notifications
  Future<String> notifySystemAlert({
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.medium,
    String? userId,
  }) async =>
      createNotification(
        title: title,
        message: message,
        type: NotificationType.systemAlert,
        priority: priority,
        userId: userId,
      );

  /// Inventory Notifications
  Future<String> notifyLowStock({
    required String itemId,
    required String itemName,
    required int currentStock,
    required int minStock,
    required String managerId,
  }) async =>
      createNotification(
        title: 'Low Stock Alert',
        message: '$itemName is running low ($currentStock/$minStock)',
        type: NotificationType.inventoryLowStock,
        priority: NotificationPriority.high,
        userId: managerId,
        relatedId: itemId,
        relatedType: 'inventory_item',
        data: {
          'itemName': itemName,
          'currentStock': currentStock,
          'minStock': minStock,
        },
      );

  /// Budget Notifications
  Future<String> notifyBudgetExceeded({
    required String budgetId,
    required String budgetName,
    required double currentAmount,
    required double budgetLimit,
    required String managerId,
  }) async =>
      createNotification(
        title: 'Budget Exceeded',
        message:
            'Budget "$budgetName" has exceeded limit (${currentAmount.toStringAsFixed(2)}/${budgetLimit.toStringAsFixed(2)})',
        type: NotificationType.budgetExceeded,
        priority: NotificationPriority.critical,
        userId: managerId,
        relatedId: budgetId,
        relatedType: 'budget',
        data: {
          'budgetName': budgetName,
          'currentAmount': currentAmount,
          'budgetLimit': budgetLimit,
        },
      );

  /// Workflow Notifications
  Future<String> notifyWorkflowApproval({
    required String workflowId,
    required String workflowName,
    required String approverId,
  }) async =>
      createNotification(
        title: 'Workflow Approval Required',
        message: 'Workflow "$workflowName" requires your approval',
        type: NotificationType.workflowApproval,
        priority: NotificationPriority.high,
        userId: approverId,
        relatedId: workflowId,
        relatedType: 'workflow',
        data: {'workflowName': workflowName},
      );

  Future<String> notifyWorkflowRejected({
    required String workflowId,
    required String workflowName,
    required String creatorId,
    required String reason,
  }) async =>
      createNotification(
        title: 'Workflow Rejected',
        message: 'Workflow "$workflowName" was rejected: $reason',
        type: NotificationType.workflowRejected,
        userId: creatorId,
        relatedId: workflowId,
        relatedType: 'workflow',
        data: {
          'workflowName': workflowName,
          'reason': reason,
        },
      );

  /// Cancels background work without closing broadcast streams (GetIt singleton).
  void stopBackgroundWork() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    stopRealtimeListener();
  }

  /// Live INSERT/UPDATE for [userId] via Supabase Realtime (filtered).
  void startRealtimeListener(String userId) {
    if (userId.isEmpty) return;
    if (_realtimeListening && _realtimeUserId == userId) return;

    stopRealtimeListener();
    _realtimeUserId = userId;
    _realtimeListening = true;
    sl<RealtimeSupabaseService>().listenToNotificationChanges(
      userId: userId,
      onChanged: () {
        unawaited(_loadNotifications());
      },
    );
  }

  void stopRealtimeListener() {
    if (!_realtimeListening && _realtimeUserId == null) return;
    sl<RealtimeSupabaseService>().stopListeningToNotificationChanges();
    _realtimeListening = false;
    _realtimeUserId = null;
  }

  /// Test-only reset. GetIt singletons must stay alive for the app lifetime.
  @visibleForTesting
  void resetForTesting() {
    stopBackgroundWork();
    _isInitialized = false;
    _notifications.clear();
    if (!_notificationController.isClosed) {
      _notificationController.add(_notifications);
    }
  }
}
