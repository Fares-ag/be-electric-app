// Workflow Routing Service - Smart routing and assignment of workflows

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../models/workflow_models.dart';
import 'unified_data_service.dart';
import '../config/locator.dart';

/// Service for routing workflows to appropriate users and managing approval chains
class WorkflowRoutingService {

  UnifiedDataService get _dataService => sl<UnifiedDataService>();

  /// Route workflow to appropriate approvers based on type and conditions
  Future<List<String>> routeWorkflow(Workflow workflow) async {
    final approvers = <String>[];

    switch (workflow.type) {
      case WorkflowType.workOrderApproval:
        approvers.addAll(await _routeWorkOrderApproval(workflow));
        break;

      case WorkflowType.workOrderCompletion:
        approvers.addAll(await _routeWorkOrderCompletion(workflow));
        break;

      case WorkflowType.partsRequest:
        approvers.addAll(await _routePartsRequest(workflow));
        break;

      case WorkflowType.purchaseOrder:
        approvers.addAll(await _routePurchaseOrder(workflow));
        break;

      case WorkflowType.budgetApproval:
        approvers.addAll(await _routeBudgetApproval(workflow));
        break;

      case WorkflowType.escalation:
        approvers.addAll(await _routeEscalation(workflow));
        break;

      case WorkflowType.assetLifecycle:
      case WorkflowType.inventoryRequest:
      case WorkflowType.qualityInspection:
      case WorkflowType.scheduling:
        // Default to managers
        approvers.addAll(await _getManagers());
        break;

      case WorkflowType.userAccessRequest:
        // Route to admins only
        approvers.addAll(await _getAdmins());
        break;
    }

    debugPrint(
      'Workflow Routing: ${workflow.type.name} routed to ${approvers.length} approver(s)',
    );

    return approvers;
  }

  /// Route work order approval workflow
  Future<List<String>> _routeWorkOrderApproval(Workflow workflow) async {
    final approvers = <String>[];
    final estimatedCost = workflow.data['estimatedCost'] as num? ?? 0;
    final priority = workflow.priority ?? 'medium';

    // High-cost work orders (> QAR 5000) require admin approval
    if (estimatedCost > 5000) {
      approvers.addAll(await _getAdmins());
    }
    // Medium-cost work orders (> QAR 1000) require manager approval
    else if (estimatedCost > 1000) {
      approvers.addAll(await _getManagers());
    }

    // Critical priority always includes admin
    if (priority.toLowerCase() == 'critical' ||
        priority.toLowerCase() == 'urgent') {
      approvers.addAll(await _getAdmins());
    }

    // If no specific approvers, default to managers
    if (approvers.isEmpty) {
      approvers.addAll(await _getManagers());
    }

    return approvers.toSet().toList(); // Remove duplicates
  }

  /// Route work order completion approval
  Future<List<String>> _routeWorkOrderCompletion(Workflow workflow) async {
    final approvers = <String>[];

    // Route to the manager who approved the original work order
    final workOrderId = workflow.relatedEntityId;
    if (workOrderId != null) {
      try {
        final workOrder = _dataService.workOrders.firstWhere(
          (wo) => wo.id == workOrderId,
        );

        // If work order had an assigned technician, route to their manager
        if (workOrder.assignedTechnicianIds.isNotEmpty) {
          final manager = await _getTechnicianManager(
            workOrder.assignedTechnicianIds.first,
          );
          if (manager != null) {
            approvers.add(manager.id);
          }
        }
      } catch (e, st) {
        // Work order not found, will default to all managers
        debugPrint('Work order $workOrderId not found: $e');
      }
    }

    // Default to all managers
    if (approvers.isEmpty) {
      approvers.addAll(await _getManagers());
    }

    return approvers;
  }

