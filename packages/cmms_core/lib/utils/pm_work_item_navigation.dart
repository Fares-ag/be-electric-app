import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pm_work_item.dart';
import '../providers/auth_provider.dart';
import '../providers/pm_occurrence_provider.dart';
import '../providers/user_provider.dart';
import '../screens/pm_tasks/pm_occurrence_detail_screen.dart';
import '../screens/pm_tasks/pm_task_detail_screen.dart';
import '../screens/requestor/pm/requestor_pm_detail_screen.dart';

/// Central routing for unified [PmWorkItem] detail screens.
///
/// Keeps legacy vs occurrence branching in one place. Requestor routes are
/// always read-only; technician occurrence routes support completion.
class PmWorkItemNavigation {
  const PmWorkItemNavigation._();

  static void openTechnicianDetail(BuildContext context, PmWorkItem item) {
    openDetail(context, item, readOnly: false);
  }

  static void openRequestorDetail(BuildContext context, PmWorkItem item) {
    openDetail(context, item, readOnly: true);
  }

  static void openDetail(
    BuildContext context,
    PmWorkItem item, {
    required bool readOnly,
  }) {
    if (readOnly) {
      final auth = context.read<AuthProvider>();
      final users = context.read<UserProvider>();
      final pmOccurrences = context.read<PmOccurrenceProvider>();
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider<UserProvider>.value(value: users),
              ChangeNotifierProvider<PmOccurrenceProvider>.value(
                value: pmOccurrences,
              ),
            ],
            child: RequestorPmDetailScreen(item: item),
          ),
        ),
      );
      return;
    }

    if (item.isLegacy && item.legacyTask != null) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => PMTaskDetailScreen(pmTask: item.legacyTask!),
        ),
      );
      return;
    }

    if (item.isOccurrence && item.occurrence != null) {
      final users = context.read<UserProvider>();
      final pmOccurrences = context.read<PmOccurrenceProvider>();
      final auth = context.read<AuthProvider>();
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: users),
              ChangeNotifierProvider<PmOccurrenceProvider>.value(
                value: pmOccurrences,
              ),
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ],
            child: PmOccurrenceDetailScreen(occurrence: item.occurrence!),
          ),
        ),
      );
    }
  }
}
