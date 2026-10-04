// Workflow List Screen - Displays filtered workflow lists

import 'package:flutter/material.dart';
import 'package:cmms_core/models/workflow_models.dart';
import 'package:cmms_core/screens/workflows/create_workflow_screen.dart';
import 'package:cmms_core/screens/workflows/workflow_detail_screen.dart';
import 'package:cmms_core/services/workflow_service.dart';
import 'package:cmms_core/utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class WorkflowListScreen extends StatefulWidget {
  const WorkflowListScreen({super.key});

  @override
  State<WorkflowListScreen> createState() => _WorkflowListScreenState();
}

class _WorkflowListScreenState extends State<WorkflowListScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Workflow> _workflows = [];
  List<Workflow> _filteredWorkflows = [];
  bool _isLoading = true;
  String _searchQuery = '';
  WorkflowStatus? _statusFilter;
  WorkflowType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadWorkflows();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkflows() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workflows = await WorkflowService.getAllWorkflows();
      setState(() {
        _workflows = workflows;
        _filteredWorkflows = workflows;
        _isLoading = false;
      });
    } catch (e, st) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load workflows. Please try again.',
          stackTrace: st,
          contextLabel: 'WorkflowList: load',
          backgroundColor: AppTheme.red,
        );
      }
    }
  }

  void _filterWorkflows() {
    setState(() {
      _filteredWorkflows = _workflows.where((workflow) {
        final matchesSearch = _searchQuery.isEmpty ||
            workflow.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            workflow.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());

        final matchesStatus =
            _statusFilter == null || workflow.status == _statusFilter;
        final matchesType = _typeFilter == null || workflow.type == _typeFilter;

        return matchesSearch && matchesStatus && matchesType;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterWorkflows();
  }

  void _onStatusFilterChanged(WorkflowStatus? status) {
    setState(() {
      _statusFilter = status;
    });
    _filterWorkflows();
  }

  void _onTypeFilterChanged(WorkflowType? type) {
    setState(() {
      _typeFilter = type;
    });
    _filterWorkflows();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = null;
      _typeFilter = null;
    });
    _filterWorkflows();
  }

  List<Workflow> _getWorkflowsForTab(int index) {
    switch (index) {
      case 0: // All
        return _filteredWorkflows;
      case 1: // Pending
        return _filteredWorkflows
            .where((w) => w.status == WorkflowStatus.pending)
            .toList();
      case 2: // In Progress
        return _filteredWorkflows
            .where((w) => w.status == WorkflowStatus.inProgress)
            .toList();
      case 3: // Completed
        return _filteredWorkflows
            .where((w) => w.status == WorkflowStatus.completed)
            .toList();
      default:
        return _filteredWorkflows;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Workflows'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadWorkflows,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.white,
            labelColor: AppTheme.white,
            unselectedLabelColor: AppTheme.white.withValues(alpha: 0.7),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.white,
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search workflows...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _onSearchChanged(''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // Filter chips
            if (_statusFilter != null || _typeFilter != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (_statusFilter != null)
                      Chip(
                        label: Text('Status: ${_statusFilter!.name}'),
                        onDeleted: () => _onStatusFilterChanged(null),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      ),
                    if (_typeFilter != null)
                      Chip(
                        label: Text('Type: ${_typeFilter!.name}'),
                        onDeleted: () => _onTypeFilterChanged(null),
                        deleteIcon: const Icon(Icons.close, size: 18),
                      ),
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),

            // Workflow list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: List.generate(4, (index) {
                        final workflows = _getWorkflowsForTab(index);
                        return _buildWorkflowList(workflows);
                      }),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'workflow_list_fab',
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateWorkflowScreen(),
              ),
            );
            if (result == true) {
              _loadWorkflows();
            }
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.add, color: AppTheme.white),
        ),
      );

  Widget _buildWorkflowList(List<Workflow> workflows) {
    if (workflows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_tree,
              size: 64,
              color: AppTheme.lightGrey,
            ),
            SizedBox(height: 16),
            Text(
              'No workflows found',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.lightGrey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Create a new workflow to get started',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.lightGrey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkflows,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: workflows.length,
        itemBuilder: (context, index) {
          final workflow = workflows[index];
          return _buildWorkflowCard(workflow);
        },
      ),
    );
  }

  Widget _buildWorkflowCard(Workflow workflow) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkflowDetailScreen(workflow: workflow),
              ),
            );
            if (result == true) {
              _loadWorkflows();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        workflow.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    _buildStatusChip(workflow.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  workflow.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textColor.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _getWorkflowTypeIcon(workflow.type),
                      size: 16,
                      color: AppTheme.lightGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      workflow.type.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.lightGrey,
                      ),
                    ),
                    const Spacer(),
                    if (workflow.dueDate != null) ...[
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: _isOverdue(workflow.dueDate!)
                            ? AppTheme.red
                            : AppTheme.lightGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(workflow.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOverdue(workflow.dueDate!)
                              ? AppTheme.red
                              : AppTheme.lightGrey,
                        ),
                      ),
                    ],
                  ],
                ),
                if (workflow.steps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _getProgressValue(workflow),
                    backgroundColor: AppTheme.lightGrey.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(workflow.status),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_getCompletedStepsCount(workflow)}/${workflow.steps.length} steps completed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.lightGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildStatusChip(WorkflowStatus status) {
    Color backgroundColor;
    var textColor = AppTheme.white;

    switch (status) {
      case WorkflowStatus.draft:
        backgroundColor = AppTheme.lightGrey;
        textColor = AppTheme.textColor;
        break;
      case WorkflowStatus.pending:
        backgroundColor = AppTheme.orange;
        break;
      case WorkflowStatus.inProgress:
        backgroundColor = AppTheme.blue;
        break;
      case WorkflowStatus.pendingApproval:
        backgroundColor = AppTheme.orange;
        break;
      case WorkflowStatus.approved:
        backgroundColor = AppTheme.green;
        break;
      case WorkflowStatus.rejected:
        backgroundColor = AppTheme.red;
        break;
      case WorkflowStatus.onHold:
        backgroundColor = AppTheme.disabledColor;
        break;
      case WorkflowStatus.completed:
        backgroundColor = AppTheme.green;
        break;
      case WorkflowStatus.cancelled:
        backgroundColor = AppTheme.lightGrey;
        textColor = AppTheme.textColor;
        break;
      case WorkflowStatus.escalated:
        backgroundColor = AppTheme.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  IconData _getWorkflowTypeIcon(WorkflowType type) {
    switch (type) {
      case WorkflowType.workOrderApproval:
        return Icons.assignment;
      case WorkflowType.workOrderCompletion:
        return Icons.assignment_turned_in;
      case WorkflowType.partsRequest:
        return Icons.settings;
      case WorkflowType.purchaseOrder:
        return Icons.shopping_cart;
      case WorkflowType.assetLifecycle:
        return Icons.build;
      case WorkflowType.inventoryRequest:
        return Icons.inventory;
      case WorkflowType.qualityInspection:
        return Icons.verified;
      case WorkflowType.escalation:
        return Icons.priority_high;
      case WorkflowType.scheduling:
        return Icons.schedule;
      case WorkflowType.budgetApproval:
        return Icons.attach_money;
      case WorkflowType.userAccessRequest:
        return Icons.person_add;
    }
  }

  bool _isOverdue(DateTime dueDate) => dueDate.isBefore(DateTime.now());

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 0) {
      return 'In $difference days';
    } else {
      return '${-difference} days ago';
    }
  }

  double _getProgressValue(Workflow workflow) {
    if (workflow.steps.isEmpty) return 0;
    return _getCompletedStepsCount(workflow) / workflow.steps.length;
  }

  int _getCompletedStepsCount(Workflow workflow) => workflow.steps.values
      .where((step) => step.status == WorkflowStatus.completed)
      .length;

  Color _getProgressColor(WorkflowStatus status) {
    switch (status) {
      case WorkflowStatus.draft:
        return AppTheme.lightGrey;
      case WorkflowStatus.pending:
        return AppTheme.orange;
      case WorkflowStatus.inProgress:
        return AppTheme.blue;
      case WorkflowStatus.pendingApproval:
        return AppTheme.orange;
      case WorkflowStatus.approved:
        return AppTheme.green;
      case WorkflowStatus.rejected:
        return AppTheme.red;
      case WorkflowStatus.onHold:
        return AppTheme.disabledColor;
      case WorkflowStatus.completed:
        return AppTheme.green;
      case WorkflowStatus.cancelled:
        return AppTheme.lightGrey;
      case WorkflowStatus.escalated:
        return AppTheme.purple;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Workflows'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<WorkflowStatus?>(
              initialValue: _statusFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  child: Text('All Statuses'),
                ),
                ...WorkflowStatus.values.map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.name),
                  ),
                ),
              ],
              onChanged: _onStatusFilterChanged,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WorkflowType?>(
              initialValue: _typeFilter,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  child: Text('All Types'),
                ),
                ...WorkflowType.values.map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name),
                  ),
                ),
              ],
              onChanged: _onTypeFilterChanged,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearFilters();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
