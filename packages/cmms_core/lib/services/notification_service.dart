// Notification Service - Handles system notifications and alerts

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/locator.dart';

enum NotificationType {
  workOrderCreated,
  workOrderAssigned,
  workOrderStarted,
  workOrderCompleted,
  pmTaskAssigned,
  pmTaskDue,
  pmTaskOverdue,
  systemAlert,
  escalation,
}

enum NotificationPriority {
  low,
  medium,
  high,
  critical,
}

class Notification {
  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.userId,
    this.relatedId,
    this.isRead = false,
    this.data,
  });

  factory Notification.fromMap(Map<String, dynamic> map) => Notification(
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
        userId: map['userId'],
        relatedId: map['relatedId'],
        createdAt: DateTime.parse(map['createdAt']),
        isRead: map['isRead'] ?? false,
        data:
            map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      );
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final String? userId;
  final String? relatedId; // Work order ID, PM task ID, etc.
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type.toString().split('.').last,
        'priority': priority.toString().split('.').last,
        'userId': userId,
        'relatedId': relatedId,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'data': data,
      };

  Notification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    String? userId,
    String? relatedId,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? data,
  }) =>
      Notification(
        id: id ?? this.id,
        title: title ?? this.title,
        message: message ?? this.message,
        type: type ?? this.type,
        priority: priority ?? this.priority,
        userId: userId ?? this.userId,
        relatedId: relatedId ?? this.relatedId,
        createdAt: createdAt ?? this.createdAt,
        isRead: isRead ?? this.isRead,
        data: data ?? this.data,
      );
}

class NotificationService {

  final List<Notification> _notifications = [];
  final StreamController<List<Notification>> _notificationsController =
      StreamController<List<Notification>>.broadcast();
  bool _isInitialized = false;

  Stream<List<Notification>> get notificationsStream =>
      _notificationsController.stream;

