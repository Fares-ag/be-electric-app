// Comprehensive CMMS Service - Main integration service for all enhanced features

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/pm_task.dart';
import '../models/work_order.dart';
import 'audit_logging_service.dart';
import 'enhanced_inventory_service.dart';
import 'enhanced_notification_service.dart';
import 'escalation_service.dart';
import 'simplified_reporting_service.dart';
import 'unified_data_service.dart';
import 'workflow_automation_service.dart';
import '../config/locator.dart';

class ComprehensiveCMMSService {

  // Core services
  UnifiedDataService get _dataService => sl<UnifiedDataService>();
  final EnhancedNotificationService _notificationService =
      sl<EnhancedNotificationService>();
  final EscalationService _escalationService = sl<EscalationService>();
  final SimplifiedReportingService _reportingService =
      sl<SimplifiedReportingService>();
  final EnhancedInventoryService _inventoryService = sl<EnhancedInventoryService>();
  final WorkflowAutomationService _automationService =
      sl<WorkflowAutomationService>();
  final AuditLoggingService _auditService = sl<AuditLoggingService>();

  bool _isInitialized = false;
  StreamSubscription<EnhancedNotification>? _newNotificationSubscription;

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 ComprehensiveCMMSService: Initializing all services...');

      // Initialize core services
      await _dataService.initialize();
      await _notificationService.initialize();
      await _escalationService.initialize();
      await _inventoryService.initialize();
      await _automationService.initialize();
      await _auditService.initialize();

      // Set up service integrations
      await _setupServiceIntegrations();

