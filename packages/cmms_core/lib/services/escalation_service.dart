// Escalation Service - Automatic escalation for overdue tasks

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pm_task.dart';
import '../models/user_role.dart';
import '../models/work_order.dart';
import 'enhanced_notification_service.dart';
import 'supabase_database_service.dart';
import 'unified_data_service.dart';
import '../config/locator.dart';

enum EscalationLevel {
  none,
  first,
  second,
  third,
  critical,
}

enum EscalationType {
  workOrderOverdue,
  pmTaskOverdue,
  budgetExceeded,
  systemHealth,
  qualityIssue,
}

class EscalationRule {
  EscalationRule({
    required this.id,
    required this.name,
    required this.type,
    required this.triggerCondition,
    required this.escalationLevels,
    required this.isActive,
    this.description,
    this.conditions = const {},
  });

  final String id;
  final String name;
  final String? description;
  final EscalationType type;
  final String triggerCondition;
  final List<EscalationLevel> escalationLevels;
  final bool isActive;
  final Map<String, dynamic> conditions;
}

class EscalationEvent {
  EscalationEvent({
    required this.id,
    required this.ruleId,
    required this.type,
    required this.itemId,
    required this.itemType,
    required this.currentLevel,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.notes,
    this.data = const {},
  });

  final String id;
  final String ruleId;
  final EscalationType type;
  final String itemId;
  final String itemType;
  final EscalationLevel currentLevel;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? notes;
  final Map<String, dynamic> data;
}

class EscalationService {

  final List<EscalationRule> _rules = [];
  final List<EscalationEvent> _events = [];
  final EnhancedNotificationService _notificationService =
      sl<EnhancedNotificationService>();
  UnifiedDataService get _dataService => sl<UnifiedDataService>();
  final SupabaseDatabaseService _firestoreService =
      sl<SupabaseDatabaseService>();

  Timer? _escalationTimer;
  bool _isInitialized = false;

  List<EscalationRule> get rules => List.unmodifiable(_rules);
  List<EscalationEvent> get events => List.unmodifiable(_events);
  List<EscalationEvent> get activeEvents =>
      _events.where((e) => e.resolvedAt == null).toList();

  /// Initialize escalation service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadDefaultRules();
    await _loadEscalationEvents();
    _startEscalationMonitoring();
    _isInitialized = true;

