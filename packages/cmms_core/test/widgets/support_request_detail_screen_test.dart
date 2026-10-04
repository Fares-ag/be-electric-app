import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmms_core/models/support_request.dart';
import 'package:cmms_core/screens/requestor/support/support_request_detail_screen.dart';

void main() {
  testWidgets('SupportRequestDetailScreen shows Know How fields', (tester) async {
    final request = SupportRequest(
      id: 'req-1',
      type: SupportRequestType.knowHow,
      status: SupportRequestStatus.submitted,
      createdBy: 'user-1',
      createdAt: DateTime(2026, 6, 25, 9, 0),
      topic: 'Firmware update',
      question: 'What is the latest version?',
      chargerModel: 'Kostad Unity',
      attachments: const ['https://example.com/files/manual.pdf'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SupportRequestDetailScreen(request: request),
      ),
    );

    expect(find.text('Know How'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Firmware update'), findsWidgets);
    expect(find.text('What is the latest version?'), findsOneWidget);
    expect(find.text('Kostad Unity'), findsOneWidget);
    expect(find.text('manual.pdf'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text('Response from Be Electric'), findsNothing);
  });

  testWidgets('SupportRequestDetailScreen shows staff reply when present',
      (tester) async {
    final request = SupportRequest(
      id: 'req-2',
      type: SupportRequestType.commissioning,
      status: SupportRequestStatus.resolved,
      createdBy: 'user-1',
      createdAt: DateTime(2026, 6, 20, 11, 0),
      summary: 'Commission new charger',
      scheduledDate: DateTime(2026, 7, 1, 10, 0),
      address: '123 Main St',
      country: 'Qatar',
      chargerSerialNumber: 'SN-001',
      chargerModel: 'Siemens Sicharge D',
      details: 'Need onsite support',
      staffReply: 'We will contact you within 2 business days.',
      attachments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SupportRequestDetailScreen(request: request),
      ),
    );

    expect(find.text('Commissioning'), findsOneWidget);
    expect(find.text('Commission new charger'), findsWidgets);
    expect(find.text('123 Main St'), findsOneWidget);
    expect(find.text('RESPONSE FROM BE ELECTRIC'), findsOneWidget);
    expect(
      find.text('We will contact you within 2 business days.'),
      findsOneWidget,
    );
    expect(find.text('No attachments'), findsOneWidget);
  });
}
