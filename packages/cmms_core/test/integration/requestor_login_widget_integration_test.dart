import 'package:cmms_core/app/cmms_app_mode_scope.dart';
import 'package:cmms_core/config/cmms_app_mode.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/screens/auth/login_screen.dart';
import 'package:cmms_core/utils/login_attempt_policy.dart';
import 'package:cmms_core/utils/security_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  tearDown(SecurityUtils.clearAllRateLimits);

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      CmmsAppModeScope(
        appMode: CmmsAppMode.requestor,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LoginScreen widget integration', () {
    testWidgets('shows validation error for malformed email', (tester) async {
      await pumpLoginScreen(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'not-an-email');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email format'), findsOneWidget);
    });

    testWidgets('shows rate-limit message on rapid repeat login taps', (
      tester,
    ) async {
      await pumpLoginScreen(tester);

      const email = 'widget.integration@test.com';
      isLoginAttemptRateLimited(email);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text(kLoginRateLimitedMessage), findsOneWidget);
    });

    testWidgets('renders login action for requestor app mode', (tester) async {
      await pumpLoginScreen(tester);

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });
  });
}
