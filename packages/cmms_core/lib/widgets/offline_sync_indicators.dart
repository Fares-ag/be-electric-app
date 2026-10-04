import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/pm_task.dart';
import '../models/work_order.dart';
import '../providers/offline_sync_status_provider.dart';
import '../screens/settings/sync_queue_status_screen.dart';
import '../utils/app_theme.dart';
import '../utils/offline_service_access.dart';
import 'offline_sync_banner.dart';

/// Compact chip shown on list cards when a row has unsynced local changes.
class PendingSyncBadge extends StatelessWidget {
  const PendingSyncBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppTheme.accentOrange.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: compact ? 12 : 14,
              color: AppTheme.accentOrange,
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                'Pending sync',
                style: TextStyle(
                  color: AppTheme.accentOrange,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
}

/// App-wide banner for technician shell: offline mode and/or pending queue items.
///
/// Uses [OfflineSyncStatusProvider] for entity-aware messaging. Tap opens the
/// sync queue screen (same affordance as [OfflineSyncBanner]).
class OfflineSyncGlobalBanner extends StatelessWidget {
  const OfflineSyncGlobalBanner({super.key});

  void _openSyncQueue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SyncQueueStatusScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isOfflineModeEnabled) {
      return const SizedBox.shrink();
    }

    return Consumer<OfflineSyncStatusProvider>(
      builder: (context, sync, _) {
        if (!sync.showGlobalBanner) {
          return const OfflineSyncBanner();
        }

        final isOffline = sync.isOffline;
        final pending = sync.pendingOperationCount;
        final background = isOffline
            ? AppTheme.accentOrange.withValues(alpha: 0.12)
            : const Color(0xFFFFF8E1);
        final foreground =
            isOffline ? AppTheme.accentOrange : const Color(0xFFF57F17);

        return Material(
          color: background,
          elevation: 0,
          child: InkWell(
            onTap: () => _openSyncQueue(context),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: foreground.withValues(alpha: 0.22),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOffline ? Icons.cloud_off_rounded : Icons.sync_rounded,
                      color: foreground,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sync.globalBannerMessage,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (pending > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$pending pending',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (!isOffline && pending > 0)
                    TextButton(
                      onPressed: () =>
                          resolveOfflineQueueService().processQueue(),
                      style: TextButton.styleFrom(
                        foregroundColor: foreground,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Sync now'),
                    ),
                  Icon(Icons.chevron_right, color: foreground, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// App bar action showing pending sync count for technician shell.
class OfflineSyncAppBarIndicator extends StatelessWidget {
  const OfflineSyncAppBarIndicator({super.key, this.onDarkHeader = false});

  final bool onDarkHeader;

  @override
  Widget build(BuildContext context) =>
      Consumer<OfflineSyncStatusProvider>(
        builder: (context, sync, _) {
          if (!sync.showGlobalBanner) return const SizedBox.shrink();

          final pending = sync.pendingOperationCount;
          final tooltip = sync.globalBannerMessage;
          final idleColor = onDarkHeader
              ? Colors.white.withValues(alpha: 0.92)
              : AppTheme.secondaryTextColor;
          final offlineColor =
              onDarkHeader ? const Color(0xFFFFD699) : AppTheme.accentOrange;

          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: tooltip,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    sync.isOffline
                        ? Icons.cloud_off
                        : Icons.cloud_upload_outlined,
                    color: sync.isOffline ? offlineColor : idleColor,
                  ),
                  if (pending > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: offlineColor,
                          shape: BoxShape.circle,
                          border: onDarkHeader
                              ? Border.all(color: AppTheme.primaryColor)
                              : null,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          pending > 9 ? '9+' : '$pending',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: onDarkHeader
                                ? AppTheme.primaryColor
                                : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

/// Wraps a work-order card badge when that row is pending sync.
class WorkOrderPendingSyncBadge extends StatelessWidget {
  const WorkOrderPendingSyncBadge({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  Widget build(BuildContext context) =>
      Selector<OfflineSyncStatusProvider, bool>(
        selector: (_, sync) => sync.isWorkOrderPendingSync(workOrder),
        builder: (context, pending, _) =>
            pending ? const PendingSyncBadge(compact: true) : const SizedBox.shrink(),
      );
}

/// Wraps a PM-task card badge when that row is pending sync.
class PMTaskPendingSyncBadge extends StatelessWidget {
  const PMTaskPendingSyncBadge({required this.pmTask, super.key});

  final PMTask pmTask;

  @override
  Widget build(BuildContext context) =>
      Selector<OfflineSyncStatusProvider, bool>(
        selector: (_, sync) => sync.isPMTaskPendingSync(pmTask),
        builder: (context, pending, _) =>
            pending ? const PendingSyncBadge(compact: true) : const SizedBox.shrink(),
      );
}
