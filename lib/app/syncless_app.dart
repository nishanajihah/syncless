import 'package:flutter/material.dart';

import '../core/routing/app_router.dart';

class SynclessApp extends StatelessWidget {
  const SynclessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Syncless',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: _darkTheme,
      routerConfig: appRouter,
    );
  }
}

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFB8A9FF),
    onPrimary: Color(0xFF211B4A),
    primaryContainer: Color(0xFF39306F),
    onPrimaryContainer: Color(0xFFE8E0FF),
    secondary: Color(0xFF8FDCFF),
    surface: Color(0xFF121214),
    onSurface: Color(0xFFF2F0F4),
    surfaceContainerHighest: Color(0xFF27262B),
    onSurfaceVariant: Color(0xFFCAC5CF),
    outline: Color(0xFF938E99),
    error: Color(0xFFFFB4AB),
  ),
  scaffoldBackgroundColor: const Color(0xFF0B0B0D),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFFF2F0F4),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF29282E),
    space: 1,
    thickness: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF16161A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF343239)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF343239)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB8A9FF), width: 1.5),
    ),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF16161A),
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
