import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/main_navigation.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final SupabaseClient supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        final Session? session =
            snapshot.data?.session ?? supabase.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        return const MainNavigation();
      },
    );
  }
}
