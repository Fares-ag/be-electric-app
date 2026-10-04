import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/pm_occurrence_provider.dart';
import '../../../utils/requestor_home_navigation.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/requestor_more_menu.dart';

Future<void> refreshRequestorPmData(BuildContext context) async {
  if (!AppConfig.enablePmOccurrences) {
    return;
  }

  final auth = Provider.of<AuthProvider>(context, listen: false);
  final user = auth.currentUser;
  if (user == null) {
    return;
  }

  final pmOccurrences =
      Provider.of<PmOccurrenceProvider>(context, listen: false);
  if (!pmOccurrences.isEnabled) {
    return;
  }

  if (user.role == 'requestor') {
    await pmOccurrences.refreshCompanyOccurrences(user.companyId);
  } else {
    await pmOccurrences.refreshAssignedOccurrences(user.id);
  }
}

PreferredSizeWidget buildRequestorPmAppBar(
  BuildContext context, {
  required String title,
}) =>
    CustomAppBar(
      title: title,
      usePageTitle: true,
      showMenu: false,
      showBackButton: true,
      onMoreTap: () => showRequestorMoreMenu(
        context,
        primaryLabel: 'Home',
        primaryIcon: Icons.home_outlined,
        onPrimaryNav: () => navigateToRequestorMain(context),
      ),
    );

Widget buildRequestorPmUnavailableBody() => const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Preventive maintenance is not available yet.',
          textAlign: TextAlign.center,
        ),
      ),
    );
