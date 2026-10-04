import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmms_core/models/support_request.dart';
import 'package:cmms_core/widgets/support/support_request_list_card.dart';

void main() {
  testWidgets('SupportRequestListCard shows type, status, date, and attachments',
      (tester) async {
    final request = SupportRequest(
      id: 'req-1',
      type: SupportRequestType.commissioning,
      status: SupportRequestStatus.open,
      createdBy: 'user-1',
      createdAt: DateTime(2026, 6, 25, 14, 30),
      summary: 'Site commissioning',
      chargerModel: 'Siemens Sicharge D',
      attachments: const [
        'https://example.com/a.pdf',
        'https://example.com/b.pdf',
      ],
    );

    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportRequestListCard(
            request: request,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Commissioning'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Site commissioning'), findsOneWidget);
    expect(find.text('Charger model: Siemens Sicharge D'), findsOneWidget);
    expect(find.text('2 attachments'), findsOneWidget);

    await tester.tap(find.byType(SupportRequestListCard));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
