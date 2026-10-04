// Layout and composite UI helpers built on [AppTheme].
//
// Token values live in `design_tokens.dart` / `app_theme.dart` only.

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'app_typography.dart';
import 'design_tokens.dart';

class UnifiedDesignSystem {
  UnifiedDesignSystem._();

  // Token forwards (avoid duplicating values; keep const for widget trees)
  static const Color primary = DesignTokens.primaryColor;
  static const Color primaryDark = DesignTokens.primaryDarkColor;
  static const Color primaryLight = DesignTokens.primaryLightColor;
  static const Color surface = DesignTokens.surfaceColor;
  static const Color background = DesignTokens.backgroundColor;
  static const Color cardBackground = DesignTokens.cardBackgroundColor;
  static const Color textPrimary = DesignTokens.primaryColor;
  static const Color textSecondary = DesignTokens.secondaryTextColor;
  static const Color textDisabled = DesignTokens.disabledColor;
  static const Color textDark = DesignTokens.darkTextColor;
  static const Color borderColor = DesignTokens.borderColor;
  static const Color accentBlue = DesignTokens.accentBlue;
  static const Color accentRed = DesignTokens.accentRed;
  static const Color accentGreen = DesignTokens.accentGreen;
  static const Color accentOrange = DesignTokens.accentOrange;
  static const Color statusActive = DesignTokens.activeColor;
  static const Color statusInactive = DesignTokens.inactiveColor;
  static const Color statusPending = DesignTokens.pendingColor;
  static const Color statusCompleted = DesignTokens.completedColor;
  static const Color statusCancelled = DesignTokens.cancelledColor;

  static const TextStyle heading1 = AppTypography.heading1;
  static const TextStyle heading2 = AppTypography.heading2;
  static const TextStyle heading3 = AppTypography.heading3;
  static const TextStyle heading4 = AppTypography.heading4;
  static const TextStyle bodyLarge = AppTypography.bodyText;
  static const TextStyle bodyMedium = AppTypography.secondaryText;
  static const TextStyle bodySmall = AppTypography.smallText;
  static const TextStyle caption = AppTypography.captionText;
  static const TextStyle button = AppTypography.buttonTextStyle;
  static const TextStyle label = AppTypography.label;

  static const double spaceXS = DesignTokens.spacingXS;
  static const double spaceS = DesignTokens.spacingS;
  static const double spaceM = DesignTokens.spacingM;
  static const double spaceL = DesignTokens.spacingL;
  static const double spaceXL = DesignTokens.spacingXL;
  static const double spaceXXL = DesignTokens.spacingXXL;

  static const double radiusS = DesignTokens.radiusS;
  static const double radiusM = DesignTokens.radiusM;
  static const double radiusL = DesignTokens.radiusL;
  static const double radiusXL = DesignTokens.radiusXL;

  static const double elevationS = DesignTokens.elevationS;
  static const double elevationM = DesignTokens.elevationM;
  static const double elevationL = DesignTokens.elevationL;

  static BoxDecoration get cardDecoration => AppTheme.getCardDecoration();
  static BoxDecoration get cardDecorationElevated =>
      AppTheme.cardDecorationElevated;

  static ButtonStyle get primaryButton => AppTheme.primaryButton;
  static ButtonStyle get secondaryButton => AppTheme.secondaryButton;
  static ButtonStyle get accentButton => AppTheme.accentButton;
  static ButtonStyle get successButton => AppTheme.successButton;
  static ButtonStyle get warningButton => AppTheme.warningButton;
  static ButtonStyle get dangerButton => AppTheme.dangerButton;

  static InputDecoration get inputDecoration => AppTheme.inputDecoration;
  static InputDecoration get searchInputDecoration =>
      AppTheme.searchInputDecoration;

  static BoxDecoration getStatusBadge(String status) =>
      AppTheme.getStatusBadge(status);

  static TextStyle getStatusText(String status) =>
      AppTheme.getStatusText(status);

  static BoxDecoration getPriorityBadge(String priority) =>
      AppTheme.getPriorityBadge(priority);

  static TextStyle getPriorityText(String priority) =>
      AppTheme.getPriorityText(priority);

  static Color getStatusColor(String status) => AppTheme.getStatusColor(status);
  static Color getPriorityColor(String priority) =>
      AppTheme.getPriorityColor(priority);
  static Color getPMTaskStatusColor(String status) =>
      AppTheme.getPMTaskStatusColor(status);
  static BoxDecoration getStatusContainer(Color color) =>
      AppTheme.getStatusContainer(color);

  static Widget screenContainer({
    required Widget child,
    EdgeInsets? padding,
    Color? backgroundColor,
  }) =>
      Container(
        width: double.infinity,
        height: double.infinity,
        color: backgroundColor ?? background,
        padding: padding ?? const EdgeInsets.all(DesignTokens.spacingM),
        child: child,
      );

  static Widget sectionHeader({
    required String title,
    String? subtitle,
    Widget? action,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: DesignTokens.spacingM),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: heading2),
                  if (subtitle != null) ...[
                    const SizedBox(height: DesignTokens.spacingXS),
                    Text(subtitle, style: bodyMedium),
                  ],
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
      );

  static Widget infoCard({
    required String title,
    required String value,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) =>
      Card(
        elevation: elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusL),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: iconColor ?? textSecondary, size: 20),
                      const SizedBox(width: DesignTokens.spacingS),
                    ],
                    Expanded(
                      child: Text(title, style: bodyMedium),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingS),
                Text(value, style: heading3),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignTokens.spacingXS),
                  Text(subtitle, style: caption),
                ],
              ],
            ),
          ),
        ),
      );

  static Widget actionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) =>
      Card(
        elevation: elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusL),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingM),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spacingM),
                  decoration: BoxDecoration(
                    color: (iconColor ?? accentBlue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(radiusM),
                  ),
                  child: Icon(icon, color: iconColor ?? accentBlue, size: 24),
                ),
                const SizedBox(width: DesignTokens.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: heading4),
                      const SizedBox(height: DesignTokens.spacingXS),
                      Text(description, style: bodyMedium),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
      );

  static Widget emptyState({
    required String title,
    required String description,
    IconData? icon,
    Widget? action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 64, color: textDisabled),
                const SizedBox(height: DesignTokens.spacingM),
              ],
              Text(title, style: heading3, textAlign: TextAlign.center),
              const SizedBox(height: DesignTokens.spacingS),
              Text(description, style: bodyMedium, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: DesignTokens.spacingL),
                action,
              ],
            ],
          ),
        ),
      );

  static Widget loadingState({String? message}) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accentBlue),
            if (message != null) ...[
              const SizedBox(height: DesignTokens.spacingM),
              Text(message, style: bodyMedium),
            ],
          ],
        ),
      );
}
