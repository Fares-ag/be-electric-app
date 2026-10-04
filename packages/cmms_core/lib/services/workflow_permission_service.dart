// Workflow Permission Service - Role-based access control for workflows

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../models/workflow_models.dart';

enum RequiredRole { admin, manager, technician, requestor, any }

/// Service for managing workflow permissions and role-based access control
class WorkflowPermissionService {

  /// Check if user can create a specific workflow type
  bool canCreateWorkflow(User user, WorkflowType type) {
    switch (type) {
      case WorkflowType.workOrderApproval:
        // Requestors, Technicians, Managers, and Admins can create work order approvals
        return true;

      case WorkflowType.workOrderCompletion:
        // Only technicians can submit completion workflows
        return user.isTechnician || user.isManager || user.isAdmin;

      case WorkflowType.partsRequest:
        // Only technicians can request parts
        return user.isTechnician || user.isManager || user.isAdmin;

      case WorkflowType.purchaseOrder:
        // Only managers and admins can create purchase orders
        return user.isManager || user.isAdmin;

      case WorkflowType.budgetApproval:
        // Only managers and admins can request budget approvals
        return user.isManager || user.isAdmin;

      case WorkflowType.assetLifecycle:
      case WorkflowType.inventoryRequest:
      case WorkflowType.qualityInspection:
      case WorkflowType.scheduling:
        // Managers and admins only
        return user.isManager || user.isAdmin;

      case WorkflowType.escalation:
        // System-generated, managers and admins can manually escalate
        return user.isManager || user.isAdmin;

      case WorkflowType.userAccessRequest:
        // Only admins can manage user access
        return user.isAdmin;
    }
  }

  /// Check if user can view a workflow
  bool canViewWorkflow(User user, Workflow workflow) {
    // Admin can view all workflows
    if (user.isAdmin) return true;

    // Manager can view all workflows
    if (user.isManager) return true;

    // User can view workflows they created
    if (workflow.createdByUserId == user.id) return true;

    // User can view workflows assigned to them
    if (workflow.assignedToUserId == user.id) return true;

    // Requestors can only view their own workflows
    if (user.role.toLowerCase() == 'requestor') {
      return workflow.createdByUserId == user.id;
    }

    // Technicians can view workflows assigned to them
    if (user.isTechnician) {
      return workflow.assignedToUserId == user.id ||
          workflow.createdByUserId == user.id;
    }

    return false;
  }

  /// Check if user can approve a workflow
  bool canApproveWorkflow(User user, Workflow workflow) {
    // Only pending approval workflows can be approved
    if (workflow.status != WorkflowStatus.pendingApproval) return false;

    // Admin can approve anything
    if (user.isAdmin) return true;

    // Check if user is in the approvers list
    if (workflow.approvers.contains(user.id)) return true;

    // Check role-based approval permissions
    switch (workflow.type) {
      case WorkflowType.workOrderApproval:
      case WorkflowType.workOrderCompletion:
      case WorkflowType.partsRequest:
      case WorkflowType.assetLifecycle:
      case WorkflowType.inventoryRequest:
      case WorkflowType.qualityInspection:
      case WorkflowType.scheduling:
      case WorkflowType.escalation:
        // Managers and admins can approve
        return user.isManager || user.isAdmin;

      case WorkflowType.purchaseOrder:
      case WorkflowType.budgetApproval:
        // High-value approvals require admin
        final estimatedCost = workflow.data['estimatedCost'] as num? ?? 0;
        if (estimatedCost > 5000) {
          return user.isAdmin;
        }
        return user.isManager || user.isAdmin;

      case WorkflowType.userAccessRequest:
        // Only admins
        return user.isAdmin;
    }
  }

  /// Check if user can reject a workflow
  bool canRejectWorkflow(User user, Workflow workflow) {
    // Same permissions as approval
    return canApproveWorkflow(user, workflow);
  }

  /// Check if user can edit a workflow
  bool canEditWorkflow(User user, Workflow workflow) {
    // Cannot edit completed or cancelled workflows
    if (workflow.isCompleted || workflow.isCancelled) return false;

    // Admin can edit anything
    if (user.isAdmin) return true;

    // Creator can edit their own workflows (if pending)
    if (workflow.createdByUserId == user.id && workflow.isPending) {
      return true;
    }

    // Assigned user can edit
    if (workflow.assignedToUserId == user.id) return true;

    // Managers can edit workflows
    if (user.isManager) return true;

    return false;
  }

  /// Check if user can cancel a workflow
  bool canCancelWorkflow(User user, Workflow workflow) {
    // Cannot cancel completed workflows
    if (workflow.isCompleted) return false;

    // Admin can cancel anything
    if (user.isAdmin) return true;

    // Creator can cancel their own pending workflows
    if (workflow.createdByUserId == user.id &&
        (workflow.isPending || workflow.status == WorkflowStatus.draft)) {
      return true;
    }

    // Managers can cancel workflows
    if (user.isManager) return true;

    return false;
  }

  /// Check if user can delete a workflow
  bool canDeleteWorkflow(User user, Workflow workflow) {
    // Only admins can delete workflows
    if (user.isAdmin) return true;

    // Managers can delete draft or cancelled workflows
    if (user.isManager &&
        (workflow.status == WorkflowStatus.draft || workflow.isCancelled)) {
      return true;
    }

    return false;
  }

