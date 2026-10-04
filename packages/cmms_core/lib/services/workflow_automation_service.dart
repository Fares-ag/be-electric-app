// Workflow Automation Service - Automated approval workflows and business rules

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_role.dart';
import '../models/work_order.dart';
import 'enhanced_notification_service.dart';
import 'unified_data_service.dart';
import '../config/locator.dart';

enum AutomationTrigger {
  workOrderCreated,
  workOrderAssigned,
  workOrderCompleted,
  pmTaskCreated,
  pmTaskAssigned,
  pmTaskCompleted,
  budgetExceeded,
  escalationRequired,
  qualityIssue,
  systemHealth,
}

enum AutomationAction {
  sendNotification,
  assignTechnician,
  escalateToManager,
  requireApproval,
  updateStatus,
  createPMTask,
  sendEmail,
  updateBudget,
  logActivity,
}

class AutomationRule {
  AutomationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.trigger,
    required this.conditions,
    required this.actions,
    required this.isActive,
    this.priority = 1,
    this.conditionsOperator = 'AND',
  });

  final String id;
  final String name;
  final String description;
  final AutomationTrigger trigger;
  final List<Map<String, dynamic>> conditions;
  final List<Map<String, dynamic>> actions;
  final bool isActive;
  final int priority;
  final String conditionsOperator; // AND or OR
}

class AutomationExecution {
  AutomationExecution({
    required this.id,
    required this.ruleId,
    required this.trigger,
    required this.itemId,
    required this.itemType,
    required this.executedAt,
    this.status = 'pending',
    this.results = const {},
    this.error,
  });

  final String id;
  final String ruleId;
  final AutomationTrigger trigger;
  final String itemId;
  final String itemType;
  final DateTime executedAt;
  String status;
  final Map<String, dynamic> results;
  String? error;
}

class WorkflowAutomationService {

  UnifiedDataService get _dataService => sl<UnifiedDataService>();
  final EnhancedNotificationService _notificationService =
      sl<EnhancedNotificationService>();

  final List<AutomationRule> _rules = [];
  final List<AutomationExecution> _executions = [];
  bool _isInitialized = false;

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  List<AutomationExecution> get executions => List.unmodifiable(_executions);

  /// Initialize automation service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadDefaultRules();
    _isInitialized = true;

