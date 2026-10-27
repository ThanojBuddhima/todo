import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

enum ReminderSchedulePrecision { exact, inexact }

typedef NotificationTapHandler = void Function(String? payload);

abstract interface class LocalNotificationDriver {
  Future<String?> initialize({
    required NotificationTapHandler onNotificationTap,
  });
  Future<void> createReminderChannel();
  Future<bool> requestNotificationPermission();
  Future<bool> areNotificationsEnabled();
  Future<bool> canScheduleExactNotifications();
  Future<bool> requestExactAlarmPermission();
  Future<void> schedule({
    required int id,
    required String title,
    required DateTime scheduledAt,
    required String payload,
    required ReminderSchedulePrecision precision,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

class NotificationService {
  NotificationService({
    LocalNotificationDriver? driver,
    Future<String> Function()? timezoneName,
  }) : _driver = driver ?? _FlutterLocalNotificationDriver(),
       _timezoneName = timezoneName ?? _deviceTimezoneName;

  static final NotificationService instance = NotificationService();

  final LocalNotificationDriver _driver;
  final Future<String> Function() _timezoneName;
  bool _initialized = false;
  String? _pendingTaskId;
  void Function(String taskId)? _taskTapHandler;

  static int generateNotificationId() {
    return Random.secure().nextInt(0x7fffffff) + 1;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    timezone_data.initializeTimeZones();
    final timezoneName = await _timezoneName();
    timezone.setLocalLocation(timezone.getLocation(timezoneName));
    final launchedTaskId = await _driver.initialize(
      onNotificationTap: _handleNotificationTap,
    );
    await _driver.createReminderChannel();
    _initialized = true;
    _handleNotificationTap(launchedTaskId);
  }

  void setTaskTapHandler(void Function(String taskId)? handler) {
    _taskTapHandler = handler;
    final pendingTaskId = _pendingTaskId;
    if (handler != null && pendingTaskId != null) {
      _pendingTaskId = null;
      handler(pendingTaskId);
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final handler = _taskTapHandler;
    if (handler == null) {
      _pendingTaskId = payload;
    } else {
      handler(payload);
    }
  }

  Future<ReminderSchedulePrecision?> requestReminderPermission() async {
    _ensureInitialized();
    if (!await _driver.requestNotificationPermission()) return null;

    return _getSchedulePrecision(requestPermission: true);
  }

  Future<ReminderSchedulePrecision> currentSchedulePrecision() {
    _ensureInitialized();
    return _getSchedulePrecision(requestPermission: false);
  }

  Future<bool> areNotificationsEnabled() {
    _ensureInitialized();
    return _driver.areNotificationsEnabled();
  }

  Future<ReminderSchedulePrecision> _getSchedulePrecision({
    required bool requestPermission,
  }) async {
    var canScheduleExactly = await _driver.canScheduleExactNotifications();
    if (!canScheduleExactly && requestPermission) {
      await _driver.requestExactAlarmPermission();
      canScheduleExactly = await _driver.canScheduleExactNotifications();
    }
    return canScheduleExactly
        ? ReminderSchedulePrecision.exact
        : ReminderSchedulePrecision.inexact;
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime remindAt,
    required String taskId,
    required ReminderSchedulePrecision precision,
  }) async {
    _ensureInitialized();
    if (!remindAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(remindAt, 'remindAt', 'Must be in the future.');
    }

    await _driver.schedule(
      id: id,
      title: title,
      scheduledAt: remindAt,
      payload: taskId,
      precision: precision,
    );
  }

  Future<void> cancelReminder(int id) async {
    _ensureInitialized();
    await _driver.cancel(id);
  }

  Future<void> cancelAllReminders() async {
    _ensureInitialized();
    await _driver.cancelAll();
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('NotificationService.initialize() must run first.');
    }
  }

  static Future<String> _deviceTimezoneName() async {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  }
}

class _FlutterLocalNotificationDriver implements LocalNotificationDriver {
  _FlutterLocalNotificationDriver({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'task_reminders';
  static const _channelName = 'Task reminders';
  static const _channelDescription = 'Reminders for your tasks';
  static const _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDescription,
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<String?> initialize({
    required NotificationTapHandler onNotificationTap,
  }) async {
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap(response.payload);
      },
    );
    if (initialized != true) {
      throw StateError('The local notifications plugin failed to initialize.');
    }
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    return launchDetails?.didNotificationLaunchApp == true
        ? launchDetails?.notificationResponse?.payload
        : null;
  }

  @override
  Future<void> createReminderChannel() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  @override
  Future<bool> requestNotificationPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    throw UnsupportedError('Notifications are unavailable on this platform.');
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    throw UnsupportedError('Notifications are unavailable on this platform.');
  }

  @override
  Future<bool> canScheduleExactNotifications() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestExactAlarmsPermission() ?? true;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required DateTime scheduledAt,
    required String payload,
    required ReminderSchedulePrecision precision,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: 'Task reminder',
      body: title,
      scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: precision == ReminderSchedulePrecision.exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
