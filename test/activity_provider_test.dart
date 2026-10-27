import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/activity/providers/activity_providers.dart';
import 'package:todo/features/tasks/data/activity_dao.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

void main() {
  test(
    'activity range provider forwards bounds and returns matching entries',
    () async {
      final dao = _FakeActivityDao();
      final container = ProviderContainer(
        overrides: [activityDaoProvider.overrideWithValue(dao)],
      );
      addTearDown(container.dispose);
      const range = (startAtInclusive: 100, endAtExclusive: 200);

      final entries = await container.read(activityRangeProvider(range).future);

      expect(dao.requestedRange, range);
      expect(entries, [dao.entry]);
    },
  );
}

class _FakeActivityDao extends ActivityDao {
  final entry = const ActivityEntry(
    id: 1,
    taskTitle: 'Example task',
    action: 0,
    occurredAt: 150,
  );
  ActivityRange? requestedRange;

  @override
  Future<List<ActivityEntry>> getInRange({
    required int startAtInclusive,
    required int endAtExclusive,
    int? limit,
  }) async {
    requestedRange = (
      startAtInclusive: startAtInclusive,
      endAtExclusive: endAtExclusive,
    );
    return [entry];
  }
}
