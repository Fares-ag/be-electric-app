import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/offline_service_access.dart';

/// Lists pending / failed sync operations with Retry and Discard.
class SyncQueueStatusScreen extends StatelessWidget {
  const SyncQueueStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = resolveSyncQueueService();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Sync queue'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () => queue.processQueue(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: queue,
        builder: (context, _) {
          final ops = queue.getDisplayOperations();
          if (ops.isEmpty) {
            return const Center(
              child: Text('No pending sync operations'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            itemCount: ops.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingS),
            itemBuilder: (context, index) {
              final op = ops[index];
              final subtitle = [
                op.collection,
                op.typeName,
                if (op.failed) 'FAILED',
                if (op.retryCount > 0) 'retries ${op.retryCount}',
                if (op.localPhotoPaths.isNotEmpty)
                  '${op.localPhotoPaths.length} photo(s)',
              ].join(' · ');

              return Card(
                child: ListTile(
                  title: Text(op.id),
                  subtitle: Text(
                    [
                      subtitle,
                      if (op.error != null) op.error!,
                    ].join('\n'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: op.error != null,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (op.failed)
                        IconButton(
                          tooltip: 'Retry',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => queue.retryFailedOperation(op.id),
                        ),
                      IconButton(
                        tooltip: 'Discard',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => queue.discardOperation(op.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
