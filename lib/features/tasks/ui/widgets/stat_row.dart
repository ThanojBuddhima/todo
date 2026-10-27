import 'package:flutter/material.dart';
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
        _StatCard(label: 'Today', count: today),
        const SizedBox(width: 8),
        _StatCard(label: 'Pending', count: pending),
        const SizedBox(width: 8),
        _StatCard(label: 'Done', count: done),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              AnimatedCount(
                value: count,
                style: theme.textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
