import 'package:flutter/material.dart';
import 'package:todo/core/theme/motion.dart';

class AnimatedCount extends StatefulWidget {
  const AnimatedCount({super.key, required this.value, required this.style});

  final int value;
  final TextStyle? style;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> {
  late int _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: _previousValue.toDouble(),
        end: widget.value.toDouble(),
      ),
      duration: AppMotion.duration(context, AppMotion.base),
      curve: AppMotion.emphasized,
      builder: (context, value, child) =>
          Text(value.round().toString(), style: widget.style),
    );
  }
}
