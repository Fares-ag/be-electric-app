import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/providers/user_provider.dart';
import 'package:cmms_core/screens/pm_tasks/pm_occurrence_detail_screen.dart';
import 'package:cmms_core/services/unified_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _UsersStubDataService extends UnifiedDataService {
  _UsersStubDataService(this.stubUsers);

  final List<User> stubUsers;

  @override
  List<User> get users => stubUsers;
}

PmOccurrence _detailOccurrence() => PmOccurrence.fromMap({
      'id': 'occ-1',
      'scheduleId': 'sched-1',
      'assetId': 'asset-1',
      'dueDate': DateTime.utc(2026, 6, 20),
      'status': 'completed',
      'assignedTechnicianIds': const ['tech-1'],
      'completedAt': DateTime.utc(2026, 6, 18, 14, 30),
      'completionNotes': 'Filter replaced and tested.',
      'schedule': {
        'id': 'sched-1',
        'taskName': 'Monthly filter PM',
        'description': 'Inspect and replace filters.',
        'frequency': 'monthly',
        'frequencyValue': 30,
        'scheduleStartDate': DateTime.utc(2026, 1, 1),
        'scheduleEndDate': DateTime.utc(2026, 12, 31),
        'metadata': {
          'checklist': ['Inspect housing', 'Replace filter'],
        },
      },
      'asset': {
        'name': 'Charger A12',
        'location': 'Bay 3',
        'manufacturer': 'ABB',
        'model': 'Terra 184',
        'serialNumber': 'SN-001',
      },
    });

Future<void> _pumpDetail(
  WidgetTester tester, {
  required PmOccurrence occurrence,
  bool readOnly = false,
  List<User> users = const [],
}) async {
  final usersProvider = UserProvider(
    dataService: _UsersStubDataService(users),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<UserProvider>.value(
          value: usersProvider,
          child: PmOccurrenceDetailContent(
            occurrence: occurrence,
            readOnly: readOnly,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollDetailToBottom(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  await tester.drag(scrollable.first, const Offset(0, -800));
  await tester.pumpAndSettle();
}

void main() {
  group('PmOccurrenceDetailContent', () {
    testWidgets('renders schedule, asset, checklist, and completion info', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        occurrence: _detailOccurrence(),
        users: [
          User(
            id: 'tech-1',
            email: 'tech@test.com',
            name: 'Taylor Tech',
            role: 'technician',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(find.text('Monthly filter PM'), findsWidgets);
      expect(find.text('Charger A12'), findsOneWidget);
      expect(find.text('Bay 3'), findsOneWidget);
      expect(find.text('ABB'), findsOneWidget);
      expect(find.text('Terra 184'), findsOneWidget);
      expect(find.text('SN-001'), findsOneWidget);
      expect(find.text('Taylor Tech'), findsOneWidget);
      expect(find.text('Inspect housing'), findsOneWidget);
      expect(find.text('Replace filter'), findsOneWidget);
      await _scrollDetailToBottom(tester);
      expect(find.text('Filter replaced and tested.'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('read-only mode hides completion entry', (tester) async {
      await _pumpDetail(
        tester,
        occurrence: _detailOccurrence(),
        readOnly: true,
      );

      expect(find.byKey(const Key('pm_occurrence_complete_button')),
          findsNothing);
      expect(find.text('Complete Task'), findsNothing);
      expect(find.text('Pause Task'), findsNothing);
      expect(find.text('Sign'), findsNothing);
    });

    testWidgets('technician mode hides legacy completion controls', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        occurrence: _detailOccurrence(),
        readOnly: false,
      );

      expect(find.byKey(const Key('pm_occurrence_complete_button')),
          findsNothing);
      expect(find.text('Complete Task'), findsNothing);
      expect(find.text('Pause Task'), findsNothing);
    });

    testWidgets('requestor screen uses read-only app bar title', (tester) async {
      final usersProvider = UserProvider(
        dataService: _UsersStubDataService(const []),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<UserProvider>.value(
            value: usersProvider,
            child: PmOccurrenceDetailScreen(
              occurrence: _detailOccurrence(),
              readOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preventive Maintenance'), findsOneWidget);
      expect(find.byKey(const Key('pm_occurrence_complete_button')),
          findsNothing);
    });
  });
}
