import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

void main() {
  final now = DateTime.now();
  final todayDue = DateTime(
    now.year,
    now.month,
    now.day,
    9,
  ).millisecondsSinceEpoch;
  final tomorrowDue = DateTime(
    now.year,
    now.month,
    now.day + 1,
    9,
  ).millisecondsSinceEpoch;

  final tasks = [
    Task(
      id: '1',
      title: 'Plan sprint review',
      notes: 'Prepare deck for engineering sync',
      categoryId: 'work',
      priority: 2,
      dueAt: todayDue,
      isDone: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      sortIndex: 1,
    ),
    Task(
      id: '2',
      title: 'Book dentist appointment',
      notes: 'Call clinic after work',
      categoryId: 'personal',
      priority: 1,
      dueAt: tomorrowDue,
      isDone: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      sortIndex: 2,
    ),
    Task(
      id: '3',
      title: 'Pay rent',
      categoryId: 'personal',
      priority: 1,
      isDone: true,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      sortIndex: 3,
    ),
  ];

  test('matches text, category, and status filters', () {
    final filter = TaskFilter(
      mode: TaskFilterMode.pending,
      query: 'sprint',
      categoryId: 'work',
    );
    expect(tasks.where(filter.matches).length, 1);
    expect(tasks.where(filter.matches).first.title, 'Plan sprint review');

    final todayFilter = TaskFilter(mode: TaskFilterMode.today);
    expect(tasks.where(todayFilter.matches).single.title, 'Plan sprint review');

    final doneFilter = TaskFilter(mode: TaskFilterMode.done);
    expect(tasks.where(doneFilter.matches).single.id, '3');
  });

  test('upcoming filter excludes today and completed tasks', () {
    final upcomingFilter = TaskFilter(mode: TaskFilterMode.upcoming);
    final upcoming = tasks.where(upcomingFilter.matches).toList();
    expect(upcoming, hasLength(1));
    expect(upcoming.single.title, 'Book dentist appointment');
  });

  test('changing status keeps the selected category', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(taskFilterProvider.notifier);
    controller.setCategory('work');
    controller.setMode(TaskFilterMode.done);

    expect(container.read(taskFilterProvider).categoryId, 'work');
    expect(container.read(taskFilterProvider).mode, TaskFilterMode.done);
  });

  test('search query updates after the debounce interval', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(taskFilterProvider.notifier).setQuery('appointment');
    expect(container.read(taskFilterProvider).query, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(container.read(taskFilterProvider).query, 'appointment');
  });

  test('reset cancels a pending search query', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(taskFilterProvider.notifier);
    controller.setQuery('stale');
    controller.reset();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(container.read(taskFilterProvider).query, isEmpty);
  });
}
