import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:intl/intl.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/reminders/notification_service.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/domain/priority.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/widgets/task_subtasks_section.dart';

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
  DateTime? remindAt;
  String? categoryId;
  Priority priority = Priority.medium;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      titleController.text = widget.task!.title;
      notesController.text = widget.task!.notes ?? '';
      categoryId = widget.task!.categoryId;
      priority = widget.task!.priority;
      if (widget.task!.remindAt != null) {
        remindAt = DateTime.fromMillisecondsSinceEpoch(widget.task!.remindAt!);
      }
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                subtitle: Text(
                  remindAt == null
                      ? 'No reminder set'
                      : DateFormat('MMM d, y · h:mm a').format(remindAt!),
                ),
                value: remindAt != null,
                onChanged: _setReminderEnabled,
              ),
              const SizedBox(height: 12),
              categoriesAsync.when(
                data: (categories) => Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        borderRadius: BorderRadius.circular(
                          AppTheme.controlRadius,
                        ),
                        dropdownColor: Theme.of(context).cardTheme.color,
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
              SegmentedButton<Priority>(
                // The selected segment would otherwise gain a check icon and
                // widen, pushing the other two; without it the three keep the
                // same widths whatever is selected.
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: Priority.low, label: Text('Low')),
                  ButtonSegment(value: Priority.medium, label: Text('Medium')),
                  ButtonSegment(value: Priority.high, label: Text('High')),
                ],
                selected: {priority},
                onSelectionChanged: (value) =>
                    setState(() => priority = value.first),
              ),
              if (widget.task != null) ...[
                const SizedBox(height: 20),
                TaskSubtasksSection(taskId: widget.task!.id),
              ],
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

  Future<void> _setReminderEnabled(bool enabled) async {
    if (!enabled) {
      setState(() => remindAt = null);
      return;
    }

    final now = DateTime.now();
    final currentReminder = remindAt;
    final initialDate = currentReminder != null && currentReminder.isAfter(now)
        ? currentReminder
        : now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a reminder time in the future')),
      );
      return;
    }

    setState(() => remindAt = selected);
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
    final notificationService = ref.read(notificationServiceProvider);
    ReminderSchedulePrecision? reminderPrecision;
    if (remindAt != null) {
      try {
        reminderPrecision = await notificationService
            .requestReminderPermission();
      } on PlatformException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not request reminder permission: ${error.message ?? error.code}',
              ),
            ),
          );
        }
        return;
      }
    }
    final reminderPermissionDenied =
        remindAt != null && reminderPrecision == null;
    final savedRemindAt = reminderPrecision == null ? null : remindAt;
    final notificationId = savedRemindAt == null
        ? null
        : widget.task?.notificationId ??
              NotificationService.generateNotificationId();

    if (widget.task == null) {
      final taskId = await dao.createTask(
        title: title,
        notes: notesController.text.trim(),
        categoryId: categoryId,
        priority: priority,
        dueAt: dueDate?.millisecondsSinceEpoch,
        remindAt: savedRemindAt?.millisecondsSinceEpoch,
        notificationId: notificationId,
      );
      if (savedRemindAt != null && notificationId != null) {
        reminderPrecision = await _scheduleReminder(
          notificationService,
          taskId: taskId,
          notificationId: notificationId,
          title: title,
          remindAt: savedRemindAt,
          precision: reminderPrecision!,
          dao: dao,
        );
      }
    } else {
      final updated = Task(
        id: widget.task!.id,
        title: title,
        notes: notesController.text.trim(),
        categoryId: categoryId,
        priority: priority,
        dueAt: dueDate?.millisecondsSinceEpoch,
        remindAt: savedRemindAt?.millisecondsSinceEpoch,
        notificationId: notificationId,
        isDone: widget.task!.isDone,
        completedAt: widget.task!.completedAt,
        createdAt: widget.task!.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        sortIndex: widget.task!.sortIndex,
        deletedAt: widget.task!.deletedAt,
      );
      await dao.updateTask(updated);
      final oldNotificationId = widget.task!.notificationId;
      if (savedRemindAt != null && notificationId != null) {
        reminderPrecision = await _scheduleReminder(
          notificationService,
          taskId: widget.task!.id,
          notificationId: notificationId,
          title: title,
          remindAt: savedRemindAt,
          precision: reminderPrecision!,
          dao: dao,
        );
      } else if (oldNotificationId != null) {
        try {
          await notificationService.cancelReminder(oldNotificationId);
        } on PlatformException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Task saved, but its previous reminder could not be canceled: ${error.message ?? error.code}',
                ),
              ),
            );
          }
        }
      }
    }

    if (mounted) {
      if (reminderPermissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Task saved, but notifications are disabled; no reminder was set.',
            ),
          ),
        );
      } else if (reminderPrecision == ReminderSchedulePrecision.inexact) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reminder set, but exact alarms are unavailable and it may be delayed.',
            ),
          ),
        );
      }
      Navigator.of(context).pop();
      ref.invalidate(tasksProvider);
    }
  }

  Future<ReminderSchedulePrecision?> _scheduleReminder(
    NotificationService service, {
    required String taskId,
    required int notificationId,
    required String title,
    required DateTime remindAt,
    required ReminderSchedulePrecision precision,
    required TaskDao dao,
  }) async {
    try {
      await service.scheduleReminder(
        id: notificationId,
        title: title,
        remindAt: remindAt,
        taskId: taskId,
        precision: precision,
      );
      return precision;
    } on PlatformException catch (error) {
      await dao.updateReminder(taskId, remindAt: null, notificationId: null);
      var message =
          'Task saved, but its reminder failed: ${error.message ?? error.code}';
      try {
        await service.cancelReminder(notificationId);
      } on PlatformException catch (cancelError) {
        message =
            'Task saved, but the reminder failed and its previous notification could not be canceled: ${cancelError.message ?? cancelError.code}';
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return null;
    }
  }
}
