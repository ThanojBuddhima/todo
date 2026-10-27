import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/reminders/notification_service.dart';

void main() {
  test(
    'initializes timezone and creates the notification channel once',
    () async {
      final driver = _FakeNotificationDriver();
      final service = NotificationService(
        driver: driver,
        timezoneName: () async => 'America/Los_Angeles',
      );

      await service.initialize();
      await service.initialize();

      expect(driver.initializeCount, 1);
      expect(driver.channelCount, 1);
    },
  );

  test(
    'delivers notification taps received before a handler is registered',
    () async {
      final driver = _FakeNotificationDriver(initialTaskId: 'launched-task');
      final service = NotificationService(
        driver: driver,
        timezoneName: () async => 'America/Los_Angeles',
      );
      await service.initialize();

      final openedTaskIds = <String>[];
      service.setTaskTapHandler(openedTaskIds.add);
      driver.onNotificationTap?.call('tapped-task');

      expect(openedTaskIds, ['launched-task', 'tapped-task']);
    },
  );

  test(
    'falls back to inexact scheduling when exact alarms are denied',
    () async {
      final driver = _FakeNotificationDriver(canScheduleExactly: false);
      final service = NotificationService(
        driver: driver,
        timezoneName: () async => 'America/Los_Angeles',
      );
      await service.initialize();

      final precision = await service.requestReminderPermission();
      expect(precision, ReminderSchedulePrecision.inexact);
      expect(driver.exactPermissionRequested, isTrue);

      final remindAt = DateTime.now().add(const Duration(days: 1));
      await service.scheduleReminder(
        id: 12,
        title: 'Review notes',
        remindAt: remindAt,
        taskId: 'task-12',
        precision: precision!,
      );

      expect(driver.scheduledAt, remindAt);
      expect(driver.scheduledPrecision, ReminderSchedulePrecision.inexact);
      expect(driver.scheduledPayload, 'task-12');
    },
  );

  test(
    'does not request exact alarms when notification permission is denied',
    () async {
      final driver = _FakeNotificationDriver(notificationPermission: false);
      final service = NotificationService(
        driver: driver,
        timezoneName: () async => 'America/Los_Angeles',
      );
      await service.initialize();

      expect(await service.requestReminderPermission(), isNull);
      expect(driver.exactPermissionRequested, isFalse);
    },
  );

  test(
    'rejects scheduling before initialization and for past reminders',
    () async {
      final service = NotificationService(
        driver: _FakeNotificationDriver(),
        timezoneName: () async => 'America/Los_Angeles',
      );

      await expectLater(service.cancelReminder(1), throwsA(isA<StateError>()));

      await service.initialize();
      final precision = await service.requestReminderPermission();
      await expectLater(
        service.scheduleReminder(
          id: 1,
          title: 'Past reminder',
          remindAt: DateTime.now().subtract(const Duration(minutes: 1)),
          taskId: 'task-1',
          precision: precision!,
        ),
        throwsArgumentError,
      );
    },
  );
}

class _FakeNotificationDriver implements LocalNotificationDriver {
  _FakeNotificationDriver({
    this.notificationPermission = true,
    this.canScheduleExactly = true,
    this.initialTaskId,
  });

  final bool notificationPermission;
  final bool canScheduleExactly;
  final String? initialTaskId;
  int initializeCount = 0;
  int channelCount = 0;
  bool exactPermissionRequested = false;
  NotificationTapHandler? onNotificationTap;
  DateTime? scheduledAt;
  String? scheduledPayload;
  ReminderSchedulePrecision? scheduledPrecision;

  @override
  Future<String?> initialize({
    required NotificationTapHandler onNotificationTap,
  }) async {
    initializeCount++;
    this.onNotificationTap = onNotificationTap;
    return initialTaskId;
  }

  @override
  Future<void> createReminderChannel() async {
    channelCount++;
  }

  @override
  Future<bool> requestNotificationPermission() async => notificationPermission;

  @override
  Future<bool> canScheduleExactNotifications() async => canScheduleExactly;

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactPermissionRequested = true;
    return false;
  }

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
    scheduledPrecision = precision;
  }

  @override
  Future<void> cancel(int id) async {}
}
