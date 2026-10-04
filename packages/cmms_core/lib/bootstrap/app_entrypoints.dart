import 'package:flutter/material.dart';

import '../app/be_electric_app.dart';
import '../config/cmms_app_mode.dart';
import 'cmms_bootstrap.dart';
import 'cmms_bootstrap_error_app.dart';
import '../utils/cmms_bootstrap_policy.dart';

/// Requestor store build: only [requestor] role is intended after sign-in.
Future<void> runRequestorApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeCmms();
    runApp(
      const BeElectricApp(
        appMode: CmmsAppMode.requestor,
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Requestor bootstrap failed: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(CmmsBootstrapErrorApp(message: bootstrapFailureUserMessage(e)));
  }
}

/// Technician / field staff build: technician, manager, and admin roles.
Future<void> runTechnicianApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeCmms();
    runApp(
      const BeElectricApp(
        appMode: CmmsAppMode.technician,
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Technician bootstrap failed: $e');
    debugPrint('Stack trace: $stackTrace');
    runApp(CmmsBootstrapErrorApp(message: bootstrapFailureUserMessage(e)));
  }
}
