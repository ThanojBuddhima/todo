import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:todo/core/theme/motion.dart';

class AnimatedCheckbox extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      checked: value,
      label: value ? 'Mark task as pending' : 'Complete task',
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: () {
            if (!value) unawaited(HapticFeedback.lightImpact());
            onChanged(!value);
          },
          radius: size,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value ? 1 : 0),
              duration: AppMotion.duration(context, AppMotion.base),
              curve: AppMotion.emphasized,
              builder: (context, progress, child) => Transform.scale(
                scale: 0.92 + progress * 0.08,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _CheckboxPainter(
                    progress: progress,
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
    required this.progress,
    required this.checkedColor,
    required this.outlineColor,
    required this.checkColor,
  });

  final double progress;
  final Color checkedColor;
  final Color outlineColor;
  final Color checkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.5;
    final fill = Paint()
      ..color = Color.lerp(Colors.transparent, checkedColor, progress)!
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = Color.lerp(outlineColor, checkedColor, progress)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, fill);
    if (progress < 1) canvas.drawCircle(center, radius, outline);
    if (progress <= 0) return;

    final checkPath = Path()
      ..moveTo(size.width * 0.27, size.height * 0.51)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.75, size.height * 0.34);
    final metric = checkPath.computeMetrics().first;
    final tracedPath = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      tracedPath,
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
      oldDelegate.progress != progress ||
      oldDelegate.checkedColor != checkedColor ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.checkColor != checkColor;
}
