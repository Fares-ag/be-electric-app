// Workflow Service - Provides workflow management operations

import 'dart:async';

import 'package:cmms_core/models/workflow_models.dart';
import 'package:cmms_core/services/notification_service.dart';

class WorkflowService {
  // Removed unused constants

  /// Create a new workflow
  static Future<Workflow> createWorkflow({
    required String title,
    required String description,
    required WorkflowType type,
    required String createdBy,
    required String createdByUserId,
    required String createdByUserRole,
    String? assignedTo,
    String? assignedToUserId,
    String? assignedToUserRole,
    DateTime? dueDate,
    Map<String, dynamic> data = const {},
    String? priority,
  }) async {
    final workflow = Workflow(
      id: _generateId(),
      title: title,
      description: description,
      type: type,
      status: WorkflowStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      createdByUserId: createdByUserId,
      createdByUserRole: createdByUserRole,
      assignedTo: assignedTo,
      assignedToUserId: assignedToUserId,
      assignedToUserRole: assignedToUserRole,
      dueDate: dueDate,
      data: data,
      priority: priority,
    );

    await _saveWorkflow(workflow);
    await _notifyWorkflowCreated(workflow);

    return workflow;
  }

  /// Create work order approval workflow
  static Future<WorkOrderApprovalWorkflow> createWorkOrderApprovalWorkflow({
    required String workOrderId,
    required double estimatedCost,
    required String createdBy,
    required String createdByUserId,
    required String createdByUserRole,
    String? justification,
    List<String> approvers = const [],
    String? priority,
  }) async {
    final workflow = WorkOrderApprovalWorkflow(
      id: _generateId(),
      title: 'Work Order Approval - $workOrderId',
      description:
          'Approval required for work order with estimated cost of \$${estimatedCost.toStringAsFixed(2)}',
      status: WorkflowStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      createdByUserId: createdByUserId,
      createdByUserRole: createdByUserRole,
      workOrderId: workOrderId,
      estimatedCost: estimatedCost,
      justification: justification,
      // priority and approvers stored in data for base Workflow fields
      data: {
        'workOrderId': workOrderId,
        'estimatedCost': estimatedCost,
        'justification': justification,
        'approvers': approvers,
        'priority': priority ?? 'medium',
      },
    );

    await _saveWorkflow(workflow);
    await _notifyWorkflowCreated(workflow);

    return workflow;
  }

  /// Create asset lifecycle workflow
  static Future<AssetLifecycleWorkflow> createAssetLifecycleWorkflow({
    required String assetId,
    required String currentStage,
    required String targetStage,
    required String createdBy,
    required String createdByUserId,
    required String createdByUserRole,
    List<String> requiredActions = const [],
    Map<String, dynamic> inspectionData = const {},
    String? priority,
  }) async {
    final workflow = AssetLifecycleWorkflow(
      id: _generateId(),
      title: 'Asset Lifecycle - $assetId',
      description:
          'Asset lifecycle transition from $currentStage to $targetStage',
      status: WorkflowStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      createdByUserId: createdByUserId,
      createdByUserRole: createdByUserRole,
      assetId: assetId,
      currentStage: currentStage,
      targetStage: targetStage,
      requiredActions: requiredActions,
      inspectionData: inspectionData,
      data: {
        'assetId': assetId,
        'currentStage': currentStage,
        'targetStage': targetStage,
        'requiredActions': requiredActions,
        'inspectionData': inspectionData,
        'priority': priority ?? 'medium',
      },
    );

    await _saveWorkflow(workflow);
    await _notifyWorkflowCreated(workflow);

    return workflow;
  }

  /// Create escalation workflow
  static Future<EscalationWorkflow> createEscalationWorkflow({
    required String originalWorkflowId,
    required String escalationReason,
    required String escalatedBy,
    required String escalatedByUserId,
    required String escalatedByUserRole,
    List<String> escalationPath = const [],
    String? priority,
  }) async {
    final workflow = EscalationWorkflow(
      id: _generateId(),
      title: 'Escalation - $originalWorkflowId',
      description: 'Workflow escalated: $escalationReason',
      status: WorkflowStatus.pending,
      createdBy: escalatedBy,
      createdAt: DateTime.now(),
      createdByUserId: escalatedByUserId,
      createdByUserRole: escalatedByUserRole,
      originalWorkflowId: originalWorkflowId,
      escalationReason: escalationReason,
      escalatedBy: escalatedBy,
      escalatedAt: DateTime.now(),
      escalationPath: escalationPath,
      data: {
        'originalWorkflowId': originalWorkflowId,
        'escalationReason': escalationReason,
        'escalatedBy': escalatedBy,
        'escalatedAt': DateTime.now().toIso8601String(),
        'escalationPath': escalationPath,
        'priority': priority ?? 'high',
      },
    );

    await _saveWorkflow(workflow);
    await _notifyWorkflowCreated(workflow);

    return workflow;
  }

