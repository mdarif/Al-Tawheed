import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/navigation/missing_edition_refresh.dart';
import 'package:myapp/navigation/route_guards.dart';
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
import 'package:myapp/providers/shell_chrome_provider.dart';
import 'package:myapp/providers/study_progress_provider.dart';
import 'package:myapp/providers/reading_provider.dart';
import 'package:myapp/providers/theme_provider.dart';
import 'package:myapp/screens/read_screen.dart';
import 'package:myapp/screens/about_page.dart';
import 'package:myapp/screens/book_reader_screen.dart';
import 'package:myapp/screens/choose_series_screen.dart';
import 'package:myapp/screens/edition_missing_screen.dart';
import 'package:myapp/screens/lecture_list_screen.dart';
import 'package:myapp/screens/lecture_search_screen.dart';
import 'package:myapp/screens/library_screen.dart';
import 'package:myapp/screens/player_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/screens/study_class_complete_screen.dart';
import 'package:myapp/screens/shell_screen.dart';
import 'package:myapp/screens/welcome.dart';
import 'package:myapp/theme/app_theme.dart';

// Root navigator key — required so /player opens on the root navigator,
// not the shell's nested navigator. Without this, context.push('/player')
// from within ShellRoute throws because /player is not a shell-level route.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _lecturesNavigatorKey = GlobalKey<NavigatorState>();
final _readNavigatorKey = GlobalKey<NavigatorState>();
final _libraryNavigatorKey = GlobalKey<NavigatorState>();
final _settingsNavigatorKey = GlobalKey<NavigatorState>();