    debugPrint('✅ EscalationService: Initialized with ${_rules.length} rules');
  }

  /// Load default escalation rules
  Future<void> _loadDefaultRules() async {
    _rules.addAll([
      // Work Order Overdue Rules
      EscalationRule(
        id: 'work_order_24h',
        name: 'Work Order 24h Overdue',
        description: 'Escalate work orders overdue by 24 hours',
        type: EscalationType.workOrderOverdue,
        triggerCondition: 'overdue_hours >= 24',
        escalationLevels: [EscalationLevel.first, EscalationLevel.second],
        isActive: true,
        conditions: {'overdue_hours': 24},
      ),
      EscalationRule(
        id: 'work_order_48h',
        name: 'Work Order 48h Overdue',
        description: 'Escalate work orders overdue by 48 hours',
        type: EscalationType.workOrderOverdue,
        triggerCondition: 'overdue_hours >= 48',
        escalationLevels: [EscalationLevel.second, EscalationLevel.third],
        isActive: true,
        conditions: {'overdue_hours': 48},
      ),
      EscalationRule(
        id: 'work_order_72h',
        name: 'Work Order 72h Overdue',
        description: 'Escalate work orders overdue by 72 hours',
        type: EscalationType.workOrderOverdue,
        triggerCondition: 'overdue_hours >= 72',
        escalationLevels: [EscalationLevel.third, EscalationLevel.critical],
        isActive: true,
        conditions: {'overdue_hours': 72},
      ),

      // PM Task Overdue Rules
      EscalationRule(
        id: 'pm_task_24h',
        name: 'PM Task 24h Overdue',
        description: 'Escalate PM tasks overdue by 24 hours',
        type: EscalationType.pmTaskOverdue,
        triggerCondition: 'overdue_hours >= 24',
        escalationLevels: [EscalationLevel.first, EscalationLevel.second],
        isActive: true,
        conditions: {'overdue_hours': 24},
      ),
      EscalationRule(
        id: 'pm_task_48h',
        name: 'PM Task 48h Overdue',
        description: 'Escalate PM tasks overdue by 48 hours',
        type: EscalationType.pmTaskOverdue,
        triggerCondition: 'overdue_hours >= 48',
        escalationLevels: [EscalationLevel.second, EscalationLevel.third],
        isActive: true,
        conditions: {'overdue_hours': 48},
      ),

      // Budget Exceeded Rules
      EscalationRule(
        id: 'budget_exceeded',
        name: 'Budget Exceeded',
        description: 'Escalate when budget is exceeded',
        type: EscalationType.budgetExceeded,
        triggerCondition: 'budget_exceeded == true',
        escalationLevels: [EscalationLevel.first, EscalationLevel.second],
        isActive: true,
        conditions: {'budget_exceeded': true},
      ),

      // System Health Rules
      EscalationRule(
        id: 'system_health',
        name: 'System Health Issues',
        description: 'Escalate system health issues',
        type: EscalationType.systemHealth,
        triggerCondition: 'system_health_score < 80',
        escalationLevels: [EscalationLevel.first, EscalationLevel.second],
        isActive: true,
        conditions: {'health_score_threshold': 80},
      ),
    ]);
  }

  /// Load escalation events from storage
  Future<void> _loadEscalationEvents() async {
    try {
      // Try Firestore first, fallback to memory
      try {
        final firestoreEvents = await _firestoreService.getEscalationEvents();
        _events.clear();
        _events.addAll(firestoreEvents);
        debugPrint(
          '✅ EscalationService: Loaded ${_events.length} events from Firestore',
        );
      } catch (e, st) {
        debugPrint(
          '⚠️ EscalationService: Firestore unavailable, using memory storage: $e',
        );
        // Events remain in memory for this session
      }
    } catch (e, st) {
      debugPrint('❌ EscalationService: Error loading escalation events: $e');
    }
  }

  /// Start escalation monitoring
  void _startEscalationMonitoring() {
    _escalationTimer?.cancel();
    _escalationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkEscalations();
    });
  }

  /// Check for escalations
  Future<void> _checkEscalations() async {
    try {
      await _checkWorkOrderEscalations();
      await _checkPMTaskEscalations();
      await _checkBudgetEscalations();
      await _checkSystemHealthEscalations();
    } catch (e, st) {
      debugPrint('❌ EscalationService: Error checking escalations: $e');
    }
  }

  /// Check work order escalations
  Future<void> _checkWorkOrderEscalations() async {
    final workOrders = _dataService.workOrders;
    final now = DateTime.now();

    for (final workOrder in workOrders) {
      if (workOrder.status == WorkOrderStatus.closed ||
          workOrder.status == WorkOrderStatus.cancelled) {
        continue;
      }

      final hoursOverdue = _calculateOverdueHours(workOrder, now);
      if (hoursOverdue <= 0) continue;

      // Check if escalation already exists
      final existingEvent = _events.firstWhere(
        (e) =>
            e.itemId == workOrder.id &&
            e.itemType == 'work_order' &&
            e.resolvedAt == null,
        orElse: () => EscalationEvent(
          id: '',
          ruleId: '',
          type: EscalationType.workOrderOverdue,
          itemId: '',
          itemType: '',
          currentLevel: EscalationLevel.none,
          createdAt: DateTime.now(),
        ),
      );

      if (existingEvent.id.isNotEmpty) continue;

      // Find applicable rules
      final applicableRules = _rules.where(
        (rule) =>
            rule.type == EscalationType.workOrderOverdue &&
            rule.isActive &&
            _evaluateCondition(
              rule.triggerCondition,
              {'overdue_hours': hoursOverdue},
            ),
      );

      for (final rule in applicableRules) {
        await _createEscalationEvent(
          rule: rule,
          itemId: workOrder.id,
          itemType: 'work_order',
          data: {
            'workOrderId': workOrder.id,
            'assetName': workOrder.assetName,
            'overdueHours': hoursOverdue,
            'assignedTechnician': workOrder.assignedTechnicianName,
          },
        );
      }
    }
  }

  /// Check PM task escalations
  Future<void> _checkPMTaskEscalations() async {
    final pmTasks = _dataService.pmTasks;
    final now = DateTime.now();

    for (final pmTask in pmTasks) {
      if (pmTask.status == PMTaskStatus.completed ||
          pmTask.status == PMTaskStatus.cancelled) {
        continue;
      }

      if (pmTask.nextDueDate == null) continue;

      final hoursOverdue = _calculatePMTaskOverdueHours(pmTask, now);
      if (hoursOverdue <= 0) continue;

      // Check if escalation already exists
      final existingEvent = _events.firstWhere(
        (e) =>
            e.itemId == pmTask.id &&
            e.itemType == 'pm_task' &&
            e.resolvedAt == null,
        orElse: () => EscalationEvent(
          id: '',
          ruleId: '',
          type: EscalationType.pmTaskOverdue,
          itemId: '',
          itemType: '',
          currentLevel: EscalationLevel.none,
          createdAt: DateTime.now(),
        ),
      );

      if (existingEvent.id.isNotEmpty) continue;

      // Find applicable rules
      final applicableRules = _rules.where(
        (rule) =>
            rule.type == EscalationType.pmTaskOverdue &&
            rule.isActive &&
            _evaluateCondition(
              rule.triggerCondition,
              {'overdue_hours': hoursOverdue},
            ),
      );

      for (final rule in applicableRules) {
        await _createEscalationEvent(
          rule: rule,
          itemId: pmTask.id,
          itemType: 'pm_task',
          data: {
            'pmTaskId': pmTask.id,
            'taskName': pmTask.taskName,
            'overdueHours': hoursOverdue,
            'assignedTechnician': pmTask.assignedTechnician?.name,
          },
        );
      }
    }
  }

  /// Check budget escalations
  Future<void> _checkBudgetEscalations() async {
    // TODO: Implement budget monitoring
    // This would check against budget limits and trigger escalations
  }

  /// Check system health escalations
  Future<void> _checkSystemHealthEscalations() async {
    // TODO: Implement system health monitoring
    // This would check system performance metrics
  }

  /// Calculate overdue hours for work order
  int _calculateOverdueHours(WorkOrder workOrder, DateTime now) {
    DateTime? dueDate;

    if (workOrder.status == WorkOrderStatus.assigned &&
        workOrder.assignedAt != null) {
      // If assigned, consider overdue after 24 hours
      dueDate = workOrder.assignedAt!.add(const Duration(hours: 24));
    } else if (workOrder.status == WorkOrderStatus.inProgress &&
        workOrder.startedAt != null) {
      // If in progress, consider overdue after 48 hours
      dueDate = workOrder.startedAt!.add(const Duration(hours: 48));
    } else if (workOrder.status == WorkOrderStatus.open) {
      // If open, consider overdue after 24 hours
      dueDate = workOrder.createdAt.add(const Duration(hours: 24));
    }

    if (dueDate == null) return 0;

    final difference = now.difference(dueDate);
    return difference.inHours;
  }

  /// Calculate overdue hours for PM task
  int _calculatePMTaskOverdueHours(PMTask pmTask, DateTime now) {
    if (pmTask.nextDueDate == null) return 0;

    final difference = now.difference(pmTask.nextDueDate!);
    return difference.inHours;
  }

  /// Evaluate escalation condition
  bool _evaluateCondition(String condition, Map<String, dynamic> variables) {
    // Simple condition evaluation
    // In a real implementation, this would be more sophisticated
    try {
      if (condition.contains('overdue_hours >=')) {
        final threshold = int.parse(condition.split('>=')[1].trim());
        final overdueHours = variables['overdue_hours'] as int? ?? 0;
        return overdueHours >= threshold;
      }
      if (condition.contains('budget_exceeded ==')) {
        final expected = condition.split('==')[1].trim() == 'true';
        final actual = variables['budget_exceeded'] as bool? ?? false;
        return actual == expected;
      }
      if (condition.contains('system_health_score <')) {
        final threshold = int.parse(condition.split('<')[1].trim());
        final healthScore = variables['system_health_score'] as int? ?? 100;
        return healthScore < threshold;
      }
      return false;
    } catch (e, st) {
      debugPrint('❌ EscalationService: Error evaluating condition: $e');
      return false;
    }
  }

  /// Create escalation event
  Future<void> _createEscalationEvent({
    required EscalationRule rule,
    required String itemId,
    required String itemType,
    Map<String, dynamic> data = const {},
  }) async {
    final event = EscalationEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ruleId: rule.id,
      type: rule.type,
      itemId: itemId,
      itemType: itemType,
      currentLevel: rule.escalationLevels.first,
      createdAt: DateTime.now(),
      data: data,
    );

    _events.add(event);

    // Save to Firestore
    try {
      await _firestoreService.saveEscalationEvent(event);
      debugPrint('✅ EscalationService: Event saved to Firestore');
    } catch (e, st) {
      debugPrint('⚠️ EscalationService: Failed to save to Firestore: $e');
    }

    await _sendEscalationNotifications(event, rule);

    debugPrint(
      '🚨 EscalationService: Created escalation event for $itemType $itemId',
    );
  }

  /// Send escalation notifications
  Future<void> _sendEscalationNotifications(
    EscalationEvent event,
    EscalationRule rule,
  ) async {
    final managers = _dataService.users
        .where((u) => u.role == UserRole.manager || u.role == UserRole.admin)
        .toList();

    for (final manager in managers) {
      await _notificationService.notifyEscalation(
        itemId: event.itemId,
        itemType: event.itemType,
        managerId: manager.id,
        reason: _getEscalationReason(event, rule),
      );
    }
  }

  /// Get escalation reason
  String _getEscalationReason(EscalationEvent event, EscalationRule rule) {
    switch (event.type) {
      case EscalationType.workOrderOverdue:
        final overdueHours = event.data['overdueHours'] as int? ?? 0;
        return 'Work order overdue by $overdueHours hours';
      case EscalationType.pmTaskOverdue:
        final overdueHours = event.data['overdueHours'] as int? ?? 0;
        return 'PM task overdue by $overdueHours hours';
      case EscalationType.budgetExceeded:
        return 'Budget limit exceeded';
      case EscalationType.systemHealth:
        return 'System health issues detected';
      case EscalationType.qualityIssue:
        return 'Quality issues detected';
    }
  }

  /// Resolve escalation event
  Future<void> resolveEscalation(
    String eventId,
    String resolvedBy,
    String? notes,
  ) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      _events[index] = EscalationEvent(
        id: _events[index].id,
        ruleId: _events[index].ruleId,
        type: _events[index].type,
        itemId: _events[index].itemId,
        itemType: _events[index].itemType,
        currentLevel: _events[index].currentLevel,
        createdAt: _events[index].createdAt,
        resolvedAt: DateTime.now(),
        resolvedBy: resolvedBy,
        notes: notes,
        data: _events[index].data,
      );

      debugPrint('✅ EscalationService: Resolved escalation event $eventId');
    }
  }

  /// Get escalation statistics
  Map<String, dynamic> getEscalationStats() {
    final now = DateTime.now();
    final last24Hours = now.subtract(const Duration(hours: 24));

    return {
      'totalEvents': _events.length,
      'activeEvents': activeEvents.length,
      'resolvedEvents': _events.where((e) => e.resolvedAt != null).length,
      'eventsLast24Hours':
          _events.where((e) => e.createdAt.isAfter(last24Hours)).length,
      'byType': _getEventsByType(),
      'byLevel': _getEventsByLevel(),
    };
  }

  /// Get events by type
  Map<String, int> _getEventsByType() {
    final result = <String, int>{};
    for (final event in _events) {
      final type = event.type.toString().split('.').last;
      result[type] = (result[type] ?? 0) + 1;
    }
    return result;
  }

  /// Get events by level
  Map<String, int> _getEventsByLevel() {
    final result = <String, int>{};
    for (final event in _events) {
      final level = event.currentLevel.toString().split('.').last;
      result[level] = (result[level] ?? 0) + 1;
    }
    return result;
  }

  /// Dispose resources
  void dispose() {
    _escalationTimer?.cancel();
  }
}
