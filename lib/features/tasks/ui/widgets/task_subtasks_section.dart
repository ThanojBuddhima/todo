import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/features/tasks/domain/subtask.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/widgets/subtask_tile.dart';

class TaskSubtasksSection extends ConsumerStatefulWidget {
  const TaskSubtasksSection({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskSubtasksSection> createState() =>
      _TaskSubtasksSectionState();
}

class _TaskSubtasksSectionState extends ConsumerState<TaskSubtasksSection> {
  final _newSubtaskController = TextEditingController();

  @override
  void dispose() {
    _newSubtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtasksAsync = ref.watch(subtasksProvider(widget.taskId));

    return subtasksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Could not load subtasks: $error'),
      ),
      data: (subtasks) {
        final completed = subtasks.where((subtask) => subtask.isDone).length;
        final progress = subtasks.isEmpty ? 0.0 : completed / subtasks.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subtasks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('$completed/${subtasks.length}'),
                const SizedBox(width: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) => SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ],
            ),
            if (subtasks.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subtasks.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorder(subtasks, oldIndex, newIndex),
                itemBuilder: (context, index) {
                  final subtask = subtasks[index];
                  return Padding(
                    key: ValueKey(subtask.id),
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_handle, size: 20),
                        Expanded(
                          child: SubtaskTile(
                            key: ValueKey('tile-${subtask.id}'),
                            subtask: subtask,
                            onToggle: (isDone) async {
                              await _mutate(
                                () => ref
                                    .read(subtaskDaoProvider)
                                    .toggleSubtask(subtask.id, isDone),
                              );
                            },
                            onRename: (title) async {
                              await _mutate(
                                () => ref
                                    .read(subtaskDaoProvider)
                                    .renameSubtask(subtask.id, title),
                              );
                            },
                            onDelete: () async {
                              await _mutate(
                                () => ref
                                    .read(subtaskDaoProvider)
                                    .deleteSubtask(subtask.id),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubtaskController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addSubtask(),
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add subtask',
                  onPressed: _addSubtask,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSubtask() async {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;
    final saved = await _mutate(
      () => ref.read(subtaskDaoProvider).addSubtask(widget.taskId, title),
    );
    if (mounted && saved) _newSubtaskController.clear();
  }

  Future<void> _reorder(
    List<Subtask> subtasks,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = [...subtasks];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await _mutate(
      () => ref
          .read(subtaskDaoProvider)
          .reorderSubtasks(
            widget.taskId,
            reordered.map((subtask) => subtask.id).toList(),
          ),
    );
  }

  Future<bool> _mutate(Future<void> Function() operation) async {
    try {
      await operation();
      if (!mounted) return false;
      ref.invalidate(subtasksProvider(widget.taskId));
      ref.invalidate(taskActivityProvider(widget.taskId));
      ref.invalidate(tasksProvider);
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update subtasks: $error')),
      );
      return false;
    }
  }
}
