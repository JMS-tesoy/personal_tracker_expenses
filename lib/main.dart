import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/reminders/data/repositories/reminder_repository.dart';
import 'features/reminders/services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dayxpfcxublzfqcixxru.supabase.co',
    anonKey: 'sb_publishable_RBQm_PxXT2B8wYudrfeoQA_Gu3oOdE0',
  );

  await LocalNotificationService.instance.initialize();
  await LocalNotificationService.instance.requestPermission();

  if (Supabase.instance.client.auth.currentSession != null) {
    await ReminderRepository.instance.syncPendingLocalNotifications();
  }

  runApp(const App());
}