  /// Route parts request workflow
  Future<List<String>> _routePartsRequest(Workflow workflow) async {
    final approvers = <String>[];
    final estimatedCost = workflow.data['estimatedCost'] as num? ?? 0;

    // High-cost parts requests (> QAR 2000) require admin
    if (estimatedCost > 2000) {
      approvers.addAll(await _getAdmins());
    } else {
      // Route to manager with least pending approvals (load balancing)
      final manager = await _getManagerWithLeastLoad();
      if (manager != null) {
        approvers.add(manager.id);
      } else {
        approvers.addAll(await _getManagers());
      }
    }

    return approvers;
  }

  /// Route purchase order workflow
  Future<List<String>> _routePurchaseOrder(Workflow workflow) async {
    final approvers = <String>[];
    final estimatedCost = workflow.data['estimatedCost'] as num? ?? 0;

    // POs > QAR 5000 require admin approval
    if (estimatedCost > 5000) {
      approvers.addAll(await _getAdmins());
    } else {
      // Route to managers
      approvers.addAll(await _getManagers());
    }

    return approvers;
  }

  /// Route budget approval workflow
  Future<List<String>> _routeBudgetApproval(Workflow workflow) async {
    // Always route to admins
    return _getAdmins();
  }

  /// Route escalation workflow
  Future<List<String>> _routeEscalation(Workflow workflow) async {
    final approvers = <String>[];
    final escalationLevel = workflow.data['escalationLevel'] as int? ?? 1;

    switch (escalationLevel) {
      case 1:
        // Level 1: Route to managers
        approvers.addAll(await _getManagers());
        break;
      case 2:
        // Level 2: Route to admins
        approvers.addAll(await _getAdmins());
        break;
      case 3:
        // Level 3: System alert - notify all admins
        approvers.addAll(await _getAdmins());
        break;
      default:
        approvers.addAll(await _getManagers());
    }

    return approvers;
  }

  /// Get all managers
  Future<List<String>> _getManagers() async {
    final managers = _dataService.users
        .where((user) => user.role.toLowerCase() == 'manager')
        .map((user) => user.id)
        .toList();

    return managers;
  }

  /// Get all admins
  Future<List<String>> _getAdmins() async {
    final admins = _dataService.users
        .where((user) => user.role.toLowerCase() == 'admin')
        .map((user) => user.id)
        .toList();

    return admins;
  }

  /// Get manager with least pending approvals (load balancing)
  Future<User?> _getManagerWithLeastLoad() async {
    final managers = _dataService.users
        .where((user) => user.role.toLowerCase() == 'manager')
        .toList();

    if (managers.isEmpty) return null;

    // For now, return random manager (TODO: implement actual load balancing)
    final random = Random();
    return managers[random.nextInt(managers.length)];
  }

  /// Get technician's manager
  Future<User?> _getTechnicianManager(String technicianId) async {
    // For now, return any manager (TODO: implement org structure)
    final managers = _dataService.users
        .where((user) => user.role.toLowerCase() == 'manager')
        .toList();

    return managers.isNotEmpty ? managers.first : null;
  }

  /// Assign technician to workflow based on workload and availability
  Future<String?> assignBestTechnician(Workflow workflow) async {
    final technicians = _dataService.users
        .where((user) => user.role.toLowerCase() == 'technician')
        .toList();

    if (technicians.isEmpty) return null;

    // Get technician workloads
    final technicianLoads = <String, int>{};
    for (final technician in technicians) {
      final assignedWorkOrders = _dataService.workOrders
          .where(
            (wo) => wo.hasTechnician(technician.id) && !wo.isCompleted,
          )
          .length;
      technicianLoads[technician.id] = assignedWorkOrders;
    }

    // Find technician with minimum workload
    String? bestTechnicianId;
    var minLoad = double.maxFinite.toInt();

    technicianLoads.forEach((techId, load) {
      if (load < minLoad) {
        minLoad = load;
        bestTechnicianId = techId;
      }
    });

    debugPrint(
      'Workflow Routing: Auto-assigned workflow to technician $bestTechnicianId (load: $minLoad)',
    );

    return bestTechnicianId;
  }

