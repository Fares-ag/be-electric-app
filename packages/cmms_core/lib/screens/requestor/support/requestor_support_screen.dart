import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/requestor_home_navigation.dart';
import '../../../utils/responsive_layout.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/requestor_more_menu.dart';
import '../../../widgets/support/support_option_card.dart';
import 'commissioning_support_screen.dart';
import 'know_how_support_screen.dart';
import 'my_support_requests_screen.dart';

class RequestorSupportScreen extends StatelessWidget {
  const RequestorSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'Be Electric Support',
        usePageTitle: true,
        showMenu: false,
        showBackButton: true,
        onMoreTap: () {
          showRequestorMoreMenu(
            context,
            primaryLabel: 'Home',
            primaryIcon: Icons.home_outlined,
            onPrimaryNav: () => navigateToRequestorMain(context),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How can we help?',
                  style: AppTheme.heading2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Choose the type of support you need.',
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                SupportOptionCard(
                  title: 'Know How',
                  description:
                      'Submit a technical question or request assistance.',
                  icon: Icons.help_outline,
                  onTap: () => _openForm(context, const KnowHowSupportScreen()),
                ),
                const SizedBox(height: AppTheme.spacingM),
                SupportOptionCard(
                  title: 'Commissioning',
                  description:
                      'Request commissioning assistance for a charging station.',
                  icon: Icons.electrical_services_outlined,
                  onTap: () => _openForm(
                    context,
                    const CommissioningSupportScreen(),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                SupportOptionCard(
                  title: 'My Support Requests',
                  description:
                      'View your submitted Know How and Commissioning requests.',
                  icon: Icons.history,
                  onTap: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MySupportRequestsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, Widget screen) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your support request was submitted successfully.'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }
}
