import '../models/workflow_models.dart';

abstract class WorkflowRepository {
  Future<String> createWorkflow(Workflow workflow);
  Future<void> updateWorkflow(String workflowId, Workflow workflow);
  Future<void> deleteWorkflow(String workflowId);
  Future<Workflow?> getWorkflowById(String workflowId);
  Future<List<Workflow>> getAllWorkflows();
  Future<List<Workflow>> getWorkflowsByStatus(WorkflowStatus status);
  Future<List<Workflow>> getWorkflowsForUser(String userId);
  Future<List<Workflow>> getPendingApprovalsForUser(String userId);
}
