import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/screens/offline_library_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/study_class_complete_screen.dart';
import 'package:myapp/screens/study_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/theme/app_theme.dart';

// Root navigator key — required so /player opens on the root navigator,
// not the shell's nested navigator. Without this, context.push('/player')
// from within ShellRoute throws because /player is not a shell-level route.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Router is a top-level singleton — created once, never recreated on rebuild.
final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
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

    // Offline library — root navigator (same as /player) so pushes from the
    // player sheet or Settings never duplicate ShellRoute page keys.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/offline-library',
      builder: (context, state) => const OfflineLibraryScreen(),
    ),

    // Full-screen player — parentNavigatorKey forces it onto the root
    // navigator so the bottom nav bar is hidden behind the player.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/player',
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: PlayerScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/study',
      builder: (context, state) => const StudyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/study/complete',
      builder: (context, state) {
        final chapterId = state.uri.queryParameters['chapterId'];
        if (chapterId == null || chapterId.isEmpty) {
          return const StudyScreen();
        }
        return StudyClassCompleteScreen(chapterId: chapterId);
      },
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
        // Remote content — load eagerly (lazy: false) so fetches start at startup
        ChangeNotifierProvider(
            create: (_) => AppConfigProvider()..load(), lazy: false),
        ChangeNotifierProvider(
            create: (_) => FeatureFlagsProvider()..load(), lazy: false),
        ChangeNotifierProvider(
            create: (_) => AnnouncementsProvider()..load(), lazy: false),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        // ProgressProvider and DownloadsProvider before PlayerNotifier
        ChangeNotifierProvider(create: (_) => ProgressProvider()..load()),
        ChangeNotifierProvider(
          create: (ctx) => StudyProgressProvider(
            ctx.read<ProgressProvider>(),
            ctx.read<CatalogProvider>(),
          )..load(),
        ),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()..load()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (ctx) => PlayerNotifier(
            audioHandler,
            ctx.read<ProgressProvider>(),
            ctx.read<DownloadsProvider>(),
            ctx.read<ConnectivityProvider>(),
          ),
        ),
        ChangeNotifierProvider(
            create: (_) => ThemeProvider()..load(), lazy: false),
        ChangeNotifierProxyProvider<FeatureFlagsProvider, LanguageProvider>(
          create: (_) => LanguageProvider()..load(),
          update: (_, flags, lang) {
            lang ??= LanguageProvider()..load();
            lang.applyLanguageFeatureFlag(flags.features.language);
            return lang;
          },
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) =>
            MaterialApp.router(
          title: 'Sharah Kitab al-Tawheed',
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
          locale: langProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return Directionality(
              textDirection:
                  langProvider.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
