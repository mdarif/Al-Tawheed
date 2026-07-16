import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/audio/audio_handler.dart';
import 'package:myapp/audio/player_notifier.dart';
import 'package:myapp/providers/announcements_provider.dart';
import 'package:myapp/providers/app_config_provider.dart';
import 'package:myapp/providers/book_provider.dart';
import 'package:myapp/providers/catalog_provider.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/downloads_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/progress_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/providers/series_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/book_chapter_list_screen.dart';
import 'package:myapp/screens/about_page.dart';
import 'package:myapp/screens/book_reader_screen.dart';
import 'package:myapp/screens/bookmarks_screen.dart';
import 'package:myapp/screens/choose_series_screen.dart';
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
    // Splash / onboarding — shown on cold start.
    // Redirect fires before the widget builds, so returning users never see
    // even a single frame of WelcomeScreen.
    GoRoute(
      path: '/',
      redirect: (context, state) {
        final s = context.read<SeriesProvider>();
        if (!s.shouldShowWelcomeForCurrentSeries) {
          return '/lectures';
        }
        return null;
      },
      builder: (context, state) => const WelcomeScreen(),
    ),

    // Shell: bottom navigation wraps these tabs (series-aware: Book and Study
    // appear only for series that have them).
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/lectures',
          builder: (context, state) => const LectureListScreen(),
        ),
        GoRoute(
          path: '/book',
          redirect: (context, state) =>
              context.read<SeriesProvider>().currentSeries.hasBook
                  ? null
                  : '/lectures',
          builder: (context, state) => const BookChapterListScreen(),
        ),
        GoRoute(
          path: '/study',
          redirect: (context, state) =>
              context.read<SeriesProvider>().currentSeries.hasStudyMode
                  ? null
                  : '/lectures',
          builder: (context, state) => const StudyScreen(),
        ),
        // Settings is a bottom-nav tab (always last), so it lives inside the
        // shell and keeps the nav bar visible. Bookmarks and About remain
        // full-screen pushes from the ⋯ overflow menu below.
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),

    // About — its own full-screen page, split out of Settings and pushed from
    // the About row there (mirrors the al-Quran app).
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/about',
      builder: (context, state) => const AboutPage(),
    ),

    // Series picker — root navigator, full-screen (no bottom nav), shown
    // only to genuinely fresh installs when multi-series is enabled.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/choose-series',
      builder: (context, state) => const ChooseSeriesScreen(),
    ),

    // Bookmarks — root navigator so it opens as a full-screen pushed view
    // (with a back button) from the Saved shortcut on Home, rather than
    // occupying a bottom nav slot.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/bookmarks',
      builder: (context, state) => const BookmarksScreen(),
    ),

    // Offline library — root navigator (same as /player) so pushes from the
    // player sheet or Settings never duplicate ShellRoute page keys.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/offline-library',
      builder: (context, state) => const OfflineLibraryScreen(),
    ),

    // Book reader — root navigator (same as /player) so the bottom nav bar
    // is hidden while reading a chapter.
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/book/:chapterId',
      builder: (context, state) => BookReaderScreen(
        chapterId: state.pathParameters['chapterId']!,
      ),
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
          create: (_) => AppConfigProvider()..load(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => FeatureFlagsProvider()..load(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => AnnouncementsProvider()..load(),
          lazy: false,
        ),
        // SeriesProvider re-resolves whenever the multiSeries flag updates —
        // lazy: false so its currentSeries is ready before the providers
        // below read it.
        ChangeNotifierProxyProvider<FeatureFlagsProvider, SeriesProvider>(
          create: (_) => SeriesProvider()..load(false),
          update: (_, flags, series) {
            series ??= SeriesProvider();
            // definitive only after the async fetch has settled — the
            // initial synchronous update() fires with default values
            // (multiSeriesEnabled=false) before any network data is read.
            series.load(flags.multiSeriesEnabled, definitive: flags.hasLoaded);
            if (flags.multiSeriesEnabled) {
              unawaited(series.loadManifest());
            }
            return series;
          },
          lazy: false,
        ),
        // ConnectivityProvider before CatalogProvider so the catalog can retry
        // its load automatically when the network comes back.
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (ctx) => CatalogProvider(
            ctx.read<SeriesProvider>(),
            ctx.read<ConnectivityProvider>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        // ProgressProvider and DownloadsProvider before PlayerNotifier
        ChangeNotifierProvider(
          create: (ctx) => ProgressProvider(ctx.read<SeriesProvider>())..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => StudyProgressProvider(
            ctx.read<ProgressProvider>(),
            ctx.read<CatalogProvider>(),
            ctx.read<SeriesProvider>(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              DownloadsProvider(ctx.read<SeriesProvider>())..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => PlayerNotifier(
            audioHandler,
            ctx.read<ProgressProvider>(),
            ctx.read<DownloadsProvider>(),
            ctx.read<ConnectivityProvider>(),
            ctx.read<CatalogProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..load(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => ReadingProvider()..load(),
          lazy: false,
        ),
        // Depends on SeriesProvider so the active edition can supply the
        // default chrome language (Arabic edition ⇒ Arabic UI). An explicit
        // pick still wins — see LanguageProvider.language / ADR-0002.
        ChangeNotifierProxyProvider2<FeatureFlagsProvider, SeriesProvider,
            LanguageProvider>(
          create: (_) => LanguageProvider()..load(),
          update: (_, flags, series, lang) {
            lang ??= LanguageProvider()..load();
            lang.applyLanguageFeatureFlag(flags.features.language);
            lang.applySeriesDefault(series.currentSeries);
            return lang;
          },
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) =>
            MaterialApp.router(
          title: 'Sharah Kitab at-Tawheed',
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
