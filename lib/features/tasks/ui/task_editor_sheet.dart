import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  final titleController = TextEditingController();
  final notesController = TextEditingController();
  DateTime? dueDate;
  String? categoryId;
  int priority = 1;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      titleController.text = widget.task!.title;
      notesController.text = widget.task!.notes ?? '';
      categoryId = widget.task!.categoryId;
      priority = widget.task!.priority;
      if (widget.task!.dueAt != null) {
        dueDate = DateTime.fromMillisecondsSinceEpoch(widget.task!.dueAt!);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.task == null ? 'New task' : 'Edit task',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDateAndTime,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        dueDate == null
                            ? 'Add due date'
                            : DateFormat('MMM d, y · h:mm a').format(dueDate!),
                      ),
                    ),
                  ),
                  if (dueDate != null)
                    IconButton(
                      onPressed: () => setState(() => dueDate = null),
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear due date',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) => Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            categories.any(
                              (category) => category.id == categoryId,
                            )
                            ? categoryId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => categoryId = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _createCategory(),
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add category',
                    ),
                  ],
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Low')),
                  ButtonSegment(value: 1, label: Text('Medium')),
                  ButtonSegment(value: 2, label: Text('High')),
                ],
                selected: {priority},
                onSelectionChanged: (value) =>
                    setState(() => priority = value.first),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save),
                  label: Text(
                    widget.task == null ? 'Create task' : 'Save changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateAndTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;

    final currentTime = dueDate ?? now;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
    );
    if (!mounted) return;

    setState(() {
      dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? currentTime.hour,
        time?.minute ?? currentTime.minute,
      );
    });
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final dao = ref.read(categoryDaoProvider);
    final createdId = await dao.createCategory(result);
    setState(() => categoryId = createdId);
    ref.invalidate(categoriesProvider);
  }

  Future<void> _submit() async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task title is required')));
      return;
    }

    final dao = ref.read(taskDaoProvider);
    if (widget.task == null) {
      await dao.createTask(
        title: title,
        notes: notesController.text.trim(),
        categoryId: categoryId,
        priority: priority,
        dueAt: dueDate?.millisecondsSinceEpoch,
      );
    } else {
      final updated = Task(
        id: widget.task!.id,
        title: title,
        notes: notesController.text.trim(),
        categoryId: categoryId,
        priority: priority,
        dueAt: dueDate?.millisecondsSinceEpoch,
        remindAt: widget.task!.remindAt,
        notificationId: widget.task!.notificationId,
        isDone: widget.task!.isDone,
        completedAt: widget.task!.completedAt,
        createdAt: widget.task!.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        sortIndex: widget.task!.sortIndex,
        deletedAt: widget.task!.deletedAt,
      );
      await dao.updateTask(updated);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ref.invalidate(tasksProvider);
    }
  }
}
