import 'package:flutter/material.dart';
import '../features/auth/presentation/screens/auth_gate.dart';
import '../shared/widgets/app_texture_background.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF8F98A3),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF2F343A),
          surfaceContainerHighest: const Color(0xFF252A31),
          primary: const Color(0xFFE6E8EA),
          onPrimary: const Color(0xFF171A1F),
          secondary: const Color(0xFF9CA6B2),
          onSurface: const Color(0xFFE8EAED),
          onSurfaceVariant: const Color(0xFFB2BAC4),
          outline: const Color(0xFF4A515B),
          outlineVariant: const Color(0xFF1D2228),
          error: const Color(0xFFFF6B6B),
        );

    return MaterialApp(
      title: 'Payday Financial Control System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          foregroundColor: Color(0xFFE8EAED),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF252A31),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF15191F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF15191F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE6E8EA), width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE6E8EA),
            foregroundColor: const Color(0xFF171A1F),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE6E8EA),
            foregroundColor: const Color(0xFF171A1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return AppTextureBackground(child: child ?? const SizedBox.shrink());
      },
      home: const AuthGate(),
    );
  }
}
