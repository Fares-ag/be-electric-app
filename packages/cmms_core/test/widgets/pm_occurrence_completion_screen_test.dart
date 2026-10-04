import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/screens/pm_tasks/pm_occurrence_completion_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_pm_occurrence_service.dart';

PmOccurrence _openOccurrence() => PmOccurrence.fromMap({
      'id': 'occ-1',
      'scheduleId': 'sched-1',
      'assetId': 'asset-1',
      'dueDate': DateTime.utc(2026, 6, 20),
      'status': 'pending',
      'schedule': {
        'id': 'sched-1',
        'taskName': 'Monthly filter PM',
        'frequency': 'monthly',
        'frequencyValue': 30,
        'scheduleStartDate': DateTime.utc(2026, 1, 1),
        'scheduleEndDate': DateTime.utc(2026, 12, 31),
      },
    });

Future<void> _pumpCompletionScreen(
  WidgetTester tester, {
  required PmOccurrenceProvider pmOccurrences,
  User? user,
}) async {
  final auth = AuthProvider();
  if (user != null) {
    auth.setUser(user);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<PmOccurrenceProvider>.value(value: pmOccurrences),
      ],
      child: MaterialApp(
        home: PmOccurrenceCompletionScreen(occurrence: _openOccurrence()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PmOccurrenceCompletionScreen', () {
    testWidgets('shows unavailable message when PM occurrences are disabled', (
      tester,
    ) async {
      final pmOccurrences = PmOccurrenceProvider(
        service: FakePmOccurrenceService(),
      );

      await _pumpCompletionScreen(tester, pmOccurrences: pmOccurrences);

      expect(find.text('Scheduled PM completion is not available yet.'),
          findsOneWidget);
      expect(find.byKey(const Key('pm_occurrence_completion_submit')),
          findsNothing);
    });

    testWidgets('submit success completes occurrence through provider', (
      tester,
    ) async {
      final service = FakePmOccurrenceService(enabled: true);
      final pmOccurrences = PmOccurrenceProvider(service: service);

      await _pumpCompletionScreen(
        tester,
        pmOccurrences: pmOccurrences,
        user: User(
          id: 'tech-1',
          email: 'tech@test.com',
          name: 'Taylor Tech',
          role: 'technician',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('pm_occurrence_completion_notes')),
        'Replaced filter',
      );
      await tester.tap(find.byKey(const Key('pm_occurrence_completion_submit')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(service.completeOccurrenceCalls, 1);
      expect(service.lastCompletionNotes, 'Replaced filter');
      expect(find.byType(PmOccurrenceCompletionScreen), findsNothing);
    });

    testWidgets('submit failure shows error snackbar', (tester) async {
      final service = FakePmOccurrenceService(
        enabled: true,
        completeError: Exception('Network error'),
      );
      final pmOccurrences = PmOccurrenceProvider(service: service);

      await _pumpCompletionScreen(
        tester,
        pmOccurrences: pmOccurrences,
        user: User(
          id: 'tech-1',
          email: 'tech@test.com',
          name: 'Taylor Tech',
          role: 'technician',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await tester.tap(find.byKey(const Key('pm_occurrence_completion_submit')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(service.completeOccurrenceCalls, 1);
      expect(
        find.text('Could not complete preventive maintenance. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
