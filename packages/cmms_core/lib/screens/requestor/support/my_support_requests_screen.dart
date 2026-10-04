import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/support_request.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/support_request_provider.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/requestor_home_navigation.dart';
import '../../../utils/responsive_layout.dart';
import '../../../utils/user_facing_errors.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/requestor_more_menu.dart';
import '../../../widgets/support/support_request_list_card.dart';
import 'support_request_detail_screen.dart';

class MySupportRequestsScreen extends StatefulWidget {
  const MySupportRequestsScreen({super.key});

  @override
  State<MySupportRequestsScreen> createState() =>
      _MySupportRequestsScreenState();
}

class _MySupportRequestsScreenState extends State<MySupportRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  Future<void> _loadRequests() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || !mounted) return;

    try {
      await Provider.of<SupportRequestProvider>(context, listen: false)
          .loadSupportRequests(user.id);
    } catch (e, st) {
      if (!mounted) return;
      showUserErrorSnackBar(
        context,
        e,
        genericMessage: 'Could not load your support requests. Pull to retry.',
        stackTrace: st,
        contextLabel: 'MySupportRequestsScreen: load',
      );
    }
  }

  Future<void> _onRefresh() async {
    await _loadRequests();
  }

  void _openDetail(SupportRequest request) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SupportRequestDetailScreen(request: request),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'My Support Requests',
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
      body: Consumer<SupportRequestProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingRequests && !provider.hasLoadedRequests) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.hasRequests) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppTheme.accentGreen,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: padding,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: AppTheme.secondaryTextColor
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              'No support requests yet',
                              style: AppTheme.heading2.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: AppTheme.spacingS),
                            Text(
                              'Submit a Know How or Commissioning request '
                              'and it will appear here.',
                              textAlign: TextAlign.center,
                              style: AppTheme.bodyText.copyWith(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.accentGreen,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: padding,
                  itemCount: provider.requests.length,
                  itemBuilder: (context, index) {
                    final request = provider.requests[index];
                    return SupportRequestListCard(
                      request: request,
                      onTap: () => _openDetail(request),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
