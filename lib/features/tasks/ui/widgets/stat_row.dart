import 'package:flutter/material.dart';
import 'package:todo/core/theme/app_colors.dart';
import 'package:todo/features/tasks/ui/widgets/animated_count.dart';

class StatRow extends StatelessWidget {
  const StatRow({
    super.key,
    required this.today,
    required this.pending,
    required this.done,
  });

  final int today;
  final int pending;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Today',
          count: today,
          accent: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Pending',
          count: pending,
          accent: AppColors.mediumPriority,
        ),
        const SizedBox(width: 8),
        _StatCard(label: 'Done', count: done, accent: AppColors.done),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.accent,
  });

  final String label;
  final int count;

  /// Hue that identifies the metric: the label and the number both take it, and
  /// the card is tinted with the same colour so the three read apart at a
  /// glance. [AppColors.onSoft] keeps the text above 4.5:1 on that tint.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final fill = AppColors.soft(accent, brightness);
    final ink = AppColors.onSoft(accent, brightness);

    return Expanded(
      child: Card(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: ink),
              ),
              const SizedBox(height: 8),
              AnimatedCount(
                value: count,
                style: theme.textTheme.headlineMedium?.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