    debugPrint(
      'WorkflowAutomationService: Initialized with ${_rules.length} rules',
    );
  }

  /// Load default automation rules
  Future<void> _loadDefaultRules() async {
    _rules.addAll([
      // High-cost work order approval
      AutomationRule(
        id: 'high_cost_approval',
        name: 'High-Cost Work Order Approval',
        description: r'Require approval for work orders exceeding $1000',
        trigger: AutomationTrigger.workOrderCreated,
        conditions: [
          {'field': 'estimatedCost', 'operator': '>=', 'value': 1000},
        ],
        actions: [
          {
            'type': 'requireApproval',
            'approvers': ['manager', 'admin'],
          },
          {
            'type': 'sendNotification',
            'message': 'High-cost work order requires approval',
          },
        ],
        isActive: true,
      ),

      // Critical priority escalation
      AutomationRule(
        id: 'critical_escalation',
        name: 'Critical Priority Escalation',
        description: 'Immediately escalate critical priority work orders',
        trigger: AutomationTrigger.workOrderCreated,
        conditions: [
          {'field': 'priority', 'operator': '==', 'value': 'critical'},
        ],
        actions: [
          {'type': 'escalateToManager', 'immediate': true},
          {
            'type': 'sendNotification',
            'message': 'Critical work order requires immediate attention',
          },
          {'type': 'updateStatus', 'status': 'escalated'},
        ],
        isActive: true,
      ),

      // Overdue work order escalation
      AutomationRule(
        id: 'overdue_escalation',
        name: 'Overdue Work Order Escalation',
        description: 'Escalate overdue work orders to manager',
        trigger: AutomationTrigger.workOrderCreated,
        conditions: [
          {'field': 'overdueHours', 'operator': '>=', 'value': 24},
        ],
        actions: [
          {'type': 'escalateToManager'},
          {
            'type': 'sendNotification',
            'message': 'Work order is overdue and requires attention',
          },
        ],
        isActive: true,
        priority: 2,
      ),

      // PM task due notification
      AutomationRule(
        id: 'pm_task_due_notification',
        name: 'PM Task Due Notification',
        description: 'Notify technician when PM task is due',
        trigger: AutomationTrigger.pmTaskCreated,
        conditions: [
          {'field': 'dueInHours', 'operator': '<=', 'value': 24},
        ],
        actions: [
          {'type': 'sendNotification', 'message': 'PM task is due soon'},
        ],
        isActive: true,
        priority: 3,
      ),

      // Budget exceeded notification
      AutomationRule(
        id: 'budget_exceeded',
        name: 'Budget Exceeded Notification',
        description: 'Notify when budget is exceeded',
        trigger: AutomationTrigger.budgetExceeded,
        conditions: [
          {'field': 'budgetExceeded', 'operator': '==', 'value': true},
        ],
        actions: [
          {
            'type': 'sendNotification',
            'message': 'Budget limit has been exceeded',
          },
          {'type': 'escalateToManager'},
        ],
        isActive: true,
      ),

      // Quality issue escalation
      AutomationRule(
        id: 'quality_issue_escalation',
        name: 'Quality Issue Escalation',
        description: 'Escalate quality issues to management',
        trigger: AutomationTrigger.qualityIssue,
        conditions: [
          {'field': 'qualityScore', 'operator': '<', 'value': 80},
        ],
        actions: [
          {'type': 'escalateToManager'},
          {
            'type': 'sendNotification',
            'message': 'Quality issue detected and escalated',
          },
          {
            'type': 'requireApproval',
            'approvers': ['quality_manager'],
          },
        ],
        isActive: true,
      ),

      // Automatic technician assignment
      AutomationRule(
        id: 'auto_technician_assignment',
        name: 'Automatic Technician Assignment',
        description:
            'Automatically assign work orders to available technicians',
        trigger: AutomationTrigger.workOrderCreated,
        conditions: [
          {'field': 'priority', 'operator': '==', 'value': 'low'},
          {'field': 'estimatedCost', 'operator': '<', 'value': 500},
        ],
        actions: [
          {'type': 'assignTechnician', 'auto': true},
          {
            'type': 'sendNotification',
            'message': 'Work order automatically assigned',
          },
        ],
        isActive: true,
        priority: 5,
      ),

      // Completion notification
      AutomationRule(
        id: 'completion_notification',
        name: 'Work Order Completion Notification',
        description: 'Notify stakeholders when work order is completed',
        trigger: AutomationTrigger.workOrderCompleted,
        conditions: [],
        actions: [
          {
            'type': 'sendNotification',
            'message': 'Work order has been completed',
          },
          {'type': 'logActivity', 'activity': 'work_order_completed'},
        ],
        isActive: true,
        priority: 3,
      ),
    ]);
  }

  /// Execute automation for trigger
  Future<void> executeAutomation({
    required AutomationTrigger trigger,
    required String itemId,
    required String itemType,
    Map<String, dynamic> context = const {},
  }) async {
    try {
      final applicableRules = _rules
          .where((rule) => rule.trigger == trigger && rule.isActive)
          .toList();

      applicableRules.sort((a, b) => a.priority.compareTo(b.priority));

      for (final rule in applicableRules) {
        if (await _evaluateConditions(
          rule.conditions,
          context,
          rule.conditionsOperator,
        )) {
          await _executeActions(rule, itemId, itemType, context);
        }
      }
    } catch (e, st) {
      debugPrint('WorkflowAutomationService: Error executing automation: $e');
    }
  }

  /// Evaluate rule conditions
  Future<bool> _evaluateConditions(
    List<Map<String, dynamic>> conditions,
    Map<String, dynamic> context,
    String operator,
  ) async {
    if (conditions.isEmpty) return true;

    final results = <bool>[];
    for (final condition in conditions) {
      final result = await _evaluateCondition(condition, context);
      results.add(result);
    }

    if (operator == 'OR') {
      return results.any((result) => result);
    } else {
      return results.every((result) => result);
    }
  }

  /// Evaluate single condition
  Future<bool> _evaluateCondition(
    Map<String, dynamic> condition,
    Map<String, dynamic> context,
  ) async {
    final field = condition['field'] as String;
    final operator = condition['operator'] as String;
    final value = condition['value'];

    final contextValue = context[field];
    if (contextValue == null) return false;

    switch (operator) {
      case '==':
        return contextValue == value;
      case '!=':
        return contextValue != value;
      case '>':
        return (contextValue as num) > (value as num);
      case '>=':
        return (contextValue as num) >= (value as num);
      case '<':
        return (contextValue as num) < (value as num);
      case '<=':
        return (contextValue as num) <= (value as num);
      case 'contains':
        return (contextValue as String).contains(value as String);
      case 'in':
        return (value as List).contains(contextValue);
      default:
        return false;
    }
  }

  /// Execute rule actions
  Future<void> _executeActions(
    AutomationRule rule,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final execution = AutomationExecution(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ruleId: rule.id,
      trigger: rule.trigger,
      itemId: itemId,
      itemType: itemType,
      executedAt: DateTime.now(),
    );

    _executions.add(execution);

    try {
      for (final action in rule.actions) {
        await _executeAction(action, itemId, itemType, context);
      }

      execution.status = 'completed';
      debugPrint(
        'WorkflowAutomationService: Executed rule ${rule.name} for $itemType $itemId',
      );
    } catch (e, st) {
      execution.status = 'failed';
      execution.error = e.toString();
      debugPrint(
        'WorkflowAutomationService: Error executing rule ${rule.name}: $e',
      );
    }
  }

  /// Execute single action
  Future<void> _executeAction(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final actionType = action['type'] as String;

    switch (actionType) {
      case 'sendNotification':
        await _sendNotification(action, itemId, itemType, context);
        break;
      case 'assignTechnician':
        await _assignTechnician(action, itemId, itemType, context);
        break;
      case 'escalateToManager':
        await _escalateToManager(action, itemId, itemType, context);
        break;
      case 'requireApproval':
        await _requireApproval(action, itemId, itemType, context);
        break;
      case 'updateStatus':
        await _updateStatus(action, itemId, itemType, context);
        break;
      case 'createPMTask':
        await _createPMTask(action, itemId, itemType, context);
        break;
      case 'sendEmail':
        await _sendEmail(action, itemId, itemType, context);
        break;
      case 'updateBudget':
        await _updateBudget(action, itemId, itemType, context);
        break;
      case 'logActivity':
        await _logActivity(action, itemId, itemType, context);
        break;
      default:
        debugPrint(
          'WorkflowAutomationService: Unknown action type: $actionType',
        );
    }
  }

  /// Send notification action
  Future<void> _sendNotification(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final message = action['message'] as String? ?? 'Automated notification';
    final priority = action['priority'] as String? ?? 'medium';

    await _notificationService.createNotification(
      title: 'Automated Notification',
      message: message,
      type: NotificationType.systemAlert,
      priority: _parseNotificationPriority(priority),
      relatedId: itemId,
      relatedType: itemType,
      data: context,
    );
  }

  /// Assign technician action
  Future<void> _assignTechnician(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    if (itemType == 'work_order') {
      final workOrder =
          _dataService.workOrders.firstWhere((wo) => wo.id == itemId);
      final availableTechnicians = _dataService.users
          .where((u) => u.role == UserRole.technician)
          .toList();

      if (availableTechnicians.isNotEmpty) {
        // Simple round-robin assignment
        final technician = availableTechnicians.first;
        await _dataService.assignTechnicianToWorkOrder(itemId, technician.id);

        await _notificationService.notifyWorkOrderAssigned(
          workOrderId: itemId,
          technicianId: technician.id,
          assetName: workOrder.assetName ??
              (workOrder.assetId == null
                  ? 'General Maintenance'
                  : 'Unknown Asset'),
        );
      }
    }
  }

  /// Escalate to manager action
  Future<void> _escalateToManager(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final managers = _dataService.users
        .where((u) => u.role == UserRole.manager || u.role == UserRole.admin)
        .toList();

    for (final manager in managers) {
      await _notificationService.notifyEscalation(
        itemId: itemId,
        itemType: itemType,
        managerId: manager.id,
        reason: context['escalationReason'] ?? 'Automated escalation',
      );
    }
  }

  /// Require approval action
  Future<void> _requireApproval(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final approvers = action['approvers'] as List<String>? ?? ['manager'];

    for (final approverRole in approvers) {
      final approvers = _dataService.users
          .where((u) => u.role.toLowerCase().contains(approverRole))
          .toList();

      for (final approver in approvers) {
        await _notificationService.createNotification(
          title: 'Approval Required',
          message: 'Approval required for $itemType $itemId',
          type: NotificationType.workflowApproval,
          priority: NotificationPriority.high,
          userId: approver.id,
          relatedId: itemId,
          relatedType: itemType,
          data: context,
        );
      }
    }
  }

  /// Update status action
  Future<void> _updateStatus(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final status = action['status'] as String;

    if (itemType == 'work_order') {
      // Update work order status
      final workOrder =
          _dataService.workOrders.firstWhere((wo) => wo.id == itemId);
      final newStatus = WorkOrderStatus.values.firstWhere(
        (s) => s.toString().split('.').last == status,
        orElse: () => workOrder.status,
      );

      if (newStatus != workOrder.status) {
        await _dataService
            .updateWorkOrder(workOrder.copyWith(status: newStatus));
      }
    }
  }

  /// Create PM task action
  Future<void> _createPMTask(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    // TODO: Implement PM task creation based on action parameters
    debugPrint(
      'WorkflowAutomationService: Creating PM task for $itemType $itemId',
    );
  }

  /// Send email action
  Future<void> _sendEmail(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    // TODO: Implement email sending
    debugPrint(
      'WorkflowAutomationService: Sending email for $itemType $itemId',
    );
  }

  /// Update budget action
  Future<void> _updateBudget(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    // TODO: Implement budget updates
    debugPrint(
      'WorkflowAutomationService: Updating budget for $itemType $itemId',
    );
  }

  /// Log activity action
  Future<void> _logActivity(
    Map<String, dynamic> action,
    String itemId,
    String itemType,
    Map<String, dynamic> context,
  ) async {
    final activity = action['activity'] as String? ?? 'automated_activity';
    debugPrint(
      'WorkflowAutomationService: Logging activity: $activity for $itemType $itemId',
    );
  }

  /// Parse notification priority
  NotificationPriority _parseNotificationPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return NotificationPriority.low;
      case 'medium':
        return NotificationPriority.medium;
      case 'high':
        return NotificationPriority.high;
      case 'critical':
        return NotificationPriority.critical;
      default:
        return NotificationPriority.medium;
    }
  }

  /// Add automation rule
  Future<void> addRule(AutomationRule rule) async {
    _rules.add(rule);
    debugPrint('WorkflowAutomationService: Added rule ${rule.name}');
  }

  /// Update automation rule
  Future<void> updateRule(AutomationRule rule) async {
    final index = _rules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _rules[index] = rule;
      debugPrint('WorkflowAutomationService: Updated rule ${rule.name}');
    }
  }

  /// Remove automation rule
  Future<void> removeRule(String ruleId) async {
    _rules.removeWhere((r) => r.id == ruleId);
    debugPrint('WorkflowAutomationService: Removed rule $ruleId');
  }

  /// Get automation statistics
  Map<String, dynamic> getAutomationStats() {
    final totalExecutions = _executions.length;
    final successfulExecutions =
        _executions.where((e) => e.status == 'completed').length;
    final failedExecutions =
        _executions.where((e) => e.status == 'failed').length;
    final activeRules = _rules.where((r) => r.isActive).length;

    return {
      'totalRules': _rules.length,
      'activeRules': activeRules,
      'totalExecutions': totalExecutions,
      'successfulExecutions': successfulExecutions,
      'failedExecutions': failedExecutions,
      'successRate': totalExecutions > 0
          ? (successfulExecutions / totalExecutions) * 100
          : 0,
    };
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
