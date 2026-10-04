// Create Workflow Screen - Form for building new workflows

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cmms_core/models/workflow_models.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/providers/workflow_provider.dart';
import 'package:cmms_core/utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

class CreateWorkflowScreen extends StatefulWidget {
  const CreateWorkflowScreen({super.key});

  @override
  State<CreateWorkflowScreen> createState() => _CreateWorkflowScreenState();
}

class _CreateWorkflowScreenState extends State<CreateWorkflowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  WorkflowType _selectedType = WorkflowType.workOrderApproval;
  String _selectedPriority = 'medium';
  String? _selectedCategory;
  DateTime? _dueDate;
  final List<WorkflowStepTemplate> _steps = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createWorkflow() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final workflowProvider =
          Provider.of<WorkflowProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final workflow = await workflowProvider.createWorkflow(
        creator: currentUser,
        type: _selectedType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        dueDate: _dueDate,
        data: _selectedCategory != null ? {'category': _selectedCategory} : {},
      );

      if (mounted) {
        if (workflow != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Workflow created successfully! Routing to approvers...',
              ),
              backgroundColor: AppTheme.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          throw Exception('Failed to create workflow');
        }
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not create workflow. Please try again.',
          stackTrace: st,
          contextLabel: 'CreateWorkflow: create',
          backgroundColor: AppTheme.red,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _dueDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _addStep() {
    showDialog(
      context: context,
      builder: (context) => _AddStepDialog(
        onStepAdded: (step) {
          setState(() {
            _steps.add(step);
          });
        },
      ),
    );
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      // Reorder steps
      for (var i = 0; i < _steps.length; i++) {
        _steps[i] = WorkflowStepTemplate(
          id: _steps[i].id,
          name: _steps[i].name,
          description: _steps[i].description,
          defaultAssignee: _steps[i].defaultAssignee,
          requiredApprovals: _steps[i].requiredApprovals,
          order: i + 1,
          defaultData: _steps[i].defaultData,
        );
      }
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final step = _steps.removeAt(oldIndex);
      _steps.insert(newIndex, step);

      // Reorder steps
      for (var i = 0; i < _steps.length; i++) {
        _steps[i] = WorkflowStepTemplate(
          id: _steps[i].id,
          name: _steps[i].name,
          description: _steps[i].description,
          defaultAssignee: _steps[i].defaultAssignee,
          requiredApprovals: _steps[i].requiredApprovals,
          order: i + 1,
          defaultData: _steps[i].defaultData,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Create Workflow'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.white,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _createWorkflow,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.white),
                      ),
                    )
                  : const Text(
                      'Create',
                      style: TextStyle(color: AppTheme.white),
                    ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBasicInfoCard(),
                const SizedBox(height: 16),
                _buildWorkflowTypeCard(),
                const SizedBox(height: 16),
                _buildDueDateCard(),
                const SizedBox(height: 16),
                _buildStepsCard(),
              ],
            ),
          ),
        ),
      );

  Widget _buildBasicInfoCard() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Basic Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter workflow title',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter workflow description',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  hintText: 'Enter category (optional)',
                ),
                onChanged: (value) {
                  _selectedCategory =
                      value.trim().isEmpty ? null : value.trim();
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildWorkflowTypeCard() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workflow Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WorkflowType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  border: OutlineInputBorder(),
                ),
                items: WorkflowType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(_getWorkflowTypeIcon(type)),
                            const SizedBox(width: 8),
                            Text(type.name),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildDueDateCard() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Due Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDueDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppTheme.lightGrey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _dueDate != null
                            ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year} ${_dueDate!.hour}:${_dueDate!.minute.toString().padLeft(2, '0')}'
                            : 'Select due date (optional)',
                        style: TextStyle(
                          color: _dueDate != null
                              ? AppTheme.textColor
                              : AppTheme.lightGrey,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.lightGrey,
                          ),
                          onPressed: () {
                            setState(() {
                              _dueDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildStepsCard() => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Workflow Steps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Step'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_steps.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 48,
                          color: AppTheme.lightGrey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No steps added yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.lightGrey,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add steps to define the workflow process',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.lightGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _steps.length,
                  onReorder: _reorderSteps,
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return Container(
                      key: ValueKey(step.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                step.order.toString(),
                                style: const TextStyle(
                                  color: AppTheme.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                                  step.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                                Text(
                                  step.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.lightGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.red),
                            onPressed: () => _removeStep(index),
                          ),
                          const Icon(
                            Icons.drag_handle,
                            color: AppTheme.lightGrey,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );

  IconData _getWorkflowTypeIcon(WorkflowType type) {
    switch (type) {
      case WorkflowType.workOrderApproval:
        return Icons.assignment;
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
      case WorkflowType.workOrderCompletion:
        return Icons.check_circle;
      case WorkflowType.partsRequest:
        return Icons.shopping_cart;
      case WorkflowType.purchaseOrder:
        return Icons.receipt;
      case WorkflowType.budgetApproval:
        return Icons.attach_money;
      case WorkflowType.userAccessRequest:
        return Icons.person_add;
    }
  }
}

class _AddStepDialog extends StatefulWidget {
  const _AddStepDialog({
    required this.onStepAdded,
  });
  final Function(WorkflowStepTemplate) onStepAdded;

  @override
  State<_AddStepDialog> createState() => _AddStepDialogState();
}

class _AddStepDialogState extends State<_AddStepDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _assigneeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _assigneeController.dispose();
    super.dispose();
  }

  void _addStep() {
    if (_formKey.currentState!.validate()) {
      final step = WorkflowStepTemplate(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        defaultAssignee: _assigneeController.text.trim().isEmpty
            ? null
            : _assigneeController.text.trim(),
        order: 1, // Will be updated when added to workflow
      );

      widget.onStepAdded(step);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add Workflow Step'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Step Name *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter step name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a step name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter step description',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _assigneeController,
                decoration: const InputDecoration(
                  labelText: 'Default Assignee',
                  border: OutlineInputBorder(),
                  hintText: 'Enter assignee (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addStep,
            child: const Text('Add Step'),
          ),
        ],
      );
}
