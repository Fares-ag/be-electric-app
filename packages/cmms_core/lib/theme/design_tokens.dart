import 'package:flutter/material.dart';

/// Canonical Be Electric design tokens (colors, spacing, radius, elevation).
abstract final class DesignTokens {
  // Color scheme
  static const Color primaryColor = Colors.black;
  static const Color primaryDarkColor = Colors.black;
  static const Color primaryLightColor = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceColor = Colors.white;
  static const Color cardBackgroundColor = Color(0xFFEEEEEE);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color disabledColor = Color(0xFFBDBDBD);
  static const Color secondaryTextColor = Color(0xFF757575);
  static const Color darkTextColor = Color(0xFF424242);

  // Accent colors
  static const Color accentBlue = Color(0xFF1976D2);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color accentGreen = Color(0xFF002911);
  static const Color accentOrange = Color(0xFFF57C00);
  static const Color accentPurple = Color(0xFF9C27B0);

  // Status colors (grey scale)
  static const Color activeColor = Color(0xFFF5F5F5);
  static const Color inactiveColor = Color(0xFFEEEEEE);
  static const Color writtenOffColor = Color(0xFFE0E0E0);
  static const Color pendingColor = Color(0xFFBDBDBD);
  static const Color completedColor = Color(0xFF9E9E9E);
  static const Color cancelledColor = Color(0xFF757575);

  // Work order status badge colors
  static const Color workOrderStatusOpen = Color(0xFF1565C0);
  static const Color workOrderStatusAssigned = Color(0xFFEF6C00);
  static const Color workOrderStatusInProgress = Color(0xFF6A1B9A);
  static const Color workOrderStatusCompleted = Color(0xFF2E7D32);
  static const Color workOrderStatusClosed = Color(0xFF455A64);
  static const Color workOrderStatusCancelled = Color(0xFFC62828);
  static const Color workOrderStatusReopened = Color(0xFF00695C);
  static const Color workOrderStatusPaused = Color(0xFFFF8F00);

  // PM task status colors
  static const Color pmTaskStatusPending = Color(0xFF5E35B1);
  static const Color pmTaskStatusInProgress = Color(0xFF0277BD);
  static const Color pmTaskStatusCompleted = Color(0xFF33691E);
  static const Color pmTaskStatusOverdue = Color(0xFFB71C1C);
  static const Color pmTaskStatusCancelled = Color(0xFF616161);

  // Priority colors
  static const Color lowPriorityColor = Color(0xFFE0E0E0);
  static const Color mediumPriorityColor = Color(0xFFBDBDBD);
  static const Color highPriorityColor = Color(0xFF9E9E9E);
  static const Color criticalPriorityColor = Color(0xFF757575);
  static const Color urgentPriorityColor = Color(0xFFFF7043);

  // Additional palette
  static const Color textColor = Colors.black87;
  static const Color cardColor = Colors.white;
  static const Color darkGrey = Color(0xFF424242);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color nearlyWhite = Color(0xFFFAFAFA);
  static const Color accentColor = Color(0xFF607D8B);
  static const Color white = Colors.white;

  static const Color errorColor = accentRed;
  static const Color successColor = accentGreen;
  static const Color warningColor = accentOrange;
  static const Color infoColor = accentGreen;

  // Spacing
  static const double spacingXS = 4;
  static const double spacingS = 8;
  static const double spacingM = 16;
  static const double spacingL = 20;
  static const double spacingXL = 24;
  static const double spacingXXL = 32;

  // Border radius
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;

  // Elevation
  static const double elevationS = 2;
  static const double elevationM = 4;
  static const double elevationL = 8;

  static const String fontFamily = 'Suisse Intl';
}
