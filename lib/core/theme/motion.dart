import 'package:flutter/widgets.dart';

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 460);
  static const Duration themeCrossFade = Duration(milliseconds: 340);

  /// Default easing for state changes: a long, soft tail so motion settles
  /// instead of snapping.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Entrances and reveals. Quart decelerates harder than cubic, which reads as
  /// "floating into place" rather than sliding to a stop.
  static const Curve entrance = Curves.easeOutQuart;

  /// Two-way moves that both start and end on screen (expand/collapse, reorder).
  static const Curve standard = Curves.easeInOutCubicEmphasized;

  /// Per-item delay in a staggered list reveal.
  static const Duration stagger = Duration(milliseconds: 55);

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
  static bool get platformReduced => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  static Duration duration(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
