import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ResponsiveLayout {
  // Breakpoints for different screen sizes
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // Get current screen type
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  // Check if current screen is mobile
  static bool isMobile(BuildContext context) => getScreenType(context) == ScreenType.mobile;

  // Check if current screen is tablet
  static bool isTablet(BuildContext context) => getScreenType(context) == ScreenType.tablet;

  // Check if current screen is desktop
  static bool isDesktop(BuildContext context) => getScreenType(context) == ScreenType.desktop;

  // Get responsive padding (aligned with AppTheme: 16 / 20 / 24)
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingM,
          vertical: DesignTokens.spacingM,
        );
      case ScreenType.tablet:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingL,
          vertical: DesignTokens.spacingL,
        );
      case ScreenType.desktop:
        return const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingXL,
          vertical: DesignTokens.spacingXL,
        );
    }
  }

  // Get responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.all(DesignTokens.spacingS);
      case ScreenType.tablet:
        return const EdgeInsets.all(DesignTokens.spacingM);
      case ScreenType.desktop:
        return const EdgeInsets.all(DesignTokens.spacingXL);
    }
  }

  // Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }

  // Get responsive icon size
  static double getResponsiveIconSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }

  // Get responsive grid columns
  static int getResponsiveColumns(
    BuildContext context, {
    required int mobile,
    required int tablet,
    required int desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }

  // Get responsive card width
  static double getResponsiveCardWidth(BuildContext context) {
    final screenType = getScreenType(context);
    final screenWidth = MediaQuery.of(context).size.width;

    switch (screenType) {
      case ScreenType.mobile:
        return screenWidth - 32; // Full width minus padding
      case ScreenType.tablet:
        return (screenWidth - 48) / 2; // Two columns
      case ScreenType.desktop:
        return (screenWidth - 64) / 3; // Three columns
    }
  }

  // Get responsive list item height
  static double getResponsiveListItemHeight(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 80;
      case ScreenType.tablet:
        return 100;
      case ScreenType.desktop:
        return 120;
    }
  }

  // Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 48;
      case ScreenType.tablet:
        return 56;
      case ScreenType.desktop:
        return 64;
    }
  }

  // Get responsive spacing
  static double getResponsiveSpacing(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }

  // Get responsive card height
  static double getResponsiveCardHeight(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 120;
      case ScreenType.tablet:
        return 140;
      case ScreenType.desktop:
        return 160;
    }
  }

  // Get responsive border radius
  static double getResponsiveBorderRadius(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 8;
      case ScreenType.tablet:
        return 12;
      case ScreenType.desktop:
        return 16;
    }
  }

  // Get responsive elevation
  static double getResponsiveElevation(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 4;
      case ScreenType.desktop:
        return 6;
    }
  }

  // Get max width for desktop content (prevents content from being too wide)
  static double getMaxContentWidth(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.tablet:
        return 800;
      case ScreenType.desktop:
        return 1400; // Optimal reading width for desktop
    }
  }

  // Get responsive form width (for login, forms, etc.)
  static double getFormMaxWidth(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.tablet:
        return 500;
      case ScreenType.desktop:
        return 450; // Narrower for forms on desktop
    }
  }

  // Get responsive horizontal padding for centered content
  static EdgeInsets getCenteredContentPadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.mobile:
        return const EdgeInsets.symmetric(horizontal: 16);
      case ScreenType.tablet:
        return const EdgeInsets.symmetric(horizontal: 48);
      case ScreenType.desktop:
        return const EdgeInsets.symmetric(horizontal: 120);
    }
  }
}

enum ScreenType {
  mobile,
  tablet,
  desktop,
}

// Responsive widget that adapts to screen size
class ResponsiveWidget extends StatelessWidget {

  const ResponsiveWidget({
    required this.mobile, super.key,
    this.tablet,
    this.desktop,
  });
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveLayout.getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

// Responsive grid widget
class ResponsiveGrid extends StatelessWidget {

  const ResponsiveGrid({
    required this.children, super.key,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
  });
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.getResponsiveColumns(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final availableWidth = screenWidth - padding.horizontal;
    final itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: children.map((child) => SizedBox(
          width: itemWidth,
          child: child,
        ),).toList(),
    );
  }
}

// Responsive container that adapts to screen size
class ResponsiveContainer extends StatelessWidget {

  const ResponsiveContainer({
    required this.child, super.key,
    this.maxWidth,
    this.padding,
    this.margin,
    this.centerContent = false,
  });
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveLayout.getScreenType(context);
    final screenWidth = MediaQuery.of(context).size.width;

    double containerMaxWidth;
    switch (screenType) {
      case ScreenType.mobile:
        containerMaxWidth = screenWidth;
        break;
      case ScreenType.tablet:
        containerMaxWidth = maxWidth ?? 800;
        break;
      case ScreenType.desktop:
        containerMaxWidth = maxWidth ?? ResponsiveLayout.getMaxContentWidth(context);
        break;
    }

    Widget content = Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: containerMaxWidth),
      padding: padding ?? ResponsiveLayout.getResponsivePadding(context),
      margin: margin ?? ResponsiveLayout.getResponsiveMargin(context),
      child: child,
    );

    if (centerContent && screenType != ScreenType.mobile) {
      return Center(child: content);
    }

    return content;
  }
}

// Responsive text widget
class ResponsiveText extends StatelessWidget {

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveLayout.getScreenType(context);

    double fontSize = 14;
    if (style?.fontSize != null) {
      fontSize = style!.fontSize!;
    }

    // Scale font size based on screen type
    switch (screenType) {
      case ScreenType.mobile:
        break; // Keep original size
      case ScreenType.tablet:
        fontSize *= 1.1;
        break;
      case ScreenType.desktop:
        fontSize *= 1.2;
        break;
    }

    return Text(
      text,
      style:
          style?.copyWith(fontSize: fontSize) ?? TextStyle(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// Responsive button widget
class ResponsiveButton extends StatelessWidget {

  const ResponsiveButton({
    required this.text, super.key,
    this.onPressed,
    this.icon,
    this.style,
    this.isFullWidth = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonStyle? style;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = ResponsiveLayout.getResponsiveButtonHeight(context);
    final isTabletOrLarger = ResponsiveLayout.isTablet(context) ||
        ResponsiveLayout.isDesktop(context);

    final Widget button = ElevatedButton(
      onPressed: onPressed,
      style: style?.copyWith(
            minimumSize: WidgetStateProperty.all(
              Size(isFullWidth ? double.infinity : 0, buttonHeight),
            ),
          ) ??
          ElevatedButton.styleFrom(
            minimumSize: Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
      child: isTabletOrLarger && icon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(text),
              ],
            )
          : icon != null
              ? Icon(icon)
              : Text(text),
    );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}
