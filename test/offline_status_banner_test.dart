import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/providers/connectivity_provider.dart';
import 'package:myapp/providers/feature_flags_provider.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/testing/widget_keys.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/offline_status_banner.dart';
import 'package:provider/provider.dart';

void main() {
  Widget wrap({
    required bool downloadsEnabled,
    required bool isOffline,
  }) {
    final flags = FeatureFlagsProvider()
      ..setFeaturesJsonForTest({'downloads': downloadsEnabled});

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) => isOffline
              ? ConnectivityProvider.testOffline()
              : ConnectivityProvider.testOnline(),
        ),
        ChangeNotifierProvider<FeatureFlagsProvider>.value(value: flags),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/lectures',
          routes: [
            GoRoute(
              path: '/lectures',
              builder: (_, __) => const Scaffold(
                body: Column(
                  children: [
                    OfflineStatusBanner(),
                    Expanded(child: Center(child: Text('Lectures'))),
                  ],
                ),
              ),
            ),
            GoRoute(
              path: '/library',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('Library'))),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('banner hidden when online', (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: false));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.offlineStatusBanner), findsNothing);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('banner shown when offline and downloads enabled',
      (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.offlineStatusBanner), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('banner hidden when downloads feature off', (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: false, isOffline: true));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.offlineStatusBanner), findsNothing);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('tapping the banner opens Library (IMP-05)', (tester) async {
    await tester.pumpWidget(wrap(downloadsEnabled: true, isOffline: true));
    await tester.pumpAndSettle();

    expect(find.text('View Library'), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.offlineStatusBanner));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Lectures'), findsNothing);
  });
}
