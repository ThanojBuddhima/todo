import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

typedef ActivityRange = ({int startAtInclusive, int endAtExclusive});

final activityRangeProvider =
    FutureProvider.family<List<ActivityEntry>, ActivityRange>((
      ref,
      range,
    ) async {
      return ref
          .watch(activityDaoProvider)
          .getInRange(
            startAtInclusive: range.startAtInclusive,
            endAtExclusive: range.endAtExclusive,
          );
    });
