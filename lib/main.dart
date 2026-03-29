import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/auth_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme(
      bodyMedium: GoogleFonts.inter(),
      bodyLarge: GoogleFonts.inter(),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w500),
    );

    return MaterialApp(
      title: 'Mercado App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: textTheme,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: textTheme,
      ),
      home: Consumer<AuthState>(
        builder: (context, auth, _) {
          // ── Loading: checking saved session ──────────────────────────
          if (auth.status == AuthStatus.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // ── Not logged in: show login screen ─────────────────────────
          if (auth.status == AuthStatus.unauthenticated) {
            return const LoginScreen();
          }

          // ── Authenticated: mount AppState scoped to this user ────────
          return ChangeNotifierProvider(
            key: ValueKey(auth.userId), // rebuild AppState when user changes
            create: (_) => AppState(
              userId: auth.userId!,
              pb: auth.pb,
            ),
            child: const HomeScreen(),
          );
        },
      ),
    );
  }
}
