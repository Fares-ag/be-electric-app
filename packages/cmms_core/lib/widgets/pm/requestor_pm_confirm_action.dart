import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pm_occurrence.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pm_occurrence_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/pm_work_item_display_status.dart';

/// Requestor acknowledgment control shown before scheduled PM execution.
class RequestorPmConfirmAction extends StatelessWidget {
  const RequestorPmConfirmAction({
    required this.occurrence,
    this.compact = false,
    super.key,
  });

  final PmOccurrence occurrence;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer2<PmOccurrenceProvider, AuthProvider>(
      builder: (context, pmOccurrences, auth, _) {
        final current = _resolveOccurrence(pmOccurrences);
        final displayStatus = normalizeOccurrenceDisplayStatus(current);

        if (!isPmWorkItemDisplayStatusOpen(displayStatus)) {
          return const SizedBox.shrink();
        }

        if (current.isRequestorConfirmed) {
          return _ConfirmedLabel(compact: compact);
        }

        final requestorId = auth.currentUser?.id;
        if (requestorId == null) {
          return const SizedBox.shrink();
        }

        final isBusy = pmOccurrences.isConfirming;

        if (compact) {
          return Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              key: Key('requestor_pm_confirm_${current.id}'),
              onPressed: isBusy
                  ? null
                  : () => _confirm(
                        context,
                        occurrenceId: current.id,
                        requestorId: requestorId,
                      ),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm'),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacingL),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: Key('requestor_pm_confirm_${current.id}'),
              onPressed: isBusy
                  ? null
                  : () => _confirm(
                        context,
                        occurrenceId: current.id,
                        requestorId: requestorId,
                      ),
              child: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm'),
            ),
          ),
        );
      },
    );
  }

  PmOccurrence _resolveOccurrence(PmOccurrenceProvider provider) {
    for (final item in provider.occurrences) {
      if (item.id == occurrence.id) {
        return item;
      }
    }
    return occurrence;
  }

  Future<void> _confirm(
    BuildContext context, {
    required String occurrenceId,
    required String requestorId,
  }) async {
    final pmOccurrences = context.read<PmOccurrenceProvider>();
    try {
      await pmOccurrences.confirmOccurrenceForRequestor(
        occurrenceId: occurrenceId,
        requestorId: requestorId,
      );
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not confirm PM: $error')),
      );
    }
  }
}

class _ConfirmedLabel extends StatelessWidget {
  const _ConfirmedLabel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(
          Icons.check_circle,
          size: compact ? 16 : 18,
          color: AppTheme.accentGreen,
        ),
        const SizedBox(width: AppTheme.spacingS),
        Text(
          'Confirmed',
          style: AppTheme.smallText.copyWith(
            color: AppTheme.accentGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (compact) {
      return Align(alignment: Alignment.centerRight, child: label);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacingL),
      child: label,
    );
  }
}
