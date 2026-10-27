import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/reminders/notification_service.dart';
import 'package:todo/features/tasks/data/task_dao.dart';
import 'package:todo/features/tasks/domain/priority.dart';
import 'package:todo/features/tasks/domain/task.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';
import 'package:todo/features/tasks/ui/task_editor_sheet.dart';

void main() {
  testWidgets('saving a task schedules and persists its reminder', (
    tester,
  ) async {
    final remindAt = DateTime.now().add(const Duration(days: 1));
    final task = _task(remindAt);
    final dao = _ReminderTaskDao();
    final driver = _FakeNotificationDriver();
    final notificationService = NotificationService(
      driver: driver,
      timezoneName: () async => 'America/Los_Angeles',
    );
    await notificationService.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDaoProvider.overrideWithValue(dao),
          notificationServiceProvider.overrideWithValue(notificationService),
          categoriesProvider.overrideWith((ref) async => []),
          subtasksProvider(task.id).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TaskEditorSheet(task: task),
                ),
                child: const Text('Edit task'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit task'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(dao.updatedTask?.remindAt, remindAt.millisecondsSinceEpoch);
    expect(dao.updatedTask?.notificationId, 42);
    expect(
      driver.scheduledAt,
      DateTime.fromMillisecondsSinceEpoch(remindAt.millisecondsSinceEpoch),
    );
    expect(driver.scheduledPayload, task.id);
  });
}

Task _task(DateTime remindAt) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Task(
    id: 'reminder-task',
    title: 'Review notes',
    priority: Priority.medium,
    remindAt: remindAt.millisecondsSinceEpoch,
    notificationId: 42,
    isDone: false,
    createdAt: now,
    updatedAt: now,
    sortIndex: now.toDouble(),
  );
}

class _ReminderTaskDao extends TaskDao {
  Task? updatedTask;

  @override
  Future<void> updateTask(Task task) async {
    updatedTask = task;
  }
}

class _FakeNotificationDriver implements LocalNotificationDriver {
  DateTime? scheduledAt;
  String? scheduledPayload;

  @override
  Future<String?> initialize({
    required NotificationTapHandler onNotificationTap,
  }) async => null;

  @override
  Future<void> createReminderChannel() async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> areNotificationsEnabled() async => true;

  @override
  Future<bool> canScheduleExactNotifications() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required DateTime scheduledAt,
    required String payload,
    required ReminderSchedulePrecision precision,
  }) async {
    this.scheduledAt = scheduledAt;
    scheduledPayload = payload;
  }

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
