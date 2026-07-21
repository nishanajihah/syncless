import 'package:flutter/material.dart';

import 'features/workspace/presentation/workspace_page.dart';

class SynclessApp extends StatelessWidget {
  const SynclessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Syncless',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C8CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const WorkspacePage(),
    );
  }
}
