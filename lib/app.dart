import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/theme/app_theme.dart';

// Router is a top-level singleton — created once, never recreated on rebuild.
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // Splash / onboarding — shown on cold start
    GoRoute(
      path: '/',
      builder: (context, state) => WelcomeScreen(),
    ),

    // Shell: bottom navigation wraps these four tabs
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/lectures',
          builder: (context, state) => const LectureListScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/bookmarks',
          builder: (context, state) => const BookmarksScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),

    // Full-screen player — outside shell so bottom nav hides
    GoRoute(
      path: '/player',
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: PlayerScreen(),
      ),
    ),
  ],
);

class MyApp extends StatelessWidget {
  final TawheedAudioHandler audioHandler;
  const MyApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => PlayerNotifier(audioHandler)),
      ],
      child: MaterialApp.router(
        title: 'Sharah Kitab al-Tawheed',
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
      ),
    );
  }
}
