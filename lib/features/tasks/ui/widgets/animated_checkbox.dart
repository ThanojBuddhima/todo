import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:todo/core/theme/motion.dart';

/// Completion control for a task.
///
/// Checking runs in three overlapping stages — the ring collapses into a filled
/// disc, the disc springs past its resting size, and the check draws itself on
/// top — so the gesture reads as one continuous motion rather than a state
/// swap. Unchecking plays the same timeline in reverse.
class AnimatedCheckbox extends StatefulWidget {
  const AnimatedCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 28,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  State<AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fill;
  late final Animation<double> _check;
  late final Animation<double> _pop;
  late final Animation<double> _burst;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 260),
      value: widget.value ? 1 : 0,
    );

    // The disc lands early so the check has a solid surface to draw on.
    _fill = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.3, 1, curve: Curves.easeInCubic),
    );
    _check = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.55, 1, curve: Curves.easeInCubic),
    );
    // A single soft overshoot; easeOutBack supplies the spring without the
    // ringing a true under-damped simulation would add on every toggle.
    _pop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeIn,
    );
    // Expanding halo, visible only on the way in.
    _burst = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.75, curve: Curves.easeOutQuart),
      reverseCurve: const Threshold(1),
    );
  }

  @override
  void didUpdateWidget(AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    if (AppMotion.reduced(context)) {
      _controller.value = widget.value ? 1 : 0;
      return;
    }
    if (widget.value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    if (reduced) _controller.value = widget.value ? 1 : 0;

    return Semantics(
      button: true,
      checked: widget.value,
      label: widget.value ? 'Mark task as pending' : 'Complete task',
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: () {
            if (!widget.value) unawaited(HapticFeedback.lightImpact());
            widget.onChanged(!widget.value);
          },
          radius: widget.size,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Transform.scale(
                scale: reduced ? 1 : 0.9 + _pop.value * 0.1,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CheckboxPainter(
                    fill: _fill.value,
                    check: _check.value,
                    burst: reduced ? 0 : _burst.value,
                    checkedColor: theme.colorScheme.primary,
                    outlineColor: theme.colorScheme.outline,
                    checkColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({
    required this.fill,
    required this.check,
    required this.burst,
    required this.checkedColor,
    required this.outlineColor,
    required this.checkColor,
  });

  final double fill;
  final double check;
  final double burst;
  final Color checkedColor;
  final Color outlineColor;
  final Color checkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.5;

    // Halo: grows outward and fades as it goes.
    if (burst > 0 && burst < 1) {
      canvas.drawCircle(
        center,
        radius * (1 + burst * 0.6),
        Paint()
          ..color = checkedColor.withValues(alpha: 0.22 * (1 - burst))
          ..style = PaintingStyle.fill,
      );
    }

    // Ring thins out as the disc takes over, so the two never double up.
    if (fill < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Color.lerp(outlineColor, checkedColor, fill)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (fill > 0) {
      canvas.drawCircle(
        center,
        radius * Curves.easeOutCubic.transform(fill.clamp(0.0, 1.0)),
        Paint()
          ..color = checkedColor
          ..style = PaintingStyle.fill,
      );
    }

    if (check <= 0) return;

    final checkPath = Path()
      ..moveTo(size.width * 0.27, size.height * 0.51)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.75, size.height * 0.34);
    final metric = checkPath.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * check.clamp(0.0, 1.0)),
      Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckboxPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.check != check ||
      oldDelegate.burst != burst ||
      oldDelegate.checkedColor != checkedColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.checkColor != checkColor;
}
