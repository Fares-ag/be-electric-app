import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/pm_occurrence_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../widgets/pm/pm_inbox_list_body.dart';

/// Technician PM tab backed by the unified inbox provider.
class PmTechnicianInboxScreen extends StatelessWidget {
  const PmTechnicianInboxScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('PM Tasks'),
        ),
        body: PmInboxListBody(
          onRefresh: () => _refreshInbox(context),
        ),
      );

  Future<void> _refreshInbox(BuildContext context) async {
    final unifiedProvider =
        Provider.of<UnifiedDataProvider>(context, listen: false);
    final pmOccurrences =
        Provider.of<PmOccurrenceProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final technicianId = authProvider.currentUser?.id;

    await unifiedProvider.refreshAll();

    if (pmOccurrences.isEnabled && technicianId != null) {
      await pmOccurrences.refreshAssignedOccurrences(technicianId);
    }
  }
}
