// Workflow Approval Screen - Manage approvals for workflows

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user.dart';
import '../../models/workflow_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

// Extension to add grey to AppTheme
extension AppThemeColors on AppTheme {
  static const Color grey = Color(0xFF9E9E9E);
}

class WorkflowApprovalScreen extends StatefulWidget {
  const WorkflowApprovalScreen({required this.workflow, super.key});
  final Workflow workflow;

  @override
  State<WorkflowApprovalScreen> createState() => _WorkflowApprovalScreenState();
}

class _WorkflowApprovalScreenState extends State<WorkflowApprovalScreen> {
  final _reasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final workflowProvider = Provider.of<WorkflowProvider>(context);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to approve workflows')),
      );
    }

    final canApprove =
        workflowProvider.canApprove(currentUser, widget.workflow);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Review Workflow'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission check
            if (!canApprove)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.red),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You do not have permission to approve this workflow.',
                        style: TextStyle(color: AppTheme.red),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Workflow summary card
            _buildWorkflowSummaryCard(),
            const SizedBox(height: 16),

            // Workflow details
            _buildWorkflowDetailsCard(),
            const SizedBox(height: 16),

            // Additional data
            if (widget.workflow.data.isNotEmpty) ...[
              _buildDataCard(),
              const SizedBox(height: 16),
            ],

            // Approval chain progress
            _buildApprovalChainCard(workflowProvider),
            const SizedBox(height: 16),

            // Previous approvals
            if (widget.workflow.approvalHistory.isNotEmpty) ...[
              _buildApprovalHistoryCard(),
              const SizedBox(height: 16),
            ],

            // Approval reason/comments
            _buildReasonCard(),
            const SizedBox(height: 80), // Space for bottom buttons
          ],
        ),
      ),
      bottomNavigationBar: canApprove
          ? _buildApprovalActions(context, currentUser, workflowProvider)
          : null,
    );
  }

  Widget _buildWorkflowSummaryCard() => Card(
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
                      widget.workflow.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(widget.workflow.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.workflow.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildWorkflowDetailsCard() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workflow Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Type',
                widget.workflow.type.name,
                Icons.category,
              ),
              if (widget.workflow.priority != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Priority',
                  widget.workflow.priority!,
                  Icons.flag,
                  valueColor: _getPriorityColor(widget.workflow.priority!),
                ),
              ],
              const SizedBox(height: 8),
              _buildDetailRow(
                'Created By',
                widget.workflow.createdBy,
                Icons.person,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Created',
                DateFormat('MMM dd, yyyy HH:mm')
                    .format(widget.workflow.createdAt),
                Icons.calendar_today,
              ),
              if (widget.workflow.dueDate != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Due Date',
                  DateFormat('MMM dd, yyyy HH:mm')
                      .format(widget.workflow.dueDate!),
                  Icons.schedule,
                  valueColor:
                      widget.workflow.isOverdue ? AppTheme.red : AppTheme.blue,
                ),
              ],
            ],
          ),
        ),
      );

  Widget _buildDataCard() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppTheme.blue),
                  SizedBox(width: 8),
                  Text(
                    'Additional Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...widget.workflow.data.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildDetailRow(
                    entry.key,
                    entry.value.toString(),
                    Icons.chevron_right,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildApprovalChainCard(WorkflowProvider workflowProvider) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: workflowProvider.getApprovalChain(widget.workflow),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final chain = snapshot.data!;
          if (chain.isEmpty) {
            return const SizedBox.shrink();
          }

          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.approval, size: 20, color: AppTheme.blue),
                      SizedBox(width: 8),
                      Text(
                        'Approval Chain',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...chain.map((step) {
                    final isCurrentStep =
                        widget.workflow.currentApprover == step['role'];
                    final stepNumber = step['step'] as int;
                    final isCompleted = widget.workflow.approvalHistory.any(
                        (h) =>
                            h['approverRole'] == step['role'] &&
                            h['action'] == 'approved',);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppTheme.green
                                  : isCurrentStep
                                      ? AppTheme.orange
                                      : AppThemeColors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : Text(
                                      '$stepNumber',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentStep
                                            ? Colors.white
                                            : AppThemeColors.grey,
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
                                  style: TextStyle(
                                    fontWeight: isCurrentStep
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCurrentStep
                                        ? Colors.black
                                        : AppThemeColors.grey,
                                  ),
                                ),
                                Text(
                                  'Approver: ${step['role']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrentStep)
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
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildApprovalHistoryCard() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history, size: 20, color: AppTheme.blue),
                  SizedBox(width: 8),
                  Text(
                    'Previous Approvals',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...widget.workflow.approvalHistory.reversed.map(
                (approval) => Padding(
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
                                DateTime.parse(approval['timestamp'] as String),
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
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildReasonCard() => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.comment, size: 20, color: AppTheme.blue),
                  SizedBox(width: 8),
                  Text(
                    'Comments (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Add comments or reason for your decision...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      );

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
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

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
      case 'urgent':
        return AppTheme.accentRed;
      case 'high':
        return AppTheme.accentOrange;
      case 'medium':
        return AppTheme.accentBlue;
      case 'low':
        return AppTheme.secondaryTextColor;
      default:
        return AppTheme.secondaryTextColor;
    }
  }

  Widget _buildApprovalActions(
    BuildContext context,
    User currentUser,
    WorkflowProvider workflowProvider,
  ) =>
      Container(
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
              child: OutlinedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () =>
                        _rejectWorkflow(context, currentUser, workflowProvider),
                icon: const Icon(Icons.cancel),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.red),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _approveWorkflow(
                        context, currentUser, workflowProvider,),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isProcessing ? 'Processing...' : 'Approve'),
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

  Future<void> _approveWorkflow(
    BuildContext context,
    User currentUser,
    WorkflowProvider workflowProvider,
  ) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await workflowProvider.approveWorkflow(
        widget.workflow.id,
        currentUser,
        _reasonController.text.isEmpty ? null : _reasonController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workflow approved successfully'),
            backgroundColor: AppTheme.green,
          ),
        );
        Navigator.pop(context);
        Navigator.pop(context); // Go back to list
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not approve workflow. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkflowApproval: approve',
          backgroundColor: AppTheme.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rejectWorkflow(
    BuildContext context,
    User currentUser,
    WorkflowProvider workflowProvider,
  ) async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for rejection'),
          backgroundColor: AppTheme.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await workflowProvider.rejectWorkflow(
        widget.workflow.id,
        currentUser,
        _reasonController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workflow rejected'),
            backgroundColor: AppTheme.orange,
          ),
        );
        Navigator.pop(context);
        Navigator.pop(context); // Go back to list
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not reject workflow. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkflowApproval: reject',
          backgroundColor: AppTheme.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
