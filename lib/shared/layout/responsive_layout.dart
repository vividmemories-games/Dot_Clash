import 'package:flutter/material.dart';

/// Responsive breakpoint helpers.
abstract final class Breakpoints {
  static const double phone = 600;
  static const double tablet = 900;
}

/// Returns true when the screen is a phone (width < 600).
bool isPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.phone;

/// Returns true when the screen is a tablet (width >= 600).
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.phone;

/// Picks a value based on screen width category.
T responsive<T>(
  BuildContext context, {
  required T phone,
  T? tablet,
}) {
  if (isTablet(context) && tablet != null) return tablet;
  return phone;
}

/// Widget that shows different layouts for phone vs tablet.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
  });

  final Widget phone;
  final Widget? tablet;

  @override
  Widget build(BuildContext context) {
    if (isTablet(context) && tablet != null) return tablet!;
    return phone;
  }
}

/// Constrains content to a max width (useful on tablets).
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
