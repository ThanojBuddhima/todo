import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/app.dart';
import 'package:todo/features/reminders/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reminders are a secondary feature: if the platform provides no
  // notification plugin, or init fails, the app must still start.
  try {
    await NotificationService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Reminder setup failed; continuing without it: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(const ProviderScope(child: App()));
}
