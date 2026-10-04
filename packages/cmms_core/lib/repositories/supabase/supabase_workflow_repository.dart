import '../../models/workflow_models.dart';
import '../../services/supabase_database_service.dart';
import '../workflow_repository.dart';
import '../../config/locator.dart';

class SupabaseWorkflowRepository implements WorkflowRepository {
  SupabaseWorkflowRepository({SupabaseDatabaseService? database})
      : _database = database ?? sl<SupabaseDatabaseService>();

  final SupabaseDatabaseService _database;

  @override
  Future<String> createWorkflow(Workflow workflow) =>
      _database.createWorkflow(workflow);

  @override
  Future<void> updateWorkflow(String workflowId, Workflow workflow) =>
      _database.updateWorkflow(workflowId, workflow);

  @override
  Future<void> deleteWorkflow(String workflowId) =>
      _database.deleteWorkflow(workflowId);

  @override
  Future<Workflow?> getWorkflowById(String workflowId) =>
      _database.getWorkflowById(workflowId);

  @override
  Future<List<Workflow>> getAllWorkflows() => _database.getAllWorkflows();

  @override
  Future<List<Workflow>> getWorkflowsByStatus(WorkflowStatus status) =>
      _database.getWorkflowsByStatus(status);

  @override
  Future<List<Workflow>> getWorkflowsForUser(String userId) =>
      _database.getWorkflowsForUser(userId);

  @override
  Future<List<Workflow>> getPendingApprovalsForUser(String userId) =>
      _database.getPendingApprovalsForUser(userId);
}
