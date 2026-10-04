import 'package:cmms_core/models/pm_work_item.dart';
import 'package:cmms_core/screens/pm_tasks/pm_occurrence_detail_screen.dart';
import 'package:cmms_core/screens/requestor/pm/requestor_pm_dashboard_screen.dart';
import 'package:cmms_core/screens/requestor/pm/requestor_pm_detail_screen.dart';
import 'package:cmms_core/screens/requestor/pm/requestor_pm_list_screen.dart';
import 'package:cmms_core/screens/requestor/pm/requestor_pm_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

      expect(find.text('Preventive maintenance is not available yet.'),
          findsOneWidget);
    });

    testWidgets('shows shortcuts and scoped counts when enabled', (tester) async {
      await pumpRequestorPmWidget(
        tester,
        pmService: FakePmOccurrenceService(
          enabled: true,
          queryResults: [
            sampleAuthorizedOccurrence(),
            sampleAuthorizedOccurrence(
              id: 'occ-2',
              assetId: 'asset-2',
              taskName: 'Filter PM',
            ),
          ],
        ),
        assets: [
          sampleAuthorizedAsset(),
          sampleAuthorizedAsset(id: 'asset-2'),
        ],
        user: sampleRequestorUser(),
        child: const RequestorPmDashboardScreen(),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.byKey(const Key('requestor_pm_shortcut_upcoming')),
          findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });
  });

  group('RequestorPmListScreen', () {
    testWidgets('shows only authorized asset items', (tester) async {
      await pumpRequestorPmWidget(
        tester,
        pmService: FakePmOccurrenceService(
          enabled: true,
          queryResults: [
            sampleAuthorizedOccurrence(),
            sampleAuthorizedOccurrence(
              id: 'occ-other',
              assetId: 'asset-other',
              taskName: 'Other company PM',
            ),
          ],
        ),
        assets: [sampleAuthorizedAsset()],
        user: sampleRequestorUser(),
        child: const RequestorPmListScreen(mode: RequestorPmListMode.upcoming),
      );

      expect(find.text('Quarterly inspection'), findsOneWidget);
      expect(find.text('Other company PM'), findsNothing);
    });

    testWidgets('does not expose completion controls', (tester) async {
      await pumpRequestorPmWidget(
        tester,
        pmService: FakePmOccurrenceService(
          enabled: true,
          queryResults: [sampleAuthorizedOccurrence()],
        ),
        assets: [sampleAuthorizedAsset()],
        user: sampleRequestorUser(),
        loadCompanyData: false,
        child: RequestorPmDetailScreen(
          item: PmWorkItem.fromOccurrence(
            sampleAuthorizedOccurrence(),
            referenceDate: DateTime.utc(2026, 6, 25),
          ),
        ),
      );

      expect(find.byKey(const Key('pm_occurrence_complete_button')),
          findsNothing);
      expect(find.byKey(const Key('pm_occurrence_completion_submit')),
          findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(find.byKey(const Key('requestor_pm_confirm_occ-1')), findsOneWidget);
    });

    testWidgets('shows Confirm on list cards and records acknowledgment', (
      tester,
    ) async {
      final pmService = FakePmOccurrenceService(
        enabled: true,
        queryResults: [sampleAuthorizedOccurrence()],
      );

      await pumpRequestorPmWidget(
        tester,
        pmService: pmService,
        assets: [sampleAuthorizedAsset()],
        user: sampleRequestorUser(),
        child: const RequestorPmListScreen(mode: RequestorPmListMode.upcoming),
      );

      expect(find.byKey(const Key('requestor_pm_confirm_occ-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('requestor_pm_confirm_occ-1')));
      await tester.pumpAndSettle();

      expect(pmService.confirmOccurrenceForRequestorCalls, 1);
      expect(pmService.lastConfirmedOccurrenceId, 'occ-1');
      expect(pmService.lastConfirmedRequestorId, 'requestor-1');
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
    });
  });

  group('Requestor PM navigation', () {
    testWidgets('dashboard shortcut opens list screen', (tester) async {
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

      final upcomingShortcut =
          find.byKey(const Key('requestor_pm_shortcut_upcoming'));
      await tester.ensureVisible(upcomingShortcut);
      await tester.tap(upcomingShortcut);
      await tester.pumpAndSettle();

      expect(find.byType(RequestorPmListScreen), findsOneWidget);
      expect(find.text('Upcoming PM'), findsOneWidget);
    });

    testWidgets('list item opens read-only detail wrapper', (tester) async {
      await pumpRequestorPmWidget(
        tester,
        pmService: FakePmOccurrenceService(
          enabled: true,
          queryResults: [sampleAuthorizedOccurrence()],
        ),
        assets: [sampleAuthorizedAsset()],
        user: sampleRequestorUser(),
        child: const RequestorPmListScreen(mode: RequestorPmListMode.upcoming),
      );

      await tester.tap(find.text('Quarterly inspection'));
      await tester.pumpAndSettle();

      expect(find.byType(RequestorPmDetailScreen), findsOneWidget);
      expect(find.byType(PmOccurrenceDetailScreen), findsOneWidget);
      expect(find.text('Preventive Maintenance'), findsOneWidget);
    });
  });

  group('RequestorPmMainScreen alias', () {
    testWidgets('deprecated alias renders dashboard', (tester) async {
      await pumpRequestorPmWidget(
        tester,
        pmService: FakePmOccurrenceService(enabled: false),
        user: sampleRequestorUser(),
        loadCompanyData: false,
        child: const RequestorPmMainScreen(),
      );

      expect(find.byType(RequestorPmDashboardScreen), findsOneWidget);
    });
  });
}