  /// Update workflow status
  static Future<Workflow> updateWorkflowStatus({
    required String workflowId,
    required WorkflowStatus status,
    String? updatedBy,
    String? comment,
  }) async {
    final workflow = await getWorkflow(workflowId);
    if (workflow == null) {
      throw Exception('Workflow not found: $workflowId');
    }

    // Placeholder update: persist and notify without modifying immutable model
    await _saveWorkflow(workflow);
    await _notifyWorkflowUpdated(workflow, updatedBy, comment);
    return workflow;
  }

  /// Complete workflow step
  static Future<Workflow> completeWorkflowStep({
    required String workflowId,
    required String stepId,
    required String completedBy,
    Map<String, dynamic>? stepData,
  }) async {
    final workflow = await getWorkflow(workflowId);
    if (workflow == null) {
      throw Exception('Workflow not found: $workflowId');
    }

    // Placeholder: notify only, step tracking stored in data externally if needed
    await _notifyWorkflowStepCompleted(workflow, stepId, completedBy);
    return workflow;
  }

  /// Approve workflow
  static Future<Workflow> approveWorkflow({
    required String workflowId,
    required String approvedBy,
    String? comment,
  }) async =>
      updateWorkflowStatus(
        workflowId: workflowId,
        status: WorkflowStatus.approved,
        updatedBy: approvedBy,
        comment: comment,
      );

  /// Reject workflow
  static Future<Workflow> rejectWorkflow({
    required String workflowId,
    required String rejectedBy,
    required String reason,
  }) async {
    final workflow = await getWorkflow(workflowId);
    if (workflow == null) {
      throw Exception('Workflow not found: $workflowId');
    }

    // Placeholder: notify only
    await _notifyWorkflowRejected(workflow, rejectedBy, reason);
    return workflow;
  }

  /// Escalate workflow
  static Future<EscalationWorkflow> escalateWorkflow({
    required String workflowId,
    required String escalationReason,
    required String escalatedBy,
    List<String> escalationPath = const [],
  }) async {
    final originalWorkflow = await getWorkflow(workflowId);
    if (originalWorkflow == null) {
      throw Exception('Workflow not found: $workflowId');
    }

    // Update original workflow status
    await updateWorkflowStatus(
      workflowId: workflowId,
      status: WorkflowStatus.escalated,
      updatedBy: escalatedBy,
    );

    // Create escalation workflow
    return createEscalationWorkflow(
      originalWorkflowId: workflowId,
      escalationReason: escalationReason,
      escalatedBy: escalatedBy,
      escalatedByUserId: escalatedBy,
      escalatedByUserRole: 'system',
      escalationPath: escalationPath,
    );
  }

  /// Get workflow by ID
  static Future<Workflow?> getWorkflow(String workflowId) async {
    final workflows = await getAllWorkflows();
    try {
      return workflows.firstWhere((w) => w.id == workflowId);
    } catch (e, st) {
      return null;
    }
  }

  /// Get all workflows
  static Future<List<Workflow>> getAllWorkflows() async {
    // In a real implementation, this would fetch from a database
    // For now, return empty list
    return [];
  }

  /// Get workflows by status
  static Future<List<Workflow>> getWorkflowsByStatus(
    WorkflowStatus status,
  ) async {
    final workflows = await getAllWorkflows();
    return workflows.where((w) => w.status == status).toList();
  }

  /// Get workflows assigned to user
  static Future<List<Workflow>> getWorkflowsAssignedTo(String userId) async {
    final workflows = await getAllWorkflows();
    return workflows.where((w) => w.assignedTo == userId).toList();
  }

  /// Get workflows created by user
  static Future<List<Workflow>> getWorkflowsCreatedBy(String userId) async {
    final workflows = await getAllWorkflows();
    return workflows.where((w) => w.createdBy == userId).toList();
  }

  /// Get overdue workflows
  static Future<List<Workflow>> getOverdueWorkflows() async {
    final now = DateTime.now();
    final workflows = await getAllWorkflows();
    return workflows
        .where(
          (w) =>
              w.dueDate != null &&
              w.dueDate!.isBefore(now) &&
              w.status != WorkflowStatus.completed &&
              w.status != WorkflowStatus.cancelled,
        )
        .toList();
  }

  /// Check for automatic escalations
  static Future<void> checkAutomaticEscalations() async {
    final overdueWorkflows = await getOverdueWorkflows();

    for (final workflow in overdueWorkflows) {
      // Check if workflow should be automatically escalated
      if (_shouldAutoEscalate(workflow)) {
        await escalateWorkflow(
          workflowId: workflow.id,
          escalationReason: 'Automatic escalation due to overdue status',
          escalatedBy: 'system',
          escalationPath: ['manager', 'director'],
        );
      }
    }
  }