  /// Check if user can escalate a workflow
  bool canEscalateWorkflow(User user, Workflow workflow) {
    // Cannot escalate completed or cancelled workflows
    if (workflow.isCompleted || workflow.isCancelled) return false;

    // Admin can escalate anything
    if (user.isAdmin) return true;

    // Manager can escalate workflows
    if (user.isManager) return true;

    // Assigned technician can escalate their own overdue workflows
    if (user.isTechnician &&
        workflow.assignedToUserId == user.id &&
        workflow.isOverdue) {
      return true;
    }

    return false;
  }

  /// Check if user can reassign a workflow
  bool canReassignWorkflow(User user, Workflow workflow) {
    // Cannot reassign completed or cancelled workflows
    if (workflow.isCompleted || workflow.isCancelled) return false;

    // Admin can reassign anything
    if (user.isAdmin) return true;

    // Manager can reassign workflows
    if (user.isManager) return true;

    return false;
  }

  /// Get list of users who can approve a workflow
  List<String> getEligibleApprovers(Workflow workflow, List<User> allUsers) {
    final eligibleApprovers = <String>[];

    for (final user in allUsers) {
      if (canApproveWorkflow(user, workflow)) {
        eligibleApprovers.add(user.id);
      }
    }

    return eligibleApprovers;
  }

  /// Get next approver in the approval chain
  String? getNextApprover(Workflow workflow, List<User> allUsers) {
    // If there are specific approvers defined, return the first one who hasn't approved
    if (workflow.approvers.isNotEmpty) {
      for (final approverId in workflow.approvers) {
        final hasApproved = workflow.approvalHistory.any(
          (approval) =>
              approval['approverId'] == approverId &&
              approval['action'] == 'approve',
        );
        if (!hasApproved) {
          return approverId;
        }
      }
    }

    // Otherwise, find the first eligible manager or admin
    final eligibleApprovers = getEligibleApprovers(workflow, allUsers);
    if (eligibleApprovers.isNotEmpty) {
      return eligibleApprovers.first;
    }

    return null;
  }

  /// Validate workflow transition
  bool canTransitionTo(
    User user,
    Workflow workflow,
    WorkflowStatus newStatus,
  ) {
    final currentStatus = workflow.status;

    // Admin can force any transition
    if (user.isAdmin) return true;

    // Define allowed transitions
    switch (currentStatus) {
      case WorkflowStatus.draft:
        return newStatus == WorkflowStatus.pending ||
            newStatus == WorkflowStatus.cancelled;

      case WorkflowStatus.pending:
        return newStatus == WorkflowStatus.inProgress ||
            newStatus == WorkflowStatus.pendingApproval ||
            newStatus == WorkflowStatus.cancelled;

      case WorkflowStatus.inProgress:
        return newStatus == WorkflowStatus.pendingApproval ||
            newStatus == WorkflowStatus.completed ||
            newStatus == WorkflowStatus.onHold ||
            newStatus == WorkflowStatus.escalated;

      case WorkflowStatus.pendingApproval:
        return newStatus == WorkflowStatus.approved ||
            newStatus == WorkflowStatus.rejected ||
            newStatus == WorkflowStatus.escalated;

      case WorkflowStatus.approved:
        return newStatus == WorkflowStatus.inProgress ||
            newStatus == WorkflowStatus.completed;

      case WorkflowStatus.rejected:
        return newStatus == WorkflowStatus.draft ||
            newStatus == WorkflowStatus.cancelled;

      case WorkflowStatus.onHold:
        return newStatus == WorkflowStatus.inProgress ||
            newStatus == WorkflowStatus.cancelled;

      case WorkflowStatus.escalated:
        return newStatus == WorkflowStatus.inProgress ||
            newStatus == WorkflowStatus.pendingApproval ||
            newStatus == WorkflowStatus.cancelled;

      case WorkflowStatus.completed:
      case WorkflowStatus.cancelled:
        // Terminal states - only admin can change
        return false;
    }
  }

  /// Get workflow permissions summary for a user
  Map<String, bool> getWorkflowPermissions(User user, Workflow workflow) => {
        'canView': canViewWorkflow(user, workflow),
        'canEdit': canEditWorkflow(user, workflow),
        'canApprove': canApproveWorkflow(user, workflow),
        'canReject': canRejectWorkflow(user, workflow),
        'canCancel': canCancelWorkflow(user, workflow),
        'canDelete': canDeleteWorkflow(user, workflow),
        'canEscalate': canEscalateWorkflow(user, workflow),
        'canReassign': canReassignWorkflow(user, workflow),
      };

  /// Log permission check for audit trail
  void logPermissionCheck({
    required User user,
    required Workflow workflow,
    required String action,
    required bool granted,
  }) {
    debugPrint(
      'ðŸ” Permission Check: User ${user.name} (${user.role}) '
      '$action workflow ${workflow.id} (${workflow.type.name}): '
      '${granted ? "GRANTED" : "DENIED"}',
    );
  }

  /// Get role hierarchy level (higher number = more permissions)
  int getRoleLevel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 4;
      case 'manager':
        return 3;
      case 'technician':
        return 2;
      case 'requestor':
        return 1;
      default:
        return 0;
    }
  }

  /// Check if user has sufficient role level for action
  bool hasMinimumRoleLevel(User user, RequiredRole requiredRole) {
    final userLevel = getRoleLevel(user.role);

    switch (requiredRole) {
      case RequiredRole.admin:
        return userLevel >= 4;
      case RequiredRole.manager:
        return userLevel >= 3;
      case RequiredRole.technician:
        return userLevel >= 2;
      case RequiredRole.requestor:
        return userLevel >= 1;
      case RequiredRole.any:
        return true;
    }
  }
}
