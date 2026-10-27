import 'package:flutter/widgets.dart';

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration themeCrossFade = Duration(milliseconds: 300);
  static const Curve emphasized = Curves.easeOutCubic;

  /// Spring for the completion checkbox: slightly under-damped so the ring
  /// overshoots once before settling.
  static const SpringDescription checkboxSpring = SpringDescription(
    mass: 1,
    stiffness: 480,
    damping: 24,
  );

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Reads the accessibility flag without a [BuildContext] — needed above
  /// MaterialApp, where no MediaQuery exists yet.
  static bool get platformReduced =>
      WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
