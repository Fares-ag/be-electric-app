import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cmms_core/screens/requestor/support/requestor_support_screen.dart';
import 'package:cmms_core/widgets/support/support_option_card.dart';

void main() {
  testWidgets('RequestorSupportScreen shows all support options', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RequestorSupportScreen(),
      ),
    );

    expect(find.text('Be Electric Support'), findsOneWidget);
    expect(find.text('Know How'), findsOneWidget);
    expect(find.text('Commissioning'), findsOneWidget);
    expect(find.text('My Support Requests'), findsOneWidget);
    expect(find.byType(SupportOptionCard), findsNWidgets(3));
  });
}
