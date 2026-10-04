import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/unified_data_provider.dart';
import '../utils/app_theme.dart';
import '../utils/user_facing_errors.dart';

class TechnicianAssignmentDialog extends StatefulWidget {
  const TechnicianAssignmentDialog({
    required this.workOrderId,
    this.currentTechnicianId,
    this.currentTechnicianIds,
    super.key,
  });

  final String workOrderId;
  final String? currentTechnicianId;
  final List<String>? currentTechnicianIds;

  @override
  State<TechnicianAssignmentDialog> createState() =>
      _TechnicianAssignmentDialogState();
}

class _TechnicianAssignmentDialogState
    extends State<TechnicianAssignmentDialog> {
  bool _isLoading = false;
  List<User> _technicians = [];
  final Set<String> _selectedTechnicianIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadTechnicians();
  }

  Future<void> _loadTechnicians() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use unified data provider for consistent data
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);

      // Get technicians from unified provider
      _technicians = unifiedProvider.getTechnicians();

      debugPrint(
        'Found ${_technicians.length} technicians from unified provider',
      );

      final seededIds = widget.currentTechnicianIds ??
          (widget.currentTechnicianId != null
              ? <String>[widget.currentTechnicianId!]
              : const <String>[]);
      _selectedTechnicianIds
        ..clear()
        ..addAll(seededIds.where((id) => id.isNotEmpty));

      // Show debug info if no technicians found
      if (_technicians.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No technicians found. Please create technicians in User Management.',
            ),
            backgroundColor: AppTheme.accentBlue,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error loading technicians: $e');
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load technicians. Please try again.',
          stackTrace: st,
          contextLabel: 'TechnicianAssignment: load',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAssignments() async {
    // Enforce role gating: only managers/admins can assign
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAllowed =
        authProvider.isManager || (authProvider.currentUser?.isAdmin ?? false);
    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only managers or admins can assign technicians'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      await unifiedProvider.updateWorkOrderTechnicians(
        widget.workOrderId,
        _selectedTechnicianIds.toList(),
      );

      if (mounted) {
        final selectedLabel = _selectedTechnicianIds.isEmpty
            ? 'No technicians'
            : '${_selectedTechnicianIds.length} technician${_selectedTechnicianIds.length == 1 ? '' : 's'}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order updated ($selectedLabel)'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update technicians. Please try again.',
          stackTrace: st,
          contextLabel: 'TechnicianAssignment: update',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unassignTechnician() async {
    // Enforce role gating: only managers/admins can unassign
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAllowed =
        authProvider.isManager || (authProvider.currentUser?.isAdmin ?? false);
    if (!isAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only managers or admins can unassign technicians'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      await unifiedProvider.unassignTechnicianFromWorkOrder(widget.workOrderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Technician unassigned successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not unassign technician. Please try again.',
          stackTrace: st,
          contextLabel: 'technician_assignment_dialog: Could not unassign technician.',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.accentBlue),
            SizedBox(width: AppTheme.spacingS),
            Text('Assign Technician'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select one or more technicians. Each selected technician receives the full recorded labor time for this work order.',
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.darkTextColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Wrap(
                      spacing: AppTheme.spacingS,
                      runSpacing: AppTheme.spacingS,
                      children: _technicians
                          .map((tech) => _TechnicianChip(
                                technician: tech,
                                selected:
                                    _selectedTechnicianIds.contains(tech.id),
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedTechnicianIds.add(tech.id);
                                    } else {
                                      _selectedTechnicianIds.remove(tech.id);
                                    }
                                  });
                                },
                              ),)
                          .toList(),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    if (_selectedTechnicianIds.isEmpty) Text(
                            'No technicians selected',
                            style: AppTheme.smallText.copyWith(
                              color: AppTheme.secondaryTextColor,
                            ),
                          ) else Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected technicians (${_selectedTechnicianIds.length}):',
                                style: AppTheme.smallText.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkTextColor,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              Text(
                                _technicians
                                    .where((tech) =>
                                        _selectedTechnicianIds.contains(tech.id))
                                    .map((tech) => tech.name)
                                    .join(', '),
                                style: AppTheme.smallText.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                    if ((widget.currentTechnicianIds?.isNotEmpty ??
                            false) ||
                        widget.currentTechnicianId != null) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(
                            color: AppTheme.accentOrange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppTheme.accentOrange,
                              size: 20,
                            ),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                'This work order already has assigned technicians. Add or remove people below, or clear the roster entirely.',
                                style: AppTheme.smallText.copyWith(
                                  color: AppTheme.accentOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        actions: [
          if ((widget.currentTechnicianIds?.isNotEmpty ?? false) ||
              widget.currentTechnicianId != null)
            TextButton.icon(
              onPressed: _isLoading ? null : _unassignTechnician,
              icon: const Icon(Icons.person_remove, color: AppTheme.errorColor),
              label: const Text('Unassign'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed:
                _isLoading ? null : () => setState(_selectedTechnicianIds.clear),
            child: const Text('Clear Selection'),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveAssignments,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isLoading ? 'Saving...' : 'Save Assignments'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
}

class _TechnicianChip extends StatelessWidget {
  const _TechnicianChip({
    required this.technician,
    required this.selected,
    required this.onSelected,
  });

  final User technician;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
        selected: selected,
        showCheckmark: true,
        elevation: selected ? 2 : 0,
        pressElevation: 0,
        onSelected: onSelected,
        label: SizedBox(
          width: 160,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.accentBlue,
                child: Text(
                  technician.name.isNotEmpty ? technician.name.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      technician.name,
                      style: AppTheme.smallText.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      technician.email,
                      style: AppTheme.smallText.copyWith(
                        color: AppTheme.secondaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
