import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dayxpfcxublzfqcixxru.supabase.co',
    anonKey: 'sb_publishable_RBQm_PxXT2B8wYudrfeoQA_Gu3oOdE0',
  );

  runApp(const App());
}
