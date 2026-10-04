import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pm_task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';
import 'create_pm_task_screen.dart';
import 'pm_task_card_widget.dart';

/// Admin/manager legacy PM task list (`pm_tasks` table).
///
/// **Freeze policy:** maintenance-only. Technicians use [PmTechnicianInboxScreen]
/// (unified [PmWorkItem] inbox). Do not extend this screen for Option A features.
class PMTaskListScreen extends StatefulWidget {
  const PMTaskListScreen({
    super.key,
    this.isTechnicianView = false,
    this.initialStatusFilter,
    this.startDate,
    this.endDate,
  });
  final bool isTechnicianView;
  final PMTaskStatus? initialStatusFilter;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  State<PMTaskListScreen> createState() => _PMTaskListScreenState();
}

class _PMTaskListScreenState extends State<PMTaskListScreen> {
  // Filter state
  PMTaskStatus? _selectedStatusFilter;
  bool _showOverdueOnly = false;
  bool _showDueTodayOnly = false;
  bool _showDueSoonOnly = false;
  
  // Sort state
  String _sortBy = 'nextDueDate'; // 'nextDueDate', 'taskName', 'createdAt', 'frequency'
  bool _sortAscending = true; // true = ascending, false = descending

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter;
  }

  @override
  Widget build(BuildContext context) =>
      Consumer2<AuthProvider, UnifiedDataProvider>(
        builder: (context, authProvider, unifiedProvider, child) {
          // Get PM tasks based on user role and view mode
          List<PMTask> pmTasks;

          if (widget.isTechnicianView) {
            // Technician view: show only assigned PM tasks
            final currentUserId = authProvider.currentUser!.id;
            pmTasks = unifiedProvider.getPMTasksByTechnician(currentUserId);
          } else if (authProvider.currentUser?.role == 'requestor') {
            // Requestors typically don't see PM tasks, but show unassigned ones
            pmTasks = unifiedProvider.pmTasks
                .where(
                  (pt) =>
                      pt.assignedTechnicianIds.isEmpty,
                )
                .toList();
          } else if (authProvider.currentUser?.role == 'technician') {
            // Technician's main view: show assigned PM tasks OR unassigned ones they can pick up
            final currentUserId = authProvider.currentUser!.id;
            pmTasks = unifiedProvider.pmTasks
                .where(
                  (pt) =>
                      pt.hasTechnician(currentUserId) ||
                      pt.assignedTechnicianIds.isEmpty,
                )
                .toList();
          } else {
            // Manager/Admin view: show all PM tasks
            pmTasks = unifiedProvider.pmTasks;
          }

          // Apply deep-link filters if provided
          if (widget.startDate != null || widget.endDate != null) {
            final start = widget.startDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final end = widget.endDate ?? DateTime.now();
            pmTasks = pmTasks.where((t) {
              final dt = t.updatedAt ?? t.createdAt;
              return (dt.isAfter(start) || dt.isAtSameMomentAs(start)) &&
                  (dt.isBefore(end) || dt.isAtSameMomentAs(end));
            }).toList();
          }

          // Apply UI filters - optimized: combine all filters in single where clause
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final todayEnd = todayStart.add(const Duration(days: 1));
          final soonDate = now.add(const Duration(days: 7));
          
          pmTasks = pmTasks.where((t) {
            // Status filter
            if (_selectedStatusFilter != null && t.status != _selectedStatusFilter) {
              return false;
            }
            // Overdue filter
            if (_showOverdueOnly) {
              if (t.nextDueDate == null ||
                  !t.nextDueDate!.isBefore(now) ||
                  t.status == PMTaskStatus.completed ||
                  t.status == PMTaskStatus.cancelled) {
                return false;
              }
            }
            // Due today filter
            if (_showDueTodayOnly) {
              if (t.nextDueDate == null ||
                  !t.nextDueDate!.isAfter(todayStart) ||
                  !t.nextDueDate!.isBefore(todayEnd)) {
                return false;
              }
            }
            // Due soon filter
            if (_showDueSoonOnly) {
              if (t.nextDueDate == null ||
                  !t.nextDueDate!.isAfter(now) ||
                  !t.nextDueDate!.isBefore(soonDate) ||
                  t.status == PMTaskStatus.completed ||
                  t.status == PMTaskStatus.cancelled) {
                return false;
              }
            }
            return true;
          }).toList();

          // Apply sorting
          pmTasks = _sortPMTasks(pmTasks);

          return Scaffold(
            appBar: AppBar(
              title: const Text('PM Tasks'),
              actions: [
                // Add Create PM Task button for admins
                if (!widget.isTechnicianView && authProvider.isManager)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreatePMTaskScreen(),
                        ),
                      );
                      if (result == true) {
                        // Refresh data from unified provider
                        await unifiedProvider.refreshAll();
                      }
                    },
                    tooltip: 'Create PM Task',
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                  onSelected: (value) {
                    setState(() {
                      if (value == 'all') {
                        _selectedStatusFilter = null;
                        _showOverdueOnly = false;
                        _showDueTodayOnly = false;
                        _showDueSoonOnly = false;
                      } else if (value == 'overdue') {
                        _showOverdueOnly = true;
                        _showDueTodayOnly = false;
                        _showDueSoonOnly = false;
                        _selectedStatusFilter = null;
                      } else if (value == 'dueToday') {
                        _showDueTodayOnly = true;
                        _showOverdueOnly = false;
                        _showDueSoonOnly = false;
                        _selectedStatusFilter = null;
                      } else if (value == 'dueSoon') {
                        _showDueSoonOnly = true;
                        _showOverdueOnly = false;
                        _showDueTodayOnly = false;
                        _selectedStatusFilter = null;
                      } else if (value == 'pending') {
                        _selectedStatusFilter = PMTaskStatus.pending;
                        _showOverdueOnly = false;
                        _showDueTodayOnly = false;
                        _showDueSoonOnly = false;
                      } else if (value == 'inProgress') {
                        _selectedStatusFilter = PMTaskStatus.inProgress;
                        _showOverdueOnly = false;
                        _showDueTodayOnly = false;
                        _showDueSoonOnly = false;
                      } else if (value == 'completed') {
                        _selectedStatusFilter = PMTaskStatus.completed;
                        _showOverdueOnly = false;
                        _showDueTodayOnly = false;
                        _showDueSoonOnly = false;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(
                            _selectedStatusFilter == null &&
                                    !_showOverdueOnly &&
                                    !_showDueTodayOnly &&
                                    !_showDueSoonOnly
                                ? Icons.check
                                : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('All'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'overdue',
                      child: Text('Overdue'),
                    ),
                    const PopupMenuItem(
                      value: 'dueToday',
                      child: Text('Due Today'),
                    ),
                    const PopupMenuItem(
                      value: 'dueSoon',
                      child: Text('Due Soon'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    const PopupMenuItem(
                      value: 'inProgress',
                      child: Text('In Progress'),
                    ),
                    const PopupMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort',
                  onSelected: (value) {
                    setState(() {
                      if (_sortBy == value) {
                        // Toggle sort direction if same field selected
                        _sortAscending = !_sortAscending;
                      } else {
                        // New field selected
                        _sortBy = value;
                        // Default sort direction based on field
                        _sortAscending = value == 'nextDueDate' || value == 'createdAt';
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'nextDueDate',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'nextDueDate' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Due Date'),
                          if (_sortBy == 'nextDueDate')
                            Icon(
                              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'taskName',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'taskName' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Name'),
                          if (_sortBy == 'taskName')
                            Icon(
                              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'createdAt',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'createdAt' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Created Date'),
                          if (_sortBy == 'createdAt')
                            Icon(
                              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'frequency',
                      child: Row(
                        children: [
                          Icon(
                            _sortBy == 'frequency' ? Icons.check : null,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text('Frequency'),
                          if (_sortBy == 'frequency')
                            Icon(
                              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                await unifiedProvider.refreshAll();
              },
              child: unifiedProvider.isPMTasksLoading
                  ? const Center(child: CircularProgressIndicator())
                  : pmTasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: ResponsiveLayout.getResponsivePadding(context),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 64,
                                  color: AppTheme.secondaryTextColor,
                                ),
                                const SizedBox(height: AppTheme.spacingM),
                                Text(
                                  'No PM tasks found',
                                  style: AppTheme.bodyText.copyWith(
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            left: ResponsiveLayout.getResponsivePadding(context).left,
                            right: ResponsiveLayout.getResponsivePadding(context).right,
                            top: ResponsiveLayout.getResponsivePadding(context).top,
                            bottom: ResponsiveLayout.getResponsivePadding(context).bottom +
                                56 +
                                MediaQuery.of(context).padding.bottom,
                          ),
                          itemCount: pmTasks.length,
                          itemBuilder: (context, index) {
                            final task = pmTasks[index];
                            return PMTaskCardWidget(task: task);
                          },
                        ),
            ),
            // Add floating action button for admins
            floatingActionButton:
                !widget.isTechnicianView && authProvider.isManager
                    ? FloatingActionButton(
                        heroTag: 'pm_task_list_fab',
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreatePMTaskScreen(),
                            ),
                          );
                          if (result == true) {
                            await unifiedProvider.refreshAll();
                          }
                        },
                        backgroundColor: AppTheme.accentBlue,
                        tooltip: 'Create PM Task',
                        child: const Icon(Icons.add, color: Colors.white),
                      )
                    : null,
          );
        },
      );

  List<PMTask> _sortPMTasks(List<PMTask> pmTasks) {
    final sorted = List<PMTask>.from(pmTasks);
    
    sorted.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'nextDueDate':
          // Handle null due dates (put them at the end)
          if (a.nextDueDate == null && b.nextDueDate == null) {
            comparison = 0;
          } else if (a.nextDueDate == null) {
            comparison = 1; // a goes to end
          } else if (b.nextDueDate == null) {
            comparison = -1; // b goes to end
          } else {
            comparison = a.nextDueDate!.compareTo(b.nextDueDate!);
          }
          break;
        case 'taskName':
          comparison = a.taskName.compareTo(b.taskName);
          break;
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'frequency':
          // Frequency order: daily > weekly > monthly > quarterly > semiAnnually > annually > asNeeded
          final frequencyOrder = {
            PMTaskFrequency.daily: 1,
            PMTaskFrequency.weekly: 2,
            PMTaskFrequency.monthly: 3,
            PMTaskFrequency.quarterly: 4,
            PMTaskFrequency.semiAnnually: 5,
            PMTaskFrequency.annually: 6,
            PMTaskFrequency.asNeeded: 7,
          };
          comparison = (frequencyOrder[a.frequency] ?? 0)
              .compareTo(frequencyOrder[b.frequency] ?? 0);
          break;
        default:
          // Default to due date
          if (a.nextDueDate == null && b.nextDueDate == null) {
            comparison = 0;
          } else if (a.nextDueDate == null) {
            comparison = 1;
          } else if (b.nextDueDate == null) {
            comparison = -1;
          } else {
            comparison = a.nextDueDate!.compareTo(b.nextDueDate!);
          }
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return sorted;
  }
}