  /// Calculate workflow priority score for routing
  int calculatePriorityScore(Workflow workflow) {
    var score = 0;

    // Base score from priority
    switch (workflow.priority?.toLowerCase()) {
      case 'critical':
        score += 100;
        break;
      case 'urgent':
        score += 80;
        break;
      case 'high':
        score += 60;
        break;
      case 'medium':
        score += 40;
        break;
      case 'low':
        score += 20;
        break;
      default:
        score += 30;
    }

    // Add score for overdue
    if (workflow.isOverdue) {
      score += 50;
    }

    // Add score for due today
    if (workflow.isDueToday) {
      score += 30;
    }

    // Add score for high cost
    final estimatedCost = workflow.data['estimatedCost'] as num? ?? 0;
    if (estimatedCost > 5000) {
      score += 40;
    } else if (estimatedCost > 2000) {
      score += 20;
    }

    // Add score for escalation
    if (workflow.isEscalated) {
      score += 60;
    }

    return score;
  }

  /// Get recommended approval chain for workflow
  Future<List<Map<String, dynamic>>> getApprovalChain(
    Workflow workflow,
  ) async {
    final chain = <Map<String, dynamic>>[];

    switch (workflow.type) {
      case WorkflowType.workOrderApproval:
        final cost = workflow.data['estimatedCost'] as num? ?? 0;
        if (cost > 5000) {
          chain.add({
            'step': 1,
            'role': 'manager',
            'description': 'Manager approval',
            'required': true,
          });
          chain.add({
            'step': 2,
            'role': 'admin',
            'description': 'Admin approval for high-cost',
            'required': true,
          });
        } else if (cost > 1000) {
          chain.add({
            'step': 1,
            'role': 'manager',
            'description': 'Manager approval',
            'required': true,
          });
        }
        break;

      case WorkflowType.partsRequest:
        chain.add({
          'step': 1,
          'role': 'manager',
          'description': 'Manager approval',
          'required': true,
        });
        final cost = workflow.data['estimatedCost'] as num? ?? 0;
        if (cost > 2000) {
          chain.add({
            'step': 2,
            'role': 'admin',
            'description': 'Admin approval for high-cost parts',
            'required': true,
          });
        }
        break;

      case WorkflowType.purchaseOrder:
        chain.add({
          'step': 1,
          'role': 'manager',
          'description': 'Manager review',
          'required': true,
        });
        final cost = workflow.data['estimatedCost'] as num? ?? 0;
        if (cost > 5000) {
          chain.add({
            'step': 2,
            'role': 'admin',
            'description': 'Admin budget approval',
            'required': true,
          });
        }
        break;

      case WorkflowType.workOrderCompletion:
        chain.add({
          'step': 1,
          'role': 'manager',
          'description': 'Manager quality review',
          'required': true,
        });
        break;

      case WorkflowType.budgetApproval:
      case WorkflowType.userAccessRequest:
        chain.add({
          'step': 1,
          'role': 'admin',
          'description': 'Admin approval',
          'required': true,
        });
        break;

      default:
        chain.add({
          'step': 1,
          'role': 'manager',
          'description': 'Manager approval',
          'required': true,
        });
    }

    return chain;
  }

  /// Check if workflow is ready for next approval step
  bool isReadyForNextApproval(Workflow workflow) {
    if (workflow.approvers.isEmpty) return false;
    if (workflow.status != WorkflowStatus.pendingApproval) return false;

    // Check if all required approvals are received
    final requiredApprovals = workflow.approvers.length;
    final receivedApprovals = workflow.approvalHistory
        .where((approval) => approval['action'] == 'approve')
        .length;

    return receivedApprovals < requiredApprovals;
  }

  /// Get workflow routing statistics
  Map<String, dynamic> getRoutingStatistics() {
    final managers = _dataService.users
        .where((user) => user.role.toLowerCase() == 'manager')
        .length;
    final admins = _dataService.users
        .where((user) => user.role.toLowerCase() == 'admin')
        .length;
    final technicians = _dataService.users
        .where((user) => user.role.toLowerCase() == 'technician')
        .length;

    return {
      'totalManagers': managers,
      'totalAdmins': admins,
      'totalTechnicians': technicians,
      'availableApprovers': managers + admins,
    };
  }
}