  List<Notification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Loads persisted notifications once. Safe to call multiple times.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadNotifications();
    if (!_notificationsController.isClosed) {
      _notificationsController.add(_notifications);
    }
    _isInitialized = true;
  }

  /// Create a new notification
  Future<void> createNotification({
    required String title,
    required String message,
    required NotificationType type,
    required NotificationPriority priority,
    String? body,
    String? userId,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    final notification = Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      priority: priority,
      userId: userId,
      relatedId: relatedId,
      createdAt: DateTime.now(),
      data: data,
    );

    _notifications.insert(0, notification);
    await _saveNotifications();
    _notificationsController.add(_notifications);

    // Log notification creation
    debugPrint('ðŸ”” Notification created: ${notification.title}');
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      _notificationsController.add(_notifications);
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _saveNotifications();
    _notificationsController.add(_notifications);
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    _notificationsController.add(_notifications);
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    _notificationsController.add(_notifications);
  }

  /// Get notifications for a specific user
  List<Notification> getNotificationsForUser(String userId) =>
      _notifications.where((n) => n.userId == userId).toList();

  /// Get unread notifications for a specific user
  List<Notification> getUnreadNotificationsForUser(String userId) =>
      _notifications.where((n) => n.userId == userId && !n.isRead).toList();

  /// Get notifications by type
  List<Notification> getNotificationsByType(NotificationType type) =>
      _notifications.where((n) => n.type == type).toList();

  /// Get notifications by priority
  List<Notification> getNotificationsByPriority(
    NotificationPriority priority,
  ) =>
      _notifications.where((n) => n.priority == priority).toList();

  /// Work Order specific notifications
  Future<void> notifyWorkOrderCreated({
    required String workOrderId,
    required String requestorId,
    required String assetId,
  }) async {
    await createNotification(
      title: 'Maintenance Request Created',
      message:
          'Your maintenance request for asset $assetId has been created and is pending assignment.',
      type: NotificationType.workOrderCreated,
      priority: NotificationPriority.medium,
      userId: requestorId,
      relatedId: workOrderId,
      data: {'assetId': assetId},
    );
  }

  Future<void> notifyWorkOrderAssigned({
    required String workOrderId,
    required String technicianId,
    required String requestorId,
    required String assetId,
  }) async {
    // Notify technician
    await createNotification(
      title: 'New Work Order Assigned',
      message: 'You have been assigned a new work order for asset $assetId.',
      type: NotificationType.workOrderAssigned,
      priority: NotificationPriority.high,
      userId: technicianId,
      relatedId: workOrderId,
      data: {'assetId': assetId},
    );

    // Notify requestor
    await createNotification(
      title: 'Work Order Assigned',
      message:
          'Your maintenance request for asset $assetId has been assigned to a technician.',
      type: NotificationType.workOrderAssigned,
      priority: NotificationPriority.medium,
      userId: requestorId,
      relatedId: workOrderId,
      data: {'assetId': assetId},
    );
  }

  Future<void> notifyWorkOrderStarted({
    required String workOrderId,
    required String requestorId,
    required String assetId,
  }) async {
    await createNotification(
      title: 'Work Started',
      message: 'Maintenance work has started on asset $assetId.',
      type: NotificationType.workOrderStarted,
      priority: NotificationPriority.medium,
      userId: requestorId,
      relatedId: workOrderId,
      data: {'assetId': assetId},
    );
  }

  Future<void> notifyWorkOrderUnassigned({
    required String workOrderId,
    required String requestorId,
    required String assetId,
  }) async {
    await createNotification(
      title: 'Work Order Unassigned',
      message:
          'Your maintenance request for asset $assetId has been unassigned and is back in the queue.',
      type: NotificationType.workOrderAssigned,
      priority: NotificationPriority.medium,
      userId: requestorId,
      relatedId: workOrderId,
      data: {'assetId': assetId},
    );
  }

  Future<void> notifyWorkOrderCompleted({
    required String workOrderId,
    required String requestorId,
    required String assetId,
  }) async {
    await createNotification(
      title: 'Work Completed',
      message: 'Maintenance work has been completed on asset $assetId.',
      type: NotificationType.workOrderCompleted,
      priority: NotificationPriority.medium,
      userId: requestorId,
      relatedId: workOrderId,
      data: {'assetId': assetId},
    );
  }

  /// PM Task specific notifications
  Future<void> notifyPMTaskAssigned({
    required String pmTaskId,
    required String technicianId,
    required String taskName,
  }) async {
    await createNotification(
      title: 'PM Task Assigned',
      message: 'You have been assigned a new PM task: $taskName',
      type: NotificationType.pmTaskAssigned,
      priority: NotificationPriority.medium,
      userId: technicianId,
      relatedId: pmTaskId,
    );
  }

  Future<void> notifyPMTaskDue({
    required String pmTaskId,
    required String technicianId,
    required String taskName,
  }) async {
    await createNotification(
      title: 'PM Task Due',
      message: 'PM task "$taskName" is due today.',
      type: NotificationType.pmTaskDue,
      priority: NotificationPriority.high,
      userId: technicianId,
      relatedId: pmTaskId,
    );
  }

  Future<void> notifyPMTaskOverdue({
    required String pmTaskId,
    required String technicianId,
    required String taskName,
    required int daysOverdue,
  }) async {
    await createNotification(
      title: 'PM Task Overdue',
      message:
          'PM task "$taskName" is $daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue.',
      type: NotificationType.pmTaskOverdue,
      priority: NotificationPriority.critical,
      userId: technicianId,
      relatedId: pmTaskId,
    );
  }

  /// Escalation notifications
  Future<void> notifyEscalation({
    required String title,
    required String message,
    required String managerId,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    await createNotification(
      title: title,
      message: message,
      type: NotificationType.escalation,
      priority: NotificationPriority.critical,
      userId: managerId,
      relatedId: relatedId,
      data: data,
    );
  }

  /// System alerts
  Future<void> notifySystemAlert({
    required String title,
    required String message,
    required NotificationPriority priority,
    String? userId,
    Map<String, dynamic>? data,
  }) async {
    await createNotification(
      title: title,
      message: message,
      type: NotificationType.systemAlert,
      priority: priority,
      userId: userId,
      data: data,
    );
  }

  /// Load notifications from storage
  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('notifications') ?? '[]';
      final notificationsList = jsonDecode(notificationsJson) as List;

      _notifications.clear();
      _notifications.addAll(
        notificationsList
            .map((n) => Notification.fromMap(Map<String, dynamic>.from(n)))
            .toList(),
      );

      // Sort by creation date (newest first)
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Save notifications to storage
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = jsonEncode(
        _notifications.map((n) => n.toMap()).toList(),
      );
      await prefs.setString('notifications', notificationsJson);
    } catch (e, st) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Clean up old notifications (older than 30 days)
  Future<void> cleanupOldNotifications() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    _notifications.removeWhere((n) => n.createdAt.isBefore(cutoffDate));
    await _saveNotifications();
    _notificationsController.add(_notifications);
  }

  /// Show local notification (static method for compatibility)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await sl<NotificationService>().createNotification(
        title: title,
        message: body,
        type: NotificationType.systemAlert,
        priority: NotificationPriority.medium,
        data: payload != null ? {'payload': payload} : null,
      );
    } catch (e, st) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Test-only reset. GetIt singletons must stay alive for the app lifetime.
  @visibleForTesting
  void resetForTesting() {
    _isInitialized = false;
    _notifications.clear();
    if (!_notificationsController.isClosed) {
      _notificationsController.add(_notifications);
    }
  }
}
