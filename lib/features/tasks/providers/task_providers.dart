import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/tasks/data/activity_dao.dart';
import 'package:todo/features/tasks/data/category_dao.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/data/subtask_dao.dart';
import 'package:todo/features/tasks/domain/category.dart';
import 'package:todo/features/tasks/domain/activity_entry.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/domain/task_filter.dart';

final taskDaoProvider = Provider<TaskDao>((ref) => TaskDao());
final activityDaoProvider = Provider<ActivityDao>((ref) => ActivityDao());
final categoryDaoProvider = Provider<CategoryDao>((ref) => CategoryDao());
final subtaskDaoProvider = Provider<SubtaskDao>((ref) => SubtaskDao());

final tasksProvider = FutureProvider<List<Task>>((ref) async {
  final dao = ref.watch(taskDaoProvider);
  return dao.getTasks();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final dao = ref.watch(categoryDaoProvider);
  return dao.getCategories();
});

final taskByIdProvider = FutureProvider.family<Task?, String>((ref, id) async {
  return ref.watch(taskDaoProvider).getTaskById(id);
});

final subtasksProvider = FutureProvider.family<List<Subtask>, String>((
  ref,
  taskId,
) async {
  return ref.watch(subtaskDaoProvider).getForTask(taskId);
});

final taskActivityProvider = FutureProvider.family<List<ActivityEntry>, String>(
  (ref, taskId) async {
    return ref.watch(activityDaoProvider).getForTask(taskId);
  },
);

class TaskFilterController extends StateNotifier<TaskFilter> {
  TaskFilterController() : super(const TaskFilter());

  Timer? _queryDebounce;

  void setMode(TaskFilterMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
    );
  }

  void setQuery(String query) {
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 250), () {
      state = state.copyWith(query: query);
    });
  }

  void reset() {
    _queryDebounce?.cancel();
    state = const TaskFilter();
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    super.dispose();
  }
}

final taskFilterProvider =
    StateNotifierProvider<TaskFilterController, TaskFilter>((ref) {
      return TaskFilterController();
    });

final filteredTasksProvider = FutureProvider<List<Task>>((ref) async {
  final tasks = await ref.watch(tasksProvider.future);
  final filter = ref.watch(taskFilterProvider);
  return tasks.where(filter.matches).toList();
});
