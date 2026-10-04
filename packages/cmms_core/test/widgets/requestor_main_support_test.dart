import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/screens/requestor/requestor_main_screen.dart';

void main() {
  testWidgets('RequestorMainScreen shows support cards above charger options',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
          child: const RequestorMainScreen(),
        ),
      ),
    );

    expect(find.text('Know How'), findsOneWidget);
    expect(find.text('Commissioning'), findsOneWidget);
    expect(find.text('Siemens'), findsOneWidget);
    expect(find.text('Kostad'), findsOneWidget);
  });
}
