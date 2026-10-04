import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../screens/settings/sync_queue_status_screen.dart';
import '../utils/app_theme.dart';
import '../utils/offline_service_access.dart';

/// Slim banner for technician shell: offline and/or pending sync count.
class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isOfflineModeEnabled) {
      return const SizedBox.shrink();
    }

    final connectivity = resolveConnectivityService();
    final queue = resolveSyncQueueService();

    return ListenableBuilder(
      listenable: Listenable.merge([connectivity, queue]),
      builder: (context, _) {
        final online = connectivity.isOnline;
        final pending = queue.pendingCount;
        final failed = queue.failedCount;
        final conflict = queue.lastConflictMessage;

        if (online && pending == 0 && failed == 0 && conflict == null) {
          return const SizedBox.shrink();
        }

        final Color bg;
        final String message;
        if (!online) {
          bg = Colors.orange.shade800;
          message = pending > 0
              ? 'Offline — $pending change${pending == 1 ? '' : 's'} will sync'
              : 'Offline — changes will sync when connected';
        } else if (failed > 0) {
          bg = Colors.red.shade700;
          message =
              '$failed sync failure${failed == 1 ? '' : 's'} — tap to review';
        } else if (conflict != null) {
          bg = Colors.blueGrey.shade700;
          message = conflict;
        } else {
          bg = AppTheme.accentGreen.withValues(alpha: 0.9);
          message =
              'Syncing $pending change${pending == 1 ? '' : 's'}…';
        }

        return Material(
          color: bg,
          child: InkWell(
            onTap: () {
              if (conflict != null) {
                queue.clearLastConflictMessage();
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SyncQueueStatusScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
              child: Row(
                children: [
                  Icon(
                    online ? Icons.cloud_sync : Icons.cloud_off,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (online && pending > 0)
                    TextButton(
                      onPressed: () => queue.processQueue(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sync now'),
                    ),
                  const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small chip for list rows with a local-only / pending work order.
class PendingSyncChip extends StatelessWidget {
  const PendingSyncChip({super.key, this.label = 'Pending sync'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade400),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.orange.shade900,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
