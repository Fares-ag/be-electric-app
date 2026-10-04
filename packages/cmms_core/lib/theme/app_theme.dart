import 'package:flutter/material.dart';

import '../models/pm_task.dart';
import '../models/work_order.dart';
import 'app_typography.dart';
import 'design_tokens.dart';

/// Single design-system entry point for colors, typography, spacing, and [ThemeData].
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Design tokens (canonical)
  // ---------------------------------------------------------------------------

  static const Color primaryColor = DesignTokens.primaryColor;
  static const Color primaryDarkColor = DesignTokens.primaryDarkColor;
  static const Color primaryLightColor = DesignTokens.primaryLightColor;
  static const Color backgroundColor = DesignTokens.backgroundColor;
  static const Color surfaceColor = DesignTokens.surfaceColor;
  static const Color cardBackgroundColor = DesignTokens.cardBackgroundColor;
  static const Color borderColor = DesignTokens.borderColor;
  static const Color disabledColor = DesignTokens.disabledColor;
  static const Color secondaryTextColor = DesignTokens.secondaryTextColor;
  static const Color darkTextColor = DesignTokens.darkTextColor;

  static const Color accentBlue = DesignTokens.accentBlue;
  static const Color accentRed = DesignTokens.accentRed;
  static const Color accentGreen = DesignTokens.accentGreen;
  static const Color accentOrange = DesignTokens.accentOrange;

  static const Color activeColor = DesignTokens.activeColor;
  static const Color inactiveColor = DesignTokens.inactiveColor;
  static const Color writtenOffColor = DesignTokens.writtenOffColor;
  static const Color pendingColor = DesignTokens.pendingColor;
  static const Color completedColor = DesignTokens.completedColor;
  static const Color cancelledColor = DesignTokens.cancelledColor;

  static const Color workOrderStatusOpen = DesignTokens.workOrderStatusOpen;
  static const Color workOrderStatusAssigned = DesignTokens.workOrderStatusAssigned;
  static const Color workOrderStatusInProgress =
      DesignTokens.workOrderStatusInProgress;
  static const Color workOrderStatusCompleted =
      DesignTokens.workOrderStatusCompleted;
  static const Color workOrderStatusClosed = DesignTokens.workOrderStatusClosed;
  static const Color workOrderStatusCancelled =
      DesignTokens.workOrderStatusCancelled;
  static const Color workOrderStatusReopened =
      DesignTokens.workOrderStatusReopened;
  static const Color workOrderStatusPaused = DesignTokens.workOrderStatusPaused;

  static const Color pmTaskStatusPending = DesignTokens.pmTaskStatusPending;
  static const Color pmTaskStatusInProgress = DesignTokens.pmTaskStatusInProgress;
  static const Color pmTaskStatusCompleted = DesignTokens.pmTaskStatusCompleted;
  static const Color pmTaskStatusOverdue = DesignTokens.pmTaskStatusOverdue;
  static const Color pmTaskStatusCancelled = DesignTokens.pmTaskStatusCancelled;

  static const Color lowPriorityColor = DesignTokens.lowPriorityColor;
  static const Color mediumPriorityColor = DesignTokens.mediumPriorityColor;
  static const Color highPriorityColor = DesignTokens.highPriorityColor;
  static const Color criticalPriorityColor = DesignTokens.criticalPriorityColor;

  static const Color textColor = DesignTokens.textColor;
  static const Color cardColor = DesignTokens.cardColor;

  @Deprecated('Use accentGreen for Be Electric brand color')
  static const Color green = accentGreen;
  @Deprecated('Use accentRed instead')
  static const Color red = accentRed;
  @Deprecated('Use accentOrange instead')
  static const Color orange = accentOrange;
  @Deprecated('Use accentBlue instead')
  static const Color blue = accentBlue;

  static const Color purple = DesignTokens.accentPurple;
  static const Color darkGrey = DesignTokens.darkGrey;
  static const Color lightGrey = DesignTokens.lightGrey;
  static const Color nearlyWhite = DesignTokens.nearlyWhite;
  static const Color accentColor = DesignTokens.accentColor;
  static const Color white = DesignTokens.white;

  static const Color errorColor = DesignTokens.errorColor;
  static const Color successColor = DesignTokens.successColor;
  static const Color warningColor = DesignTokens.warningColor;
  static const Color infoColor = DesignTokens.infoColor;

  // Legacy names from the removed duplicate theme file
  static const Color primaryBlack = primaryColor;
  static const Color primaryWhite = surfaceColor;
  static const Color cardGrey = cardBackgroundColor;
  static const Color borderGrey = borderColor;
  static const Color disabledGrey = disabledColor;
  static const Color secondaryTextGrey = secondaryTextColor;
  static const Color darkTextGrey = darkTextColor;
  static const Color accentPurple = DesignTokens.accentPurple;

  static const double spacingXS = DesignTokens.spacingXS;
  static const double spacingS = DesignTokens.spacingS;
  static const double spacingM = DesignTokens.spacingM;
  static const double spacingL = DesignTokens.spacingL;
  static const double spacingXL = DesignTokens.spacingXL;
  static const double spacingXXL = DesignTokens.spacingXXL;

  static const double radiusS = DesignTokens.radiusS;
  static const double radiusM = DesignTokens.radiusM;
  static const double radiusL = DesignTokens.radiusL;
  static const double radiusXL = DesignTokens.radiusXL;

  static const double elevationS = DesignTokens.elevationS;
  static const double elevationM = DesignTokens.elevationM;
  static const double elevationL = DesignTokens.elevationL;

  // Typography
  static const TextStyle heading1 = AppTypography.heading1;
  static const TextStyle heading2 = AppTypography.heading2;
  static const TextStyle bodyText = AppTypography.bodyText;
  static const TextStyle secondaryText = AppTypography.secondaryText;
  static const TextStyle smallText = AppTypography.smallText;
  static const TextStyle headline4 = AppTypography.headline4;
  static const TextStyle headline6 = AppTypography.headline6;
  static const TextStyle captionText = AppTypography.captionText;
  static const TextStyle titleStyle = AppTypography.titleStyle;
  static const TextStyle subtitleStyle = AppTypography.subtitleStyle;
  static const TextStyle bodyStyle = AppTypography.bodyStyle;
  static const TextStyle buttonTextStyle = AppTypography.buttonTextStyle;
  static const TextStyle captionStyle = AppTypography.captionStyle;
  static const TextStyle heading3 = AppTypography.heading3;
  static const TextStyle heading4 = AppTypography.heading4;
  static const TextStyle label = AppTypography.label;

  // Component styles
  static const InputDecoration inputDecoration = InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(DesignTokens.radiusS)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: DesignTokens.borderColor),
      borderRadius: BorderRadius.all(Radius.circular(DesignTokens.radiusS)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: DesignTokens.accentGreen),
      borderRadius: BorderRadius.all(Radius.circular(DesignTokens.radiusS)),
    ),
    filled: true,
    fillColor: DesignTokens.surfaceColor,
  );

  static const ButtonStyle elevatedButtonStyle = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(DesignTokens.accentGreen),
    foregroundColor: WidgetStatePropertyAll(Colors.white),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(DesignTokens.radiusS)),
      ),
    ),
  );

  static const ButtonStyle outlinedButtonStyle = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(DesignTokens.accentGreen),
    side: WidgetStatePropertyAll(BorderSide(color: DesignTokens.accentGreen)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(DesignTokens.radiusS)),
      ),
    ),
  );

  static ThemeData get lightTheme {
    const baseTextTheme = TextTheme(
      displayLarge: TextStyle(fontFamily: DesignTokens.fontFamily),
      displayMedium: TextStyle(fontFamily: DesignTokens.fontFamily),
      displaySmall: TextStyle(fontFamily: DesignTokens.fontFamily),
      headlineLarge: TextStyle(fontFamily: DesignTokens.fontFamily),
      headlineMedium: TextStyle(fontFamily: DesignTokens.fontFamily),
      headlineSmall: TextStyle(fontFamily: DesignTokens.fontFamily),
      titleLarge: TextStyle(fontFamily: DesignTokens.fontFamily),
      titleMedium: TextStyle(fontFamily: DesignTokens.fontFamily),
      titleSmall: TextStyle(fontFamily: DesignTokens.fontFamily),
      bodyLarge: TextStyle(fontFamily: DesignTokens.fontFamily),
      bodyMedium: TextStyle(fontFamily: DesignTokens.fontFamily),
      bodySmall: TextStyle(fontFamily: DesignTokens.fontFamily),
      labelLarge: TextStyle(fontFamily: DesignTokens.fontFamily),
      labelMedium: TextStyle(fontFamily: DesignTokens.fontFamily),
      labelSmall: TextStyle(fontFamily: DesignTokens.fontFamily),
    );

    return ThemeData(
        useMaterial3: true,
        fontFamily: DesignTokens.fontFamily,
        textTheme: baseTextTheme.apply(
          bodyColor: darkTextColor,
          displayColor: darkTextColor,
        ),
        primaryTextTheme: baseTextTheme.apply(
          bodyColor: darkTextColor,
          displayColor: darkTextColor,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentGreen,
          primary: darkTextColor,
          secondary: secondaryTextColor,
          surface: surfaceColor,
          background: backgroundColor,
          error: accentRed,
        ),
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceColor,
          foregroundColor: primaryColor,
          elevation: 1,
          centerTitle: true,
          shadowColor: Colors.black12,
          titleTextStyle: TextStyle(
            fontFamily: DesignTokens.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentGreen,
            foregroundColor: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
            minimumSize: const Size(120, 44),
            textStyle: buttonTextStyle,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkTextColor,
            side: const BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(120, 44),
            textStyle: buttonTextStyle,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: buttonTextStyle,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: surfaceColor,
          shadowColor: Colors.black12,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: accentGreen),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: accentRed),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: backgroundColor,
          labelStyle: secondaryText,
          hintStyle: TextStyle(
            fontFamily: DesignTokens.fontFamily,
            color: disabledColor,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: surfaceColor,
          elevation: 2,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceColor,
          selectedItemColor: darkTextColor,
          unselectedItemColor: disabledColor,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        dividerTheme: const DividerThemeData(
          color: borderColor,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      );
  }

  static Color workOrderStatusColor(WorkOrderStatus status) {
    switch (status) {
      case WorkOrderStatus.open:
        return workOrderStatusOpen;
      case WorkOrderStatus.assigned:
        return workOrderStatusAssigned;
      case WorkOrderStatus.inProgress:
        return workOrderStatusInProgress;
      case WorkOrderStatus.completed:
        return workOrderStatusCompleted;
      case WorkOrderStatus.closed:
        return workOrderStatusClosed;
      case WorkOrderStatus.cancelled:
        return workOrderStatusCancelled;
      case WorkOrderStatus.reopened:
        return workOrderStatusReopened;
    }
  }

  static Color pmTaskStatusColorFromEnum(PMTaskStatus status) {
    switch (status) {
      case PMTaskStatus.pending:
        return pmTaskStatusPending;
      case PMTaskStatus.inProgress:
        return pmTaskStatusInProgress;
      case PMTaskStatus.completed:
        return pmTaskStatusCompleted;
      case PMTaskStatus.overdue:
        return pmTaskStatusOverdue;
      case PMTaskStatus.cancelled:
        return pmTaskStatusCancelled;
    }
  }

  static Color getStatusColor(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'open':
        return workOrderStatusOpen;
      case 'assigned':
        return workOrderStatusAssigned;
      case 'inprogress':
      case 'in_progress':
        return workOrderStatusInProgress;
      case 'completed':
        return workOrderStatusCompleted;
      case 'closed':
        return workOrderStatusClosed;
      case 'cancelled':
        return workOrderStatusCancelled;
      case 'reopened':
        return workOrderStatusReopened;
      case 'active':
        return activeColor;
      case 'inactive':
        return inactiveColor;
      case 'written_off':
        return writtenOffColor;
      case 'pending':
        return pmTaskStatusPending;
      case 'overdue':
        return pmTaskStatusOverdue;
      default:
        return DesignTokens.mediumPriorityColor;
    }
  }

  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return lowPriorityColor;
      case 'medium':
        return mediumPriorityColor;
      case 'high':
        return highPriorityColor;
      case 'urgent':
        return DesignTokens.urgentPriorityColor;
      case 'critical':
        return criticalPriorityColor;
      default:
        return mediumPriorityColor;
    }
  }

  static Color getPMTaskStatusColor(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'pending':
        return pmTaskStatusPending;
      case 'inprogress':
      case 'in_progress':
        return pmTaskStatusInProgress;
      case 'completed':
        return pmTaskStatusCompleted;
      case 'overdue':
        return pmTaskStatusOverdue;
      case 'cancelled':
        return pmTaskStatusCancelled;
      default:
        return DesignTokens.mediumPriorityColor;
    }
  }

  static BoxDecoration getCardDecoration() => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static BoxDecoration getStatusContainerDecoration(Color color) =>
      BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(radiusS),
      );

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: accentGreen,
        foregroundColor: surfaceColor,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        elevation: elevationS,
        textStyle: buttonTextStyle,
      );

  static ButtonStyle get secondaryButton => OutlinedButton.styleFrom(
        foregroundColor: accentGreen,
        side: const BorderSide(color: accentGreen),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        textStyle: buttonTextStyle,
      );

  static ButtonStyle get accentButton => ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        foregroundColor: surfaceColor,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        elevation: elevationS,
        textStyle: buttonTextStyle,
      );

  static ButtonStyle get successButton => primaryButton;

  static ButtonStyle get warningButton => ElevatedButton.styleFrom(
        backgroundColor: accentOrange,
        foregroundColor: surfaceColor,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        elevation: elevationS,
        textStyle: buttonTextStyle,
      );

  static ButtonStyle get dangerButton => ElevatedButton.styleFrom(
        backgroundColor: accentRed,
        foregroundColor: surfaceColor,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingXL,
          vertical: spacingM,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusS),
        ),
        elevation: elevationS,
        textStyle: buttonTextStyle,
      );

  static InputDecoration get searchInputDecoration => InputDecoration(
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search, color: secondaryTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: accentGreen),
        ),
        filled: true,
        fillColor: surfaceColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: spacingM, vertical: spacingM),
      );

  static BoxDecoration getStatusBadge(String status) {
    final color = getStatusColor(status);
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(radiusS),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    );
  }

  static TextStyle getStatusText(String status) {
    final color = getStatusColor(status);
    return TextStyle(
      fontFamily: DesignTokens.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static BoxDecoration getPriorityBadge(String priority) {
    final color = getPriorityColor(priority);
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(radiusS),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    );
  }

  static TextStyle getPriorityText(String priority) {
    final color = getPriorityColor(priority);
    return TextStyle(
      fontFamily: DesignTokens.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }

  static BoxDecoration getStatusContainer(Color color) =>
      getStatusContainerDecoration(color);

  static BoxDecoration get cardDecorationElevated => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
