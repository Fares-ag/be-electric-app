import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cmms_core/models/support_request.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/providers/support_request_provider.dart';
import 'package:cmms_core/screens/requestor/support/my_support_requests_screen.dart';
import 'package:cmms_core/screens/requestor/support/support_request_detail_screen.dart';
import 'package:cmms_core/services/support_request_service.dart';

import '../support/fake_support_request_repository.dart';

void main() {
  Widget buildTestApp({
    required FakeSupportRequestRepository repository,
    required AuthProvider authProvider,
  }) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<SupportRequestProvider>(
            create: (_) => SupportRequestProvider(
              service: SupportRequestService(repository: repository),
            ),
          ),
        ],
        child: const MySupportRequestsScreen(),
      ),
    );
  }

  testWidgets('MySupportRequestsScreen shows empty state', (tester) async {
    final auth = AuthProvider()
      ..setUser(
        User.create(
          email: 'requestor@example.com',
          name: 'Requestor',
          role: 'requestor',
        ),
      );

    await tester.pumpWidget(
      buildTestApp(
        repository: FakeSupportRequestRepository(),
        authProvider: auth,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No support requests yet'), findsOneWidget);
  });

  testWidgets('MySupportRequestsScreen lists requests and opens detail',
      (tester) async {
    final auth = AuthProvider()
      ..setUser(
        User.create(
          email: 'requestor@example.com',
          name: 'Requestor',
          role: 'requestor',
        ),
      );

    final repository = FakeSupportRequestRepository()
      ..requests = [
        SupportRequest(
          id: 'req-1',
          type: SupportRequestType.knowHow,
          status: SupportRequestStatus.submitted,
          createdBy: auth.currentUser!.id,
          createdAt: DateTime(2026, 6, 25, 10, 0),
          topic: 'OCPP configuration',
          question: 'How do I set the backend URL?',
          attachments: const [],
        ),
      ];

    await tester.pumpWidget(
      buildTestApp(repository: repository, authProvider: auth),
    );
    await tester.pumpAndSettle();

    expect(find.text('OCPP configuration'), findsOneWidget);
    expect(find.text('Know How'), findsOneWidget);

    await tester.tap(find.text('OCPP configuration'));
    await tester.pumpAndSettle();

    expect(find.byType(SupportRequestDetailScreen), findsOneWidget);
    expect(find.text('How do I set the backend URL?'), findsOneWidget);
  });
}
