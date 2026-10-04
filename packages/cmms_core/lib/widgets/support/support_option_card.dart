import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';

class SupportOptionCard extends StatelessWidget {
  const SupportOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isDesktop ? 12 : AppTheme.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isDesktop ? 12 : AppTheme.radiusM),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isDesktop ? 24 : AppTheme.spacingL),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(isDesktop ? 12 : AppTheme.radiusM),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppTheme.accentGreen,
                  size: isDesktop ? 28 : 24,
                ),
              ),
              SizedBox(width: isDesktop ? 20 : AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.heading2.copyWith(
                        fontSize: isDesktop ? 20 : 18,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      description,
                      style: AppTheme.bodyText.copyWith(
                        color: AppTheme.secondaryTextColor,
                        fontSize: isDesktop ? 15 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.secondaryTextColor,
                size: isDesktop ? 28 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
