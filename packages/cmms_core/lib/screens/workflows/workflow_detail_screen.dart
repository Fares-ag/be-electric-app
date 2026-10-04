// Workflow Detail Screen - Comprehensive view and actions for workflows

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/workflow_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../utils/app_theme.dart';
import 'workflow_approval_screen.dart';
import '../../utils/user_facing_errors.dart';

// Extension to add grey to AppTheme
extension AppThemeColors on AppTheme {
  static const Color grey = Color(0xFF9E9E9E);
}

class WorkflowDetailScreen extends StatefulWidget {
  const WorkflowDetailScreen({required this.workflow, super.key});
  final Workflow workflow;

  @override
  State<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends State<WorkflowDetailScreen> {
  late Workflow _currentWorkflow;

  @override
  void initState() {
    super.initState();
    _currentWorkflow = widget.workflow;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final workflowProvider = Provider.of<WorkflowProvider>(context);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view workflow details')),
      );
    }

    final permissions =
        workflowProvider.getWorkflowPermissions(currentUser, _currentWorkflow);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Workflow Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (permissions['canEdit'] ?? false)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditDialog(context),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'cancel':
                  await _cancelWorkflow(context);
                  break;
                case 'escalate':
                  await _escalateWorkflow(context);
                  break;
                case 'reassign':
                  await _reassignWorkflow(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (permissions['canCancel'] ?? false)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: AppTheme.red),
                      SizedBox(width: 8),
                      Text('Cancel Workflow'),
                    ],
                  ),
                ),
              if (permissions['canEscalate'] ?? false)
                const PopupMenuItem(
                  value: 'escalate',
                  child: Row(
                    children: [
                      Icon(Icons.arrow_upward, color: AppTheme.orange),
                      SizedBox(width: 8),
                      Text('Escalate'),
                    ],
                  ),
                ),
              if (permissions['canReassign'] ?? false)
                const PopupMenuItem(
                  value: 'reassign',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: AppTheme.blue),
                      SizedBox(width: 8),
                      Text('Reassign'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await workflowProvider.loadWorkflows();
          setState(() {
            _currentWorkflow = workflowProvider.workflows.firstWhere(
              (w) => w.id == _currentWorkflow.id,
              orElse: () => _currentWorkflow,
            );
          });
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              _buildHeaderCard(),
              const SizedBox(height: 16),

              // Status and metadata
              _buildMetadataCard(),
              const SizedBox(height: 16),

              // Description
              _buildSectionCard(
                title: 'Description',
                icon: Icons.description,
                child: Text(
                  _currentWorkflow.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),

              // Additional data
              if (_currentWorkflow.data.isNotEmpty) ...[
                _buildSectionCard(
                  title: 'Additional Information',
                  icon: Icons.info_outline,
                  child: _buildDataList(_currentWorkflow.data),
                ),
                const SizedBox(height: 16),
              ],

              // Approval chain
              if (_currentWorkflow.approvers.isNotEmpty ||
                  _currentWorkflow.currentApprover != null) ...[
                _buildApprovalChainCard(workflowProvider),
                const SizedBox(height: 16),
              ],

              // Approval history
              if (_currentWorkflow.approvalHistory.isNotEmpty) ...[
                _buildApprovalHistoryCard(),
                const SizedBox(height: 16),
              ],

              // Tags
              if (_currentWorkflow.tags.isNotEmpty) ...[
                _buildSectionCard(
                  title: 'Tags',
                  icon: Icons.local_offer,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _currentWorkflow.tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: AppTheme.blue.withOpacity(0.1),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.blue,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Escalation path
              if (_currentWorkflow.escalationPath.isNotEmpty) ...[
                _buildSectionCard(
                  title: 'Escalation History',
                  icon: Icons.warning_amber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _currentWorkflow.escalationPath
                        .asMap()
                        .entries
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.key + 1}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.orange,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: permissions['canApprove'] ??
              false && _currentWorkflow.status == WorkflowStatus.pendingApproval
          ? _buildApprovalActions(context)
          : null,
    );
  }

  Widget _buildHeaderCard() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentWorkflow.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(_currentWorkflow.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoRow(
                    Icons.category,
                    'Type',
                    _currentWorkflow.type.name,
                  ),
                  if (_currentWorkflow.priority != null)
                    _buildInfoRow(
                      Icons.flag,
                      'Priority',
                      _currentWorkflow.priority!,
                    ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildMetadataCard() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workflow Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.person,
                'Created By',
                _currentWorkflow.createdBy,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_today,
                'Created',
                DateFormat('MMM dd, yyyy HH:mm')
                    .format(_currentWorkflow.createdAt),
              ),
              if (_currentWorkflow.updatedAt != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.update,
                  'Updated',
                  DateFormat('MMM dd, yyyy HH:mm')
                      .format(_currentWorkflow.updatedAt!),
                ),
              ],
              if (_currentWorkflow.dueDate != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.schedule,
                  'Due Date',
                  DateFormat('MMM dd, yyyy HH:mm')
                      .format(_currentWorkflow.dueDate!),
                  valueColor:
                      _currentWorkflow.isOverdue ? AppTheme.red : AppTheme.blue,
                ),
              ],
              if (_currentWorkflow.assignedToUserId != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.person_outline,
                  'Assigned To',
                  '${_currentWorkflow.assignedToUserRole ?? 'User'} (ID: ${_currentWorkflow.assignedToUserId})',
                ),
              ],
              if (_currentWorkflow.completedAt != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.check_circle,
                  'Completed',
                  DateFormat('MMM dd, yyyy HH:mm')
                      .format(_currentWorkflow.completedAt!),
                  valueColor: AppTheme.green,
                ),
                if (_currentWorkflow.completedBy != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.person_pin,
                    'Completed By',
                    _currentWorkflow.completedBy!,
                  ),
                ],
              ],
              if (_currentWorkflow.rejectionReason != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.error,
                  'Rejection Reason',
                  _currentWorkflow.rejectionReason!,
                  valueColor: AppTheme.red,
                ),
              ],
              if (_currentWorkflow.cancellationReason != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.cancel,
                  'Cancellation Reason',
                  _currentWorkflow.cancellationReason!,
                  valueColor: AppThemeColors.grey,
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );

  Widget _buildDataList(Map<String, dynamic> data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildInfoRow(
                  Icons.chevron_right,
                  entry.key,
                  entry.value.toString(),
                ),
              ),
            )
            .toList(),
      );

  Widget _buildApprovalChainCard(WorkflowProvider workflowProvider) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: workflowProvider.getApprovalChain(_currentWorkflow),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final chain = snapshot.data!;
          if (chain.isEmpty) {
            return const SizedBox.shrink();
          }

          return _buildSectionCard(
            title: 'Approval Chain',
            icon: Icons.approval,
            child: Column(
              children: chain
                  .map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  '${step['step']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.blue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step['description'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Approver: ${step['role']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_currentWorkflow.currentApprover ==
                                step['role'])
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),)
                  .toList(),
            ),
          );
        },
      );

  Widget _buildApprovalHistoryCard() => _buildSectionCard(
        title: 'Approval History',
        icon: Icons.history,
        child: Column(
          children: _currentWorkflow.approvalHistory.reversed
              .map((approval) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          approval['action'] == 'approved'
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: approval['action'] == 'approved'
                              ? AppTheme.green
                              : AppTheme.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                approval['approverName'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                approval['action'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: approval['action'] == 'approved'
                                      ? AppTheme.green
                                      : AppTheme.red,
                                ),
                              ),
                              if (approval['reason'] != null)
                                Text(
                                  approval['reason'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              Text(
                                DateFormat('MMM dd, yyyy HH:mm').format(
                                  DateTime.parse(
                                      approval['timestamp'] as String,),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),)
              .toList(),
        ),
      );

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppThemeColors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      );

  Widget _buildStatusBadge(WorkflowStatus status) {
    Color color;
    String text;

    switch (status) {
      case WorkflowStatus.draft:
        color = AppThemeColors.grey;
        text = 'DRAFT';
        break;
      case WorkflowStatus.pending:
        color = AppTheme.orange;
        text = 'PENDING';
        break;
      case WorkflowStatus.inProgress:
        color = AppTheme.blue;
        text = 'IN PROGRESS';
        break;
      case WorkflowStatus.pendingApproval:
        color = AppTheme.orange;
        text = 'PENDING APPROVAL';
        break;
      case WorkflowStatus.approved:
        color = AppTheme.green;
        text = 'APPROVED';
        break;
      case WorkflowStatus.rejected:
        color = AppTheme.red;
        text = 'REJECTED';
        break;
      case WorkflowStatus.completed:
        color = AppTheme.green;
        text = 'COMPLETED';
        break;
      case WorkflowStatus.cancelled:
        color = AppThemeColors.grey;
        text = 'CANCELLED';
        break;
      case WorkflowStatus.escalated:
        color = AppTheme.purple;
        text = 'ESCALATED';
        break;
      case WorkflowStatus.onHold:
        color = AppTheme.orange;
        text = 'ON HOLD';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildApprovalActions(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkflowApprovalScreen(
                        workflow: _currentWorkflow,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Review & Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _cancelWorkflow(BuildContext context) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancellationReasonDialog(),
    );

    if (reason != null && reason.isNotEmpty && mounted) {
      final workflowProvider =
          Provider.of<WorkflowProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        await workflowProvider.cancelWorkflow(
          _currentWorkflow.id,
          authProvider.currentUser!,
          reason,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workflow cancelled successfully'),
              backgroundColor: AppTheme.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not cancel workflow. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkflowDetail: cancel',
          backgroundColor: AppTheme.red,
        );
        }
      }
    }
  }

  Future<void> _escalateWorkflow(BuildContext context) async {
    final workflowProvider =
        Provider.of<WorkflowProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate Workflow'),
        content: const Text(
          'This will escalate the workflow to the next level of management. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );

    if (confirm ?? false && mounted) {
      try {
        await workflowProvider.escalateWorkflow(
          _currentWorkflow.id,
          authProvider.currentUser!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workflow escalated successfully'),
              backgroundColor: AppTheme.green,
            ),
          );
        }
      } catch (e, st) {
        if (mounted) {
          showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not escalate workflow. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkflowDetail: escalate',
          backgroundColor: AppTheme.red,
        );
        }
      }
    }
  }

  Future<void> _reassignWorkflow(BuildContext context) async {
    // TODO: Implement reassign workflow dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reassign workflow - To be implemented'),
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    // TODO: Implement edit workflow dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit workflow - To be implemented'),
      ),
    );
  }
}

class _CancellationReasonDialog extends StatefulWidget {
  @override
  _CancellationReasonDialogState createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cancel Workflow'),
        content: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Cancellation Reason',
            hintText: 'Enter reason for cancellation...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      );
}
