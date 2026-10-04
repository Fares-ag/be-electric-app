import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Canonical Be Electric typography styles.
abstract final class AppTypography {
  static const TextStyle heading1 = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: DesignTokens.primaryColor,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: DesignTokens.primaryColor,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: DesignTokens.darkTextColor,
  );

  static const TextStyle secondaryText = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: DesignTokens.secondaryTextColor,
  );

  static const TextStyle smallText = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: DesignTokens.secondaryTextColor,
  );

  static const TextStyle headline4 = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: DesignTokens.primaryColor,
  );

  static const TextStyle headline6 = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: DesignTokens.primaryColor,
  );

  static const TextStyle captionText = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: DesignTokens.secondaryTextColor,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  /// Used by asset selection widgets.
  static const TextStyle heading3 = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: DesignTokens.primaryColor,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: DesignTokens.primaryColor,
  );

  static const TextStyle label = TextStyle(
    fontFamily: DesignTokens.fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: DesignTokens.secondaryTextColor,
  );

  // Legacy aliases
  static const TextStyle titleStyle = heading1;
  static const TextStyle subtitleStyle = secondaryText;
  static const TextStyle bodyStyle = bodyText;
  static const TextStyle captionStyle = smallText;
}