/// Builds the route graph shared by the app and widget-level route tests.
///
/// Keeping this in one place ensures tests exercise the production branch
/// navigator keys and capability redirects instead of a smaller substitute.
///
/// While the saved edition is missing from the manifest (BLK-06) the top-level
/// redirect confines the app to `/edition-missing` and `/choose-series`.
/// Pass [refreshListenable] (a [MissingEditionRefresh]) so that guard also
/// re-runs when the edition goes missing *after* launch, not just on
/// navigation.
GoRouter createAppRouter({
  String initialLocation = '/',
  Listenable? refreshListenable,
}) =>
    GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initialLocation,
      refreshListenable: refreshListenable,
      redirect: (context, state) => RouteGuards.missingEdition(
        isMissing: context.read<SeriesProvider>().hasMissingSelectedSeries,
        path: state.uri.path,
      ),
      routes: [
        // Splash / onboarding — shown on cold start.
        // Redirect fires before the widget builds, so returning users never see
        // even a single frame of WelcomeScreen.
        GoRoute(
          path: '/',
          redirect: (context, state) => RouteGuards.welcome(
            shouldShowWelcome: context
                .read<SeriesProvider>()
                .shouldShowWelcomeForCurrentSeries,
          ),
          builder: (context, state) => const WelcomeScreen(),
        ),

        // Indexed branches preserve each destination's scroll and nested state.
        // Their order mirrors SeriesNavigationPolicy for the shipped capabilities.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ShellScreen(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              navigatorKey: _lecturesNavigatorKey,
              routes: [
                GoRoute(
                  path: '/lectures',
                  builder: (context, state) => const LectureListScreen(),
                  routes: [
                    // Search lives INSIDE the Lectures branch so the bottom nav
                    // and mini-player stay visible; it pops a chapter id back
                    // to Lectures for "Go to class".
                    GoRoute(
                      path: 'search',
                      builder: (context, state) => const LectureSearchScreen(),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _readNavigatorKey,
              routes: [
                GoRoute(
                  path: '/read',
                  redirect: (context, state) => RouteGuards.read(
                    context.read<SeriesProvider>().currentSeries,
                  ),
                  // `?tab=book|study` selects the tab (Study completion links
                  // to `?tab=study`).
                  builder: (context, state) => ReadScreen(
                    initialTab: ReadTab.fromQuery(
                      state.uri.queryParameters['tab'],
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _libraryNavigatorKey,
              routes: [
                // `?tab=bookmarks|downloads` selects the tab (the offline banner
                // links to `?tab=downloads`).
                GoRoute(
                  path: '/library',
                  builder: (context, state) => LibraryScreen(
                    initialTab: LibraryTab.fromQuery(
                      state.uri.queryParameters['tab'],
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _settingsNavigatorKey,
              routes: [
                // Settings is a bottom-nav tab (always last), so it lives inside the
                // shell and keeps the nav bar visible. About remains a full-screen
                // push.
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
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

        // Shown instead of silently substituting Urdu when the saved edition
        // isn't in the loaded manifest (BLK-06). The top-level redirect above
        // sends every other route here while that holds.
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/edition-missing',
          builder: (context, state) => const EditionMissingScreen(),
        ),

        // Legacy collection routes — kept on the root navigator (same as
        // /player) because Player, Settings and the offline sheet push them and
        // Back must return to the pusher; pushing the shell's /library there
        // would duplicate ShellRoute page keys. They are adapters, not separate
        // screens: the same LibraryScreen as the shell tab, on the matching tab.
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/bookmarks',
          builder: (context, state) => const LibraryScreen(
            initialTab: LibraryTab.bookmarks,
            standalone: true,
          ),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/offline-library',
          builder: (context, state) => const LibraryScreen(
            initialTab: LibraryTab.downloads,
            standalone: true,
          ),
        ),

        // Book reader — root navigator (same as /player) so the bottom nav bar
        // is hidden while reading a chapter.
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/book/:chapterId',
          builder: (context, state) => BookReaderScreen(
            chapterId: state.pathParameters['chapterId']!,
            startFromTop: state.uri.queryParameters['startFromTop'] == 'true',
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
        // Study completion — root navigator, over the shell. Its "Back to
        // overview" goes to `/read?tab=study`: there is no `/study` route,
        // Book and Study share the Read destination.
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/study/complete',
          // Without a chapter there is nothing to celebrate: go to Study.
          redirect: (context, state) {
            final chapterId = state.uri.queryParameters['chapterId'];
            return chapterId == null || chapterId.isEmpty
                ? '/read?tab=study'
                : null;
          },
          builder: (context, state) => StudyClassCompleteScreen(
            chapterId: state.uri.queryParameters['chapterId']!,
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
        // Must precede DownloadsProvider, which posts the download
        // notification in the chrome language. Depends on SeriesProvider so
        // the active edition can supply the default chrome language (Arabic
        // edition ⇒ Arabic UI). An explicit pick still wins — see
        // LanguageProvider.language / ADR-0002.
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
        ChangeNotifierProvider(
          create: (ctx) => DownloadsProvider(
            ctx.read<SeriesProvider>(),
            ctx.read<ConnectivityProvider>(),
            ctx.read<LanguageProvider>(),
          )..load(),
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
          create: (ctx) => ReadingProvider(ctx.read<SeriesProvider>())..load(),
          lazy: false,
        ),
        ChangeNotifierProvider(create: (_) => ShellChromeProvider()),
      ],
      child: const _AppView(),
    );
  }
}

/// Owns the router. It lives below the provider tree, in State, so it is
/// created once (never on rebuild) yet can listen to [SeriesProvider] for the
/// BLK-06 missing-edition redirect.
class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final MissingEditionRefresh _missingEdition;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _missingEdition = MissingEditionRefresh(context.read<SeriesProvider>());
    _router = createAppRouter(refreshListenable: _missingEdition);
  }

  @override
  void dispose() {
    _router.dispose();
    _missingEdition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, langProvider, _) => MaterialApp.router(
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
          // MaterialApp swaps theme/darkTheme instantly with no transition,
          // which reads as a hard flash when the system or in-app toggle
          // changes it. AnimatedTheme crossfades the resolved ThemeData
          // across rebuilds instead.
          return AnimatedTheme(
            data: Theme.of(context),
            duration: const Duration(milliseconds: 200),
            child: Directionality(
              textDirection:
                  langProvider.isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
