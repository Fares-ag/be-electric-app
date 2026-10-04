import 'package:cmms_core/providers/pm_inbox_provider.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/screens/requestor/pm/requestor_pm_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_pm_occurrence_service.dart';
import '../helpers/requestor_pm_test_harness.dart';

void main() {
  group('RequestorPmDashboardScreen', () {
    testWidgets('shows unavailable message when PM occurrences are disabled', (
      tester,
    ) async {
      await pumpRequestorPmWidget(
        tester,
        pmService: FakePmOccurrenceService(enabled: false),
        user: sampleRequestorUser(),
        loadCompanyData: false,
        child: const RequestorPmDashboardScreen(),
      );

      expect(find.text('Preventive Maintenance'), findsOneWidget);
      expect(
        find.text('Preventive maintenance is not available yet.'),
        findsOneWidget,
      );
    });
  });
}