      _isInitialized = true;
      debugPrint(
        '✅ ComprehensiveCMMSService: All services initialized successfully',
      );
    } catch (e, st) {
      debugPrint('❌ ComprehensiveCMMSService: Error initializing services: $e');
      rethrow;
    }
  }

  /// Set up integrations between services
  Future<void> _setupServiceIntegrations() async {
    await _newNotificationSubscription?.cancel();
    _newNotificationSubscription =
        _notificationService.newNotificationStream.listen((notification) {
      _auditService.logEvent(
        type: AuditEventType.notificationSent,
        userId: notification.userId ?? 'system',
        description: 'Notification sent: ${notification.title}',
        severity:
            _mapNotificationPriorityToAuditSeverity(notification.priority),
        resourceId: notification.relatedId,
        resourceType: notification.relatedType,
        metadata: {'notificationType': notification.type.toString()},
      );
    });

    // Set up escalation listeners
    for (final event in _escalationService.activeEvents) {
      _auditService.logEvent(
        type: AuditEventType.escalationTriggered,
        userId: 'system',
        description: 'Escalation triggered: ${event.type}',
        severity: AuditEventSeverity.high,
        resourceId: event.itemId,
        resourceType: event.itemType,
        metadata: {'escalationLevel': event.currentLevel.toString()},
      );
    }

    debugPrint('🔗 ComprehensiveCMMSService: Service integrations configured');
  }

  /// Map notification priority to audit severity
  AuditEventSeverity _mapNotificationPriorityToAuditSeverity(
    NotificationPriority priority,
  ) {
    switch (priority) {
      case NotificationPriority.low:
        return AuditEventSeverity.low;
      case NotificationPriority.medium:
        return AuditEventSeverity.medium;
      case NotificationPriority.high:
        return AuditEventSeverity.high;
      case NotificationPriority.critical:
        return AuditEventSeverity.critical;
    }
  }

  /// Enhanced work order creation with full integration
  Future<String> createWorkOrderWithIntegration({
    required String assetId,
    required String problemDescription,
    required String requestorId,
    String? photoPath,
    String priority = 'medium',
    String? category,
    String? notes,
  }) async {
    try {
      // Create work order using existing method
      final workOrderId = await _dataService.createWorkOrder(
        WorkOrder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          ticketNumber: 'WO-${DateTime.now().millisecondsSinceEpoch}',
          assetId: assetId,
          problemDescription: problemDescription,
          requestorId: requestorId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Log audit event
      await _auditService.logWorkOrderCreated(
        userId: requestorId,
        workOrderId: workOrderId,
        workOrderData: {
          'assetId': assetId,
          'problemDescription': problemDescription,
          'priority': priority,
          'category': category,
        },
      );

      // Send notification
      await _notificationService.notifyWorkOrderCreated(
        workOrderId: workOrderId,
        requestorId: requestorId,
        assetName: _dataService.assets.firstWhere((a) => a.id == assetId).name,
      );

      // Trigger automation
      await _automationService.executeAutomation(
        trigger: AutomationTrigger.workOrderCreated,
        itemId: workOrderId,
        itemType: 'work_order',
        context: {
          'priority': priority,
          'estimatedCost': 0, // Would be calculated in real implementation
          'overdueHours': 0,
        },
      );

      return workOrderId;
    } catch (e, st) {
      await _auditService.logError(
        userId: requestorId,
        error: 'Failed to create work order: $e',
        errorData: {
          'assetId': assetId,
          'problemDescription': problemDescription,
        },
      );
      rethrow;
    }
  }

  /// Enhanced work order assignment with full integration
  Future<void> assignWorkOrderWithIntegration({
    required String workOrderId,
    required String technicianId,
    required String assignedBy,
  }) async {
    try {
      // Assign work order
      await _dataService.assignTechnicianToWorkOrder(workOrderId, technicianId);

      // Log audit event
      await _auditService.logWorkOrderUpdated(
        userId: assignedBy,
        workOrderId: workOrderId,
        oldValues: {'assignedTechnicianIds': []},
        newValues: {
          'assignedTechnicianIds': [technicianId],
        },
      );

      // Send notification
      final workOrder =
          _dataService.workOrders.firstWhere((wo) => wo.id == workOrderId);
      await _notificationService.notifyWorkOrderAssigned(
        workOrderId: workOrderId,
        technicianId: technicianId,
        assetName: workOrder.assetName ??
            (workOrder.assetId == null
                ? 'General Maintenance'
                : 'Unknown Asset'),
      );

      // Trigger automation
      await _automationService.executeAutomation(
        trigger: AutomationTrigger.workOrderAssigned,
        itemId: workOrderId,
        itemType: 'work_order',
        context: {
          'technicianId': technicianId,
          'assignedBy': assignedBy,
        },
      );
    } catch (e, st) {
      await _auditService.logError(
        userId: assignedBy,
        error: 'Failed to assign work order: $e',
        errorData: {
          'workOrderId': workOrderId,
          'technicianId': technicianId,
        },
      );
      rethrow;
    }
  }

  /// Enhanced work order completion with full integration
  Future<void> completeWorkOrderWithIntegration({
    required String workOrderId,
    required String technicianId,
    required String correctiveActions,
    String? recommendations,
    double? laborCost,
    double? partsCost,
    String? completionPhotoPath,
  }) async {
    try {
      // Find and update work order
      final workOrder =
          _dataService.workOrders.firstWhere((wo) => wo.id == workOrderId);
      final updatedWorkOrder = workOrder.copyWith(
        status: WorkOrderStatus.completed,
        correctiveActions: correctiveActions,
        recommendations: recommendations,
        laborCost: laborCost,
        partsCost: partsCost,
        totalCost: (laborCost ?? 0) + (partsCost ?? 0),
        completedAt: DateTime.now(),
        completionPhotoPath: completionPhotoPath,
      );

      await _dataService.updateWorkOrder(updatedWorkOrder);

      // Log audit event
      await _auditService.logWorkOrderCompleted(
        userId: technicianId,
        workOrderId: workOrderId,
        completionData: {
          'correctiveActions': correctiveActions,
          'recommendations': recommendations,
          'laborCost': laborCost,
          'partsCost': partsCost,
          'totalCost': (laborCost ?? 0) + (partsCost ?? 0),
        },
      );

      // Send notification
      await _notificationService.notifyWorkOrderCompleted(
        workOrderId: workOrderId,
        requestorId: workOrder.requestorId,
        assetName: workOrder.assetName ??
            (workOrder.assetId == null
                ? 'General Maintenance'
                : 'Unknown Asset'),
      );

      // Trigger automation
      await _automationService.executeAutomation(
        trigger: AutomationTrigger.workOrderCompleted,
        itemId: workOrderId,
        itemType: 'work_order',
        context: {
          'technicianId': technicianId,
          'totalCost': (laborCost ?? 0) + (partsCost ?? 0),
        },
      );
    } catch (e, st) {
      await _auditService.logError(
        userId: technicianId,
        error: 'Failed to complete work order: $e',
        errorData: {
          'workOrderId': workOrderId,
          'correctiveActions': correctiveActions,
        },
      );
      rethrow;
    }
  }

  /// Enhanced PM task creation with full integration
  Future<String> createPMTaskWithIntegration({
    required String taskName,
    required String assetId,
    required String description,
    required List<String> checklist,
    required String frequency,
    required DateTime nextDue,
    List<String>? assignedTechnicianIds,
    String? createdBy,
  }) async {
    try {
      // Create PM task using existing method
      final assignedIds =
          (assignedTechnicianIds ?? <String>[]).where((id) => id.isNotEmpty).toList();
      final checklistJson = jsonEncode(
        checklist
            .map(
              (item) => {
                'text': item,
                'required': true,
              },
            )
            .toList(),
      );
      final pmTask = PMTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        taskName: taskName,
        assetId: assetId,
        description: description,
        checklist: checklistJson,
        frequency: PMTaskFrequency.monthly, // Default frequency
        intervalDays: 30,
        nextDueDate: nextDue,
        primaryTechnicianId: assignedIds.isNotEmpty ? assignedIds.first : null,
        assignedTechnicianIds: assignedIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _dataService.createPMTask(
        taskName: taskName,
        assetId: assetId,
        description: description,
        checklistJson: checklistJson,
        frequency: PMTaskFrequency.monthly,
        nextDue: nextDue,
        assignedTechnicianIds: assignedIds,
      );
      final pmTaskId = pmTask.id;

      // Log audit event
      await _auditService.logPMTaskCreated(
        userId: createdBy ?? 'system',
        pmTaskId: pmTaskId,
        pmTaskData: {
          'taskName': taskName,
          'assetId': assetId,
          'frequency': frequency,
          'assignedTechnicianIds': assignedIds,
        },
      );

      // Send notification if assigned
      if (assignedIds.isNotEmpty) {
        for (final techId in assignedIds) {
          await _notificationService.notifyPMTaskAssigned(
            pmTaskId: pmTaskId,
            technicianId: techId,
            taskName: taskName,
          );
        }
      }

      // Trigger automation
      await _automationService.executeAutomation(
        trigger: AutomationTrigger.pmTaskCreated,
        itemId: pmTaskId,
        itemType: 'pm_task',
        context: {
          'taskName': taskName,
          'frequency': frequency,
          'dueInHours': nextDue.difference(DateTime.now()).inHours,
        },
      );

      return pmTaskId;
    } catch (e, st) {
      await _auditService.logError(
        userId: createdBy ?? 'system',
        error: 'Failed to create PM task: $e',
        errorData: {
          'taskName': taskName,
          'assetId': assetId,
        },
      );
      rethrow;
    }
  }

  /// Enhanced inventory request with full integration
  Future<String> createInventoryRequestWithIntegration({
    required String itemId,
    required int quantity,
    required String requestedBy,
    InventoryRequestPriority priority = InventoryRequestPriority.medium,
    String? justification,
    String? workOrderId,
    String? pmTaskId,
    String? notes,
  }) async {
    try {
      // Create inventory request
      final requestId = await _inventoryService.createInventoryRequest(
        itemId: itemId,
        quantity: quantity,
        requestedBy: requestedBy,
        priority: priority,
        justification: justification,
        workOrderId: workOrderId,
        pmTaskId: pmTaskId,
        notes: notes,
      );

      // Log audit event
      await _auditService.logInventoryRequestCreated(
        userId: requestedBy,
        requestId: requestId,
        requestData: {
          'itemId': itemId,
          'quantity': quantity,
          'priority': priority.toString(),
          'workOrderId': workOrderId,
          'pmTaskId': pmTaskId,
        },
      );

      return requestId;
    } catch (e, st) {
      await _auditService.logError(
        userId: requestedBy,
        error: 'Failed to create inventory request: $e',
        errorData: {
          'itemId': itemId,
          'quantity': quantity,
        },
      );
      rethrow;
    }
  }

  /// Generate comprehensive report
  Future<ReportData> generateComprehensiveReport({
    required String reportName,
    required ReportType type,
    required ReportFormat format,
    required ReportPeriod period,
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final config = ReportConfig(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: reportName,
        type: type,
        format: format,
        period: period,
        filters: filters,
      );

      // Generate report
      final reportData = await _reportingService.generateReport(config);

      // Log audit event
      await _auditService.logDataExported(
        userId: 'system', // Would be actual user ID in real implementation
        reportType: type.toString(),
        exportData: {
          'reportName': reportName,
          'format': format.toString(),
          'period': period.toString(),
          'filters': filters,
        },
      );

      return reportData;
    } catch (e, st) {
      await _auditService.logError(
        userId: 'system',
        error: 'Failed to generate report: $e',
        errorData: {
          'reportName': reportName,
          'type': type.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get comprehensive system statistics
  Map<String, dynamic> getSystemStatistics() => {
        'dataService': {
          'workOrders': _dataService.workOrders.length,
          'pmTasks': _dataService.pmTasks.length,
          'users': _dataService.users.length,
          'assets': _dataService.assets.length,
          'inventoryItems': _dataService.inventoryItems.length,
        },
        'notifications': {
          'total': _notificationService.totalCount,
          'unread': _notificationService.unreadCount,
        },
        'escalations': {
          'active': _escalationService.activeEvents.length,
          'total': _escalationService.events.length,
          'stats': _escalationService.getEscalationStats(),
        },
        'inventory': {
          'stats': _inventoryService.getInventoryStats(),
          'requests': _inventoryService.requests.length,
          'vendors': _inventoryService.vendors.length,
        },
        'automation': {
          'stats': _automationService.getAutomationStats(),
          'rules': _automationService.rules.length,
          'executions': _automationService.executions.length,
        },
        'audit': {
          'stats': _auditService.getAuditStats(),
          'events': _auditService.events.length,
        },
      };

  /// Get service health status
  Map<String, dynamic> getServiceHealth() => {
        'comprehensiveService': _isInitialized,
        'dataService': true, // Would check actual health
        'notificationService': true,
        'escalationService': true,
        'reportingService': true,
        'inventoryService': true,
        'automationService': true,
        'auditService': true,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

  /// Cancels integration listeners without tearing down GetIt singletons.
  Future<void> cancelIntegrationListeners() async {
    await _newNotificationSubscription?.cancel();
    _newNotificationSubscription = null;
  }

  /// Dispose integration listeners only. Registered services remain singletons.
  Future<void> dispose() async {
    await cancelIntegrationListeners();
    debugPrint('🧹 ComprehensiveCMMSService: Integration listeners cancelled');
  }
}
