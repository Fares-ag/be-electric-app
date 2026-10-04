import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/cmms_app_mode.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_main_screen.dart';
import '../screens/auth/wrong_app_role_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/requestor/requestor_main_screen.dart';
import '../screens/technician/technician_main_screen.dart';
import '../utils/app_role_policy.dart';

class RoleBasedNavigation extends StatelessWidget {
  const RoleBasedNavigation({super.key, required this.appMode});

  final CmmsAppMode appMode;

  @override
  Widget build(BuildContext context) => Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;

          if (user == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final role = user.role.toLowerCase();

          if (!isRoleAllowedForAppMode(role: role, appMode: appMode)) {
            return WrongAppRoleScreen(
              message: wrongAppRoleMessage(role: user.role, appMode: appMode),
            );
          }

          switch (appMode) {
            case CmmsAppMode.requestor:
              return const RequestorMainScreen();
            case CmmsAppMode.technician:
              switch (role) {
                case 'technician':
                  return const TechnicianMainScreen();
                case 'manager':
                case 'admin':
                  return const AdminMainScreen();
                default:
                  return const DashboardScreen();
              }
          }
        },
      );
}
