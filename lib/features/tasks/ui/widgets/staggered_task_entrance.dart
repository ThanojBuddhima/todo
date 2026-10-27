import 'dart:async';

import 'package:flutter/material.dart';
import 'package:todo/core/theme/motion.dart';

class StaggeredTaskEntrance extends StatefulWidget {
  const StaggeredTaskEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<StaggeredTaskEntrance> createState() => _StaggeredTaskEntranceState();
}

class _StaggeredTaskEntranceState extends State<StaggeredTaskEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _delay;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.slow);
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
    );
    _opacity = animation;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(animation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppMotion.reduced(context);
    if (_reducedMotion == reduceMotion) return;
    _reducedMotion = reduceMotion;
    if (reduceMotion) {
      _delay?.cancel();
      _controller.value = 1;
    } else {
      final delayMilliseconds = widget.index.clamp(0, 9).toInt() * 40;
      _delay = Timer(Duration(milliseconds: delayMilliseconds), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