  /// Create workflow template
  static Future<WorkflowTemplate> createWorkflowTemplate({
    required String name,
    required String description,
    required WorkflowType type,
    required List<WorkflowStepTemplate> steps,
    Map<String, dynamic> defaultData = const {},
    String? category,
  }) async {
    final template = WorkflowTemplate(
      id: _generateId(),
      name: name,
      description: description,
      type: type,
      steps: steps,
      defaultData: defaultData,
      category: category,
    );

    await _saveWorkflowTemplate(template);
    return template;
  }

  /// Get workflow templates
  static Future<List<WorkflowTemplate>> getWorkflowTemplates() async {
    // In a real implementation, this would fetch from a database
    return [];
  }

  /// Create workflow from template
  static Future<Workflow> createWorkflowFromTemplate({
    required String templateId,
    required String createdBy,
    required String createdByUserId,
    required String createdByUserRole,
    String? assignedTo,
    String? assignedToUserId,
    String? assignedToUserRole,
    DateTime? dueDate,
    Map<String, dynamic>? customData,
    String? priority,
  }) async {
    final template = await getWorkflowTemplate(templateId);
    if (template == null) {
      throw Exception('Workflow template not found: $templateId');
    }

    final stepsMap = <String, WorkflowStep>{};
    for (var i = 0; i < template.steps.length; i++) {
      final stepTemplate = template.steps[i];
      final stepId = '${_generateId()}_$i';
      stepsMap[stepId] = WorkflowStep(
        id: stepId,
        name: stepTemplate.name,
        description: stepTemplate.description,
        assignedTo: stepTemplate.defaultAssignee,
        status: WorkflowStatus.pending,
        data: stepTemplate.defaultData,
        order: stepTemplate.order,
      );
    }

    return createWorkflow(
      title: template.name,
      description: template.description,
      type: template.type,
      createdBy: createdBy,
      createdByUserId: createdByUserId,
      createdByUserRole: createdByUserRole,
      assignedTo: assignedTo,
      assignedToUserId: assignedToUserId,
      assignedToUserRole: assignedToUserRole,
      dueDate: dueDate,
      data: {
        ...template.defaultData,
        ...?customData,
        'steps': stepsMap.map((k, v) => MapEntry(k, v.toJson())),
        if (priority != null) 'priority': priority,
        if (template.category != null) 'category': template.category,
      },
    );
  }

  /// Get workflow template by ID
  static Future<WorkflowTemplate?> getWorkflowTemplate(
    String templateId,
  ) async {
    final templates = await getWorkflowTemplates();
    try {
      return templates.firstWhere((t) => t.id == templateId);
    } catch (e, st) {
      return null;
    }
  }

  // Private helper methods

  static String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static Future<void> _saveWorkflow(Workflow workflow) async {
    // In a real implementation, this would save to a database
    // For now, this is a placeholder
  }

  static Future<void> _saveWorkflowTemplate(WorkflowTemplate template) async {
    // In a real implementation, this would save to a database
    // For now, this is a placeholder
  }

  // Step builder helpers removed; steps are serialized into data when needed.

  static bool _shouldAutoEscalate(Workflow workflow) {
    // Simple auto-escalation logic
    // In a real implementation, this would be more sophisticated
    final hoursOverdue = DateTime.now().difference(workflow.dueDate!).inHours;
    return hoursOverdue > 24; // Auto-escalate after 24 hours
  }

  // Notification methods

  static Future<void> _notifyWorkflowCreated(Workflow workflow) async {
    await NotificationService.showLocalNotification(
      title: 'New Workflow Created',
      body: '${workflow.title} has been created and assigned to you.',
    );
  }

  static Future<void> _notifyWorkflowUpdated(
    Workflow workflow,
    String? updatedBy,
    String? comment,
  ) async {
    await NotificationService.showLocalNotification(
      title: 'Workflow Updated',
      body:
          '${workflow.title} has been updated${comment != null ? ': $comment' : ''}.',
    );
  }

  static Future<void> _notifyWorkflowStepCompleted(
    Workflow workflow,
    String stepId,
    String completedBy,
  ) async {
    await NotificationService.showLocalNotification(
      title: 'Workflow Step Completed',
      body: 'A step in ${workflow.title} has been completed by $completedBy.',
    );
  }

  static Future<void> _notifyWorkflowRejected(
    Workflow workflow,
    String rejectedBy,
    String reason,
  ) async {
    await NotificationService.showLocalNotification(
      title: 'Workflow Rejected',
      body:
          '${workflow.title} has been rejected by $rejectedBy. Reason: $reason',
    );
  }
}
