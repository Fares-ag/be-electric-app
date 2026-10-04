import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Quick Create actions from the technician shell app bar.
///
/// [canCreatePmTask] must align with backend `pm_tasks` INSERT RLS (admin/manager).
class QuickCreateMenuSheet extends StatelessWidget {
  const QuickCreateMenuSheet({
    super.key,
    required this.canCreatePmTask,
    required this.onCreateWorkOrder,
    required this.onCreatePmTask,
    required this.onScanQr,
  });

  final bool canCreatePmTask;
  final VoidCallback onCreateWorkOrder;
  final VoidCallback onCreatePmTask;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM,
                AppTheme.spacingL,
                AppTheme.spacingM,
                AppTheme.spacingS,
              ),
              child: Text(
                'Quick Create',
                style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.build_circle_outlined, color: AppTheme.accentGreen),
              title: const Text('Create Work Order'),
              subtitle: const Text('Report a new issue or maintenance need'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              onTap: onCreateWorkOrder,
            ),
            if (canCreatePmTask) ...[
              ListTile(
                leading: const Icon(Icons.schedule_outlined, color: AppTheme.accentOrange),
                title: const Text('Create PM Task'),
                subtitle: const Text('Schedule preventive maintenance'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingXS,
                ),
                onTap: onCreatePmTask,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: AppTheme.accentGreen),
              title: const Text('Scan QR Code'),
              subtitle: const Text('Scan asset QR to create task'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingXS,
              ),
              onTap: onScanQr,
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
        ),
      );
}
