import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../utils/app_theme.dart';
import '../../utils/cmms_package_assets.dart';
import '../../utils/charger_asset_filter.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/requestor_more_menu.dart';
import 'create_maintenance_request_screen.dart';
import 'requestor_status_screen.dart';
import 'support/commissioning_support_screen.dart';
import 'support/know_how_support_screen.dart';
import '../../utils/user_facing_errors.dart';

class RequestorMainScreen extends StatefulWidget {
  const RequestorMainScreen({super.key});

  @override
  State<RequestorMainScreen> createState() => _RequestorMainScreenState();
}

class _RequestorMainScreenState extends State<RequestorMainScreen> {

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFE5E7EB),
        appBar: CustomAppBar(
          title: 'Maintenance Request',
          showMenu: false,
          onMoreTap: () {
            showRequestorMoreMenu(
              context,
              primaryLabel: 'View My Requests',
              primaryIcon: Icons.history,
              onPrimaryNav: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestorStatusScreen(),
                  ),
                );
              },
            );
          },
        ),
        body: _buildMainContent(),
      );

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero card that extends all the way down
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    image: DecorationImage(
                      image: AssetImage(
                        'assets/images/MaintenanceRequestBg.png',
                        package: kCmmsCoreAssetPackage,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppTheme.spacingM,
                                    ),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                    child: Icon(
                                      Icons.build,
                                      size: 28,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingL),
                                  Text(
                                    'Request Maintenance',
                                    style: AppTheme.heading1.copyWith(
                                      color: Colors.white,
                                      fontSize: 24,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  Text(
                                    'Select an asset to request maintenance work',
                                    style: AppTheme.bodyText.copyWith(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildHeroActionCard(
                                          icon: Icons.qr_code_scanner,
                                          title: 'Siemens',
                                          description: '',
                                          imagePath:
                                              'assets/images/SiemensCharger.png',
                                          onTap: () =>
                                              _navigateToMaintenanceForm(
                                            'Siemens',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacingM),
                                      Expanded(
                                        child: _buildHeroActionCard(
                                          icon: Icons.search,
                                          title: 'Kostad',
                                          description: '',
                                          imagePath:
                                              'assets/images/KostadCharger.png',
                                          onTap: () =>
                                              _navigateToMaintenanceForm(
                                            'Kostad',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spacingM),
                                  _buildCompactHeroCard(
                                    icon: Icons.help_outline,
                                    title: 'Know How',
                                    description:
                                        'Submit a technical question or request assistance.',
                                    onTap: () => _openSupportForm(
                                      const KnowHowSupportScreen(),
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingS),
                                  _buildCompactHeroCard(
                                    icon: Icons.electrical_services_outlined,
                                    title: 'Commissioning',
                                    description:
                                        'Request commissioning assistance for a charging station.',
                                    onTap: () => _openSupportForm(
                                      const CommissioningSupportScreen(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
  }

  /// Compact white card for support actions inside the hero panel.
  Widget _buildCompactHeroCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTheme.heading2.copyWith(
                        color: AppTheme.darkTextColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 11,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSupportForm(Widget screen) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your support request was submitted successfully.'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  /// White option card used inside the green hero panel, matching the design.
  Widget _buildHeroActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    String? imagePath,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 200,
          ),
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show image if provided, otherwise show icon
              if (imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  child: Image.asset(
                    imagePath,
                    package: kCmmsCoreAssetPackage,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      return Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: AppTheme.accentGreen,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: AppTheme.accentGreen,
                  ),
                ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                title,
                style: AppTheme.heading2.copyWith(
                  color: AppTheme.darkTextColor,
                  fontSize: 16,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  description,
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate to maintenance form after verifying chargers exist for this type.
  Future<void> _navigateToMaintenanceForm(String chargerType) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final companyId = user?.companyId;

    if (companyId == null || companyId.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No company assigned to your account'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    try {
      final company =
          await CmmsRepositories.users.getCompanyById(companyId);
      final allAssets =
          await CmmsRepositories.assets.getAssetsByCompanyId(
        companyId,
      );
      if (!mounted) {
        return;
      }
      final matchingChargers = allAssets.where((asset) {
        return assetBelongsToUserCompany(
              asset,
              companyId,
              resolvedCompanyName: company?.name,
            ) &&
            isChargerLikeAsset(asset) &&
            matchesChargerBrand(asset, chargerType);
      }).toList();

      if (matchingChargers.isEmpty) {
        final anyCharger = allAssets.where((asset) {
          return assetBelongsToUserCompany(
                asset,
                companyId,
                resolvedCompanyName: company?.name,
              ) &&
              isChargerLikeAsset(asset);
        }).toList();
        final body = anyCharger.isEmpty
            ? 'Your company has no charger-style assets yet, or they are missing '
                'type/manufacturer details. Ask your admin to add chargers in '
                'Company → Chargers and set Manufacturer (e.g. $chargerType).'
            : 'You have ${anyCharger.length} charger(s) for your company, but none '
                'are registered as $chargerType (check Manufacturer, name, or '
                'description in the admin app). Try the other brand, or ask your '
                'admin to set the manufacturer to $chargerType for the right units.';

        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('No $chargerType Chargers'),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e, st) {
      if (!mounted) {
        return;
      }
      showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not load chargers. Please try again.',
          stackTrace: st,
          contextLabel: 'RequestorMain: load chargers',
          backgroundColor: AppTheme.accentRed,
        );
      return;
    }

    if (!mounted) {
      return;
    }

    final chargerAsset = Asset(
      id: chargerType.toLowerCase(),
      name: '$chargerType Charger',
      location: '',
      manufacturer: chargerType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMaintenanceRequestScreen(
          asset: chargerAsset,
          qrCode: '',
          chargerType: chargerType,
        ),
      ),
    );
  }

}
