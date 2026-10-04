import 'package:cmms_core/screens/requestor/pm/requestor_pm_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pm_occurrence_service.dart';
import '../helpers/requestor_pm_test_harness.dart';

void main() {
  testWidgets('debug dashboard tree', (tester) async {
    await pumpRequestorPmWidget(
      tester,
      pmService: FakePmOccurrenceService(
        enabled: true,
        queryResults: [sampleAuthorizedOccurrence()],
      ),
      assets: [sampleAuthorizedAsset()],
      user: sampleRequestorUser(),
      child: const RequestorPmDashboardScreen(),
    );

    print('Overview: ${find.text("Overview").evaluate().length}');
    print('Browse: ${find.text("Browse").evaluate().length}');
    print('Upcoming: ${find.text("Upcoming").evaluate().length}');
    print(
      'Shortcut key: ${find.byKey(const Key("requestor_pm_shortcut_upcoming")).evaluate().length}',
    );
    print('ListTiles: ${find.byType(ListTile).evaluate().length}');
    print('Cards: ${find.byType(Card).evaluate().length}');
    print('Spinner: ${find.byType(CircularProgressIndicator).evaluate().length}');
  });
}
