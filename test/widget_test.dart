// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app.dart';
import 'package:todo/features/reminders/notification_service.dart';
import 'package:todo/features/tasks/providers/task_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final notificationService = NotificationService(
      driver: _FakeNotificationDriver(),
      timezoneName: () async => 'America/Los_Angeles',
    );
    await notificationService.initialize();
    const secureStorageChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: const App(),
      ),
    );
    for (
      var attempt = 0;
      attempt < 10 && !tester.any(find.text('Add task'));
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Add task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeNotificationDriver implements LocalNotificationDriver {
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
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}
