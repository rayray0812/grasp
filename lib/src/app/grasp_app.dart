import 'package:flutter/material.dart';

import '../data/hive_grasp_repository.dart';
import '../ui/home_screen.dart';
import '../ui/import_screen.dart';
import '../ui/library_screen.dart';
import '../ui/settings_screen.dart';
import 'app_controller.dart';

class GraspApp extends StatefulWidget {
  const GraspApp({super.key});

  @override
  State<GraspApp> createState() => _GraspAppState();
}

class _GraspAppState extends State<GraspApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(repository: HiveGraspRepository());
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Grasp',
    debugShowCheckedModeBanner: false,
    theme: _theme(),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) return const _LoadingScreen();
        if (controller.error != null) {
          return _ErrorScreen(message: controller.error!);
        }
        return AppShell(controller: controller);
      },
    ),
  );
}

ThemeData _theme() {
  const seed = Color(0xFF315C4C);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
    surface: const Color(0xFFF8F7F2),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8F7F2),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7E3D9)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2DED4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2DED4)),
      ),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: index,
        children: [
          HomeScreen(controller: widget.controller),
          LibraryScreen(controller: widget.controller),
          ImportScreen(controller: widget.controller),
          SettingsScreen(controller: widget.controller),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today_rounded),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: '單字庫',
        ),
        NavigationDestination(
          icon: Icon(Icons.file_download_outlined),
          selectedIcon: Icon(Icons.file_download_rounded),
          label: 'Import',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune_rounded),
          label: '設定',
        ),
      ],
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 18),
          Text('正在準備學測字庫…'),
        ],
      ),
    ),
  );
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_rounded, size: 54),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
